package com.mindhealth.backend.service;

import cn.hutool.core.io.IORuntimeException;
import cn.hutool.http.HttpException;
import cn.hutool.http.HttpRequest;
import cn.hutool.http.HttpResponse;
import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import cn.hutool.json.JSONUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.SocketTimeoutException;

/**
 * DeepSeek Chat Completions 客户端。
 *
 * <p>从 {@code AIServiceImpl} 里抽出来，让「AI 聊天」和「测评分析」共用同一套调用与错误处理：
 * 401 配置错误 / 402 额度不足 / 429 与 5xx 退避重试一次 / 超时与 IO 异常分别归类。
 * 之前这段逻辑写在聊天服务内部，测评要用只能复制一份，迟早出现两套不一样的错误码处理。
 */
@Component
public class DeepSeekClient {

    private static final Logger log = LoggerFactory.getLogger(DeepSeekClient.class);

    @Value("${deepseek.api-url:}")
    private String apiUrl;

    @Value("${deepseek.api-key:}")
    private String apiKey;

    @Value("${deepseek.model:deepseek-chat}")
    private String model;

    @Value("${deepseek.timeout-ms:60000}")
    private int timeoutMs;

    public String getModel() {
        return model;
    }

    public boolean isConfigured() {
        return apiUrl != null && !apiUrl.isBlank() && apiKey != null && !apiKey.isBlank();
    }

    /**
     * 单次补全调用。messages 由调用方拼好（system + 上下文 + 本次输入）。
     *
     * @throws RuntimeException 任何失败都会抛出**面向用户可读**的中文提示
     */
    public String complete(JSONArray messages, int maxTokens, double temperature) {
        if (!isConfigured()) {
            throw new RuntimeException("AI 服务配置错误，请联系管理员");
        }

        String requestBody = buildBody(messages, maxTokens, temperature);

        for (int attempt = 0; attempt < 2; attempt++) {
            if (attempt > 0) {
                try {
                    Thread.sleep(500);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    throw new RuntimeException("AI 服务暂时不可用");
                }
            }
            try (HttpResponse response = post(requestBody)) {
                int status = response.getStatus();
                if (status == 200) {
                    return parseContent(response.body());
                }
                if (status == 401) {
                    log.warn("DeepSeek 返回 401，请检查 api-key");
                    throw new RuntimeException("AI 服务配置错误，请联系管理员");
                }
                if (status == 402) {
                    log.warn("DeepSeek 返回 402，额度不足");
                    throw new RuntimeException("AI 服务额度不足");
                }
                if (status == 429 || status >= 500) {
                    log.warn("DeepSeek 返回 {}，attempt={}", status, attempt);
                    if (attempt == 0) {
                        continue;
                    }
                    throw new RuntimeException("AI 服务繁忙，请稍后重试");
                }
                log.warn("DeepSeek 返回异常状态 {} : {}", status, response.body());
                throw new RuntimeException("AI 服务暂时不可用");
            } catch (IORuntimeException e) {
                if (isTimeout(e)) {
                    log.warn("DeepSeek 请求超时: {}", e.getMessage());
                    throw new RuntimeException("AI 服务响应超时，请稍后重试");
                }
                log.warn("DeepSeek 请求 IO 异常: {}", e.getMessage());
                throw new RuntimeException("AI 服务暂时不可用");
            } catch (HttpException e) {
                log.warn("DeepSeek 请求异常: {}", e.getMessage());
                throw new RuntimeException("AI 服务暂时不可用");
            }
        }
        throw new RuntimeException("AI 服务繁忙，请稍后重试");
    }

    // ------------------------------------------------------------------ 私有方法

    private String buildBody(JSONArray messages, int maxTokens, double temperature) {
        JSONObject body = new JSONObject();
        body.set("model", model);
        body.set("messages", messages);
        body.set("temperature", temperature);
        body.set("max_tokens", maxTokens);
        body.set("stream", false);
        return body.toString();
    }

    private HttpResponse post(String requestBody) {
        return HttpRequest.post(apiUrl)
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .body(requestBody)
                .timeout(timeoutMs)
                .execute();
    }

    /** 取 choices[0].message.content */
    private String parseContent(String responseBody) {
        String content = null;
        try {
            JSONArray choices = JSONUtil.parseObj(responseBody).getJSONArray("choices");
            if (choices != null && !choices.isEmpty()) {
                content = choices.getJSONObject(0)
                        .getJSONObject("message")
                        .getStr("content");
            }
        } catch (Exception e) {
            log.warn("DeepSeek 响应解析失败: {}", e.getMessage());
        }
        if (content == null || content.trim().isEmpty()) {
            throw new RuntimeException("AI 服务暂时不可用");
        }
        return content;
    }

    /** hutool 把 IO 异常包成 IORuntimeException，沿 cause 链找 SocketTimeoutException 判定超时 */
    private boolean isTimeout(IORuntimeException e) {
        Throwable cause = e.getCause();
        while (cause != null) {
            if (cause instanceof SocketTimeoutException) {
                return true;
            }
            cause = cause.getCause();
        }
        return false;
    }
}
