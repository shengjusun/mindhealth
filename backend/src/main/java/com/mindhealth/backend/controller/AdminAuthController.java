package com.mindhealth.backend.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.Admin;
import com.mindhealth.backend.mapper.AdminMapper;
import com.mindhealth.backend.utils.JwtUtils;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * Web 管理后台登录
 */
@RestController
@RequestMapping("/admin")
public class AdminAuthController {

    @Autowired
    private AdminMapper adminMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtils jwtUtils;

    @Data
    public static class AdminLoginRequest {
        private String username;
        private String password;
    }

    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody AdminLoginRequest request) {
        String username = request.getUsername() == null ? "" : request.getUsername().trim();
        String password = request.getPassword() == null ? "" : request.getPassword();

        if (username.isEmpty() || password.isEmpty()) {
            throw new RuntimeException("用户名和密码不能为空");
        }

        Admin admin = adminMapper.selectOne(new QueryWrapper<Admin>().eq("username", username));
        if (admin == null || !passwordEncoder.matches(password, admin.getPassword())) {
            throw new RuntimeException("用户名或密码错误");
        }

        String token = jwtUtils.generateAdminToken(admin.getId());

        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("username", admin.getUsername());
        data.put("role", admin.getRole());
        return ApiResponse.success(data);
    }
}
