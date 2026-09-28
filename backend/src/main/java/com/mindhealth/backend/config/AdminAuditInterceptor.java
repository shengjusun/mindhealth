package com.mindhealth.backend.config;

import com.mindhealth.backend.entity.Admin;
import com.mindhealth.backend.entity.AdminOperationLog;
import com.mindhealth.backend.mapper.AdminMapper;
import com.mindhealth.backend.mapper.AdminOperationLogMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.ServletRequestBindingException;
import org.springframework.web.servlet.DispatcherServlet;
import org.springframework.web.servlet.HandlerInterceptor;

import java.time.LocalDateTime;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 管理员操作审计。
 * <p>
 * 只记录「有后果」的请求，避免把日志表刷成垃圾场：
 * <ul>
 *   <li>所有写操作（POST / PUT / DELETE）</li>
 *   <li>读取用户私密日记的 GET（{@code /admin/diaries}、{@code /admin/users/{id}/detail}）</li>
 * </ul>
 * 登录、验证码、纯统计查询不记录。
 * <p>
 * 审计本身失败绝不能影响正常请求，因此整段写入被 try/catch 包住、静默丢弃。
 */
@Component
public class AdminAuditInterceptor implements HandlerInterceptor {

    /** 请求属性名：preHandle 记录的开始时间戳 */
    private static final String ATTR_START = "auditStartMs";

    /** 从路径里抠出资源 ID，例如 /admin/users/12/password -> 12 */
    private static final Pattern ID_IN_PATH = Pattern.compile("/(\\d+)(?:/|$)");

    private static final int MAX_PATH_LEN = 255;
    private static final int MAX_TEXT_LEN = 200;

    @Autowired
    private AdminOperationLogMapper logMapper;

