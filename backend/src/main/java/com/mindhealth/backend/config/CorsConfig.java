package com.mindhealth.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("*")   // 鸿蒙开发环境用 *
                .allowedMethods("*")
                .allowedHeaders("*")
                .allowCredentials(true)       // 关键：允许携带 Token/Cookie
                .maxAge(3600);
    }
}
