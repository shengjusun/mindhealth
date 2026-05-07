package com.mindhealth.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("ai_chat")
public class AIChat {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private String content;
    private String aiResponse;
    private LocalDateTime createTime;
}