-- ============================================================
-- 迁移脚本：测评题库后端化 + 帮助反馈表
-- 适用库：mindhealth（MySQL）
-- 执行前请先备份数据库
-- ============================================================

-- 1. assessment 表增加题库列（JSON 文本）
ALTER TABLE `assessment`
    ADD COLUMN `questions` TEXT NULL COMMENT '题库JSON: [{id,title,options:[{key,text,score}]}]' AFTER `type`;

-- 2. 为现有量表写入题库（5 题 × 0-3 分，满分 15，与等级判定逻辑一致）
-- 2.1 通用默认题库：所有没有专属题库的量表都会用它兜底
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否经常感到情绪低落或烦躁？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
  {"id":2,"title":"最近一周，你是否容易因为小事紧张或担心？","options":[{"key":"A","text":"完全不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"非常明显","score":3}]},
  {"id":3,"title":"最近一周，你的睡眠情况如何？","options":[{"key":"A","text":"很好","score":0},{"key":"B","text":"偶尔睡不好","score":1},{"key":"C","text":"经常睡不好","score":2},{"key":"D","text":"严重影响休息","score":3}]},
  {"id":4,"title":"最近一周，你做事时是否难以集中注意力？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"非常严重","score":3}]},
  {"id":5,"title":"最近一周，你是否愿意主动与他人交流？","options":[{"key":"A","text":"很愿意","score":0},{"key":"B","text":"还可以","score":1},{"key":"C","text":"不太愿意","score":2},{"key":"D","text":"完全不想","score":3}]}
]'
WHERE `questions` IS NULL OR `questions` = '';

-- 2.2 焦虑专项（按名称/类型匹配，未匹配到也没关系，有兜底题库）
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否经常感到紧张、不安或担心？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
  {"id":2,"title":"最近一周，你是否会因为担心而难以放松？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"一直如此","score":3}]},
  {"id":3,"title":"最近一周，你是否出现过心跳加快、手心出汗等身体反应？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"非常频繁","score":3}]},
  {"id":4,"title":"最近一周，你是否会回避让你感到紧张的场合？","options":[{"key":"A","text":"不会回避","score":0},{"key":"B","text":"偶尔回避","score":1},{"key":"C","text":"经常回避","score":2},{"key":"D","text":"完全回避","score":3}]},
  {"id":5,"title":"最近一周，担心的念头是否影响到你的工作或生活？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]}
]'
WHERE (`name` LIKE '%焦虑%' OR `type` LIKE '%焦虑%' OR `type` LIKE '%anxiety%')
  AND (`questions` IS NULL OR `questions` = '');

-- 2.3 情绪低落/抑郁专项
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否感到情绪低落、开心不起来？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
  {"id":2,"title":"最近一周，你对以前喜欢的事情还有兴趣吗？","options":[{"key":"A","text":"和以前一样","score":0},{"key":"B","text":"兴趣少了一些","score":1},{"key":"C","text":"明显没兴趣","score":2},{"key":"D","text":"完全提不起兴趣","score":3}]},
  {"id":3,"title":"最近一周，你是否觉得自己没什么价值或容易自责？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"总是如此","score":3}]},
  {"id":4,"title":"最近一周，你的食欲和精力怎么样？","options":[{"key":"A","text":"正常","score":0},{"key":"B","text":"稍微下降","score":1},{"key":"C","text":"明显下降","score":2},{"key":"D","text":"非常差","score":3}]},
  {"id":5,"title":"最近一周，早晨醒来时你的心情如何？","options":[{"key":"A","text":"比较平静","score":0},{"key":"B","text":"有点低落","score":1},{"key":"C","text":"比较低落","score":2},{"key":"D","text":"非常低落","score":3}]}
]'
WHERE (`name` LIKE '%抑郁%' OR `name` LIKE '%低落%' OR `type` LIKE '%抑郁%' OR `type` LIKE '%depress%')
  AND (`questions` IS NULL OR `questions` = '');

-- 2.4 压力专项
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否感到压力超出了自己的承受范围？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"一直有","score":3}]},
  {"id":2,"title":"最近一周，你是否因为任务太多而感到喘不过气？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎每天","score":3}]},
  {"id":3,"title":"最近一周，你是否因为压力而情绪失控或易怒？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"非常频繁","score":3}]},
  {"id":4,"title":"最近一周，压力是否影响到你的睡眠或饮食？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]},
  {"id":5,"title":"最近一周，你是否有能力安排时间来放松自己？","options":[{"key":"A","text":"经常有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"很少","score":2},{"key":"D","text":"完全没有","score":3}]}
]'
WHERE (`name` LIKE '%压力%' OR `type` LIKE '%压力%' OR `type` LIKE '%stress%')
  AND (`questions` IS NULL OR `questions` = '');

-- 2.5 睡眠专项
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你通常需要多久才能入睡？","options":[{"key":"A","text":"30 分钟内","score":0},{"key":"B","text":"半小时到 1 小时","score":1},{"key":"C","text":"1~2 小时","score":2},{"key":"D","text":"超过 2 小时","score":3}]},
  {"id":2,"title":"最近一周，你夜里是否会频繁醒来？","options":[{"key":"A","text":"几乎不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常醒来","score":2},{"key":"D","text":"几乎每晚","score":3}]},
  {"id":3,"title":"最近一周，早晨醒来后你是否感到休息够了？","options":[{"key":"A","text":"休息够了","score":0},{"key":"B","text":"勉强够","score":1},{"key":"C","text":"明显不够","score":2},{"key":"D","text":"非常疲惫","score":3}]},
  {"id":4,"title":"最近一周，你是否会因为白天犯困而影响状态？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天","score":3}]},
  {"id":5,"title":"最近一周，你的总体睡眠质量如何？","options":[{"key":"A","text":"很好","score":0},{"key":"B","text":"还可以","score":1},{"key":"C","text":"比较差","score":2},{"key":"D","text":"非常差","score":3}]}
]'
WHERE (`name` LIKE '%睡眠%' OR `type` LIKE '%睡眠%' OR `type` LIKE '%sleep%')
  AND (`questions` IS NULL OR `questions` = '');

-- 3. 帮助反馈表
CREATE TABLE IF NOT EXISTS `feedback` (
    `id` BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id` BIGINT NOT NULL COMMENT '提交用户',
    `type` VARCHAR(20) NOT NULL DEFAULT 'suggestion' COMMENT '类型: bug/suggestion/other',
    `content` VARCHAR(1000) NOT NULL COMMENT '反馈内容',
    `contact` VARCHAR(100) NULL COMMENT '联系方式（选填）',
    `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (`id`),
    INDEX `idx_feedback_user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户反馈表';
