package com.mindhealth.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("assessment")
public class Assessment {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;
    private String description;
    private String type;
    /**
     * 题库 JSON：[{"id":1,"title":"...","options":[{"key":"A","text":"...","score":0}]}]
     * 由迁移脚本/管理侧维护，接口原样返回给前端渲染
     */
    private String questions;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}