package com.mindhealth.backend.dto;

import lombok.Data;

/**
 * 华为账号登录请求：前端 Account Kit 授权后拿到的一次性 authorizationCode
 */
@Data
public class HuaweiLoginRequest {
    private String authorizationCode;
}
