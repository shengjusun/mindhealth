package com.mindhealth.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("feedback")
public class Feedback {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    /** 类型: bug / suggestion / other */
    private String type;
    private String content;
    private String contact;
    private LocalDateTime createTime;
    /** 是否已处理 */
    private Boolean isHandled;
    private LocalDateTime handledTime;
}
