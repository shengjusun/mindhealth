mysql -u root -p111111 < REMOVED/Desktop/project/mindHealsh/backend/update_password.sql-- 临时更新用户密码为明文,方便测试
-- 测试完成后需要改回BCrypt哈希值

USE mindhealth;

-- 更新用户密码为明文
UPDATE user SET password = '123456' WHERE phone = '13800138000';

-- 验证更新
SELECT phone, password FROM user WHERE phone = '13800138000';
