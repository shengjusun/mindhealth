package com.mindhealth.backend.common;

import com.mindhealth.backend.dto.ApiResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.ServletRequestBindingException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

/**
 * 全局异常处理：
 * 统一以 HTTP 200 + 业务码返回（与现有前端「code==200 判定、否则展示 message」的解析逻辑兼容），
 * 避免业务异常落到 Spring 默认 500 白板导致前端只能提示「网络异常」。
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    /** 业务/参数错误（Service 层抛出的 RuntimeException 统一按 400 处理） */
    @ExceptionHandler({RuntimeException.class, IllegalArgumentException.class})
    public ApiResponse<Object> handleBusinessException(RuntimeException e) {
        log.warn("业务异常: {}", e.getMessage());
        return ApiResponse.error(400, e.getMessage() == null ? "请求处理失败" : e.getMessage());
    }

    /** 请求参数类型不匹配 / 缺参 / 请求体不可读 */
    @ExceptionHandler({MethodArgumentTypeMismatchException.class,
            MissingServletRequestParameterException.class,
            HttpMessageNotReadableException.class})
    public ApiResponse<Object> handleBadRequest(Exception e) {
        log.warn("请求参数错误: {}", e.getMessage());
        return ApiResponse.error(400, "请求参数错误");
    }

    /** 缺少登录态（@RequestAttribute("userId") 绑定失败） */
    @ExceptionHandler(ServletRequestBindingException.class)
    public ApiResponse<Object> handleUnauthenticated(ServletRequestBindingException e) {
        log.warn("缺少登录态: {}", e.getMessage());
        return ApiResponse.error(401, "请先登录后操作");
    }

    /** 请求方法不支持 */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ApiResponse<Object> handleMethodNotSupported(HttpRequestMethodNotSupportedException e) {
        return ApiResponse.error(405, "请求方法不支持");
    }

    /** 兜底：未预期异常 */
    @ExceptionHandler(Exception.class)
    public ApiResponse<Object> handleUnexpected(Exception e) {
        log.error("未处理异常: {}", e.getMessage(), e);
        return ApiResponse.error(500, "服务器内部异常，请稍后重试");
    }
}
