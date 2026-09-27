package com.mindhealth.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 管理员操作日志。
 * <p>
 * 管理端能删除用户全部数据、能逐条读取用户的私密日记，
 * 这类操作必须留痕——此前后台登录页写着「所有操作将被记录」，
 * 但系统里一条都没记，属于对外的虚假承诺。
 */
@Data
@TableName("admin_operation_log")
public class AdminOperationLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 操作人（管理员）ID；解析不到时为空 */
    private Long adminId;

    /** 操作人用户名快照，避免管理员被删除后日志变成一串孤儿 ID */
    private String adminUsername;

    /** HTTP 方法 */
    private String method;

    /** 请求路径（已去掉 context-path） */
    private String path;

    /**
     * 人类可读的操作摘要，例如「查看用户日记」「删除日记」。
     * 列名带 _desc 后缀：action / target 在 SQL 里是保留字风险词，
     * 交给 MyBatis-Plus 生成 SQL 时不会被加反引号。
     */
    @TableField("action_desc")
    private String action;

    /** 操作对象，例如「用户ID=12」「ID=88」 */
    @TableField("target_desc")
    private String target;

    /** 来源 IP */
    private String ip;

    /** HTTP 状态码 */
    private Integer status;

    /** 处理耗时（毫秒） */
    private Long durationMs;

    private LocalDateTime createTime;
}
