package com.mindhealth.backend.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.AIChat;
import com.mindhealth.backend.entity.AssessmentResult;
import com.mindhealth.backend.entity.Diary;
import com.mindhealth.backend.entity.Feedback;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.mapper.AIChatMapper;
import com.mindhealth.backend.mapper.AssessmentResultMapper;
import com.mindhealth.backend.mapper.DiaryMapper;
import com.mindhealth.backend.mapper.FeedbackMapper;
import com.mindhealth.backend.mapper.UserMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理后台增强接口：趋势统计 / 分布统计 / 用户详情 / 批量操作
 * 需管理员令牌，JwtAuthenticationFilter 注入 adminId
 */
@RestController
@RequestMapping("/admin")
public class AdminExtController {

    private static final DateTimeFormatter DAY_LABEL = DateTimeFormatter.ofPattern("MM-dd");

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private DiaryMapper diaryMapper;

    @Autowired
    private FeedbackMapper feedbackMapper;

    @Autowired
    private AssessmentResultMapper assessmentResultMapper;

    @Autowired
    private AIChatMapper aiChatMapper;

    // ===== 趋势统计 =====

    /** 近 N 天新增用户 / 日记 / 反馈趋势 */
    @GetMapping("/stats/trend")
    public ApiResponse<Map<String, Object>> trend(@RequestParam(defaultValue = "14") int days) {
        int span = Math.max(1, Math.min(90, days));
        LocalDate today = LocalDate.now();
        LocalDate start = today.minusDays(span - 1L);
        LocalDateTime startTime = start.atStartOfDay();

        Map<String, Long> userMap = countByDay(userMapper.selectMaps(new QueryWrapper<User>()
                .select("DATE(create_time) AS d", "COUNT(*) AS c")
                .ge("create_time", startTime)
                .groupBy("DATE(create_time)")));

        Map<String, Long> diaryMap = countByDay(diaryMapper.selectMaps(new QueryWrapper<Diary>()
                .select("DATE(create_time) AS d", "COUNT(*) AS c")
                .ge("create_time", startTime)
                .groupBy("DATE(create_time)")));

        Map<String, Long> feedbackMap = countByDay(feedbackMapper.selectMaps(new QueryWrapper<Feedback>()
                .select("DATE(create_time) AS d", "COUNT(*) AS c")
                .ge("create_time", startTime)
                .groupBy("DATE(create_time)")));

        List<String> labels = new ArrayList<>();
        List<Long> users = new ArrayList<>();
        List<Long> diaries = new ArrayList<>();
        List<Long> feedbacks = new ArrayList<>();

        for (int i = 0; i < span; i++) {
            LocalDate day = start.plusDays(i);
            String key = day.toString();
            labels.add(day.format(DAY_LABEL));
            users.add(userMap.getOrDefault(key, 0L));
            diaries.add(diaryMap.getOrDefault(key, 0L));
            feedbacks.add(feedbackMap.getOrDefault(key, 0L));
        }

        Map<String, Object> data = new HashMap<>();
        data.put("labels", labels);
        data.put("users", users);
        data.put("diaries", diaries);
        data.put("feedbacks", feedbacks);
        return ApiResponse.success(data);
    }

    /** 日记情绪分布 */
    @GetMapping("/stats/emotion")
    public ApiResponse<List<Map<String, Object>>> emotionDistribution() {
        List<Map<String, Object>> rows = diaryMapper.selectMaps(new QueryWrapper<Diary>()
                .select("emotion AS name", "COUNT(*) AS value")
                .isNotNull("emotion")
                .ne("emotion", "")
                .groupBy("emotion")
                .orderByDesc("value"));
        return ApiResponse.success(normalizeDistribution(rows, "name", "value"));
    }

    /** 反馈类型占比 */
    @GetMapping("/stats/feedback-types")
    public ApiResponse<List<Map<String, Object>>> feedbackTypes() {
        List<Map<String, Object>> rows = feedbackMapper.selectMaps(new QueryWrapper<Feedback>()
                .select("type AS name", "COUNT(*) AS value")
                .groupBy("type")
                .orderByDesc("value"));
        return ApiResponse.success(normalizeDistribution(rows, "name", "value"));
    }

    // ===== 用户详情 =====

    @GetMapping("/users/{id}/detail")
    public ApiResponse<Map<String, Object>> userDetail(@PathVariable Long id) {
        User user = userMapper.selectById(id);
        if (user == null) {
            throw new RuntimeException("用户不存在");
        }

        Map<String, Object> row = new HashMap<>();
        row.put("id", user.getId());
        row.put("phone", user.getPhone());
        row.put("nickname", user.getNickname());
        row.put("gender", user.getGender());
        row.put("age", user.getAge());
        row.put("avatar", user.getAvatar());
        row.put("signature", user.getSignature());
        row.put("isHuaweiUser", user.getHuaweiUnionId() != null);
        row.put("deleted", user.getDeleted());
        row.put("createTime", user.getCreateTime());
        row.put("updateTime", user.getUpdateTime());

        long diaryCount = diaryMapper.selectCount(new QueryWrapper<Diary>().eq("user_id", id));
        long feedbackCount = feedbackMapper.selectCount(new QueryWrapper<Feedback>().eq("user_id", id));
        long assessmentCount = assessmentResultMapper.selectCount(
                new QueryWrapper<AssessmentResult>().eq("user_id", id));
        long chatCount = aiChatMapper.selectCount(new QueryWrapper<AIChat>().eq("user_id", id));

        List<Diary> recent = diaryMapper.selectList(new QueryWrapper<Diary>()
                .eq("user_id", id)
                .orderByDesc("create_time")
                .last("LIMIT 8"));
        List<Map<String, Object>> recentDiaries = new ArrayList<>();
        for (Diary d : recent) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", d.getId());
            item.put("title", d.getTitle());
            item.put("emotion", d.getEmotion());
            item.put("intensity", d.getIntensity());
            item.put("createTime", d.getCreateTime());
            recentDiaries.add(item);
        }

