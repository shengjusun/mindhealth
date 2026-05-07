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
}