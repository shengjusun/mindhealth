package com.mindhealth.backend.service;

import com.mindhealth.backend.dto.DiaryRequest;
import com.mindhealth.backend.entity.Diary;

import java.util.List;

public interface DiaryService {
    Diary createDiary(Long userId, DiaryRequest request);
    Diary updateDiary(Long id, Long userId, DiaryRequest request);
    void deleteDiary(Long id, Long userId);
    Diary getDiaryById(Long id, Long userId);
    List<Diary> getDiaryList(Long userId);
}