package com.mindhealth.backend.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindhealth.backend.dto.AssessmentRequest;
import com.mindhealth.backend.entity.Assessment;
import com.mindhealth.backend.entity.AssessmentResult;
import com.mindhealth.backend.mapper.AssessmentMapper;
import com.mindhealth.backend.mapper.AssessmentResultMapper;
import com.mindhealth.backend.service.AssessmentAiService;
import com.mindhealth.backend.service.AssessmentService;
import com.mindhealth.backend.service.ScaleService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 测评服务。
 *
 * <p>相比改造前的三点变化：
 * <ol>
 *   <li><b>服务端算分</b>：此前直接采用客户端传来的 {@code score}，等于把计分权交给客户端
 *       （改个包就能刷成「状态良好」），而且服务端永远拿不到答题内容。</li>
 *   <li><b>分级按量表自身配置</b>：此前 6 套量表共用 {@code <=3/8/12} 和三句写死的话，
 *       现在从 {@code assessment.scoring.bands} 读取，每套量表各有一套阈值和文案。</li>
 *   <li><b>提交即返回，AI 后置</b>：落库后立刻返回规则基线结果，AI 深度解读异步写入，
 *       失败也只标记状态，不影响测评本身。</li>
 * </ol>
 */
@Service
public class AssessmentServiceImpl implements AssessmentService {

    private static final Logger log = LoggerFactory.getLogger(AssessmentServiceImpl.class);

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    private AssessmentMapper assessmentMapper;

    @Autowired
    private AssessmentResultMapper assessmentResultMapper;

    @Autowired
    private ScaleService scaleService;

    @Autowired
    private AssessmentAiService assessmentAiService;

    /** 逐题明细的落库结构（字段名即 JSON 字段名，管理端与 AI 都读它） */
    public static class AnswerDetail {
        public long questionId;
        public String title;
        public String optionKey;
        public String optionText;
        public int score;
        public int maxScore;
    }

    private static class Scoring {
        int score;
        int maxScore;
        String answersJson;
    }

    private static class Band {
        final String level;
        final String suggestion;

        Band(String level, String suggestion) {
            this.level = level;
            this.suggestion = suggestion;
        }
    }

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
        Assessment assessment = assessmentMapper.selectById(request.getAssessmentId());
        if (assessment == null) {
            throw new RuntimeException("量表不存在");
        }

        List<ScaleService.Question> questions = scaleService.parseQuestions(request.getAssessmentId());
        Scoring scoring = score(questions, request);
        Band band = resolveBand(assessment.getId(), scoring.score, scoring.maxScore);

        AssessmentResult result = new AssessmentResult();
        result.setUserId(userId);
        result.setAssessmentId(request.getAssessmentId());
        result.setAssessmentTitle(assessment.getName());
        result.setScore(scoring.score);
        result.setMaxScore(scoring.maxScore);
        result.setAnswersJson(scoring.answersJson);
        result.setLevel(band.level);
        result.setSuggestion(band.suggestion);
        result.setAiStatus("pending");
        result.setCreateTime(LocalDateTime.now());

        assessmentResultMapper.insert(result);

        // 异步生成 AI 解读；失败只写状态，不回滚测评结果
        assessmentAiService.analyzeAsync(result.getId());

