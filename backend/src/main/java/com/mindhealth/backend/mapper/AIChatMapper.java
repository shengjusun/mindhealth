package com.mindhealth.backend.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.mindhealth.backend.entity.AIChat;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface AIChatMapper extends BaseMapper<AIChat> {
    @Select("SELECT * FROM ai_chat WHERE user_id = #{userId}")
    List<AIChat> selectByUserId(Long userId);
}