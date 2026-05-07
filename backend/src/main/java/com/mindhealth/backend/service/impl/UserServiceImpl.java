package com.mindhealth.backend.service.impl;

import com.mindhealth.backend.dto.LoginRequest;
import com.mindhealth.backend.dto.LoginResponse;
import com.mindhealth.backend.dto.RegisterRequest;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.mapper.UserMapper;
import com.mindhealth.backend.service.UserService;
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

    @Override
    public LoginResponse login(LoginRequest request) {
        String phone = request.getPhone() == null ? "" : request.getPhone().trim();
        String password = request.getPassword() == null ? "" : request.getPassword().trim();

        User user = userMapper.selectByPhone(phone);
        if (user == null) {
            throw new RuntimeException("用户不存在");
        }

        boolean passwordMatch = false;
        if (user.getPassword().startsWith("$2a$")) {
            passwordMatch = passwordEncoder.matches(password, user.getPassword());
        } else {
            passwordMatch = password.equals(user.getPassword());
            if (passwordMatch) {
                user.setPassword(passwordEncoder.encode(password));
                user.setUpdateTime(LocalDateTime.now());
                userMapper.updateById(user);
            }
        }

        if (!passwordMatch) {
            throw new RuntimeException("手机号或密码错误");
        }

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
        if (userMapper.selectByPhone(request.getPhone()) != null) {
            throw new RuntimeException("手机号已注册");
        }

        User user = new User();
        user.setPhone(request.getPhone());
        user.setPassword(passwordEncoder.encode(request.getPassword()));
        user.setNickname("用户" + request.getPhone().substring(7));
        user.setCreateTime(LocalDateTime.now());
        user.setUpdateTime(LocalDateTime.now());
        user.setDeleted(0);

        userMapper.insert(user);
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