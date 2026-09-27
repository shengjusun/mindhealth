package com.mindhealth.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("admin")
public class Admin {

    /**
     * 超级管理员：唯一能管理管理员账号（/admin/accounts/**）的角色。
     * 角色值收口成这两个常量，避免各处散落字符串字面量。
     */
    public static final String ROLE_SUPER_ADMIN = "SUPER_ADMIN";

    /** 普通管理员：能用除「账号管理」以外的全部后台功能 */
    public static final String ROLE_ADMIN = "ADMIN";

    @TableId(type = IdType.AUTO)
    private Long id;
    private String username;
    private String password;
    private String role;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
