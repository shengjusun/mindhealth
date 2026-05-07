package com.mindhealth.backend.dto;

import lombok.Data;

@Data
public class DiaryRequest {
    private String title;
    private String content;
    private String emotion;
    private Integer intensity;
    private String event;
}