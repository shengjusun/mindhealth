package com.mindhealth.backend.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.Assessment;
import com.mindhealth.backend.entity.Diary;
import com.mindhealth.backend.entity.Feedback;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.mapper.AssessmentMapper;
import com.mindhealth.backend.mapper.DiaryMapper;
import com.mindhealth.backend.mapper.FeedbackMapper;
import com.mindhealth.backend.mapper.UserMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Web 管理后台数据接口（需管理员令牌，JwtAuthenticationFilter 注入 adminId）
 */
@RestController
@RequestMapping("/admin")
public class AdminController {

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private DiaryMapper diaryMapper;

    @Autowired
    private AssessmentMapper assessmentMapper;

    @Autowired
    private FeedbackMapper feedbackMapper;

    @Autowired
    private com.mindhealth.backend.mapper.AssessmentResultMapper assessmentResultMapper;

    @Autowired
    private com.mindhealth.backend.mapper.AIChatMapper aiChatMapper;

    @Autowired
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    private final ObjectMapper objectMapper = new ObjectMapper();

    // ===== 概览统计 =====

    @GetMapping("/stats")
    public ApiResponse<Map<String, Object>> stats() {
        Map<String, Object> stats = new HashMap<>();
        stats.put("userCount", userMapper.selectCount(null));
        stats.put("diaryCount", diaryMapper.selectCount(null));
        stats.put("assessmentResultCount", assessmentResultMapper.selectCount(null));
        stats.put("feedbackUnhandled", feedbackMapper.selectCount(
                new QueryWrapper<Feedback>().eq("is_handled", 0)));
        stats.put("feedbackTotal", feedbackMapper.selectCount(null));
        return ApiResponse.success(stats);
    }

    // ===== 用户管理 =====

    @GetMapping("/users")
    public ApiResponse<Map<String, Object>> users(@RequestParam(defaultValue = "1") long page,
                                                  @RequestParam(defaultValue = "10") long size,
                                                  @RequestParam(required = false) String keyword) {
        QueryWrapper<User> wrapper = new QueryWrapper<>();
        if (keyword != null && !keyword.trim().isEmpty()) {
            wrapper.and(w -> w.like("nickname", keyword.trim()).or().like("phone", keyword.trim()));
        }
        wrapper.orderByDesc("create_time");
        Page<User> result = userMapper.selectPage(new Page<>(page, size), wrapper);

        List<Map<String, Object>> rows = result.getRecords().stream().map(u -> {
            Map<String, Object> row = new HashMap<>();
            row.put("id", u.getId());
            row.put("phone", u.getPhone());
            row.put("nickname", u.getNickname());
            row.put("gender", u.getGender());
            row.put("age", u.getAge());
            row.put("avatar", u.getAvatar());
            row.put("isHuaweiUser", u.getHuaweiUnionId() != null);
            row.put("deleted", u.getDeleted());
            row.put("createTime", u.getCreateTime());
            return row;
        }).collect(Collectors.toList());

        Map<String, Object> data = new HashMap<>();
        data.put("total", result.getTotal());
        data.put("records", rows);
        return ApiResponse.success(data);
    }

    /** 启用 / 禁用用户（deleted: 0 启用，1 禁用） */
    @PutMapping("/users/{id}/status")
    public ApiResponse<Object> setUserStatus(@PathVariable Long id, @RequestParam Integer deleted) {
        User user = userMapper.selectById(id);
        if (user == null) {
            throw new RuntimeException("用户不存在");
        }
        User patch = new User();
        patch.setId(id);
        patch.setDeleted(deleted != null && deleted == 1 ? 1 : 0);
        patch.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(patch);
        return ApiResponse.success(true);
    }

    /** 管理员新增用户（手机号 + 初始密码） */
    @PostMapping("/users")
    public ApiResponse<Object> addUser(@RequestBody Map<String, Object> body) {
        String phone = str(body.get("phone"));
        String password = str(body.get("password"));
        String nickname = str(body.get("nickname"));

        if (!phone.matches("^1[3-9]\\d{9}$")) {
            throw new RuntimeException("手机号格式不正确");
        }
        if (password.length() < 6 || password.length() > 64) {
            throw new RuntimeException("初始密码需为 6~64 位");
        }
        if (userMapper.selectOne(new QueryWrapper<User>().eq("phone", phone)) != null) {
            throw new RuntimeException("该手机号已注册");
        }

        User user = new User();
        user.setPhone(phone);
        user.setPassword(passwordEncoder.encode(password));
        user.setNickname(nickname.isEmpty() ? "用户" + phone.substring(phone.length() - 4) : nickname);
        String gender = str(body.get("gender"));
        if (!gender.isEmpty()) {
            user.setGender(gender);
        }
        Object age = body.get("age");
        if (age != null) {
            try {
                user.setAge(Integer.valueOf(age.toString()));
            } catch (NumberFormatException ignored) {
            }
        }
        user.setCreateTime(LocalDateTime.now());
        user.setUpdateTime(LocalDateTime.now());
        user.setDeleted(0);
        userMapper.insert(user);
        return ApiResponse.success(user.getId());
    }

