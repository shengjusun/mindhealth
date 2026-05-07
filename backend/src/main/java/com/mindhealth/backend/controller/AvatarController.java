package com.mindhealth.backend.controller;

import com.mindhealth.backend.common.Result;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.service.UserService;
import com.mindhealth.backend.utils.FileUploadUtil;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

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

            String fileName = FileUploadUtil.saveFile(uploadDir, originalFileName, file);

            // 只存相对路径，不存死IP
            String avatarPath = "/api/" + uploadDir + fileName;
            System.out.println("avatarPath = " + avatarPath);

            User user = new User();
            user.setId(userId);
            user.setAvatar(avatarPath);
            userService.updateUser(user);

            return Result.success(avatarPath);

        } catch (IOException e) {
            e.printStackTrace();
            return Result.error("文件上传失败: " + e.getMessage());
        } catch (Exception e) {
            e.printStackTrace();
            return Result.error("头像更新失败: " + e.getMessage());
        }
    }
}