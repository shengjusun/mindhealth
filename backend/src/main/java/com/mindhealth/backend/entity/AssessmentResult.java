package com.mindhealth.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("assessment_result")
public class AssessmentResult {
    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("assessment_id")
    private Long assessmentId;

    @TableField("assessment_title")
    private String assessmentTitle;

    @TableField("score")
    private Integer score;

    @TableField("level")
    private String level;

    @TableField("suggestion")
    private String suggestion;

    @TableField("create_time")
    private LocalDateTime createTime;
}