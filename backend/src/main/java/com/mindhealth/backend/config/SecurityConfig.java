package com.mindhealth.backend.config;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration authenticationConfiguration) throws Exception {
        return authenticationConfiguration.getAuthenticationManager();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                .csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/user/login", "/user/register", "/user/huawei/login").permitAll()
                        .requestMatchers("/admin/login", "/admin/captcha").permitAll()
                        // 管理员账号管理只允许超级管理员。
                        // 必须排在 /admin/** 之前：requestMatchers 按声明顺序匹配，放后面永远轮不到
                        .requestMatchers("/admin/accounts", "/admin/accounts/**")
                        .hasAuthority("ROLE_SUPER_ADMIN")
                        // 操作日志同样只给超管：审计记录是用来约束管理员的，
                        // 不应该让被审计者随手翻看、据此规避
                        .requestMatchers("/admin/logs", "/admin/logs/**")
                        .hasAuthority("ROLE_SUPER_ADMIN")
                        // 管理端其余接口只允许 ROLE_ADMIN（P0-1：此前任何登录用户都能调）
                        .requestMatchers("/admin/**").hasAuthority("ROLE_ADMIN")
                        .requestMatchers("/error").permitAll()
                        .requestMatchers("/swagger-ui/**", "/v3/api-docs/**", "/doc.html", "/swagger-ui.html").permitAll()

                        // 头像等静态资源：保留 Security 过滤链，仅匿名放行
                        .requestMatchers("/uploads/**").permitAll()

                        // 量表浏览公开
                        .requestMatchers("/assessment/list", "/assessment/{id}").permitAll()

                        // 量表题库静态化接口：题库是公开只读配置，未登录也应可拉取（客户端首次启动预缓存）
                        .requestMatchers("/assessment/manifest", "/assessment/{id}/questions").permitAll()

                        // 题库静态文件（classpath:static/scales/**），可由 Nginx/CDN 直接托管
                        .requestMatchers("/scales/**").permitAll()

                        // 心理科普文章：公开只读内容，未登录也可浏览（客户端进入科普 Tab 即拉取）
                        .requestMatchers("/article/**").permitAll()

                        // 必须登录
                        .requestMatchers("/user/info", "/user/update", "/user/phone").authenticated()
                        .requestMatchers("/user/avatar/**").authenticated()
                        .requestMatchers("/assessment/results", "/assessment/submit").authenticated()
                        .requestMatchers("/diary/**").authenticated()
                        .requestMatchers("/ai/**").authenticated()

                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOriginPatterns(Arrays.asList("*"));
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setExposedHeaders(Arrays.asList("Authorization"));
        configuration.setAllowCredentials(false);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}