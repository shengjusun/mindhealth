-- ============================================================
-- 迁移脚本：华为账号登录支持 + 安全整改
-- 适用库：mindhealth（MySQL）
-- 执行前请先备份数据库
-- ============================================================

-- 1. user 表增加华为账号标识列
ALTER TABLE `user`
    ADD COLUMN `huawei_union_id` VARCHAR(64) NULL COMMENT '华为账号 unionID（账号主标识）' AFTER `signature`,
    ADD COLUMN `huawei_open_id`  VARCHAR(64) NULL COMMENT '华为账号 openID（应用内标识）' AFTER `huawei_union_id`;

-- 2. unionID 唯一索引（同一华为账号只能对应一个系统账号）
ALTER TABLE `user`
    ADD UNIQUE INDEX `uk_user_huawei_union_id` (`huawei_union_id`);

-- 3. phone 改为可空：纯华为登录用户可能未绑定手机号
--    MySQL 唯一索引允许多个 NULL，不影响已注册手机号的唯一约束
ALTER TABLE `user`
    MODIFY COLUMN `phone` VARCHAR(20) NULL COMMENT '手机号，华为登录用户可为空';

-- 4. 清理存量明文密码（本次整改后登录仅支持 BCrypt）
--    查出仍是明文的账号：
--    SELECT id, phone FROM `user` WHERE password NOT LIKE '$2%';
--    处理方式二选一：
--    a) 让用户走注册/忘记密码流程重新设置；
--    b) 开发测试账号可直接删除后重新注册：
--       DELETE FROM `user` WHERE phone = '13800138000';
