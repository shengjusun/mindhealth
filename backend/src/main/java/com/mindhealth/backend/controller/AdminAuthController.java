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

import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Web 管理后台登录。
 *
 * 登录保护（演示级，够用且讲得清）：
 *  1. 失败计数：同一用户名第 1 次登录失败后，后续请求必须带图形验证码；
 *  2. 验证码由后端签发、后端校验、一次性消费、3 分钟过期；
 *  3. 连续失败 10 分钟无操作则计数清零，避免误锁死。
 *
 * 已知边界（面试时主动讲）：验证码字符是明文下发前端的，便于用 DOM 渲染，
 * 因此可被直接读取；生产环境应改为服务端渲染 PNG（java.awt 即可，无需新依赖）。
 * 存储用内存 Map，单实例够用；多实例部署应换成 Redis（项目里已有依赖）。
 */
@RestController
@RequestMapping("/admin")
public class AdminAuthController {

    /** 验证码有效期 */
    private static final long CAPTCHA_TTL_MS = 3 * 60 * 1000L;

    /** 失败几次后开始要求验证码 */
    private static final int CAPTCHA_TRIGGER_FAILURES = 1;

    /** 距上次失败超过这么久，失败计数清零（避免长期累积把正常用户锁住） */
    private static final long FAILURE_RESET_MS = 10 * 60 * 1000L;

    private static final int CAPTCHA_LENGTH = 4;

    /** 去掉了 0/O/1/I/l 这些肉眼容易看错的字符 */
    private static final char[] CAPTCHA_CHARS =
            "ABCDEFGHJKMNPQRSTUVWXYZ23456789".toCharArray();

    private static final SecureRandom RANDOM = new SecureRandom();

    /** captchaId -> 验证码记录 */
    private final Map<String, CaptchaEntry> captchaStore = new ConcurrentHashMap<>();

    /** username -> 失败记录 */
    private final Map<String, LoginFailure> loginFailures = new ConcurrentHashMap<>();

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
        /** 验证码 id，仅在被要求时必填 */
        private String captchaId;
        /** 用户输入的验证码，大小写不敏感 */
        private String captchaCode;
    }

    // ===================== 验证码 =====================

    /**
     * 签发一张验证码。
     * 返回明文 code 是为了让前端用 DOM 逐字符渲染（倾斜 / 变色 / 干扰线），
     * 代价是字符可被直接读取——演示可接受，生产应改成服务端渲染 PNG。
     */
    @GetMapping("/captcha")
    public ApiResponse<Map<String, Object>> captcha() {
        purgeExpiredCaptchas();

        StringBuilder sb = new StringBuilder(CAPTCHA_LENGTH);
        for (int i = 0; i < CAPTCHA_LENGTH; i++) {
            sb.append(CAPTCHA_CHARS[RANDOM.nextInt(CAPTCHA_CHARS.length)]);
        }
        String code = sb.toString();
        String captchaId = UUID.randomUUID().toString().replace("-", "");

        captchaStore.put(captchaId, new CaptchaEntry(code, System.currentTimeMillis() + CAPTCHA_TTL_MS));

        Map<String, Object> data = new HashMap<>();
        data.put("captchaId", captchaId);
        data.put("code", code);
        data.put("expireSeconds", CAPTCHA_TTL_MS / 1000);
        return ApiResponse.success(data);
    }

    // ===================== 登录 =====================

    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody AdminLoginRequest request) {
        String username = request.getUsername() == null ? "" : request.getUsername().trim();
        String password = request.getPassword() == null ? "" : request.getPassword();

        if (username.isEmpty() || password.isEmpty()) {
            throw new RuntimeException("用户名和密码不能为空");
        }

        // 失败过至少一次就先卡验证码，且不校验密码，避免验证码只挡前端
        if (failureCount(username) >= CAPTCHA_TRIGGER_FAILURES) {
            verifyCaptcha(request);
        }

        Admin admin = adminMapper.selectOne(new QueryWrapper<Admin>().eq("username", username));
        if (admin == null || !passwordEncoder.matches(password, admin.getPassword())) {
            recordFailure(username);
            throw new RuntimeException("用户名或密码错误");
        }

        clearFailure(username);

        String token = jwtUtils.generateAdminToken(admin.getId());

        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("username", admin.getUsername());
        data.put("role", admin.getRole());
        // 创建后从未改过密码（update_time == create_time）→ 前端提示尽快改密
        data.put("pwdNeverChanged", isPasswordNeverChanged(admin));
        return ApiResponse.success(data);
    }

    // ===================== 内部逻辑 =====================

    /** 校验验证码；不通过直接抛业务异常，由 GlobalExceptionHandler 转成 code=400 */
    private void verifyCaptcha(AdminLoginRequest request) {
        String captchaId = request.getCaptchaId() == null ? "" : request.getCaptchaId().trim();
        String captchaCode = request.getCaptchaCode() == null ? "" : request.getCaptchaCode().trim();

        if (captchaId.isEmpty() || captchaCode.isEmpty()) {
            throw new RuntimeException("请先输入图形验证码");
        }

        CaptchaEntry entry = captchaStore.remove(captchaId);
        if (entry == null) {
            throw new RuntimeException("验证码已失效，请点击刷新");
        }
        if (System.currentTimeMillis() > entry.expireAt) {
            throw new RuntimeException("验证码已过期，请点击刷新");
        }
        if (!entry.code.equalsIgnoreCase(captchaCode)) {
            throw new RuntimeException("验证码错误，请重新输入");
        }
    }

    private int failureCount(String username) {
        LoginFailure failure = loginFailures.get(username);
        if (failure == null) {
            return 0;
        }
        if (System.currentTimeMillis() - failure.lastFailAt > FAILURE_RESET_MS) {
            loginFailures.remove(username);
            return 0;
        }
        return failure.count;
    }

    private void recordFailure(String username) {
        LoginFailure failure = loginFailures.get(username);
        long now = System.currentTimeMillis();
        if (failure == null || now - failure.lastFailAt > FAILURE_RESET_MS) {
            loginFailures.put(username, new LoginFailure(1, now));
        } else {
            failure.count++;
            failure.lastFailAt = now;
        }
    }

    private void clearFailure(String username) {
        loginFailures.remove(username);
    }

    /** 顺手清理过期验证码，避免 Map 无限增长 */
    private void purgeExpiredCaptchas() {
        long now = System.currentTimeMillis();
        captchaStore.entrySet().removeIf(e -> now > e.getValue().expireAt);
    }

    /**
     * 密码是否从未修改过。
     * 新建账号时 create_time 与 update_time 相同；改过密码后 update_time 会被刷新。
     */
    private boolean isPasswordNeverChanged(Admin admin) {
        if (admin.getCreateTime() == null || admin.getUpdateTime() == null) {
            return true;
        }
        return admin.getCreateTime().equals(admin.getUpdateTime());
    }

    private static class CaptchaEntry {
        final String code;
        final long expireAt;

        CaptchaEntry(String code, long expireAt) {
            this.code = code;
            this.expireAt = expireAt;
        }
    }

    private static class LoginFailure {
        int count;
        long lastFailAt;

        LoginFailure(int count, long lastFailAt) {
            this.count = count;
            this.lastFailAt = lastFailAt;
        }
    }
}
