package com.mindhealth.backend.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.mindhealth.backend.entity.Admin;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AdminMapper extends BaseMapper<Admin> {
}
