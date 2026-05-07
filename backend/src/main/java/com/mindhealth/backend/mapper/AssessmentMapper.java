package com.mindhealth.backend.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.mindhealth.backend.entity.Assessment;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AssessmentMapper extends BaseMapper<Assessment> {
}