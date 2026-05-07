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
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}