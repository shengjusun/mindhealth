package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.dto.AssessmentRequest;
import com.mindhealth.backend.entity.AssessmentResult;
import com.mindhealth.backend.service.AssessmentAiService;
import com.mindhealth.backend.service.AssessmentService;
import com.mindhealth.backend.service.ScaleService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/assessment")
public class AssessmentController {

    @Autowired
    private AssessmentService assessmentService;

    @Autowired
    private ScaleService scaleService;

    @Autowired
    private AssessmentAiService assessmentAiService;

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
        return ApiResponse.success(scaleService.manifest());
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
        String questions = scaleService.questions(id);
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

    /**
     * 单条测评结果。
     * 客户端提交后用它轮询 AI 解读：aiStatus 由 pending → success / failed。
     */
    @GetMapping("/result/{id}")
    public ApiResponse<Object> getAssessmentResult(@RequestAttribute("userId") Long userId,
                                                   @PathVariable Long id) {
        AssessmentResult result = assessmentService.getAssessmentResult(userId, id);
        if (result == null) {
            return ApiResponse.error(404, "测评记录不存在");
        }
        return ApiResponse.success(result);
    }

    /** 手动重试 AI 解读（首次生成因超时/额度等原因失败时用） */
    @PostMapping("/result/{id}/analyze")
    public ApiResponse<Object> reanalyze(@RequestAttribute("userId") Long userId,
                                         @PathVariable Long id) {
        AssessmentResult result = assessmentService.getAssessmentResult(userId, id);
        if (result == null) {
            return ApiResponse.error(404, "测评记录不存在");
        }
        assessmentAiService.analyzeAsync(id);
        return ApiResponse.success(true);
    }
}