        List<AssessmentResult> results = assessmentResultMapper.selectList(
                new QueryWrapper<AssessmentResult>()
                        .eq("user_id", id)
                        .orderByDesc("create_time")
                        .last("LIMIT 8"));
        List<Map<String, Object>> assessmentResults = new ArrayList<>();
        for (AssessmentResult r : results) {
            Map<String, Object> item = new HashMap<>();
            item.put("id", r.getId());
            item.put("title", r.getAssessmentTitle());
            item.put("score", r.getScore());
            item.put("level", r.getLevel());
            item.put("createTime", r.getCreateTime());
            assessmentResults.add(item);
        }

        Map<String, Object> data = new HashMap<>();
        data.put("user", row);
        data.put("diaryCount", diaryCount);
        data.put("feedbackCount", feedbackCount);
        data.put("assessmentCount", assessmentCount);
        data.put("chatCount", chatCount);
        data.put("recentDiaries", recentDiaries);
        data.put("assessmentResults", assessmentResults);
        return ApiResponse.success(data);
    }

    // ===== 批量操作 =====

    /**
     * 批量操作
     * body: { type: user|diary|feedback, action: delete|enable|disable|handle, ids: [] }
     */
    @PostMapping("/batch")
    public ApiResponse<Map<String, Object>> batch(@RequestBody Map<String, Object> body) {
        String type = str(body.get("type"));
        String action = str(body.get("action"));
        Object rawIds = body.get("ids");
        if (!(rawIds instanceof List)) {
            throw new RuntimeException("ids 必须是数组");
        }

        List<Long> ids = new ArrayList<>();
        for (Object o : (List<?>) rawIds) {
            if (o == null) {
                continue;
            }
            try {
                ids.add(Long.valueOf(o.toString()));
            } catch (NumberFormatException ignored) {
                // 跳过非法 id
            }
        }
        if (ids.isEmpty()) {
            throw new RuntimeException("请选择要操作的数据");
        }

        int affected = 0;
        if ("user".equals(type)) {
            if ("delete".equals(action)) {
                for (Long id : ids) {
                    if (userMapper.selectById(id) == null) {
                        continue;
                    }
                    diaryMapper.delete(new QueryWrapper<Diary>().eq("user_id", id));
                    feedbackMapper.delete(new QueryWrapper<Feedback>().eq("user_id", id));
                    assessmentResultMapper.delete(new QueryWrapper<AssessmentResult>().eq("user_id", id));
                    aiChatMapper.delete(new QueryWrapper<AIChat>().eq("user_id", id));
                    userMapper.deleteById(id);
                    affected++;
                }
            } else if ("enable".equals(action) || "disable".equals(action)) {
                int flag = "disable".equals(action) ? 1 : 0;
                for (Long id : ids) {
                    User patch = new User();
                    patch.setId(id);
                    patch.setDeleted(flag);
                    patch.setUpdateTime(LocalDateTime.now());
                    affected += userMapper.updateById(patch);
                }
            } else {
                throw new RuntimeException("不支持的批量操作: " + action);
            }
        } else if ("diary".equals(type)) {
            if (!"delete".equals(action)) {
                throw new RuntimeException("不支持的批量操作: " + action);
            }
            affected = diaryMapper.deleteBatchIds(ids);
        } else if ("feedback".equals(type)) {
            if ("delete".equals(action)) {
                affected = feedbackMapper.deleteBatchIds(ids);
            } else if ("handle".equals(action)) {
                for (Long id : ids) {
                    Feedback patch = new Feedback();
                    patch.setId(id);
                    patch.setIsHandled(true);
                    patch.setHandledTime(LocalDateTime.now());
                    affected += feedbackMapper.updateById(patch);
                }
            } else {
                throw new RuntimeException("不支持的批量操作: " + action);
            }
        } else {
            throw new RuntimeException("不支持的数据类型: " + type);
        }

        Map<String, Object> data = new HashMap<>();
        data.put("affected", affected);
        return ApiResponse.success(data);
    }

    // ===== 内部工具 =====

    private static String str(Object o) {
        return o == null ? "" : o.toString().trim();
    }

    private static long toLong(Object o) {
        if (o == null) {
            return 0L;
        }
        if (o instanceof Number) {
            return ((Number) o).longValue();
        }
        try {
            return Long.parseLong(o.toString());
        } catch (NumberFormatException e) {
            return 0L;
        }
    }

    /** 把 selectMaps 的 DATE(...) 分组结果整理成 {yyyy-MM-dd: count} */
    private static Map<String, Long> countByDay(List<Map<String, Object>> rows) {
        Map<String, Long> map = new HashMap<>();
        for (Map<String, Object> row : rows) {
            Object day = row.get("d");
            Object count = row.get("c");
            if (day == null) {
                continue;
            }
            map.put(day.toString(), toLong(count));
        }
        return map;
    }

    /** 统一分布数据格式为 [{name, value}]，并过滤空名称 */
    private static List<Map<String, Object>> normalizeDistribution(List<Map<String, Object>> rows,
                                                                   String nameKey,
                                                                   String valueKey) {
        List<Map<String, Object>> list = new ArrayList<>();
        for (Map<String, Object> row : rows) {
            Object name = row.get(nameKey);
            if (name == null || name.toString().trim().isEmpty()) {
                continue;
            }
            Map<String, Object> item = new HashMap<>();
            item.put("name", name.toString().trim());
            item.put("value", toLong(row.get(valueKey)));
            list.add(item);
        }
        return list;
    }
}
