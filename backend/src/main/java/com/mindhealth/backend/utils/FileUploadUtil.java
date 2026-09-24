package com.mindhealth.backend.utils;

import org.springframework.web.multipart.MultipartFile;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Locale;
import java.util.UUID;

public class FileUploadUtil {

    /**
     * 通过文件魔数判断真实类型，防止伪造扩展名上传脚本/可执行文件
     */
    public static boolean isRealImage(MultipartFile file) throws IOException {
        byte[] header = new byte[12];
        try (InputStream in = file.getInputStream()) {
            int read = in.read(header);
            if (read < 4) {
                return false;
            }
        }
        // JPEG: FF D8 FF
        if ((header[0] & 0xFF) == 0xFF && (header[1] & 0xFF) == 0xD8 && (header[2] & 0xFF) == 0xFF) {
            return true;
        }
        // PNG: 89 50 4E 47
        if ((header[0] & 0xFF) == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47) {
            return true;
        }
        // WEBP: RIFF....WEBP
        if (header[0] == 'R' && header[1] == 'I' && header[2] == 'F' && header[3] == 'F'
                && header[8] == 'W' && header[9] == 'E' && header[10] == 'B' && header[11] == 'P') {
            return true;
        }
        return false;
    }

    /**
     * 清洗原始文件名：只保留扩展名，磁盘文件名一律用 UUID 生成，
     * 避免中文/特殊字符/路径穿越问题
     */
    public static String saveFile(String uploadDir, String originalFileName, MultipartFile file) throws IOException {
        Path uploadPath = Paths.get(uploadDir);

        // 如果目录不存在,创建目录
        if (!Files.exists(uploadPath)) {
            Files.createDirectories(uploadPath);
        }

        String extension = extractExtension(originalFileName);
        String uniqueFileName = UUID.randomUUID().toString().replace("-", "") + extension;
        Path filePath = uploadPath.resolve(uniqueFileName);

        // 保存文件
        Files.copy(file.getInputStream(), filePath);

        return uniqueFileName;
    }

    public static String extractExtension(String originalFileName) {
        if (originalFileName == null) {
            return ".jpg";
        }
        String name = Paths.get(originalFileName).getFileName().toString();
        int dot = name.lastIndexOf('.');
        if (dot < 0 || dot == name.length() - 1) {
            return ".jpg";
        }
        String ext = name.substring(dot).toLowerCase(Locale.ROOT);
        // 只允许已知图片扩展名，其他一律归为 jpg（上传前已有白名单校验）
        if (!ext.matches("\\.(jpg|jpeg|png|webp)")) {
            return ".jpg";
        }
        return ext;
    }
}
