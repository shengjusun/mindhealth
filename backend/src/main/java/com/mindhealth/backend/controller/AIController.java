package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.AIChatRequest;
import com.mindhealth.backend.dto.AIChatResponse;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.service.AIService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/ai")
public class AIController {

    @Autowired
    private AIService aiService;

    @PostMapping("/chat")
    public ApiResponse<AIChatResponse> chat(@RequestAttribute("userId") Long userId, @RequestBody AIChatRequest request) {
        return ApiResponse.success(aiService.chat(userId, request));
    }

    @GetMapping("/history")
    public ApiResponse<Object> getChatHistory(@RequestAttribute("userId") Long userId) {
        // 包统一响应体：客户端按 {code, data} 解析，裸返回会导致历史永远加载不出（审计 B-01）
        return ApiResponse.success(aiService.getChatHistory(userId));
    }

    @DeleteMapping("/history")
    public ApiResponse<Object> deleteChatHistory(@RequestAttribute("userId") Long userId) {
        aiService.deleteChatHistory(userId);
        // 返回可解析的空成功包体：void 空响应体在客户端 JSON.parse 会抛错、误报失败
        return ApiResponse.success(true);
    }
}