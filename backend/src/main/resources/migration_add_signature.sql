-- 添加 signature 字段到 user 表
-- 执行此脚本前请先备份数据库

USE mindhealth;

-- 检查字段是否已存在，如果不存在则添加
SET @dbname = 'mindhealth';
SET @tablename = 'user';
SET @columnname = 'signature';
SET @preparedStatement = (SELECT IF(
  (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE
      TABLE_SCHEMA = @dbname
      AND TABLE_NAME = @tablename
      AND COLUMN_NAME = @columnname
  ) > 0,
  'SELECT 1',
  CONCAT('ALTER TABLE ', @tablename, ' ADD COLUMN `', @columnname, '` VARCHAR(200) DEFAULT NULL COMMENT ''个性签名'' AFTER `avatar`')
));
PREPARE alterIfNotExists FROM @preparedStatement;
EXECUTE alterIfNotExists;
DEALLOCATE PREPARE alterIfNotExists;

-- 验证字段已添加
SELECT COLUMN_NAME, COLUMN_TYPE, COLUMN_COMMENT 
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_SCHEMA = 'mindhealth' AND TABLE_NAME = 'user' AND COLUMN_NAME = 'signature';