    /** 管理员编辑用户资料（昵称/年龄/性别/签名） */
    @PutMapping("/users/{id}")
    public ApiResponse<Object> updateUser(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        User user = userMapper.selectById(id);
        if (user == null) {
            throw new RuntimeException("用户不存在");
        }
        User patch = new User();
        patch.setId(id);
        String nickname = str(body.get("nickname"));
        if (!nickname.isEmpty()) {
            patch.setNickname(nickname);
        }
        String gender = str(body.get("gender"));
        if (!gender.isEmpty()) {
            patch.setGender(gender);
        }
        Object age = body.get("age");
        if (age != null) {
            try {
                patch.setAge(Integer.valueOf(age.toString()));
            } catch (NumberFormatException ignored) {
            }
        }
        String signature = str(body.get("signature"));
        if (body.containsKey("signature")) {
            patch.setSignature(signature);
        }
        patch.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(patch);
        return ApiResponse.success(true);
    }

    /** 管理员重置用户密码 */
    @PutMapping("/users/{id}/password")
    public ApiResponse<Object> resetPassword(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        if (userMapper.selectById(id) == null) {
            throw new RuntimeException("用户不存在");
        }
        String password = str(body.get("password"));
        if (password.length() < 6 || password.length() > 64) {
            throw new RuntimeException("新密码需为 6~64 位");
        }
        User patch = new User();
        patch.setId(id);
        patch.setPassword(passwordEncoder.encode(password));
        patch.setUpdateTime(LocalDateTime.now());
        userMapper.updateById(patch);
        return ApiResponse.success(true);
    }

    /** 删除用户（物理删除，并清理其日记/测评记录/反馈/AI 聊天记录） */
    @DeleteMapping("/users/{id}")
    public ApiResponse<Object> deleteUser(@PathVariable Long id) {
        if (userMapper.selectById(id) == null) {
            throw new RuntimeException("用户不存在");
        }
        diaryMapper.delete(new QueryWrapper<Diary>().eq("user_id", id));
        feedbackMapper.delete(new QueryWrapper<Feedback>().eq("user_id", id));
        assessmentResultMapper.delete(new QueryWrapper<com.mindhealth.backend.entity.AssessmentResult>().eq("user_id", id));
        aiChatMapper.delete(new QueryWrapper<com.mindhealth.backend.entity.AIChat>().eq("user_id", id));
        userMapper.deleteById(id);
        return ApiResponse.success(true);
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString().trim();
    }


    // ===== 日记管理 =====

    @GetMapping("/diaries")
    public ApiResponse<Map<String, Object>> diaries(@RequestParam(defaultValue = "1") long page,
                                                    @RequestParam(defaultValue = "10") long size,
                                                    @RequestParam(required = false) String keyword) {
        QueryWrapper<Diary> wrapper = new QueryWrapper<>();
        if (keyword != null && !keyword.trim().isEmpty()) {
            wrapper.and(w -> w.like("title", keyword.trim()).or().like("content", keyword.trim()));
        }
        wrapper.orderByDesc("create_time");
        Page<Diary> result = diaryMapper.selectPage(new Page<>(page, size), wrapper);

        // 批量补充作者昵称
        Map<Long, String> nicknames = new HashMap<>();
        List<Long> userIds = result.getRecords().stream()
                .map(Diary::getUserId).distinct().collect(Collectors.toList());
        if (!userIds.isEmpty()) {
            userMapper.selectBatchIds(userIds)
                    .forEach(u -> nicknames.put(u.getId(), u.getNickname()));
        }

        List<Map<String, Object>> rows = result.getRecords().stream().map(d -> {
            Map<String, Object> row = new HashMap<>();
            row.put("id", d.getId());
            row.put("userId", d.getUserId());
            row.put("author", nicknames.getOrDefault(d.getUserId(), "未知用户"));
            row.put("title", d.getTitle());
            row.put("content", d.getContent());
            row.put("emotion", d.getEmotion());
            row.put("intensity", d.getIntensity());
            row.put("createTime", d.getCreateTime());
            return row;
        }).collect(Collectors.toList());

        Map<String, Object> data = new HashMap<>();
        data.put("total", result.getTotal());
        data.put("records", rows);
        return ApiResponse.success(data);
    }

    @DeleteMapping("/diaries/{id}")
    public ApiResponse<Object> deleteDiary(@PathVariable Long id) {
        diaryMapper.deleteById(id);
        return ApiResponse.success(true);
    }

    // ===== 测评量表 / 题库管理 =====

    @GetMapping("/assessments")
    public ApiResponse<Object> assessments() {
        return ApiResponse.success(assessmentMapper.selectList(
                new QueryWrapper<Assessment>().orderByAsc("id")));
    }

