package com.mindhealth.backend.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.AdminOperationLog;
import com.mindhealth.backend.mapper.AdminOperationLogMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * 管理员操作日志查询。
 * <p>
 * 访问权限在 SecurityConfig 里限定为 ROLE_SUPER_ADMIN：
 * 审计记录用来约束管理员，不应该让被审计者随手翻看或据此规避。
 */
@RestController
@RequestMapping("/admin")
public class AdminLogController {

    @Autowired
    private AdminOperationLogMapper logMapper;

    @GetMapping("/logs")
    public ApiResponse<Map<String, Object>> logs(@RequestParam(defaultValue = "1") long page,
                                                 @RequestParam(defaultValue = "20") long size,
                                                 @RequestParam(required = false) Long adminId,
                                                 @RequestParam(required = false) String keyword) {
        QueryWrapper<AdminOperationLog> wrapper = new QueryWrapper<>();
        if (adminId != null) {
            wrapper.eq("admin_id", adminId);
        }
        if (keyword != null && !keyword.trim().isEmpty()) {
            String k = keyword.trim();
            // action_desc / target_desc 是真实列名（见 AdminOperationLog 上的 @TableField）
            wrapper.and(w -> w.like("action_desc", k)
                    .or().like("path", k)
                    .or().like("admin_username", k)
                    .or().like("ip", k)
                    .or().like("target_desc", k));
        }
        // 同一秒内的多条记录按 ID 兜底排序，避免分页时顺序抖动
        wrapper.orderByDesc("create_time").orderByDesc("id");

        Page<AdminOperationLog> result = logMapper.selectPage(new Page<>(page, size), wrapper);

        Map<String, Object> data = new HashMap<>();
        data.put("total", result.getTotal());
        data.put("records", result.getRecords());
        return ApiResponse.success(data);
    }
}
