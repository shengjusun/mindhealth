package com.mindhealth.backend.service;

import com.mindhealth.backend.dto.AssessmentRequest;
import com.mindhealth.backend.entity.Assessment;
import com.mindhealth.backend.entity.AssessmentResult;

import java.util.List;

public interface AssessmentService {
    List<Assessment> getAssessmentList();
    Assessment getAssessmentById(Long id);
    AssessmentResult submitAssessment(Long userId, AssessmentRequest request);
    List<AssessmentResult> getAssessmentResults(Long userId);

    /** 单条结果（用于轮询 AI 解读）；不属于该用户时返回 null */
    AssessmentResult getAssessmentResult(Long userId, Long id);
}