        return result;
    }

    @Override
    public List<AssessmentResult> getAssessmentResults(Long userId) {
        QueryWrapper<AssessmentResult> queryWrapper = new QueryWrapper<>();
        queryWrapper.eq("user_id", userId).orderByDesc("create_time");
        return assessmentResultMapper.selectList(queryWrapper);
    }

    /** 单条结果，用于客户端轮询 AI 解读；非本用户的结果一律视为不存在 */
    @Override
    public AssessmentResult getAssessmentResult(Long userId, Long id) {
        AssessmentResult result = assessmentResultMapper.selectById(id);
        if (result == null || !result.getUserId().equals(userId)) {
            return null;
        }
        return result;
    }

    // ------------------------------------------------------------------ 算分

    private Scoring score(List<ScaleService.Question> questions, AssessmentRequest request) {
        Scoring out = new Scoring();

        if (questions == null || questions.isEmpty()) {
            // 题库缺失（理论上不该发生）：退回客户端分数，保证测评仍可用，只是没有逐题明细
            log.warn("量表题库为空，回退使用客户端分数");
            out.score = request.getScore() == null ? 0 : Math.max(0, request.getScore());
            out.maxScore = 0;
            out.answersJson = null;
            return out;
        }

        int fullScore = 0;
        for (ScaleService.Question question : questions) {
            fullScore += questionMax(question);
        }

        boolean hasAnswers = request.getAnswers() != null && !request.getAnswers().isEmpty();
        if (!hasAnswers) {
            // 旧版客户端只上报总分：保持可用，但仍然补上满分为后续分析提供分母
            log.info("本次提交未携带答题明细（旧客户端），使用客户端分数");
            out.score = clamp(request.getScore() == null ? 0 : request.getScore(), fullScore);
            out.maxScore = fullScore;
            out.answersJson = null;
            return out;
        }

        Map<Long, String> answerMap = new HashMap<>();
        for (AssessmentRequest.Answer answer : request.getAnswers()) {
            if (answer != null && answer.getQuestionId() != null) {
                answerMap.put(answer.getQuestionId(), answer.getOptionKey());
            }
        }

        List<AnswerDetail> details = new ArrayList<>();
        int total = 0;

        for (ScaleService.Question question : questions) {
            String optionKey = answerMap.get(question.id);
            ScaleService.Option chosen = findOption(question, optionKey);
            if (chosen != null) {
                total += chosen.score;
            }

            AnswerDetail detail = new AnswerDetail();
            detail.questionId = question.id;
            detail.title = question.title;
            detail.optionKey = chosen == null ? null : chosen.key;
            detail.optionText = chosen == null ? null : chosen.text;
            detail.score = chosen == null ? 0 : chosen.score;
            detail.maxScore = questionMax(question);
            details.add(detail);
        }

        out.score = total;
        out.maxScore = fullScore;
        out.answersJson = toJson(details);
        return out;
    }

    private int questionMax(ScaleService.Question question) {
        int max = 0;
        if (question.options != null) {
            for (ScaleService.Option option : question.options) {
                max = Math.max(max, option.score);
            }
        }
        return max;
    }

    private ScaleService.Option findOption(ScaleService.Question question, String optionKey) {
        if (optionKey == null || question.options == null) {
            return null;
        }
        for (ScaleService.Option option : question.options) {
            if (optionKey.equalsIgnoreCase(option.key)) {
                return option;
            }
        }
        return null;
    }

    private int clamp(int value, int ceiling) {
        if (value < 0) {
            return 0;
        }
        return ceiling > 0 && value > ceiling ? ceiling : value;
    }

    // ------------------------------------------------------------------ 分级

    /** 优先用题库自带的 bands；量表没配 scoring 时按得分比例兜底，避免完全没有文案 */
    private Band resolveBand(long assessmentId, int score, int maxScore) {
        JsonNode scoring = scaleService.scoringOf(assessmentId);
        if (scoring != null) {
            JsonNode bands = scoring.path("bands");
            if (bands.isArray() && !bands.isEmpty()) {
                for (JsonNode band : bands) {
                    if (score <= band.path("max").asInt(Integer.MAX_VALUE)) {
                        String level = band.path("level").asText("").trim();
                        String suggestion = band.path("suggestion").asText("").trim();
                        if (!level.isEmpty()) {
                            return new Band(level, suggestion);
                        }
                    }
                }
            }
        }
        return proportionalBand(score, maxScore);
    }

    private Band proportionalBand(int score, int maxScore) {
        int full = maxScore > 0 ? maxScore : 36;
        double ratio = (double) score / full;
        if (ratio <= 0.25) {
            return new Band("状态良好", "最近状态比较平稳，继续保持规律作息和情绪记录。");
        }
        if (ratio <= 0.5) {
            return new Band("轻度波动", "最近存在一定压力或情绪波动，建议适当休息并关注睡眠。");
        }
        if (ratio <= 0.75) {
            return new Band("中度困扰", "最近困扰比较明显，建议主动调整节奏，并多和信任的人聊一聊。");
        }
        return new Band("困扰较重", "当前困扰程度较高，建议尽快联系可信任的人，或寻求专业心理支持。");
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception e) {
            log.warn("序列化答题明细失败: {}", e.getMessage());
            return null;
        }
    }
}
