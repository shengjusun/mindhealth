package com.mindhealth.backend.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 心理科普内容（knowledge 表）。
 * 仅供客户端「心理科普」Tab 只读消费，当前无写入口（管理侧未开放维护）。
 */
@Data
@TableName("knowledge")
public class Knowledge {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String title;
    private String content;
    private String category;
    /** 封面图地址，可为空 */
    private String cover;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
