package com.mindhealth.backend.service.impl;

import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.mindhealth.backend.dto.AIChatRequest;
import com.mindhealth.backend.dto.AIChatResponse;
import com.mindhealth.backend.entity.AIChat;
import com.mindhealth.backend.mapper.AIChatMapper;
import com.mindhealth.backend.service.AIService;
import com.mindhealth.backend.service.DeepSeekClient;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

@Service
public class AIServiceImpl implements AIService {

    private static final Logger log = LoggerFactory.getLogger(AIServiceImpl.class);

    /** 心理健康陪伴场景 system prompt */
    private static final String SYSTEM_PROMPT = "你是轻心，一位温和、有耐心的心理健康陪伴者。你倾听用户的情绪，用共情的语言回应，必要时给出简单的情绪调节建议。你不做医学诊断，不开药，遇到严重心理危机（自伤、自杀倾向）时建议用户联系专业机构或拨打心理援助热线。回复控制在 200 字以内。";

    /** 随每次请求携带的历史轮数（一轮 = 一条用户输入 + 一条 AI 回复） */
    private static final int HISTORY_ROUNDS = 10;

    /** 聊天回复的生成参数 */
    private static final int CHAT_MAX_TOKENS = 500;
    private static final double CHAT_TEMPERATURE = 0.7;

    /** 限流窗口：每用户每分钟最多 10 次 /ai/chat */
    private static final long RATE_WINDOW_MS = 60_000L;
    private static final int RATE_LIMIT_PER_MINUTE = 10;

    /** 滑动窗口：userId -> 窗口内的请求时间戳 */
    private final Map<Long, List<Long>> chatTimestamps = new ConcurrentHashMap<>();

    /** 定期清掉窗口外的时间戳和空 key，避免 map 随历史用户数无限膨胀 */
    private final ScheduledExecutorService rateLimitCleaner = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread thread = new Thread(r, "ai-chat-rate-cleaner");
        thread.setDaemon(true);
        return thread;
    });

    @Autowired
    private AIChatMapper aiChatMapper;

    /** HTTP 调用与错误码处理已抽到 DeepSeekClient，测评分析复用同一份 */
    @Autowired
    private DeepSeekClient deepSeekClient;

    @PostConstruct
    public void startRateLimitCleaner() {
        log.info("DeepSeek 配置: model={}, configured={}",
                deepSeekClient.getModel(), deepSeekClient.isConfigured());
        rateLimitCleaner.scheduleAtFixedRate(this::cleanExpiredTimestamps, 1, 1, TimeUnit.MINUTES);
    }

    @PreDestroy
    public void stopRateLimitCleaner() {
        rateLimitCleaner.shutdownNow();
    }

    @Override
    public AIChatResponse chat(Long userId, AIChatRequest request) {
        checkRateLimit(userId);

        String userContent = request.getContent() == null ? "" : request.getContent();
        String response = deepSeekClient.complete(
                buildMessages(userId, userContent), CHAT_MAX_TOKENS, CHAT_TEMPERATURE);

        // 先拿到真实回复再落库；调用失败会在 complete 内抛异常，不会把错误信息写进 ai_chat
        AIChat aiChat = new AIChat();
        aiChat.setUserId(userId);
        aiChat.setContent(userContent);
        aiChat.setAiResponse(response);
        aiChat.setCreateTime(LocalDateTime.now());
        aiChatMapper.insert(aiChat);

        AIChatResponse chatResponse = new AIChatResponse();
        chatResponse.setResponse(response);

        recordRate(userId);
        return chatResponse;
    }

    @Override
    public List<AIChat> getChatHistory(Long userId) {
        return aiChatMapper.selectByUserId(userId);
    }

    @Override
    public void deleteChatHistory(Long userId) {
        aiChatMapper.delete(new QueryWrapper<AIChat>().eq("user_id", userId));
    }

    // ------------------------------------------------------------------ 限流

    /** 入口检查：清理窗口外时间戳后判断是否超限，超限抛业务异常 */
    private void checkRateLimit(Long userId) {
        long now = System.currentTimeMillis();
        List<Long> stamps = chatTimestamps.computeIfAbsent(userId, k -> new ArrayList<>());
        synchronized (stamps) {
            stamps.removeIf(t -> now - t > RATE_WINDOW_MS);
            if (stamps.size() >= RATE_LIMIT_PER_MINUTE) {
                throw new RuntimeException("请求过于频繁，请稍后再试");
            }
        }
    }

    /** 请求成功后记录时间戳（失败的请求不计入限流窗口） */
    private void recordRate(Long userId) {
        long now = System.currentTimeMillis();
        List<Long> stamps = chatTimestamps.computeIfAbsent(userId, k -> new ArrayList<>());
        synchronized (stamps) {
            stamps.add(now);
        }
    }

    private void cleanExpiredTimestamps() {
        long now = System.currentTimeMillis();
        chatTimestamps.entrySet().removeIf(entry -> {
            List<Long> stamps = entry.getValue();
            synchronized (stamps) {
                stamps.removeIf(t -> now - t > RATE_WINDOW_MS);
                return stamps.isEmpty();
            }
        });
    }

    // ------------------------------------------------------------------ 请求组装

    /** system prompt + 最近 10 轮历史（create_time 升序，每轮拆 user/assistant）+ 本次输入 */
    private JSONArray buildMessages(Long userId, String userContent) {
        JSONArray messages = new JSONArray();

        JSONObject system = new JSONObject();
        system.set("role", "system");
        system.set("content", SYSTEM_PROMPT);
        messages.add(system);

        for (AIChat row : recentHistory(userId)) {
            JSONObject user = new JSONObject();
            user.set("role", "user");
            user.set("content", row.getContent());
            messages.add(user);

            JSONObject assistant = new JSONObject();
            assistant.set("role", "assistant");
            assistant.set("content", row.getAiResponse());
            messages.add(assistant);
        }

        JSONObject current = new JSONObject();
        current.set("role", "user");
        current.set("content", userContent);
        messages.add(current);

        return messages;
    }

    /** 最近 10 轮历史，按 create_time 升序返回 */
    private List<AIChat> recentHistory(Long userId) {
        List<AIChat> rows = aiChatMapper.selectList(new QueryWrapper<AIChat>()
                .eq("user_id", userId)
                .orderByDesc("create_time")
                .last("LIMIT " + HISTORY_ROUNDS));
        Collections.reverse(rows);
        return rows;
    }
}
