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

    /**
     * 计分配置 JSON：{"bands":[{"max":8,"level":"状态平稳","suggestion":"..."}]}
     * bands 按 max 升序，最后一条兜住剩余分数。
     * 每套量表各有一套阈值——此前 6 套量表共用同一组阈值，是测评「千篇一律」的主因。
     */
    private String scoring;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}