package com.mindhealth.backend.controller;

import com.mindhealth.backend.common.Result;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.dto.LoginRequest;
import com.mindhealth.backend.dto.LoginResponse;
import com.mindhealth.backend.dto.RegisterRequest;
import com.mindhealth.backend.dto.UpdatePhoneRequest;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.service.UserService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/user")
public class UserController {

    @Autowired
    private UserService userService;

    @PostMapping("/login")
    public ApiResponse<LoginResponse> login(@RequestBody LoginRequest request) {
        try {
            LoginResponse response = userService.login(request);
            return ApiResponse.success(response);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        } catch (Exception e) {
            return ApiResponse.error("服务器内部异常");
        }
    }

    @PostMapping("/register")
    public ApiResponse<Void> register(@RequestBody RegisterRequest request) {
        userService.register(request);
        return ApiResponse.success(null);
    }

    /**
     * 获取用户信息
     */
    @GetMapping("/info")
    public Result getUserInfo(@RequestAttribute("userId") Long userId) {
        User user = userService.getUserById(userId);
        return Result.success(user);
    }

    /**
     * 更新用户信息
     */
    @PutMapping("/update")
    public Result updateUser(@RequestAttribute("userId") Long userId, @RequestBody User user) {
        user.setId(userId);
        userService.updateUser(user);
        User updatedUser = userService.getUserById(userId);
        return Result.success(updatedUser);
    }

    /**
     * 更换手机号
     */
    @PutMapping("/phone")
    public Result updatePhone(@RequestAttribute("userId") Long userId, @RequestBody UpdatePhoneRequest request) {
        userService.updatePhone(userId, request.getNewPhone(), request.getCode());
        return Result.success(null);
    }
}