package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.dto.AssessmentRequest;
import com.mindhealth.backend.service.AssessmentService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/assessment")
public class AssessmentController {

    @Autowired
    private AssessmentService assessmentService;

    @GetMapping("/list")
    public ApiResponse<Object> getAssessmentList() {
        return ApiResponse.success(assessmentService.getAssessmentList());
    }

    @GetMapping("/{id}")
    public ApiResponse<Object> getAssessmentById(@PathVariable Long id) {
        return ApiResponse.success(assessmentService.getAssessmentById(id));
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