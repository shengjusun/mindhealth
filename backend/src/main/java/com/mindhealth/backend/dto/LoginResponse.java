package com.mindhealth.backend.dto;

import lombok.Data;

@Data
public class LoginResponse {
    private String token;
    private String refreshToken;
    private UserInfo userInfo;

    @Data
    public static class UserInfo {
        private Long id;
        private String phone;
        private String nickname;
        private String avatar;
    }
}