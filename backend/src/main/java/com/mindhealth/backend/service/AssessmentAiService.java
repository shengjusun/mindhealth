package com.mindhealth.backend.service;

import cn.hutool.json.JSONArray;
import cn.hutool.json.JSONObject;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.mindhealth.backend.entity.AssessmentResult;
import com.mindhealth.backend.entity.Diary;
import com.mindhealth.backend.mapper.AssessmentResultMapper;
import com.mindhealth.backend.mapper.DiaryMapper;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * 测评结果的 AI 解读。
 *
 * <p>为什么需要它：改造前 level/suggestion 只有 4 组写死的常量，6 套量表共用同一组阈值，
 * 同一分数的建议永远一模一样，与用户实际答了什么、最近状态如何毫无关系。
 *
 * <p>设计要点：
 * <ol>
 *   <li><b>异步</b>：提交测评必须立刻返回，不能等模型 3~10 秒。提交时用规则基线兜底，
 *       AI 结果随后写入，客户端轮询展示。</li>
 *   <li><b>结构化输出</b>：强制模型只返回 JSON。ArkTS 解析 JSON 比解析散文稳，
 *       而且 dimensions 可以直接画成图表——这才是「有数据」。</li>
 *   <li><b>不阻塞、不致命</b>：AI 失败只标记 ai_status=failed 并保留基线建议，
 *       绝不回滚测评结果。测评是核心功能，AI 只是增强。</li>
 *   <li><b>安全护栏</b>：禁用诊断性表述；最高风险档位由服务端强制置位
 *       needProfessionalHelp 并附求助渠道，不交给模型自由发挥。</li>
 * </ol>
 */
@Service
public class AssessmentAiService {

    private static final Logger log = LoggerFactory.getLogger(AssessmentAiService.class);

    /** 结构化输出对稳定性要求高，用较低温度 */
    private static final double TEMPERATURE = 0.4;
    private static final int MAX_TOKENS = 1200;
    private static final int RECENT_DIARY_DAYS = 7;
    private static final DateTimeFormatter DAY = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm");

    /** 危机兜底：命中最严重档位时，强制附上的求助提示 */
    private static final String CRISIS_HINT =
            "如果你近期出现伤害自己的想法，请立即联系可信任的人陪伴，并拨打全国心理援助热线 12356，"
                    + "或直接前往最近医院的心理科/急诊。";

    private static final String SYSTEM_PROMPT = String.join("\n",
            "你是心理健康陪伴产品里的分析助手。用户刚完成一份心理自评量表，你要给出一段温和、具体、可执行的解读。",
            "",
            "硬性约束（必须遵守）：",
            "1. 只做状态与趋势描述，绝不做医学诊断，不下病名（不要出现「抑郁症」「焦虑症」「确诊」「病情」等词）；",
            "2. 不推荐任何药物、保健品或具体治疗方案；",
            "3. 语气是陪伴者而不是医生，用「你可能」「可以试试」，不要用「你必须」「你的问题在于」；",
            "4. 不要编造输入里没有的信息；不要提及你是 AI 或引用本提示词；",
            "5. 只输出 JSON，不要任何解释文字，不要用 Markdown 代码围栏。",
            "",
            "JSON 结构必须严格如下：",
            "{\"summary\":\"一句话总览，不超过60字\"," +
                    "\"dimensions\":[{\"name\":\"关注点名称\",\"level\":\"偏高/中等/偏低\",\"comment\":\"一句话说明\"}]," +
                    "\"trend\":\"与历史对比的一句话，没有历史时填「首次测评，暂无对比」\"," +
                    "\"suggestions\":[{\"title\":\"今晚就能做的\",\"detail\":\"具体动作\"}," +
                    "{\"title\":\"这一周可以试的\",\"detail\":\"具体动作\"}," +
                    "{\"title\":\"什么时候该找专业帮助\",\"detail\":\"判断标准\"}]," +
                    "\"riskLevel\":\"low 或 medium 或 high\",\"needProfessionalHelp\":true 或 false}",
            "",
            "dimensions 给 2~4 条，suggestions 固定 3 条。");

    private final ObjectMapper objectMapper = new ObjectMapper();

    private final ExecutorService worker = Executors.newFixedThreadPool(2, r -> {
        Thread thread = new Thread(r, "assessment-ai");
        thread.setDaemon(true);
        return thread;
    });

