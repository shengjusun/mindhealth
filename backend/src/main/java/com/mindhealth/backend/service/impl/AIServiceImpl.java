package com.mindhealth.backend.service.impl;

import com.mindhealth.backend.dto.AIChatRequest;
import com.mindhealth.backend.dto.AIChatResponse;
import com.mindhealth.backend.entity.AIChat;
import com.mindhealth.backend.mapper.AIChatMapper;
import com.mindhealth.backend.service.AIService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class AIServiceImpl implements AIService {

    @Autowired
    private AIChatMapper aiChatMapper;

    @Override
    public AIChatResponse chat(Long userId, AIChatRequest request) {
        // 模拟AI回复
        String response = "我理解你的感受。" + request.getContent() + "，这确实是一个需要关注的问题。你可以尝试一些放松的方法，比如深呼吸、冥想或者做一些你喜欢的事情。如果需要进一步的支持，我会一直在这里倾听你。";

        // 保存对话记录
        AIChat aiChat = new AIChat();
        aiChat.setUserId(userId);
        aiChat.setContent(request.getContent());
        aiChat.setAiResponse(response);
        aiChat.setCreateTime(LocalDateTime.now());
        aiChatMapper.insert(aiChat);

        AIChatResponse chatResponse = new AIChatResponse();
        chatResponse.setResponse(response);
        return chatResponse;
    }

    @Override
    public List<AIChat> getChatHistory(Long userId) {
        return aiChatMapper.selectByUserId(userId);
    }

    @Override
    public void deleteChatHistory(Long userId) {
        // 这里应该实现删除用户的聊天记录
        // 由于使用MyBatis-Plus，这里可以使用条件删除
    }
}