package com.mindhealth.backend.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.mindhealth.backend.dto.DiaryRequest;
import com.mindhealth.backend.entity.Diary;
import com.mindhealth.backend.mapper.DiaryMapper;
import com.mindhealth.backend.service.DiaryService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.List;

@Service
public class DiaryServiceImpl implements DiaryService {

    @Autowired
    private DiaryMapper diaryMapper;

    @Override
    public Diary createDiary(Long userId, DiaryRequest request) {
        Diary diary = new Diary();
        diary.setUserId(userId);
        diary.setTitle(request.getTitle());
        diary.setContent(request.getContent());
        diary.setEmotion(request.getEmotion());
        diary.setIntensity(request.getIntensity());
        diary.setEvent(request.getEvent());
        diary.setCreateTime(LocalDateTime.now());
        diary.setUpdateTime(LocalDateTime.now());
        diaryMapper.insert(diary);
        return diary;
    }

    @Override
    public Diary updateDiary(Long id, Long userId, DiaryRequest request) {
        Diary diary = diaryMapper.selectById(id);
        if (diary == null || !diary.getUserId().equals(userId)) {
            throw new RuntimeException("日记不存在或无权限");
        }
        diary.setTitle(request.getTitle());
        diary.setContent(request.getContent());
        diary.setEmotion(request.getEmotion());
        diary.setIntensity(request.getIntensity());
        diary.setEvent(request.getEvent());
        diary.setUpdateTime(LocalDateTime.now());
        diaryMapper.updateById(diary);
        return diary;
    }

    @Override
    public void deleteDiary(Long id, Long userId) {
        Diary diary = diaryMapper.selectById(id);
        if (diary == null || !diary.getUserId().equals(userId)) {
            throw new RuntimeException("日记不存在或无权限");
        }
        diaryMapper.deleteById(id);
    }

    @Override
    public Diary getDiaryById(Long id, Long userId) {
        Diary diary = diaryMapper.selectById(id);
        if (diary == null || !diary.getUserId().equals(userId)) {
            throw new RuntimeException("日记不存在或无权限");
        }
        return diary;
    }

    @Override
    public List<Diary> getDiaryList(Long userId) {
        QueryWrapper<Diary> queryWrapper = new QueryWrapper<>();
        queryWrapper.eq("user_id", userId);
        queryWrapper.orderByDesc("create_time");
        return diaryMapper.selectList(queryWrapper);
    }
}