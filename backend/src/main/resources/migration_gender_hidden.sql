-- 性别第三项语义调整：「其他」->「隐藏」（保密式设计）
-- 存储体系统一为英文：male / female / hidden（与客户端 toBackendGenderValue 一致）
-- 历史数据迁移：客户端存过的 other 及管理端旧表单可能写过的中文，统一归一到 hidden
USE mindhealth;

UPDATE `user` SET `gender` = 'hidden' WHERE `gender` IN ('other', 'others', '3', '其他');

-- 验证：迁移后不应再有任何 other/其他 残留
SELECT `gender`, COUNT(*) AS cnt FROM `user` GROUP BY `gender`;
