-- 创建用户表
CREATE TABLE IF NOT EXISTS "user" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "phone" TEXT NOT NULL UNIQUE COMMENT '手机号',
  "password" TEXT NOT NULL COMMENT '密码',
  "nickname" TEXT DEFAULT NULL COMMENT '昵称',
  "age" INTEGER DEFAULT NULL COMMENT '年龄',
  "gender" TEXT DEFAULT NULL COMMENT '性别',
  "avatar" TEXT DEFAULT NULL COMMENT '头像',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  "update_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  "deleted" INTEGER NOT NULL DEFAULT 0 COMMENT '逻辑删除'
);

-- 创建AI对话表
CREATE TABLE IF NOT EXISTS "ai_chat" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL COMMENT '用户ID',
  "content" TEXT NOT NULL COMMENT '对话内容',
  "ai_response" TEXT NOT NULL COMMENT 'AI回复',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- 创建测评表
CREATE TABLE IF NOT EXISTS "assessment" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL COMMENT '测评名称',
  "description" TEXT DEFAULT NULL COMMENT '测评描述',
  "type" TEXT NOT NULL COMMENT '测评类型',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  "update_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
);

-- 创建测评结果表
CREATE TABLE IF NOT EXISTS "assessment_result" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL COMMENT '用户ID',
  "assessment_id" INTEGER NOT NULL COMMENT '测评ID',
  "score" INTEGER NOT NULL COMMENT '测评分数',
  "result" TEXT NOT NULL COMMENT '测评结果',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  FOREIGN KEY ("user_id") REFERENCES "user" ("id"),
  FOREIGN KEY ("assessment_id") REFERENCES "assessment" ("id")
);

-- 创建情绪日记表
CREATE TABLE IF NOT EXISTS "diary" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL COMMENT '用户ID',
  "title" TEXT NOT NULL COMMENT '日记标题',
  "content" TEXT NOT NULL COMMENT '日记内容',
  "emotion" TEXT NOT NULL COMMENT '情绪类型',
  "intensity" INTEGER NOT NULL COMMENT '情绪强度',
  "event" TEXT DEFAULT NULL COMMENT '事件描述',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  "update_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- 创建心理科普内容表
CREATE TABLE IF NOT EXISTS "knowledge" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "title" TEXT NOT NULL COMMENT '标题',
  "content" TEXT NOT NULL COMMENT '内容',
  "category" TEXT NOT NULL COMMENT '分类',
  "cover" TEXT DEFAULT NULL COMMENT '封面',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  "update_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
);

-- 创建社区帖子表
CREATE TABLE IF NOT EXISTS "community_post" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "user_id" INTEGER NOT NULL COMMENT '用户ID',
  "title" TEXT NOT NULL COMMENT '标题',
  "content" TEXT NOT NULL COMMENT '内容',
  "anonymous" INTEGER NOT NULL DEFAULT 1 COMMENT '是否匿名',
  "like_count" INTEGER NOT NULL DEFAULT 0 COMMENT '点赞数',
  "comment_count" INTEGER NOT NULL DEFAULT 0 COMMENT '评论数',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  "update_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间',
  FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- 创建社区评论表
CREATE TABLE IF NOT EXISTS "community_comment" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "post_id" INTEGER NOT NULL COMMENT '帖子ID',
  "user_id" INTEGER NOT NULL COMMENT '用户ID',
  "content" TEXT NOT NULL COMMENT '评论内容',
  "anonymous" INTEGER NOT NULL DEFAULT 1 COMMENT '是否匿名',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  FOREIGN KEY ("post_id") REFERENCES "community_post" ("id"),
  FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- 创建管理员表
CREATE TABLE IF NOT EXISTS "admin" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "username" TEXT NOT NULL UNIQUE COMMENT '用户名',
  "password" TEXT NOT NULL COMMENT '密码',
  "role" TEXT NOT NULL COMMENT '角色',
  "create_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  "update_time" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '更新时间'
);

-- 插入默认管理员
INSERT OR IGNORE INTO "admin" ("username", "password", "role") VALUES 
('admin', 'REMOVED', 'SUPER_ADMIN');

-- 插入普通用户测试数据
INSERT OR IGNORE INTO "user" ("phone", "password", "nickname", "age", "gender", "avatar") VALUES 
('13800138000', 'REMOVED', '小明', 25, '男', 'https://api.dicebear.com/7.x/avataaars/svg?seed=xiaoming'),
('13800138001', 'REMOVED', '小红', 23, '女', 'https://api.dicebear.com/7.x/avataaars/svg?seed=xiaohong'),
('13800138002', 'REMOVED', '小李', 28, '男', 'https://api.dicebear.com/7.x/avataaars/svg?seed=xiaoli');

