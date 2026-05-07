package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.AIChatRequest;
import com.mindhealth.backend.dto.AIChatResponse;
import com.mindhealth.backend.service.AIService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/ai")
public class AIController {

    @Autowired
    private AIService aiService;

    @PostMapping("/chat")
    public AIChatResponse chat(@RequestAttribute("userId") Long userId, @RequestBody AIChatRequest request) {
        return aiService.chat(userId, request);
    }

    @GetMapping("/history")
    public Object getChatHistory(@RequestAttribute("userId") Long userId) {
        return aiService.getChatHistory(userId);
    }

    @DeleteMapping("/history")
    public void deleteChatHistory(@RequestAttribute("userId") Long userId) {
        aiService.deleteChatHistory(userId);
    }
}