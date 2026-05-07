package com.mindhealth.backend.controller;

import com.mindhealth.backend.dto.ApiResponse;
import com.mindhealth.backend.dto.DiaryRequest;
import com.mindhealth.backend.service.DiaryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/diary")
public class DiaryController {

    @Autowired
    private DiaryService diaryService;

    @PostMapping
    public ApiResponse<Object> createDiary(@RequestAttribute("userId") Long userId, @RequestBody DiaryRequest request) {
        Object result = diaryService.createDiary(userId, request);
        return ApiResponse.success(result);
    }

    @PutMapping("/{id}")
    public ApiResponse<Object> updateDiary(@PathVariable Long id, @RequestAttribute("userId") Long userId, @RequestBody DiaryRequest request) {
        Object result = diaryService.updateDiary(id, userId, request);
        return ApiResponse.success(result);
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteDiary(@PathVariable Long id, @RequestAttribute("userId") Long userId) {
        diaryService.deleteDiary(id, userId);
        return ApiResponse.success(null);
    }

    @GetMapping("/{id}")
    public ApiResponse<Object> getDiaryById(@PathVariable Long id, @RequestAttribute("userId") Long userId) {
        Object result = diaryService.getDiaryById(id, userId);
        return ApiResponse.success(result);
    }

    @GetMapping
    public ApiResponse<Object> getDiaryList(@RequestAttribute("userId") Long userId) {
        Object result = diaryService.getDiaryList(userId);
        return ApiResponse.success(result);
    }
}