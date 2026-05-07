package com.mindhealth.backend.service;

import com.mindhealth.backend.dto.AIChatRequest;
import com.mindhealth.backend.dto.AIChatResponse;
import com.mindhealth.backend.entity.AIChat;

import java.util.List;

public interface AIService {
    AIChatResponse chat(Long userId, AIChatRequest request);
    List<AIChat> getChatHistory(Long userId);
    void deleteChatHistory(Long userId);
}