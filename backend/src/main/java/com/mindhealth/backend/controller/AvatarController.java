package com.mindhealth.backend.controller;

import com.mindhealth.backend.common.Result;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.service.UserService;
import com.mindhealth.backend.utils.FileUploadUtil;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@Slf4j
@RestController
@RequestMapping("/user/avatar")
public class AvatarController {

    @Value("${file.upload.path}")
    private String uploadDir;

    @Autowired
    private UserService userService;

    @PostMapping("/upload")
    public Result uploadAvatar(@RequestAttribute("userId") Long userId,
                               @RequestParam("file") MultipartFile file) {
        try {
            if (file.isEmpty()) {
                return Result.error("上传文件不能为空");
            }

            if (file.getSize() > 5 * 1024 * 1024) {
                return Result.error("文件大小不能超过5MB");
            }

            String contentType = file.getContentType();
            if (contentType == null || !contentType.startsWith("image/")) {
                return Result.error("只能上传图片文件");
            }

            String originalFileName = file.getOriginalFilename();
            if (originalFileName == null || !originalFileName.contains(".")) {
                return Result.error("文件名无效");
            }

            String extension = originalFileName.substring(originalFileName.lastIndexOf(".")).toLowerCase();
            if (!extension.matches("\\.(jpg|jpeg|png|webp)$")) {
                return Result.error("只支持JPG、JPEG、PNG、WEBP格式");
            }

            // 校验文件魔数，防止伪造扩展名
            if (!FileUploadUtil.isRealImage(file)) {
                return Result.error("文件内容不是有效的图片");
            }

            String fileName = FileUploadUtil.saveFile(uploadDir, originalFileName, file);

            // 只存相对路径，不存死IP
            String avatarPath = "/api/" + uploadDir + fileName;

            User user = new User();
            user.setId(userId);
            user.setAvatar(avatarPath);
            userService.updateUser(user);

            return Result.success(avatarPath);

        } catch (IOException e) {
            log.error("头像文件写入失败: {}", e.getMessage());
            return Result.error("文件上传失败");
        } catch (Exception e) {
            log.error("头像更新失败: {}", e.getMessage());
            return Result.error("头像更新失败");
        }
    }
}