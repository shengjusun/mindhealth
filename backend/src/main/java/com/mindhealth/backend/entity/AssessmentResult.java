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

    /**
     * 答题明细 JSON：[{questionId,title,optionKey,optionText,score,maxScore}]
     * <p>
     * 有它之后才能做逐题分析、维度统计与 AI 解读——此前服务端只拿到一个总分，
     * 除了按固定阈值挑一句写死的话，什么也做不了。
     */
    @TableField("answers_json")
    private String answersJson;

    /** 本次量表满分，给 AI 和前端一个尺度感（没有分母的分数没有意义） */
    @TableField("max_score")
    private Integer maxScore;

    /** AI 分析状态：none / pending / success / failed */
    @TableField("ai_status")
    private String aiStatus;

    /** AI 分析结果（结构化 JSON，字段见 AssessmentAiService 的 prompt 约定） */
    @TableField("ai_analysis")
    private String aiAnalysis;

    /** AI 失败原因，可展示给用户并支持重试 */
    @TableField("ai_error")
    private String aiError;

    @TableField("create_time")
    private LocalDateTime createTime;
}