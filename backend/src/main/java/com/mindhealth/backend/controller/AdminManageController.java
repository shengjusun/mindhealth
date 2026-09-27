package com.mindhealth.backend.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.Admin;
import com.mindhealth.backend.mapper.AdminMapper;
import jakarta.servlet.http.HttpServletRequest;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理员账号管理。
 *
 * 权限：整个 {@code /admin/accounts/**} 在 SecurityConfig 里限定为 ROLE_SUPER_ADMIN，
 * 这里再显式校验一次登录态（双保险，也方便直接读单测）。
 *
 * 三条防自锁护栏（没有它们很容易把系统管死）：
 *  1. 不能删除当前登录的账号；
 *  2. 不能删除最后一个超级管理员；
 *  3. 不能把最后一个超级管理员降级成普通管理员。
 *
 * 另外：所有接口都不返回密码字段；新建 / 重置统一走 BCrypt 并校验密码强度，
 * 避免再出现 admin/123456 这类可被直接登录的弱口令。
 */
@RestController
@RequestMapping("/admin")
public class AdminManageController {

    private static final int PASSWORD_MIN = 8;
    private static final int PASSWORD_MAX = 64;
    private static final int USERNAME_MIN = 3;
    private static final int USERNAME_MAX = 50;

    /** 常见弱口令黑名单：管理后台账号一律不允许使用 */
    private static final List<String> WEAK_PASSWORDS = List.of(
            "123456", "1234567", "12345678", "123456789", "1234567890",
            "password", "password1", "admin123", "admin888", "administrator",
            "qwerty123", "11111111", "88888888", "abc123456", "iloveyou");

    @Autowired
    private AdminMapper adminMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Data
    public static class CreateAdminRequest {
        private String username;
        private String password;
        private String role;
    }

    // ===================== 账号管理 =====================

    /** 管理员列表（绝不返回密码） */
    @GetMapping("/accounts")
    public ApiResponse<List<Map<String, Object>>> accounts(HttpServletRequest request) {
        requireSuperAdmin(request);

        List<Admin> admins = adminMapper.selectList(new QueryWrapper<Admin>().orderByAsc("id"));

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Admin admin : admins) {
            Map<String, Object> row = new HashMap<>();
            row.put("id", admin.getId());
            row.put("username", admin.getUsername());
            row.put("role", admin.getRole());
            row.put("createTime", admin.getCreateTime());
            row.put("updateTime", admin.getUpdateTime());
            rows.add(row);
        }
        return ApiResponse.success(rows);
    }

    /** 新建管理员 */
    @PostMapping("/accounts")
    public ApiResponse<Object> create(@RequestBody CreateAdminRequest body, HttpServletRequest request) {
        requireSuperAdmin(request);

        String username = body.getUsername() == null ? "" : body.getUsername().trim();
        if (username.length() < USERNAME_MIN || username.length() > USERNAME_MAX) {
            throw new RuntimeException("用户名长度需为 " + USERNAME_MIN + "~" + USERNAME_MAX + " 位");
        }
        validatePassword(body.getPassword());

        Long exists = adminMapper.selectCount(new QueryWrapper<Admin>().eq("username", username));
        if (exists != null && exists > 0) {
            throw new RuntimeException("用户名已存在");
        }

        Admin admin = new Admin();
        admin.setUsername(username);
        admin.setPassword(passwordEncoder.encode(body.getPassword()));
        admin.setRole(normalizeRole(body.getRole()));
        // 用同一个时间点：登录时会用 create_time 与 update_time 是否相等来判断
        // 「该账号从未修改过初始密码」，两者必须一致才能触发提示
        LocalDateTime now = LocalDateTime.now();
        admin.setCreateTime(now);
        admin.setUpdateTime(now);
        adminMapper.insert(admin);

        return ApiResponse.success(true);
    }

    /** 重置指定管理员的密码（不需要旧密码，只有超级管理员能调） */
    @PutMapping("/accounts/{id}/password")
    public ApiResponse<Object> resetPassword(@PathVariable Long id,
                                             @RequestBody Map<String, String> body,
                                             HttpServletRequest request) {
        requireSuperAdmin(request);

        Admin target = adminMapper.selectById(id);
        if (target == null) {
            throw new RuntimeException("管理员账号不存在");
        }

        String newPassword = body.get("newPassword") == null ? "" : body.get("newPassword");
        validatePassword(newPassword);

        Admin patch = new Admin();
        patch.setId(id);
        patch.setPassword(passwordEncoder.encode(newPassword));
        patch.setUpdateTime(LocalDateTime.now());
        adminMapper.updateById(patch);

        return ApiResponse.success(true);
    }

    /** 修改指定管理员的角色 */
    @PutMapping("/accounts/{id}/role")
    public ApiResponse<Object> changeRole(@PathVariable Long id,
                                          @RequestBody Map<String, String> body,
                                          HttpServletRequest request) {
        requireSuperAdmin(request);

        Admin target = adminMapper.selectById(id);
        if (target == null) {
            throw new RuntimeException("管理员账号不存在");
        }

        String role = validateRole(body.get("role"));
        if (role.equals(target.getRole())) {
            return ApiResponse.success(true);
        }
        if (Admin.ROLE_SUPER_ADMIN.equals(target.getRole()) && countSuperAdmins() <= 1) {
            throw new RuntimeException("不能降级最后一个超级管理员，否则没人能再管理账号");
        }

        Admin patch = new Admin();
        patch.setId(id);
        patch.setRole(role);
        patch.setUpdateTime(LocalDateTime.now());
        adminMapper.updateById(patch);

        return ApiResponse.success(true);
    }

    /** 删除管理员 */
    @DeleteMapping("/accounts/{id}")
    public ApiResponse<Object> delete(@PathVariable Long id, HttpServletRequest request) {
        Admin operator = requireSuperAdmin(request);

        if (operator.getId() != null && operator.getId().equals(id)) {
            throw new RuntimeException("不能删除当前登录的账号");
        }

        Admin target = adminMapper.selectById(id);
        if (target == null) {
            throw new RuntimeException("管理员账号不存在");
        }
        if (Admin.ROLE_SUPER_ADMIN.equals(target.getRole()) && countSuperAdmins() <= 1) {
            throw new RuntimeException("不能删除最后一个超级管理员");
        }

        adminMapper.deleteById(id);
        return ApiResponse.success(true);
    }

    // ===================== 内部工具 =====================

    /** 取当前登录管理员；令牌失效或账号已被删都直接拒绝 */
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

    /** 只有超级管理员能管理管理员账号；普通管理员即使直接调 URL 也会被挡住 */
    private Admin requireSuperAdmin(HttpServletRequest request) {
        Admin admin = currentAdmin(request);
        if (!Admin.ROLE_SUPER_ADMIN.equals(admin.getRole())) {
            throw new RuntimeException("只有超级管理员可以管理管理员账号");
        }
        return admin;
    }

    /** 密码强度校验：长度 + 弱口令黑名单，新建和重置共用 */
    private void validatePassword(String password) {
        if (password == null || password.length() < PASSWORD_MIN || password.length() > PASSWORD_MAX) {
            throw new RuntimeException("密码长度需为 " + PASSWORD_MIN + "~" + PASSWORD_MAX + " 位");
        }
        if (WEAK_PASSWORDS.contains(password.toLowerCase())) {
            throw new RuntimeException("该密码过于常见，请换一个更复杂的");
        }
    }

    /** 新建时角色收口：只认 SUPER_ADMIN，其余一律按普通管理员 */
    private String normalizeRole(String role) {
        String value = role == null ? "" : role.trim().toUpperCase();
        return Admin.ROLE_SUPER_ADMIN.equals(value) ? Admin.ROLE_SUPER_ADMIN : Admin.ROLE_ADMIN;
    }

    /** 改角色时严格校验：不接受未知值，避免写进脏数据 */
    private String validateRole(String role) {
        String value = role == null ? "" : role.trim().toUpperCase();
        if (!Admin.ROLE_SUPER_ADMIN.equals(value) && !Admin.ROLE_ADMIN.equals(value)) {
            throw new RuntimeException("角色只能是 SUPER_ADMIN 或 ADMIN");
        }
        return value;
    }

    private long countSuperAdmins() {
        Long count = adminMapper.selectCount(
                new QueryWrapper<Admin>().eq("role", Admin.ROLE_SUPER_ADMIN));
        return count == null ? 0L : count;
    }
}