-- 插入AI对话测试数据
INSERT OR IGNORE INTO "ai_chat" ("user_id", "content", "ai_response") VALUES 
(1, '最近工作压力很大，感觉很焦虑', '我理解你的感受。工作压力是现代人常见的问题，适当的焦虑可以帮助我们更好地应对挑战。你可以尝试一些放松的方法，比如深呼吸、冥想或者运动。如果感到压力过大，也可以和朋友或家人聊聊，或者寻求专业的心理咨询。'),
(1, '谢谢你的建议，我会试试的', '不客气！记住，照顾好自己的心理健康很重要。如果以后还有任何困扰，随时可以来找我聊聊。祝你一切顺利！'),
(2, '最近睡眠质量不好，有什么建议吗？', '睡眠问题确实会影响我们的身心健康。以下是一些改善睡眠的建议：1. 保持规律的作息时间；2. 睡前避免使用电子设备；3. 创造一个舒适的睡眠环境；4. 睡前可以尝试放松活动，如阅读或冥想；5. 避免睡前摄入咖啡因。希望这些方法能帮到你！');

-- 插入情绪日记测试数据
INSERT OR IGNORE INTO "diary" ("user_id", "title", "content", "emotion", "intensity", "event") VALUES 
(1, '今天的工作压力', '今天的工作量很大，感觉有些喘不过气来。但是通过和同事的合作，最终完成了任务。', '焦虑', 6, '项目截止日期临近，需要加班完成'),
(1, '周末的放松时光', '周末和朋友一起去爬山，感觉心情好多了。大自然真的很治愈。', '开心', 8, '和朋友去郊外爬山'),
(2, '最近的情绪波动', '最近情绪起伏比较大，可能是因为工作压力和生活琐事。需要好好调整一下。', '平静', 4, '工作和生活中的一些小挫折');

-- 插入测评结果测试数据
INSERT OR IGNORE INTO "assessment_result" ("user_id", "assessment_id", "score", "result") VALUES 
(1, 1, 45, '您的心理健康状况良好，但需要注意一些轻微的症状。建议保持良好的生活习惯，适当放松。'),
(1, 2, 35, '您的抑郁程度较低，情绪状态良好。继续保持积极的生活态度。'),
(2, 1, 52, '您的心理健康状况一般，存在一些需要关注的问题。建议寻求专业的心理咨询。');

-- 插入社区帖子测试数据
INSERT OR IGNORE INTO "community_post" ("user_id", "title", "content", "anonymous", "like_count", "comment_count") VALUES 
(1, '大家都是如何应对工作压力的？', '最近工作压力很大，感觉喘不过气来，想听听大家都是如何调节的...', 1, 23, 8),
(2, '分享一个缓解焦虑的小方法', '我发现每天冥想10分钟，对缓解焦虑很有帮助...', 1, 45, 12),
(3, '和家人沟通总是很困难，怎么办？', '最近和家人的关系有点紧张，不知道如何有效沟通...', 1, 18, 6);

-- 插入社区评论测试数据
INSERT OR IGNORE INTO "community_comment" ("post_id", "user_id", "content", "anonymous") VALUES 
(1, 2, '我也是，最近工作特别忙，感觉压力很大。我一般会去跑步或者听音乐来放松。', 1),
(1, 3, '建议你可以试试冥想，对我很有帮助。', 1),
(2, 1, '谢谢分享！我也试试冥想。', 1);

-- 插入默认测评数据
INSERT OR IGNORE INTO "assessment" ("name", "description", "type") VALUES 
('SCL-90症状自评量表', '用于评估个体在一周内的心理健康状况，包括9个因子：躯体化、强迫症状、人际关系敏感、抑郁、焦虑、敌对、恐怖、偏执及精神病性。', 'SCL-90'),
('SDS抑郁自评量表', '用于评估抑郁程度，适用于具有抑郁症状的成年人。', 'SDS'),
('SAS焦虑自评量表', '用于评估焦虑程度，适用于具有焦虑症状的成年人。', 'SAS'),
('压力感知量表', '用于评估个体对压力的感知程度，帮助了解自身的压力水平。', 'PSS');

-- 插入默认心理科普内容
INSERT OR IGNORE INTO "knowledge" ("title", "content", "category") VALUES 
('如何应对焦虑情绪', '焦虑是一种常见的情绪反应，适当的焦虑可以帮助我们应对挑战，但过度焦虑会影响生活质量。以下是一些应对焦虑的方法：1. 深呼吸练习；2. 渐进式肌肉放松；3. 正念冥想；4. 规律运动；5. 保持良好的作息。', '情绪调节'),
('压力管理技巧', '现代生活中，压力无处不在。有效的压力管理可以帮助我们保持身心健康：1. 识别压力源；2. 制定合理的目标；3. 学会说"不"；4. 培养兴趣爱好；5. 寻求社会支持。', '压力管理'),
('建立健康的人际关系', '良好的人际关系对心理健康至关重要：1. 积极沟通；2. 学会倾听；3. 尊重他人；4. 保持边界；5. 真诚相待。', '人际关系'),
('自我成长的重要性', '自我成长是一个持续的过程，有助于提升心理健康水平：1. 设定个人目标；2. 持续学习；3. 接受挑战；4. 反思自我；5. 保持开放的心态。', '自我成长');
