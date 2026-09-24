package com.mindhealth.backend.controller;

import com.mindhealth.backend.common.Result;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.dto.LoginRequest;
import com.mindhealth.backend.dto.LoginResponse;
import com.mindhealth.backend.dto.HuaweiLoginRequest;
import com.mindhealth.backend.dto.RegisterRequest;
import com.mindhealth.backend.dto.UpdatePhoneRequest;
import com.mindhealth.backend.dto.UpdateUserRequest;
import com.mindhealth.backend.dto.UserVO;
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

    /**
     * 华为账号登录：前端拿 authorizationCode 换本系统 token
     */
    @PostMapping("/huawei/login")
    public ApiResponse<LoginResponse> huaweiLogin(@RequestBody HuaweiLoginRequest request) {
        try {
            LoginResponse response = userService.loginWithHuaweiId(request.getAuthorizationCode());
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
     * 获取用户信息（脱敏，不含密码）
     */
    @GetMapping("/info")
    public Result getUserInfo(@RequestAttribute("userId") Long userId) {
        User user = userService.getUserById(userId);
        return Result.success(UserVO.from(user));
    }

    /**
     * 更新用户信息（仅白名单字段）
     */
    @PutMapping("/update")
    public Result updateUser(@RequestAttribute("userId") Long userId, @RequestBody UpdateUserRequest request) {
        User patch = new User();
        patch.setId(userId);
        patch.setNickname(request.getNickname());
        patch.setAge(request.getAge());
        patch.setGender(request.getGender());
        patch.setAvatar(request.getAvatar());
        patch.setSignature(request.getSignature());
        userService.updateUser(patch);
        User updatedUser = userService.getUserById(userId);
        return Result.success(UserVO.from(updatedUser));
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
