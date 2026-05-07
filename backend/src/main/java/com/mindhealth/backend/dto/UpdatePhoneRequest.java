package com.mindhealth.backend.dto;

import lombok.Data;

@Data
public class UpdatePhoneRequest {
    private String newPhone;
    private String code;
}
