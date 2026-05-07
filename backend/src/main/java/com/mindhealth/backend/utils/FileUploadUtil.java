package com.mindhealth.backend.utils;

import org.springframework.web.multipart.MultipartFile;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

public class FileUploadUtil {

    // 保存文件并返回文件名
    public static String saveFile(String uploadDir, String fileName, MultipartFile file) throws IOException {
        Path uploadPath = Paths.get(uploadDir);

        // 如果目录不存在,创建目录
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        // 生成唯一文件名
        String uniqueFileName = UUID.randomUUID().toString() + "_" + fileName;
        Path filePath = uploadPath.resolve(uniqueFileName);

        // 保存文件
        Files.copy(file.getInputStream(), filePath);

        return uniqueFileName;
    }
}