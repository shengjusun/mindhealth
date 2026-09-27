package com.mindhealth.backend.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindhealth.backend.entity.Assessment;
import com.mindhealth.backend.mapper.AssessmentMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 量表题库服务。
 *
 * <p>改造说明（重要）：这里原先叫 {@code ScaleFileService}，逻辑是「静态文件
 * {@code classpath:static/scales/*.json} 优先、数据库兜底」。结果是管理后台在库里改了题目、
 * 客户端拿到的却还是包内的旧题库——数据库里是「情绪状态自评」等 6 套，包里却是
 * 「SCL-90症状自评量表」等 5 套（挂着临床量表名，实际只有 5 道通用题），两边长期不一致。
 *
 * <p>现在改为<b>数据库是唯一来源</b>：{@code assessment} 表即题库，管理后台改完立即生效。
 * 静态 scales 目录已删除，客户端侧仍保留一份 rawfile 作为「首次安装且无网络」的离线种子，
 * 联网后由 manifest 的版本号驱动更新。
 *
 * <p>不再做内存缓存：量表只有个位数行，接口又只在客户端启动/同步时调用，每次读库的代价可忽略，
 * 换来的是「管理端改完立刻生效」，不必再操心缓存失效。
 */
@Service
public class ScaleService {

    private static final Logger log = LoggerFactory.getLogger(ScaleService.class);

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Autowired
    private AssessmentMapper assessmentMapper;

    /** 单道题（供算分复用） */
    public static class Option {
        public String key;
        public String text;
        public int score;
    }

    /** 单道题 */
    public static class Question {
        public long id;
        public String title;
        public List<Option> options;
    }

    // ------------------------------------------------------------------ 对外接口

    /**
     * 量表清单，供客户端判断是否需要更新本地题库。
     * 未配置题目的量表不会出现在清单里（拉下来也做不了）。
     */
    public String manifest() {
        Map<String, Object> manifest = new LinkedHashMap<>();
        List<Map<String, Object>> scales = new ArrayList<>();
        long maxVersion = 0L;

        for (Assessment a : assessmentMapper.selectList(new QueryWrapper<Assessment>().orderByAsc("id"))) {
            String raw = a.getQuestions();
            if (raw == null || raw.isBlank()) {
                continue;
            }
            long version = versionOf(a);
            if (version > maxVersion) {
                maxVersion = version;
            }
            Map<String, Object> meta = new LinkedHashMap<>();
            meta.put("id", a.getId());
            meta.put("name", a.getName());
            meta.put("type", a.getType());
            meta.put("description", a.getDescription());
            meta.put("questionCount", countQuestions(raw));
            meta.put("maxScore", calcMaxScore(raw));
            meta.put("version", version);
            scales.add(meta);
        }

        manifest.put("version", maxVersion);
        manifest.put("updatedAt", maxVersion > 0
                ? LocalDateTime.ofEpochSecond(maxVersion, 0, ZoneOffset.ofHours(8)).toString()
                : null);
        manifest.put("scales", scales);
        return toJson(manifest);
    }

    /**
     * 单套量表题目包，结构与客户端 ScaleDetail 一致：
     * {@code {id,name,type,version,maxScore,scoring,questions:[{id,title,options:[{key,text,score}]}]}}
     *
     * @return 量表不存在、或没有配置题目时返回 {@code null}
     */
    public String questions(long id) {
        Assessment assessment = assessmentMapper.selectById(id);
        if (assessment == null) {
            return null;
        }
        String raw = assessment.getQuestions();
        if (raw == null || raw.isBlank()) {
            return null;
        }

        try {
            Map<String, Object> pkg = new LinkedHashMap<>();
            pkg.put("id", assessment.getId());
            pkg.put("name", assessment.getName());
            pkg.put("type", assessment.getType());
            pkg.put("description", assessment.getDescription());
            pkg.put("version", versionOf(assessment));
            pkg.put("maxScore", calcMaxScore(raw));
            // scoring 一并下发：客户端可以据此画分数区间，不必自己再写一份阈值
            JsonNode scoring = readScoring(assessment);
            if (scoring != null) {
                pkg.put("scoring", scoring);
            }
            pkg.put("questions", objectMapper.readValue(raw, Object.class));
            return toJson(pkg);
        } catch (Exception e) {
            log.warn("组装量表 {} 题目失败: {}", id, e.getMessage());
            return null;
        }
    }

    /**
     * 解析后的题目列表，供服务端算分使用。
     * 后端必须自己能按题库算分，不能信任客户端传上来的分数。
     *
     * @return 量表不存在或题目解析失败时返回 {@code null}
     */
    public List<Question> parseQuestions(long id) {
        Assessment assessment = assessmentMapper.selectById(id);
        if (assessment == null) {
            return null;
        }
        String raw = assessment.getQuestions();
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return objectMapper.readValue(raw,
                    objectMapper.getTypeFactory().constructCollectionType(List.class, Question.class));
        } catch (Exception e) {
            log.warn("解析量表 {} 题目失败: {}", id, e.getMessage());
            return null;
        }
    }

    /** 量表的计分配置（bands），没有配置时返回 null，由调用方回退到通用阈值 */
    public JsonNode scoringOf(long id) {
        Assessment assessment = assessmentMapper.selectById(id);
        return assessment == null ? null : readScoring(assessment);
    }

    // ------------------------------------------------------------------ 私有方法

    private JsonNode readScoring(Assessment assessment) {
        String raw = assessment.getScoring();
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return objectMapper.readTree(raw);
        } catch (Exception e) {
            log.warn("量表 {} 的 scoring 不是合法 JSON，已忽略: {}", assessment.getId(), e.getMessage());
            return null;
        }
    }

    /** 版本号取 update_time（缺失时用 create_time）的秒级时间戳，保证单调递增 */
    private long versionOf(Assessment assessment) {
        LocalDateTime time = assessment.getUpdateTime() != null
                ? assessment.getUpdateTime() : assessment.getCreateTime();
        return time == null ? Instant.now().getEpochSecond() : time.toEpochSecond(ZoneOffset.ofHours(8));
    }

    private int countQuestions(String questionsJson) {
        try {
            JsonNode arr = objectMapper.readTree(questionsJson);
            return arr.isArray() ? arr.size() : 0;
        } catch (Exception e) {
            return 0;
        }
    }

    /** 满分 = 每题最高分之和（与客户端 getMaxScore 口径一致） */
    private int calcMaxScore(String questionsJson) {
        try {
            JsonNode arr = objectMapper.readTree(questionsJson);
            if (!arr.isArray()) {
                return 0;
            }
            int max = 0;
            for (JsonNode question : arr) {
                int questionMax = 0;
                JsonNode options = question.get("options");
                if (options != null && options.isArray()) {
                    for (JsonNode option : options) {
                        JsonNode score = option.get("score");
                        if (score != null && score.asInt() > questionMax) {
                            questionMax = score.asInt();
                        }
                    }
                }
                max += questionMax;
            }
            return max;
        } catch (Exception e) {
            log.warn("计算满分失败: {}", e.getMessage());
            return 0;
        }
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (Exception e) {
            log.warn("序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