    @Autowired
    private AdminMapper adminMapper;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        request.setAttribute(ATTR_START, System.currentTimeMillis());
        return true;
    }

    @Override
    public void afterCompletion(HttpServletRequest request, HttpServletResponse response,
                                Object handler, Exception ex) {
        try {
            String path = servletPath(request);
            if (!shouldRecord(request.getMethod(), path)) {
                return;
            }

            Object startAttr = request.getAttribute(ATTR_START);
            long duration = startAttr instanceof Long
                    ? System.currentTimeMillis() - (Long) startAttr
                    : 0L;

            AdminOperationLog log = new AdminOperationLog();

            Object adminIdAttr = request.getAttribute("adminId");
            if (adminIdAttr instanceof Long) {
                Long adminId = (Long) adminIdAttr;
                log.setAdminId(adminId);
                Admin admin = adminMapper.selectById(adminId);
                log.setAdminUsername(admin == null ? "(账号已删除)" : admin.getUsername());
            } else {
                log.setAdminUsername("(未认证)");
            }

            log.setMethod(truncate(request.getMethod(), 10));
            log.setPath(truncate(path, MAX_PATH_LEN));
            log.setAction(truncate(describeAction(request.getMethod(), path), MAX_TEXT_LEN));
            log.setTarget(truncate(describeTarget(request, path), MAX_TEXT_LEN));
            log.setIp(truncate(clientIp(request), 64));
            log.setStatus(resolveStatus(request, response));
            log.setDurationMs(duration);
            log.setCreateTime(LocalDateTime.now());

            logMapper.insert(log);
        } catch (Exception ignored) {
            // 审计失败静默处理：不能因为日志写不进去就让业务请求失败
        }
    }

    /** 去掉 context-path 后的真实路径 */
    private static String servletPath(HttpServletRequest request) {
        String uri = request.getRequestURI();
        String ctx = request.getContextPath();
        if (uri == null) {
            return "";
        }
        if (ctx != null && !ctx.isEmpty() && uri.startsWith(ctx)) {
            return uri.substring(ctx.length());
        }
        return uri;
    }

    private static boolean shouldRecord(String method, String path) {
        if (!path.startsWith("/admin/")) {
            return false;
        }
        // 登录 / 验证码不需要 token，记了也定位不到人
        if (path.equals("/admin/login") || path.equals("/admin/captcha")) {
            return false;
        }

        if ("POST".equals(method) || "PUT".equals(method) || "DELETE".equals(method)) {
            return true;
        }

        // 读私密内容也要留痕：谁能证明自己没看过别人的日记？
        if ("GET".equals(method)) {
            return path.startsWith("/admin/diaries") || path.matches("^/admin/users/\\d+/detail$");
        }
        return false;
    }

    private static String describeAction(String method, String path) {
        if (path.startsWith("/admin/diaries")) {
            return "DELETE".equals(method) ? "删除日记" : "查看用户日记";
        }
        if (path.matches("^/admin/users/\\d+/detail$")) {
            return "查看用户详情（含日记摘要）";
        }
        if (path.matches("^/admin/users/\\d+/status$")) {
            return "启用/禁用用户";
        }
        if (path.matches("^/admin/users/\\d+/password$")) {
            return "重置用户登录密码";
        }
        if (path.equals("/admin/users")) {
            return "POST".equals(method) ? "新增用户" : "查询用户";
        }
        if (path.startsWith("/admin/users")) {
            return "DELETE".equals(method) ? "删除用户（级联清理其全部数据）" : "修改用户资料";
        }
        if (path.startsWith("/admin/feedbacks")) {
            return "DELETE".equals(method) ? "删除反馈" : "处理反馈";
        }
        if (path.startsWith("/admin/assessments")) {
            return "DELETE".equals(method) ? "删除量表" : "维护测评题库";
        }
        if (path.startsWith("/admin/accounts")) {
            return "DELETE".equals(method) ? "删除管理员账号" : "维护管理员账号";
        }
        if (path.startsWith("/admin/password")) {
            return "修改自己的登录密码";
        }
        if (path.startsWith("/admin/batch")) {
            return "批量操作";
        }
        return method + " " + path;
    }

    private static String describeTarget(HttpServletRequest request, String path) {
        // 看日记最关键的信息是「看了谁」，取 userId 而不是日记 ID
        if (path.startsWith("/admin/diaries")) {
            String uid = request.getParameter("userId");
            return (uid == null || uid.isEmpty()) ? "全部用户" : "用户ID=" + uid;
        }
        Matcher matcher = ID_IN_PATH.matcher(path);
        if (matcher.find()) {
            return "ID=" + matcher.group(1);
        }
        return null;
    }

    private static String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isEmpty()) {
            int comma = forwarded.indexOf(',');
            return comma > 0 ? forwarded.substring(0, comma).trim() : forwarded.trim();
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isEmpty()) {
            return realIp.trim();
        }
        return request.getRemoteAddr();
    }

    private static String truncate(String value, int max) {
        if (value == null) {
            return null;
        }
        return value.length() <= max ? value : value.substring(0, max);
    }

    /**
     * 取「业务结果码」写入日志的 status 列。
     * <p>
     * 不能直接用 {@code response.getStatus()}：{@code GlobalExceptionHandler} 把所有业务异常
     * 都按「HTTP 200 + 业务码」返回，于是「删除用户成功」和「删除用户失败」在日志里长得
     * 一模一样，这一列等于白记。200 表示成功，其余为失败，与 ApiResponse.code 同义。
     * <p>
     * 注意 afterCompletion 的 {@code ex} 参数在这里恒为 null —— 异常只要被
     * {@code @RestControllerAdvice} 解析掉，DispatcherServlet 就不再向上透传它。
     * 所以改读 {@code DispatcherServlet.EXCEPTION_ATTRIBUTE}：MVC 在异常被解析器吃掉时
     * 会把它塞进 request（见 DispatcherServlet#processHandlerException）。
     */
    private static int resolveStatus(HttpServletRequest request, HttpServletResponse response) {
        Object resolved = request.getAttribute(DispatcherServlet.EXCEPTION_ATTRIBUTE);
        if (resolved instanceof Exception) {
            return businessCodeOf((Exception) resolved);
        }
        return response.getStatus();
    }

    /**
     * 与 {@code GlobalExceptionHandler} 的 @ExceptionHandler 映射保持一致，那边调整时这里需同步。
     * <p>
     * 顺序有讲究：{@code MissingServletRequestParameterException} 是
     * {@code ServletRequestBindingException} 的子类，但前者按 400、后者按 401 返回，
     * 所以子类必须先判断。
     */
    private static int businessCodeOf(Exception ex) {
        if (ex instanceof MissingServletRequestParameterException) {
            return 400;
        }
        if (ex instanceof ServletRequestBindingException) {
            return 401;
        }
        if (ex instanceof HttpRequestMethodNotSupportedException) {
            return 405;
        }
        if (ex instanceof RuntimeException) {
            return 400;
        }
        return 500;
    }
}
