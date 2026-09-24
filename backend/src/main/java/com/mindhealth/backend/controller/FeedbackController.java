package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.Feedback;
import com.mindhealth.backend.mapper.FeedbackMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

@RestController
@RequestMapping("/feedback")
public class FeedbackController {

    private static final int CONTENT_MAX_LENGTH = 1000;

    @Autowired
    private FeedbackMapper feedbackMapper;

    /**
     * 提交反馈（需登录）
     * 请求体: { "type": "bug|suggestion|other", "content": "...", "contact": "选填" }
     */
    @PostMapping
    public ApiResponse<Object> submitFeedback(@RequestAttribute("userId") Long userId,
                                              @RequestBody Map<String, String> body) {
        String content = body.get("content") == null ? "" : body.get("content").trim();
        if (content.isEmpty()) {
            throw new RuntimeException("反馈内容不能为空");
        }
        if (content.length() > CONTENT_MAX_LENGTH) {
            throw new RuntimeException("反馈内容最多 " + CONTENT_MAX_LENGTH + " 字");
        }

        String type = body.get("type") == null || body.get("type").trim().isEmpty()
                ? "suggestion" : body.get("type").trim();
        if (!type.matches("^(bug|suggestion|other)$")) {
            type = "other";
        }

        Feedback feedback = new Feedback();
        feedback.setUserId(userId);
        feedback.setType(type);
        feedback.setContent(content);
        feedback.setContact(body.get("contact") == null ? null : body.get("contact").trim());
        feedback.setCreateTime(LocalDateTime.now());
        feedbackMapper.insert(feedback);

        return ApiResponse.success(true);
    }
}
