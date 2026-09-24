package com.mindhealth.backend.service;

import com.mindhealth.backend.dto.LoginRequest;
import com.mindhealth.backend.dto.LoginResponse;
import com.mindhealth.backend.dto.RegisterRequest;
import com.mindhealth.backend.entity.User;

public interface UserService {
    LoginResponse login(LoginRequest request);
    LoginResponse loginWithHuaweiId(String authorizationCode);
    void register(RegisterRequest request);
    User getUserByPhone(String phone);
    User getUserById(Long id);
    void updateUser(User user);
    void updatePhone(Long userId, String newPhone, String code);
}