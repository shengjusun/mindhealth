package com.mindhealth.backend.controller;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.entity.Knowledge;
import com.mindhealth.backend.mapper.KnowledgeMapper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 心理科普文章接口（只读 knowledge 表）。
 *
 * 路径说明：客户端 apiConfig.ets 已固化为 /api/article/list 与 /api/article/detail/{id}，
 * 服务端 context-path=/api，故此处映射为 /article/list 与 /article/detail/{id}。
 *
 * 返回字段对齐客户端 ArticleItem：id/title/summary/content/category/cover/author/createTime/updateTime；
 * 其中 summary、author 由服务端补齐（knowledge 表无这两列），避免客户端出现空字段。
 */
@RestController
@RequestMapping("/article")
public class ArticleController {

    /** knowledge 表无 author 列，与客户端兜底文案保持一致，统一由服务端补齐 */
    private static final String DEFAULT_AUTHOR = "轻心编辑部";

    /** 列表摘要截断长度 */
    private static final int SUMMARY_LENGTH = 60;

    @Autowired
    private KnowledgeMapper knowledgeMapper;

    /**
     * 文章列表，可按分类筛选。
     * 未传 category 或传空串时返回全部（客户端 getArticleList 的分支行为）。
     */
    @GetMapping("/list")
    public ApiResponse<List<Map<String, Object>>> list(@RequestParam(required = false) String category) {
        QueryWrapper<Knowledge> wrapper = new QueryWrapper<>();
        if (category != null && !category.trim().isEmpty()) {
            wrapper.eq("category", category.trim());
        }
        wrapper.orderByDesc("create_time").orderByDesc("id");

        List<Map<String, Object>> rows = knowledgeMapper.selectList(wrapper).stream()
                .map(this::toVO)
                .collect(Collectors.toList());
        return ApiResponse.success(rows);
    }

    /** 文章详情；查不到抛业务异常，由 GlobalExceptionHandler 统一转为 code=400 */
    @GetMapping("/detail/{id}")
    public ApiResponse<Map<String, Object>> detail(@PathVariable Long id) {
        Knowledge knowledge = knowledgeMapper.selectById(id);
        if (knowledge == null) {
            throw new RuntimeException("文章不存在");
        }
        return ApiResponse.success(toVO(knowledge));
    }

    /** 实体 → 客户端契约字段（补齐 summary / author） */
    private Map<String, Object> toVO(Knowledge knowledge) {
        Map<String, Object> vo = new HashMap<>();
        vo.put("id", knowledge.getId());
        vo.put("title", knowledge.getTitle());
        vo.put("summary", buildSummary(knowledge.getContent()));
        vo.put("content", knowledge.getContent());
        vo.put("category", knowledge.getCategory());
        vo.put("cover", knowledge.getCover());
        vo.put("author", DEFAULT_AUTHOR);
        vo.put("createTime", knowledge.getCreateTime());
        vo.put("updateTime", knowledge.getUpdateTime());
        return vo;
    }

    /** 摘要：正文压平空白后截断，正文短于阈值时原样返回 */
    private String buildSummary(String content) {
        if (content == null || content.isEmpty()) {
            return "";
        }
        String flat = content.replaceAll("\\s+", " ").trim();
        return flat.length() <= SUMMARY_LENGTH ? flat : flat.substring(0, SUMMARY_LENGTH) + "…";
    }
}
