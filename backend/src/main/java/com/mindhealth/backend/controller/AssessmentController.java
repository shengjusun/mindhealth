package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.dto.AssessmentRequest;
import com.mindhealth.backend.service.AssessmentService;
import com.mindhealth.backend.service.ScaleFileService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/assessment")
public class AssessmentController {

    @Autowired
    private AssessmentService assessmentService;

    @Autowired
    private ScaleFileService scaleFileService;

    @GetMapping("/list")
    public ApiResponse<Object> getAssessmentList() {
        return ApiResponse.success(assessmentService.getAssessmentList());
    }

    /**
     * 量表清单（含版本号）。公开接口，未登录也能拉取，便于客户端启动即预缓存题库。
     * 返回 static/scales/manifest.json 的内容。
     */
    @GetMapping("/manifest")
    public ApiResponse<Object> getScaleManifest() {
        return ApiResponse.success(scaleFileService.manifest());
    }

    @GetMapping("/{id}")
    public ApiResponse<Object> getAssessmentById(@PathVariable Long id) {
        return ApiResponse.success(assessmentService.getAssessmentById(id));
    }

    /**
     * 单套量表题目。公开接口，返回内容与 assessment.questions 结构一致：
     * {"id":1,"version":1,"maxScore":15,"questions":[{"id":1,"title":"...","options":[{"key":"A","text":"...","score":0}]}]}
     * 静态文件缺失时自动回退数据库。
     */
    @GetMapping("/{id}/questions")
    public ApiResponse<Object> getScaleQuestions(@PathVariable Long id) {
        String questions = scaleFileService.questions(id);
        if (questions == null) {
            return ApiResponse.error(404, "量表不存在或暂无题目");
        }
        return ApiResponse.success(questions);
    }

    @PostMapping("/submit")
    public ApiResponse<Object> submitAssessment(@RequestAttribute("userId") Long userId,
                                                @RequestBody AssessmentRequest request) {
        return ApiResponse.success(assessmentService.submitAssessment(userId, request));
    }

    @GetMapping("/results")
    public ApiResponse<Object> getAssessmentResults(@RequestAttribute("userId") Long userId) {
        return ApiResponse.success(assessmentService.getAssessmentResults(userId));
    }
}