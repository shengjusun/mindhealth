package com.mindhealth.backend.service.impl;

import com.mindhealth.backend.dto.LoginRequest;
import com.mindhealth.backend.dto.LoginResponse;
import com.mindhealth.backend.dto.RegisterRequest;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.mapper.UserMapper;
import com.mindhealth.backend.service.UserService;
import com.mindhealth.backend.utils.HuaweiAuthService;
import com.mindhealth.backend.utils.JwtUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

@Service
public class UserServiceImpl implements UserService {

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private HuaweiAuthService huaweiAuthService;

    @Override
    public LoginResponse login(LoginRequest request) {
        String phone = request.getPhone() == null ? "" : request.getPhone().trim();
        String password = request.getPassword() == null ? "" : request.getPassword().trim();

        validatePhoneFormat(phone);
        if (password.isEmpty()) {
            throw new RuntimeException("密码不能为空");
        }

        User user = userMapper.selectByPhone(phone);
        if (user == null) {
            throw new RuntimeException("手机号或密码错误");
        }
        if (user.getDeleted() != null && user.getDeleted() == 1) {
            throw new RuntimeException("账号已被禁用，请联系管理员");
        }

        if (!passwordEncoder.matches(password, user.getPassword())) {
            throw new RuntimeException("手机号或密码错误");
        }

        return buildLoginResponse(user);
    }

    /**
     * 华为账号登录：unionID 匹配已有用户则直接登录，否则自动创建账号
     */
    @Override
    public LoginResponse loginWithHuaweiId(String authorizationCode) {
        HuaweiAuthService.HuaweiUserInfo huaweiUser = huaweiAuthService.exchangeCode(authorizationCode);

        User user = userMapper.selectByHuaweiUnionId(huaweiUser.getUnionId());
        if (user != null && user.getDeleted() != null && user.getDeleted() == 1) {
            throw new RuntimeException("账号已被禁用，请联系管理员");
        }
        if (user == null) {
            user = new User();
            user.setHuaweiUnionId(huaweiUser.getUnionId());
            user.setHuaweiOpenId(huaweiUser.getOpenId());
            user.setPassword(passwordEncoder.encode(java.util.UUID.randomUUID().toString()));
            user.setNickname(huaweiUser.getNickname() == null || huaweiUser.getNickname().isEmpty()
                    ? "轻心用户" : huaweiUser.getNickname());
            if (huaweiUser.getAvatarUrl() != null && !huaweiUser.getAvatarUrl().isEmpty()) {
                user.setAvatar(huaweiUser.getAvatarUrl());
            }
            user.setCreateTime(LocalDateTime.now());
            user.setUpdateTime(LocalDateTime.now());
            user.setDeleted(0);
            userMapper.insert(user);
        } else {
            // 已有用户补充 openId / 最新头像昵称
            boolean changed = false;
            if (user.getHuaweiOpenId() == null) {
                user.setHuaweiOpenId(huaweiUser.getOpenId());
                changed = true;
            }
            if (huaweiUser.getNickname() != null && !huaweiUser.getNickname().isEmpty()
                    && !huaweiUser.getNickname().equals(user.getNickname())
                    && (user.getNickname() == null || user.getNickname().startsWith("轻心用户"))) {
                user.setNickname(huaweiUser.getNickname());
                changed = true;
            }
            if (changed) {
                user.setUpdateTime(LocalDateTime.now());
                userMapper.updateById(user);
            }
        }

        return buildLoginResponse(user);
    }

    private LoginResponse buildLoginResponse(User user) {
        LoginResponse response = new LoginResponse();
        response.setToken(jwtUtils.generateToken(user.getId()));
        response.setRefreshToken(jwtUtils.generateRefreshToken(user.getId()));

        LoginResponse.UserInfo userInfo = new LoginResponse.UserInfo();
        userInfo.setId(user.getId());
        userInfo.setPhone(user.getPhone());
        userInfo.setNickname(user.getNickname());
        userInfo.setAvatar(user.getAvatar());
        response.setUserInfo(userInfo);
        return response;
    }

    @Override
    public void register(RegisterRequest request) {
        String phone = request.getPhone() == null ? "" : request.getPhone().trim();
        String password = request.getPassword() == null ? "" : request.getPassword().trim();

        validatePhoneFormat(phone);
        if (password.length() < 6 || password.length() > 64) {
            throw new RuntimeException("密码长度需为 6~64 位");
        }
        if (request.getConfirmPassword() != null && !password.equals(request.getConfirmPassword().trim())) {
            throw new RuntimeException("两次输入的密码不一致");
        }

        if (userMapper.selectByPhone(phone) != null) {
            throw new RuntimeException("手机号已注册");
        }

        User user = new User();
        user.setPhone(phone);
        user.setPassword(passwordEncoder.encode(password));
        user.setNickname("用户" + phone.substring(phone.length() - 4));
        user.setCreateTime(LocalDateTime.now());
        user.setUpdateTime(LocalDateTime.now());
        user.setDeleted(0);

        userMapper.insert(user);
    }

    private void validatePhoneFormat(String phone) {
        if (phone == null || phone.isEmpty()) {
            throw new RuntimeException("手机号不能为空");
        }
        if (!phone.matches("^1[3-9]\\d{9}$")) {
            throw new RuntimeException("手机号格式不正确");
        }
    }

    @Override
    public User getUserByPhone(String phone) {
        return userMapper.selectByPhone(phone);
    }

    @Override
    public User getUserById(Long id) {
        return userMapper.selectById(id);
    }

    @Override
    public void updateUser(User user) {
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);
    }

    @Override
    public void updatePhone(Long userId, String newPhone, String code) {
        // 验证手机号格式
        if (!newPhone.matches("^1[3-9]\\d{9}$")) {
            throw new RuntimeException("手机号格式错误");
        }

        // 检查手机号是否已被使用
        User existUser = userMapper.selectByPhone(newPhone);
        if (existUser != null && !existUser.getId().equals(userId)) {
            throw new RuntimeException("手机号已被使用");
        }

        // TODO: 验证验证码（需要实现验证码服务）

        // 更新手机号
        User user = userMapper.selectById(userId);
        user.setPhone(newPhone);
        user.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(user);
    }
}