    /** 管理员新增量表（题库必须是合法 JSON 数组） */
    @PostMapping("/assessments")
    public ApiResponse<Object> addAssessment(@RequestBody Map<String, String> body) {
        String name = str(body.get("name"));
        if (name.isEmpty()) {
            throw new RuntimeException("量表名称不能为空");
        }
        String questions = body.get("questions");
        if (questions == null || questions.trim().isEmpty()) {
            throw new RuntimeException("题库不能为空");
        }
        try {
            JsonNode node = objectMapper.readTree(questions);
            if (!node.isArray() || node.isEmpty()) {
                throw new RuntimeException("题库必须是Array且不能为空");
            }
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("题库 JSON 格式错误: " + e.getMessage());
        }

        Assessment assessment = new Assessment();
        assessment.setName(name);
        String type = str(body.get("type"));
        assessment.setType(type.isEmpty() ? name : type);
        assessment.setDescription(str(body.get("description")));
        assessment.setQuestions(questions.trim());
        assessment.setCreateTime(LocalDateTime.now());
        assessment.setUpdateTime(LocalDateTime.now());
        assessmentMapper.insert(assessment);
        return ApiResponse.success(assessment.getId());
    }

    @DeleteMapping("/assessments/{id}")
    public ApiResponse<Object> deleteAssessment(@PathVariable Long id) {
        if (assessmentMapper.selectById(id) == null) {
            throw new RuntimeException("量表不存在");
        }
        assessmentResultMapper.delete(new QueryWrapper<com.mindhealth.backend.entity.AssessmentResult>().eq("assessment_id", id));
        assessmentMapper.deleteById(id);
        return ApiResponse.success(true);
    }

    /** 更新量表名称/描述/题库（题库必须是合法 JSON 数组） */
    @PutMapping("/assessments/{id}")
    public ApiResponse<Object> updateAssessment(@PathVariable Long id,
                                                @RequestBody Map<String, String> body) {
        Assessment assessment = assessmentMapper.selectById(id);
        if (assessment == null) {
            throw new RuntimeException("量表不存在");
        }

        String questions = body.get("questions");
        if (questions != null && !questions.trim().isEmpty()) {
            try {
                JsonNode node = objectMapper.readTree(questions);
                if (!node.isArray() || node.isEmpty()) {
                    throw new RuntimeException("题库必须是Array且不能为空");
                }
            } catch (Exception e) {
                throw new RuntimeException("题库 JSON 格式错误: " + e.getMessage());
            }
            assessment.setQuestions(questions.trim());
        }
        if (body.get("name") != null && !body.get("name").trim().isEmpty()) {
            assessment.setName(body.get("name").trim());
        }
        if (body.get("description") != null) {
            assessment.setDescription(body.get("description").trim());
        }
        assessment.setUpdateTime(LocalDateTime.now());
        assessmentMapper.updateById(assessment);
        return ApiResponse.success(true);
    }

    // ===== 反馈管理 =====

    @GetMapping("/feedbacks")
    public ApiResponse<Map<String, Object>> feedbacks(@RequestParam(defaultValue = "1") long page,
                                                      @RequestParam(defaultValue = "10") long size,
                                                      @RequestParam(required = false) Integer handled) {
        QueryWrapper<Feedback> wrapper = new QueryWrapper<>();
        if (handled != null) {
            wrapper.eq("is_handled", handled);
        }
        wrapper.orderByDesc("create_time");
        Page<Feedback> result = feedbackMapper.selectPage(new Page<>(page, size), wrapper);

        Map<Long, String> nicknames = new HashMap<>();
        List<Long> fbUserIds = result.getRecords().stream()
                .map(Feedback::getUserId).distinct().collect(Collectors.toList());
        if (!fbUserIds.isEmpty()) {
            userMapper.selectBatchIds(fbUserIds)
                    .forEach(u -> nicknames.put(u.getId(), u.getNickname()));
        }

        List<Map<String, Object>> rows = result.getRecords().stream().map(fb -> {
            Map<String, Object> row = new HashMap<>();
            row.put("id", fb.getId());
            row.put("userId", fb.getUserId());
            row.put("author", nicknames.getOrDefault(fb.getUserId(), "未知用户"));
            row.put("type", fb.getType());
            row.put("content", fb.getContent());
            row.put("contact", fb.getContact());
            row.put("isHandled", fb.getIsHandled());
            row.put("handledTime", fb.getHandledTime());
            row.put("createTime", fb.getCreateTime());
            return row;
        }).collect(Collectors.toList());

        Map<String, Object> data = new HashMap<>();
        data.put("total", result.getTotal());
        data.put("records", rows);
        return ApiResponse.success(data);
    }

    @PutMapping("/feedbacks/{id}/handle")
    public ApiResponse<Object> handleFeedback(@PathVariable Long id) {
        Feedback feedback = feedbackMapper.selectById(id);
        if (feedback == null) {
            throw new RuntimeException("反馈不存在");
        }
        Feedback patch = new Feedback();
        patch.setId(id);
        patch.setIsHandled(true);
        patch.setHandledTime(LocalDateTime.now());
        feedbackMapper.updateById(patch);
        return ApiResponse.success(true);
    }

    @DeleteMapping("/feedbacks/{id}")
    public ApiResponse<Object> deleteFeedback(@PathVariable Long id) {
        feedbackMapper.deleteById(id);
        return ApiResponse.success(true);
    }
}