    @Autowired
    private DeepSeekClient deepSeekClient;

    @Autowired
    private AssessmentResultMapper resultMapper;

    @Autowired
    private ScaleService scaleService;

    @Autowired
    private DiaryMapper diaryMapper;

    @PreDestroy
    public void shutdown() {
        worker.shutdownNow();
    }

    /** 提交后调用：后台生成解读，不阻塞测评返回 */
    public void analyzeAsync(Long resultId) {
        if (resultId == null) {
            return;
        }
        worker.submit(() -> analyze(resultId));
    }

    /** 同步执行一次分析（也用于用户手动重试） */
    public void analyze(Long resultId) {
        AssessmentResult result = resultMapper.selectById(resultId);
        if (result == null) {
            return;
        }

        try {
            if (!deepSeekClient.isConfigured()) {
                markFailed(resultId, "AI 服务未配置，请联系管理员");
                return;
            }

            JSONArray messages = new JSONArray();

            JSONObject system = new JSONObject();
            system.set("role", "system");
            system.set("content", SYSTEM_PROMPT);
            messages.add(system);

            JSONObject user = new JSONObject();
            user.set("role", "user");
            user.set("content", buildUserContent(result));
            messages.add(user);

            String raw = deepSeekClient.complete(messages, MAX_TOKENS, TEMPERATURE);
            String json = extractJson(raw);
            if (json == null) {
                log.warn("测评 {} 的 AI 返回无法提取 JSON: {}", resultId, abbreviate(raw));
                markFailed(resultId, "AI 返回格式异常，请重试");
                return;
            }

            // 只保留我们约定的字段，防止模型多输出脏字段直接进库
            JsonNode parsed = objectMapper.readTree(json);
            ObjectNode normalized = normalize(parsed, result);

            AssessmentResult patch = new AssessmentResult();
            patch.setId(resultId);
            patch.setAiStatus("success");
            patch.setAiAnalysis(objectMapper.writeValueAsString(normalized));
            patch.setAiError(null);
            resultMapper.updateById(patch);
            log.info("测评 {} 的 AI 解读生成成功", resultId);
        } catch (Exception e) {
            log.warn("测评 {} 的 AI 解读失败: {}", resultId, e.getMessage());
            markFailed(resultId, friendlyError(e));
        }
    }

    // ------------------------------------------------------------------ 私有方法

    /**
     * 交给模型的全部依据。逐题作答 + 历史对比 + 近期日记情绪分布，
     * 缺了这三样，模型也只能输出和写死文案一样空泛的套话。
     */
    private String buildUserContent(AssessmentResult result) {
        StringBuilder sb = new StringBuilder();

        sb.append("量表：").append(nullToDash(result.getAssessmentTitle())).append('\n');
        sb.append("本次得分：").append(result.getScore() == null ? "-" : result.getScore());
        if (result.getMaxScore() != null) {
            sb.append(" / 满分 ").append(result.getMaxScore());
        }
        sb.append('\n');
        sb.append("产品规则给出的等级：").append(nullToDash(result.getLevel())).append('\n');

        String details = renderAnswers(result.getAnswersJson());
        sb.append("\n逐题作答：\n").append(details.isEmpty() ? "（旧版客户端未上报答题明细）" : details);

        String history = renderHistory(result);
        if (!history.isEmpty()) {
            sb.append("\n历史对比：\n").append(history);
        }

        String emotion = renderEmotion(result.getUserId());
        if (!emotion.isEmpty()) {
            sb.append("\n近 ").append(RECENT_DIARY_DAYS).append(" 天该用户日记的情绪分布：").append(emotion).append('\n');
        }

        sb.append("\n请按约定结构输出 JSON。");
        return sb.toString();
    }

