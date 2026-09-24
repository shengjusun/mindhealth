package com.mindhealth.backend.dto;

import lombok.Data;

/**
 * 用户资料更新请求：白名单字段，防止越权修改 phone/deleted 等
 */
@Data
public class UpdateUserRequest {
    private String nickname;
    private Integer age;
    private String gender;
    private String avatar;
    private String signature;
}
