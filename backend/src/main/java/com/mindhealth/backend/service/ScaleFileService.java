package com.mindhealth.backend.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindhealth.backend.entity.Assessment;
import com.mindhealth.backend.mapper.AssessmentMapper;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.util.StreamUtils;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 量表题库静态文件服务
 *
 * <p>题库属于「只读配置」，不适合每次都从数据库读。本服务把题库以静态 JSON 的形式
 * 放在 {@code classpath:static/scales/} 下，启动时一次性加载到内存：
 * <ul>
 *   <li>{@code manifest.json}：量表清单 + 版本号，客户端据此做增量更新</li>
 *   <li>{@code {id}.json}：单套量表题目，结构与 {@code assessment.questions} 完全一致</li>
 * </ul>
 *
 * <p>静态文件缺失时（例如管理后台新增了量表但还没发布），自动回退读取数据库，
 * 保证接口行为与改造前一致，不会因为静态化导致 404。
 */
@Service
public class ScaleFileService {

    private static final Logger log = LoggerFactory.getLogger(ScaleFileService.class);

    /** 静态题库在 classpath 下的目录 */
    private static final String SCALES_DIR = "static/scales/";
    private static final String MANIFEST_FILE = SCALES_DIR + "manifest.json";
    private static final String EMPTY_MANIFEST = "{\"version\":0,\"updatedAt\":null,\"scales\":[]}";

    private final ObjectMapper objectMapper = new ObjectMapper();

    /** 题目缓存：scaleId -> 题库 JSON 文本 */
    private final Map<Long, String> questionCache = new ConcurrentHashMap<>();

    /** 清单缓存 */
    private volatile String manifestCache = EMPTY_MANIFEST;

    @Autowired
    private AssessmentMapper assessmentMapper;

    /** 启动时加载；管理后台发布题库后可再次调用以热更新 */
    @PostConstruct
    public void reload() {
        String manifest = readClasspath(MANIFEST_FILE);
        if (manifest == null) {
            log.warn("静态题库未发布（{} 不存在），量表接口将回退读取数据库", MANIFEST_FILE);
            return;
        }
        try {
            manifestCache = manifest;
            questionCache.clear();

            JsonNode scales = objectMapper.readTree(manifest).get("scales");
            if (scales != null && scales.isArray()) {
                for (JsonNode node : scales) {
                    JsonNode idNode = node.get("id");
                    if (idNode == null) {
                        continue;
                    }
                    long id = idNode.asLong();
                    String body = readClasspath(SCALES_DIR + id + ".json");
                    if (body != null) {
                        questionCache.put(id, body);
                    } else {
                        log.warn("清单中登记了量表 {}，但缺少静态文件 {}，将回退数据库", id, SCALES_DIR + id + ".json");
                    }
                }
            }
            log.info("静态题库加载完成，共 {} 套", questionCache.size());
        } catch (Exception e) {
            log.warn("静态题库加载失败，回退数据库: {}", e.getMessage());
            manifestCache = EMPTY_MANIFEST;
            questionCache.clear();
        }
    }

    /** 量表清单（含版本号），供客户端判断是否需要更新本地缓存 */
    public String manifest() {
        return manifestCache;
    }

    /**
     * 单套量表题目。
     *
     * @return 题库 JSON；静态文件与数据库中都没有时返回 {@code null}
     */
    public String questions(long id) {
        String cached = questionCache.get(id);
        if (cached != null) {
            return cached;
        }
        return fallbackFromDb(id);
    }

    // ------------------------------------------------------------------ 私有方法

    /** 静态文件缺失时，按与改造前完全一致的结构从数据库组装 */
    private String fallbackFromDb(long id) {
        try {
            Assessment assessment = assessmentMapper.selectById(id);
            if (assessment == null) {
                return null;
            }
            String raw = assessment.getQuestions();
            if (raw == null || raw.isBlank()) {
                return null;
            }

            Map<String, Object> pkg = new LinkedHashMap<>();
            pkg.put("id", assessment.getId());
            pkg.put("name", assessment.getName());
            pkg.put("type", assessment.getType());
            pkg.put("version", versionOf(assessment));
            pkg.put("questions", objectMapper.readValue(raw, Object.class));
            pkg.put("maxScore", calcMaxScore(raw));
            return objectMapper.writeValueAsString(pkg);
        } catch (Exception e) {
            log.warn("从数据库读取量表 {} 失败: {}", id, e.getMessage());
            return null;
        }
    }

    /** 版本号取 update_time（缺失时用 create_time）的秒级时间戳，保证单调递增 */
    private long versionOf(Assessment assessment) {
        LocalDateTime time = assessment.getUpdateTime() != null
                ? assessment.getUpdateTime() : assessment.getCreateTime();
        return time == null ? 1L : time.toEpochSecond(ZoneOffset.ofHours(8));
    }

    /** 满分 = 每题最高分之和（与客户端 AssessmentQuestionPage.getMaxScore() 口径一致） */
    private int calcMaxScore(String questionsJson) throws Exception {
        JsonNode arr = objectMapper.readTree(questionsJson);
        if (!arr.isArray()) {
            return 15;
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
        return max > 0 ? max : 15;
    }

    private String readClasspath(String path) {
        try {
            ClassPathResource resource = new ClassPathResource(path);
            if (!resource.exists()) {
                return null;
            }
            return StreamUtils.copyToString(resource.getInputStream(), StandardCharsets.UTF_8);
        } catch (Exception e) {
            log.warn("读取 classpath 资源失败 {}: {}", path, e.getMessage());
            return null;
        }
    }
}
