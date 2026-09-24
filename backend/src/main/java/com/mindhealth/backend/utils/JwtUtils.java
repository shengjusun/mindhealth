package com.mindhealth.backend.utils;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.Claims;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Date;

@Component
public class JwtUtils {

    public static final String SUBJECT_ADMIN_PREFIX = "admin:";

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.expire}")
    private long expire;

    @Value("${jwt.refresh-expire}")
    private long refreshExpire;

    public String generateToken(Long userId) {
        return build(userId.toString(), expire);
    }

    public String generateRefreshToken(Long userId) {
        return build(userId.toString(), refreshExpire);
    }

    /** 管理员令牌：subject = admin:{adminId} */
    public String generateAdminToken(Long adminId) {
        return build(SUBJECT_ADMIN_PREFIX + adminId, expire);
    }

    private String build(String subject, long ttlSeconds) {
        Date now = new Date();
        Date expireDate = new Date(now.getTime() + ttlSeconds * 1000);
        return Jwts.builder()
                .setSubject(subject)
                .setIssuedAt(now)
                .setExpiration(expireDate)
                .signWith(SignatureAlgorithm.HS256, secret)
                .compact();
    }

    /** 解析并校验令牌，返回 claims；无效令牌抛异常 */
    public Claims parseClaims(String token) {
        return Jwts.parser()
                .setSigningKey(secret)
                .parseClaimsJws(token)
                .getBody();
    }

    public Long getUserIdFromToken(String token) {
        return Long.valueOf(parseClaims(token).getSubject());
    }

    /** 从 admin:{id} 形态的 subject 中取出管理员 ID；非管理员令牌返回 null */
    public Long getAdminIdFromToken(String token) {
        String subject = parseClaims(token).getSubject();
        if (subject != null && subject.startsWith(SUBJECT_ADMIN_PREFIX)) {
            return Long.valueOf(subject.substring(SUBJECT_ADMIN_PREFIX.length()));
        }
        return null;
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parser().setSigningKey(secret).parseClaimsJws(token);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
