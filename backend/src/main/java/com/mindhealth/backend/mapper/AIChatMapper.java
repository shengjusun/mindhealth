package com.mindhealth.backend.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.mindhealth.backend.entity.AIChat;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface AIChatMapper extends BaseMapper<AIChat> {
    /**
     * 查询某用户的全部聊天记录。
     * <p>
     * 必须显式排序：此前依赖主键顺序恰好等于时间顺序，属于巧合而非保证。
     * 一旦新增索引、优化器改选执行计划或数据页重排，返回顺序就会变，
     * 前端会直接把消息渲染成乱序。按 create_time 排，id 兜底同一时刻的记录。
     */
    @Select("SELECT * FROM ai_chat WHERE user_id = #{userId} ORDER BY create_time ASC, id ASC")
    List<AIChat> selectByUserId(Long userId);
}