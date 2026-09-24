package com.mindhealth.backend.dto;

import com.mindhealth.backend.entity.User;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 对外暴露的用户信息视图，禁止包含 password、deleted 等敏感字段
 */
@Data
public class UserVO {
    private Long id;
    private String phone;
    private String nickname;
    private Integer age;
    private String gender;
    private String avatar;
    private String signature;
    private LocalDateTime createTime;

    public static UserVO from(User user) {
        if (user == null) {
            return null;
        }
        UserVO vo = new UserVO();
        vo.setId(user.getId());
        vo.setPhone(user.getPhone());
        vo.setNickname(user.getNickname());
        vo.setAge(user.getAge());
        vo.setGender(user.getGender());
        vo.setAvatar(user.getAvatar());
        vo.setSignature(user.getSignature());
        vo.setCreateTime(user.getCreateTime());
        return vo;
    }
}
