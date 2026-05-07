package com.mindhealth.backend.dto;

import lombok.Data;

@Data
public class AssessmentRequest {
    private Long assessmentId;
    private Integer score;
}