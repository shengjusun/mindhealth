package com.mindhealth.backend.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.mindhealth.backend.dto.AssessmentRequest;
import com.mindhealth.backend.entity.Assessment;
import com.mindhealth.backend.entity.AssessmentResult;
import com.mindhealth.backend.mapper.AssessmentMapper;
import com.mindhealth.backend.mapper.AssessmentResultMapper;
import com.mindhealth.backend.service.AssessmentService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class AssessmentServiceImpl implements AssessmentService {

    @Autowired
    private AssessmentMapper assessmentMapper;

    @Autowired
    private AssessmentResultMapper assessmentResultMapper;

    @Override
    public List<Assessment> getAssessmentList() {
        return assessmentMapper.selectList(null);
    }

    @Override
    public Assessment getAssessmentById(Long id) {
        return assessmentMapper.selectById(id);
    }


    @Override
    public AssessmentResult submitAssessment(Long userId, AssessmentRequest request) {
        if (request.getAssessmentId() == null) {
            throw new RuntimeException("assessmentId不能为空");
        }
        if (request.getScore() == null) {
            throw new RuntimeException("score不能为空");
        }
        Assessment assessment = assessmentMapper.selectById(request.getAssessmentId());

        String assessmentTitle = assessment != null ? assessment.getName() : "心理测评";
        String level = generateLevel(request.getScore());
        String suggestion = generateSuggestion(request.getScore());

        AssessmentResult assessmentResult = new AssessmentResult();
        assessmentResult.setUserId(userId);
        assessmentResult.setAssessmentId(request.getAssessmentId());
        assessmentResult.setAssessmentTitle(assessmentTitle);
        assessmentResult.setScore(request.getScore());
        assessmentResult.setLevel(level);
        assessmentResult.setSuggestion(suggestion);
        assessmentResult.setCreateTime(LocalDateTime.now());

        assessmentResultMapper.insert(assessmentResult);
        return assessmentResult;
    }

    @Override
    public List<AssessmentResult> getAssessmentResults(Long userId) {
        QueryWrapper<AssessmentResult> queryWrapper = new QueryWrapper<>();
        queryWrapper.eq("user_id", userId).orderByDesc("create_time");
        return assessmentResultMapper.selectList(queryWrapper);
    }

    private String generateLevel(Integer score) {
        if (score == null) {
            return "未知";
        }

        if (score <= 3) {
            return "状态良好";
        } else if (score <= 8) {
            return "轻度波动";
        } else if (score <= 12) {
            return "中度风险";
        } else {
            return "较高风险";
        }
    }

    private String generateSuggestion(Integer score) {
        if (score == null) {
            return "请继续关注自己的情绪变化。";
        }

        if (score <= 3) {
            return "你当前整体状态不错，建议继续保持规律作息和情绪记录。";
        } else if (score <= 8) {
            return "你最近可能存在一定压力或情绪波动，建议适当休息并关注睡眠。";
        } else if (score <= 12) {
            return "你最近的情绪或压力状态较明显，建议主动调整节奏，并尝试寻求支持。";
        } else {
            return "你当前可能承受较大心理压力，建议尽快和可信任的人沟通，必要时寻求专业帮助。";
        }
    }
}