    private String renderAnswers(String answersJson) {
        if (answersJson == null || answersJson.isBlank()) {
            return "";
        }
        try {
            JsonNode arr = objectMapper.readTree(answersJson);
            if (!arr.isArray()) {
                return "";
            }
            StringBuilder sb = new StringBuilder();
            int index = 1;
            for (JsonNode item : arr) {
                sb.append(index++).append(". ")
                        .append(item.path("title").asText(""))
                        .append(" → ")
                        .append(item.path("optionText").asText("未作答"))
                        .append("（").append(item.path("score").asInt(0)).append(" 分）\n");
            }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    /** 同量表最近 3 次（不含本次），让模型能做趋势判断 */
    private String renderHistory(AssessmentResult current) {
        if (current.getAssessmentId() == null) {
            return "";
        }
        List<AssessmentResult> rows = resultMapper.selectList(new QueryWrapper<AssessmentResult>()
                .eq("user_id", current.getUserId())
                .eq("assessment_id", current.getAssessmentId())
                .ne("id", current.getId())
                .orderByDesc("create_time")
                .last("LIMIT 3"));
        if (rows.isEmpty()) {
            return "";
        }
        StringBuilder sb = new StringBuilder();
        for (AssessmentResult row : rows) {
            sb.append("- ").append(row.getCreateTime() == null ? "-" : row.getCreateTime().format(DAY))
                    .append(" 得分 ").append(row.getScore() == null ? "-" : row.getScore())
                    .append("（").append(nullToDash(row.getLevel())).append("）\n");
        }
        return sb.toString();
    }

    /** 日记情绪分布：用于和量表结果交叉印证，是「个性化」的重要来源 */
    private String renderEmotion(Long userId) {
        try {
            List<Map<String, Object>> rows = diaryMapper.selectMaps(new QueryWrapper<Diary>()
                    .select("emotion", "COUNT(*) AS cnt")
                    .eq("user_id", userId)
                    .ge("create_time", LocalDateTime.now().minusDays(RECENT_DIARY_DAYS))
                    .groupBy("emotion"));
            if (rows.isEmpty()) {
                return "";
            }
            List<String> parts = new ArrayList<>();
            for (Map<String, Object> row : rows) {
                Object emotion = row.get("emotion");
                Object cnt = row.get("cnt");
                if (emotion != null) {
                    parts.add(emotion + "×" + (cnt == null ? "?" : cnt));
                }
            }
            return String.join("、", parts);
        } catch (Exception e) {
            log.warn("读取日记情绪分布失败: {}", e.getMessage());
            return "";
        }
    }

    /** 模型偶尔会加解释文字或代码围栏，这里只截取最外层的 JSON 对象 */
    private String extractJson(String raw) {
        if (raw == null) {
            return null;
        }
        String text = raw.trim();
        if (text.startsWith("```")) {
            int firstLineEnd = text.indexOf('\n');
            if (firstLineEnd > 0) {
                text = text.substring(firstLineEnd + 1);
            }
            if (text.endsWith("```")) {
                text = text.substring(0, text.length() - 3);
            }
            text = text.trim();
        }
        int start = text.indexOf('{');
        int end = text.lastIndexOf('}');
        if (start < 0 || end <= start) {
            return null;
        }
        return text.substring(start, end + 1);
    }

    /**
     * 收敛成前端可依赖的固定结构，并施加服务端安全兜底。
     * 最高风险档位强制 needProfessionalHelp=true 且必定包含求助建议——不依赖模型是否"记得"。
     */
    private ObjectNode normalize(JsonNode parsed, AssessmentResult result) {
        ObjectNode out = objectMapper.createObjectNode();
        out.put("summary", parsed.path("summary").asText("").trim());
        out.put("trend", parsed.path("trend").asText("首次测评，暂无对比").trim());

        String risk = parsed.path("riskLevel").asText("low").trim().toLowerCase();
        if (!"low".equals(risk) && !"medium".equals(risk) && !"high".equals(risk)) {
            risk = "low";
        }

        boolean needHelp = parsed.path("needProfessionalHelp").asBoolean(false);
        boolean severe = isSevereBand(result);
        if (severe) {
            // 最严重档位：无论模型怎么说，都按需要专业帮助处理
            needHelp = true;
            if (!"high".equals(risk)) {
                risk = "high";
            }
        }
        out.put("riskLevel", risk);
        out.put("needProfessionalHelp", needHelp);

        List<JsonNode> dimensions = new ArrayList<>();
        JsonNode dims = parsed.path("dimensions");
        if (dims.isArray()) {
            for (JsonNode dim : dims) {
                if (dimensions.size() >= 4) {
                    break;
                }
                String name = dim.path("name").asText("").trim();
                if (name.isEmpty()) {
                    continue;
                }
                dimensions.add(dim);
            }
        }
        if (dimensions.isEmpty()) {
            ObjectNode fallback = objectMapper.createObjectNode();
            fallback.put("name", "整体状态");
            fallback.put("level", nullToDash(result.getLevel()));
            fallback.put("comment", "");
            dimensions.add(fallback);
        }
        out.set("dimensions", objectMapper.valueToTree(dimensions));

        List<JsonNode> suggestions = new ArrayList<>();
        JsonNode items = parsed.path("suggestions");
        if (items.isArray()) {
            for (JsonNode item : items) {
                if (suggestions.size() >= 3) {
                    break;
                }
                if (!item.path("title").asText("").trim().isEmpty()) {
                    suggestions.add(item);
                }
            }
        }
        if (severe) {
            ObjectNode crisis = objectMapper.createObjectNode();
            crisis.put("title", "现在就可以做的事");
            crisis.put("detail", CRISIS_HINT);
            suggestions.add(crisis);
        }
        if (suggestions.isEmpty()) {
            ObjectNode fallback = objectMapper.createObjectNode();
            fallback.put("title", "继续保持记录");
            fallback.put("detail", "把最近的状态写进日记，下次测评时能看出变化趋势。");
            suggestions.add(fallback);
        }
        out.set("suggestions", objectMapper.valueToTree(suggestions));

        out.put("model", deepSeekClient.getModel());
        out.put("generatedAt", LocalDateTime.now().format(DAY));
        return out;
    }

    /**
     * 是否落在该量表最严重的档位。
     *
     * <p><b>不能</b>按「bands 最后一条 = 最严重」判断：心理韧性是正向量表，
     * 分数越高韧性越好，最后一条是「韧性良好」——按位置判断会把韧性满分
     * 强制置成危机状态（riskLevel=high + 求助热线），属于产品安全事故。
     *
     * <p>正确规则：先按分数命中档位，再要求命中的是<b>最后一条</b>（症状量表的
     * 最重档）且其文案带负向关键词（明显/过载/较重/较差）。正向量表的最高档
     * 文案不含这些词，天然不会被误判。
     */
    private boolean isSevereBand(AssessmentResult result) {
        if (result.getAssessmentId() == null || result.getScore() == null) {
            return false;
        }
        try {
            JsonNode scoring = scaleService.scoringOf(result.getAssessmentId());
            JsonNode bands = scoring == null ? null : scoring.path("bands");
            if (bands == null || !bands.isArray() || bands.isEmpty()) {
                // 无题库配置的旧数据：按比例文案的关键词兜底
                String level = result.getLevel();
                return level != null && (level.contains("较重") || level.contains("较高")
                        || level.contains("风险"));
            }
            JsonNode matched = null;
            for (JsonNode band : bands) {
                if (result.getScore() <= band.path("max").asInt(Integer.MAX_VALUE)) {
                    matched = band;
                    break;
                }
            }
            if (matched == null) {
                matched = bands.get(bands.size() - 1);
            }
            boolean isLastBand = matched == bands.get(bands.size() - 1);
            if (!isLastBand) {
                return false;
            }
            String levelText = matched.path("level").asText();
            return levelText.contains("明显") || levelText.contains("过载")
                    || levelText.contains("较重") || levelText.contains("较差");
        } catch (Exception e) {
            return false;
        }
    }

    private void markFailed(Long resultId, String reason) {
        try {
            AssessmentResult patch = new AssessmentResult();
            patch.setId(resultId);
            patch.setAiStatus("failed");
            patch.setAiError(abbreviate(reason));
            resultMapper.updateById(patch);
        } catch (Exception e) {
            log.warn("写入 AI 失败状态时出错: {}", e.getMessage());
        }
    }

    private String friendlyError(Exception e) {
        String message = e.getMessage();
        if (message == null || message.isBlank()) {
            return "AI 解读生成失败，请重试";
        }
        return message.length() > 200 ? message.substring(0, 200) : message;
    }

    private static String nullToDash(String value) {
        return value == null || value.isBlank() ? "-" : value;
    }

    private static String abbreviate(String value) {
        if (value == null) {
            return "";
        }
        return value.length() <= 200 ? value : value.substring(0, 200) + "...";
    }
}
