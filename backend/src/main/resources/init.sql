CREATE DATABASE IF NOT EXISTS mindhealth CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE mindhealth;

-- 用户表
CREATE TABLE IF NOT EXISTS `user` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `phone` VARCHAR(11) NOT NULL COMMENT '手机号',
  `password` VARCHAR(255) NOT NULL COMMENT '密码',
  `nickname` VARCHAR(50) DEFAULT NULL COMMENT '昵称',
  `age` INT(11) DEFAULT NULL COMMENT '年龄',
  `gender` VARCHAR(10) DEFAULT NULL COMMENT '性别',
  `avatar` VARCHAR(255) DEFAULT NULL COMMENT '头像',
  `signature` VARCHAR(200) DEFAULT NULL COMMENT '个性签名',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `deleted` TINYINT(4) NOT NULL DEFAULT 0 COMMENT '逻辑删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_phone` (`phone`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- AI对话表
CREATE TABLE IF NOT EXISTS `ai_chat` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `content` TEXT NOT NULL COMMENT '对话内容',
  `ai_response` TEXT NOT NULL COMMENT 'AI回复',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI对话表';

-- 测评表
CREATE TABLE IF NOT EXISTS `assessment` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL COMMENT '测评名称',
  `description` TEXT DEFAULT NULL COMMENT '测评描述',
  `type` VARCHAR(50) NOT NULL COMMENT '测评类型',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='测评表';

-- 测评结果表
CREATE TABLE IF NOT EXISTS `assessment_result` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `assessment_id` BIGINT(20) NOT NULL COMMENT '测评ID',
  `score` INT(11) NOT NULL COMMENT '测评分数',
  `result` TEXT NOT NULL COMMENT '测评结果',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_assessment_id` (`assessment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='测评结果表';

-- 情绪日记表
CREATE TABLE IF NOT EXISTS `diary` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `title` VARCHAR(100) NOT NULL COMMENT '日记标题',
  `content` TEXT NOT NULL COMMENT '日记内容',
  `emotion` VARCHAR(50) NOT NULL COMMENT '情绪类型',
  `intensity` INT(11) NOT NULL COMMENT '情绪强度',
  `event` TEXT DEFAULT NULL COMMENT '事件描述',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='情绪日记表';

-- 心理科普内容表
CREATE TABLE IF NOT EXISTS `knowledge` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(100) NOT NULL COMMENT '标题',
  `content` TEXT NOT NULL COMMENT '内容',
  `category` VARCHAR(50) NOT NULL COMMENT '分类',
  `cover` VARCHAR(255) DEFAULT NULL COMMENT '封面',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='心理科普内容表';

-- 社区帖子表
CREATE TABLE IF NOT EXISTS `community_post` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `title` VARCHAR(100) NOT NULL COMMENT '标题',
  `content` TEXT NOT NULL COMMENT '内容',
  `anonymous` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '是否匿名',
  `like_count` INT(11) NOT NULL DEFAULT 0 COMMENT '点赞数',
  `comment_count` INT(11) NOT NULL DEFAULT 0 COMMENT '评论数',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社区帖子表';

-- 社区评论表
CREATE TABLE IF NOT EXISTS `community_comment` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `post_id` BIGINT(20) NOT NULL COMMENT '帖子ID',
  `user_id` BIGINT(20) NOT NULL COMMENT '用户ID',
  `content` TEXT NOT NULL COMMENT '评论内容',
  `anonymous` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '是否匿名',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  KEY `idx_post_id` (`post_id`),
  KEY `idx_user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='社区评论表';

-- 管理员表
CREATE TABLE IF NOT EXISTS `admin` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(50) NOT NULL COMMENT '用户名',
  `password` VARCHAR(255) NOT NULL COMMENT '密码',
  `role` VARCHAR(50) NOT NULL COMMENT '角色',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `update_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员表';

-- 插入默认管理员
INSERT INTO `admin` (`username`, `password`, `role`) VALUES 
('admin', 'REMOVED', 'SUPER_ADMIN');

-- 插入默认测评数据
INSERT INTO `assessment` (`name`, `description`, `type`) VALUES 
('SCL-90症状自评量表', '用于评估个体在一周内的心理健康状况，包括9个因子：躯体化、强迫症状、人际关系敏感、抑郁、焦虑、敌对、恐怖、偏执及精神病性。', 'SCL-90'),
('SDS抑郁自评量表', '用于评估抑郁程度，适用于具有抑郁症状的成年人。', 'SDS'),
('SAS焦虑自评量表', '用于评估焦虑程度，适用于具有焦虑症状的成年人。', 'SAS'),
('压力感知量表', '用于评估个体对压力的感知程度，帮助了解自身的压力水平。', 'PSS');

-- 插入默认心理科普内容
INSERT INTO `knowledge` (`title`, `content`, `category`) VALUES 
('如何应对焦虑情绪', '焦虑是一种常见的情绪反应，适当的焦虑可以帮助我们应对挑战，但过度焦虑会影响生活质量。以下是一些应对焦虑的方法：1. 深呼吸练习；2. 渐进式肌肉放松；3. 正念冥想；4. 规律运动；5. 保持良好的作息。', '情绪调节'),
('压力管理技巧', '现代生活中，压力无处不在。有效的压力管理可以帮助我们保持身心健康：1. 识别压力源；2. 制定合理的目标；3. 学会说"不"；4. 培养兴趣爱好；5. 寻求社会支持。', '压力管理'),
('建立健康的人际关系', '良好的人际关系对心理健康至关重要：1. 积极沟通；2. 学会倾听；3. 尊重他人；4. 保持边界；5. 真诚相待。', '人际关系'),
('自我成长的重要性', '自我成长是一个持续的过程，有助于提升心理健康水平：1. 设定个人目标；2. 持续学习；3. 接受挑战；4. 反思自我；5. 保持开放的心态。', '自我成长');

-- 管理员操作日志表（审计留痕）
-- 管理端能删除用户全部数据、能读取用户私密日记，必须可追溯
CREATE TABLE IF NOT EXISTS `admin_operation_log` (
  `id` BIGINT(20) NOT NULL AUTO_INCREMENT,
  `admin_id` BIGINT(20) DEFAULT NULL COMMENT '操作管理员ID',
  `admin_username` VARCHAR(50) DEFAULT NULL COMMENT '操作管理员用户名快照',
  `method` VARCHAR(10) NOT NULL COMMENT 'HTTP方法',
  `path` VARCHAR(255) NOT NULL COMMENT '请求路径(已去context-path)',
  `action_desc` VARCHAR(200) DEFAULT NULL COMMENT '操作摘要',
  `target_desc` VARCHAR(200) DEFAULT NULL COMMENT '操作对象标识',
  `ip` VARCHAR(64) DEFAULT NULL COMMENT '来源IP',
  `status` INT(11) DEFAULT NULL COMMENT 'HTTP状态码',
  `duration_ms` BIGINT(20) DEFAULT NULL COMMENT '处理耗时(ms)',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '操作时间',
  PRIMARY KEY (`id`),
  KEY `idx_admin_id` (`admin_id`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理员操作日志表';
