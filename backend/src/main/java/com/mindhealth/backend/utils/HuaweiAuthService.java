package com.mindhealth.backend.utils;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;

/**
 * 华为账号（Account Kit / Login Kit）服务端凭证处理：
 * 用前端传来的 authorizationCode 到华为 OAuth 端点换取 id_token，
 * 解析出 openID / unionID，作为本系统账号的第三方标识。
 */
@Slf4j
@Component
public class HuaweiAuthService {

    private static final String DEFAULT_TOKEN_URL = "https://oauth-login.cloud.huawei.com/oauth2/v3/token";

    @Value("${huawei.client-id:}")
    private String clientId;

    @Value("${huawei.client-secret:}")
    private String clientSecret;

    @Value("${huawei.token-url:" + DEFAULT_TOKEN_URL + "}")
    private String tokenUrl;

    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Data
    public static class HuaweiUserInfo {
        private String openId;
        private String unionId;
        private String nickname;
        private String avatarUrl;
    }

    /**
     * 一次性 authorizationCode 换取用户标识
     */
    public HuaweiUserInfo exchangeCode(String authorizationCode) {
        if (authorizationCode == null || authorizationCode.trim().isEmpty()) {
            throw new RuntimeException("authorizationCode 不能为空");
        }
        if (clientId == null || clientId.isEmpty() || clientSecret == null || clientSecret.isEmpty()) {
            throw new RuntimeException("华为登录未配置，请在服务端环境变量中设置 HUAWEI_CLIENT_ID / HUAWEI_CLIENT_SECRET");
        }

        String form = "grant_type=authorization_code"
                + "&code=" + urlEncode(authorizationCode.trim())
                + "&client_id=" + urlEncode(clientId)
                + "&client_secret=" + urlEncode(clientSecret);

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(tokenUrl))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .timeout(Duration.ofSeconds(15))
                .POST(HttpRequest.BodyPublishers.ofString(form))
                .build();

        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() != 200) {
                log.error("华为 token 接口返回 {}: {}", response.statusCode(), response.body());
                throw new RuntimeException("华为登录凭证校验失败");
            }

            JsonNode body = objectMapper.readTree(response.body());
            String idToken = body.path("id_token").asText(null);
            if (idToken == null || idToken.isEmpty()) {
                log.error("华为 token 接口未返回 id_token: {}", response.body());
                throw new RuntimeException("华为登录凭证校验失败");
            }
            return parseIdToken(idToken);
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            log.error("请求华为 token 接口异常: {}", e.getMessage());
            throw new RuntimeException("华为登录服务暂时不可用");
        }
    }

    /**
     * 解析 id_token 的 payload 段（生产环境建议额外做公钥验签）
     */
    private HuaweiUserInfo parseIdToken(String idToken) throws Exception {
        String[] parts = idToken.split("\\.");
        if (parts.length < 2) {
            throw new RuntimeException("id_token 格式错误");
        }
        byte[] payload = Base64.getUrlDecoder().decode(parts[1]);
        JsonNode claims = objectMapper.readTree(new String(payload, StandardCharsets.UTF_8));

        HuaweiUserInfo info = new HuaweiUserInfo();
        String sub = claims.path("sub").asText(null);
        if (sub == null || sub.isEmpty()) {
            throw new RuntimeException("id_token 缺少 sub");
        }
        info.setOpenId(sub);
        // union_id 缺失时退化为 sub，保证账号主键可用
        String unionId = claims.path("union_id").asText("");
        info.setUnionId(unionId.isEmpty() ? sub : unionId);
        info.setNickname(claims.path("name").asText(""));
        info.setAvatarUrl(claims.path("picture").asText(""));
        return info;
    }

    private String urlEncode(String value) {
        return java.net.URLEncoder.encode(value, StandardCharsets.UTF_8);
    }
}
