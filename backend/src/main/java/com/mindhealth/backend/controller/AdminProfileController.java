package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.Admin;
import com.mindhealth.backend.mapper.AdminMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * 管理员个人资料：查看当前登录管理员信息 + 修改密码
 * 依赖 JwtAuthenticationFilter 注入的 request attribute "adminId"
 */
@RestController
@RequestMapping("/admin")
public class AdminProfileController {

    @Autowired
    private AdminMapper adminMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    /** 取当前登录管理员，未登录或令牌失效直接拒绝 */
    private Admin currentAdmin(HttpServletRequest request) {
        Object attr = request.getAttribute("adminId");
        if (attr == null) {
            throw new RuntimeException("登录已失效，请重新登录");
        }
        Long adminId;
        try {
            adminId = Long.valueOf(attr.toString());
        } catch (NumberFormatException e) {
            throw new RuntimeException("登录状态异常，请重新登录");
        }
        Admin admin = adminMapper.selectById(adminId);
        if (admin == null) {
            throw new RuntimeException("管理员账号不存在");
        }
        return admin;
    }

    /** 当前管理员资料（绝不返回密码） */
    @GetMapping("/profile")
    public ApiResponse<Map<String, Object>> profile(HttpServletRequest request) {
        Admin admin = currentAdmin(request);
        Map<String, Object> data = new HashMap<>();
        data.put("id", admin.getId());
        data.put("username", admin.getUsername());
        data.put("role", admin.getRole());
        data.put("createTime", admin.getCreateTime());
        return ApiResponse.success(data);
    }

    /** 修改当前管理员密码 */
    @PutMapping("/password")
    public ApiResponse<Object> changePassword(@RequestBody Map<String, String> body,
                                              HttpServletRequest request) {
        Admin admin = currentAdmin(request);

        String oldPassword = body.get("oldPassword") == null ? "" : body.get("oldPassword");
        String newPassword = body.get("newPassword") == null ? "" : body.get("newPassword");

        if (oldPassword.isEmpty()) {
            throw new RuntimeException("请输入当前密码");
        }
        if (newPassword.length() < 6 || newPassword.length() > 64) {
            throw new RuntimeException("新密码需为 6~64 位");
        }
        if (oldPassword.equals(newPassword)) {
            throw new RuntimeException("新密码不能与当前密码相同");
        }
        if (!passwordEncoder.matches(oldPassword, admin.getPassword())) {
            throw new RuntimeException("当前密码不正确");
        }

        Admin patch = new Admin();
        patch.setId(admin.getId());
        patch.setPassword(passwordEncoder.encode(newPassword));
        patch.setUpdateTime(LocalDateTime.now());
        adminMapper.updateById(patch);
        return ApiResponse.success(true);
    }
}
