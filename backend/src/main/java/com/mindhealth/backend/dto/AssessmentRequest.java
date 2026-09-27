package com.mindhealth.backend.dto;

import lombok.Data;

import java.util.List;

@Data
public class AssessmentRequest {

    private Long assessmentId;

    /**
     * 客户端算出的总分。
     * <p>
     * 保留该字段只为兼容尚未升级的旧客户端：**服务端始终按 {@link #answers} 重新计算**，
     * 拿不到明细时才退回使用它。把分数交给客户端算等于「改个包就能刷成状态良好」，
     * 而且服务端也永远拿不到答题内容，做不了任何个性化分析。
     */
    private Integer score;

    /** 答题明细，服务端据此重算分数并做逐题分析 */
    private List<Answer> answers;

    @Data
    public static class Answer {
        private Long questionId;
        /** 选项 key，如 "A" */
        private String optionKey;
    }
}
