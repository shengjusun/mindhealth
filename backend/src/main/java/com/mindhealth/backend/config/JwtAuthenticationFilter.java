package com.mindhealth.backend.config;

import com.mindhealth.backend.entity.Admin;
import com.mindhealth.backend.entity.User;
import com.mindhealth.backend.mapper.AdminMapper;
import com.mindhealth.backend.mapper.UserMapper;
import com.mindhealth.backend.utils.JwtUtils;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    /** Spring Security 侧的角色名，与 Admin.ROLE_* 一一对应 */
    private static final String AUTHORITY_ADMIN = "ROLE_ADMIN";
    private static final String AUTHORITY_SUPER_ADMIN = "ROLE_SUPER_ADMIN";

    @Autowired
    private JwtUtils jwtUtils;

    @Autowired
    private UserMapper userMapper;

    @Autowired
    private AdminMapper adminMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        String token = request.getHeader("Authorization");
        if (token != null && token.startsWith("Bearer ")) {
            token = token.substring(7);
            if (jwtUtils.validateToken(token)) {
                Claims claims = jwtUtils.parseClaims(token);
                String subject = claims.getSubject();

                if (subject != null && subject.startsWith(JwtUtils.SUBJECT_ADMIN_PREFIX)) {
                    // 管理员令牌：注入 adminId + 角色 authority。
                    // JWT payload 里不带角色，所以每次按主键查一次库：
                    // /admin/** 要 ROLE_ADMIN，/admin/accounts/** 额外要 ROLE_SUPER_ADMIN
                    Long adminId = Long.valueOf(subject.substring(JwtUtils.SUBJECT_ADMIN_PREFIX.length()));
                    Admin admin = adminMapper.selectById(adminId);
                    // 账号已被删除：保持 SecurityContext 为空，由授权环节按未登录拒绝（fail-closed）
                    if (admin != null) {
                        // 超级管理员是普通管理员的「超集」：必须同时持有 ROLE_ADMIN。
                        // SecurityConfig 里 /admin/** 要的是 ROLE_ADMIN，而 hasAuthority 是精确匹配——
                        // 只给 ROLE_SUPER_ADMIN 的话，超管会被自己这条规则挡在门外（全后台 403）。
                        List<SimpleGrantedAuthority> authorities = Admin.ROLE_SUPER_ADMIN.equals(admin.getRole())
                                ? List.of(new SimpleGrantedAuthority(AUTHORITY_SUPER_ADMIN),
                                          new SimpleGrantedAuthority(AUTHORITY_ADMIN))
                                : List.of(new SimpleGrantedAuthority(AUTHORITY_ADMIN));
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken("admin:" + adminId, null, authorities);
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                        request.setAttribute("adminId", adminId);
                    }
                } else {
                    // 普通用户令牌：禁用/已删除账号的存量 token 不放行（每请求一次主键查询）
                    Long userId = Long.valueOf(subject);
                    if (isUsableUser(userId)) {
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(userId, null,
                                        List.of(new SimpleGrantedAuthority("ROLE_USER")));
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                        request.setAttribute("userId", userId);
                    }
                    // 不可用：保持 SecurityContext 为空，由授权环节按未登录拒绝
                }
            }
        }
        filterChain.doFilter(request, response);
    }

    /** 用户存在且未被禁用才放行；查询异常按不可用处理（fail-closed） */
    private boolean isUsableUser(Long userId) {
        try {
            User user = userMapper.selectById(userId);
            return user != null && (user.getDeleted() == null || user.getDeleted() == 0);
        } catch (Exception e) {
            return false;
        }
    }
}
