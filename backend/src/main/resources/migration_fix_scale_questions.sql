-- ============================================================
-- 修复脚本：让数据库题库与静态题库 static/scales/*.json 保持一致
-- 适用库：mindhealth（MySQL）
-- 执行前请先备份数据库
--
-- 【为什么要修】
-- migration_assessment_questions_feedback.sql 的 2.1 先把所有量表写成了「通用题库」，
-- 而 2.2 ~ 2.5 的 WHERE 条件里带了 (questions IS NULL OR questions = '')，
-- 此时 questions 已经被 2.1 填过了，条件恒为 false，
-- 结果是：SDS / SAS / PSS 三套专项量表实际上拿到的都是「通用题库」。
-- 本脚本按 type 精确覆盖，使 DB 内容与 static/scales/{id}.json 一一对应。
--
-- 【未执行】本脚本不会自动运行，需由 DBA / 开发者手动执行。
-- ============================================================

-- id=1 SCL-90：通用题库
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否经常感到情绪低落或烦躁？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
  {"id":2,"title":"最近一周，你是否容易因为小事紧张或担心？","options":[{"key":"A","text":"完全不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"非常明显","score":3}]},
  {"id":3,"title":"最近一周，你的睡眠情况如何？","options":[{"key":"A","text":"很好","score":0},{"key":"B","text":"偶尔睡不好","score":1},{"key":"C","text":"经常睡不好","score":2},{"key":"D","text":"严重影响休息","score":3}]},
  {"id":4,"title":"最近一周，你做事时是否难以集中注意力？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"非常严重","score":3}]},
  {"id":5,"title":"最近一周，你是否愿意主动与他人交流？","options":[{"key":"A","text":"很愿意","score":0},{"key":"B","text":"还可以","score":1},{"key":"C","text":"不太愿意","score":2},{"key":"D","text":"完全不想","score":3}]}
]'
WHERE `type` = 'SCL-90';

-- id=2 SDS：情绪低落 / 抑郁专项
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否感到情绪低落、开心不起来？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
  {"id":2,"title":"最近一周，你对以前喜欢的事情还有兴趣吗？","options":[{"key":"A","text":"和以前一样","score":0},{"key":"B","text":"兴趣少了一些","score":1},{"key":"C","text":"明显没兴趣","score":2},{"key":"D","text":"完全提不起兴趣","score":3}]},
  {"id":3,"title":"最近一周，你是否觉得自己没什么价值或容易自责？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"总是如此","score":3}]},
  {"id":4,"title":"最近一周，你的食欲和精力怎么样？","options":[{"key":"A","text":"正常","score":0},{"key":"B","text":"稍微下降","score":1},{"key":"C","text":"明显下降","score":2},{"key":"D","text":"非常差","score":3}]},
  {"id":5,"title":"最近一周，早晨醒来时你的心情如何？","options":[{"key":"A","text":"比较平静","score":0},{"key":"B","text":"有点低落","score":1},{"key":"C","text":"比较低落","score":2},{"key":"D","text":"非常低落","score":3}]}
]'
WHERE `type` = 'SDS';

-- id=3 SAS：焦虑专项
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否经常感到紧张、不安或担心？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
  {"id":2,"title":"最近一周，你是否会因为担心而难以放松？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"一直如此","score":3}]},
  {"id":3,"title":"最近一周，你是否出现过心跳加快、手心出汗等身体反应？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"非常频繁","score":3}]},
  {"id":4,"title":"最近一周，你是否会回避让你感到紧张的场合？","options":[{"key":"A","text":"不会回避","score":0},{"key":"B","text":"偶尔回避","score":1},{"key":"C","text":"经常回避","score":2},{"key":"D","text":"完全回避","score":3}]},
  {"id":5,"title":"最近一周，担心的念头是否影响到你的工作或生活？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]}
]'
WHERE `type` = 'SAS';

-- id=4 PSS：压力专项
UPDATE `assessment`
SET `questions` = '[
  {"id":1,"title":"最近一周，你是否感到压力超出了自己的承受范围？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"一直有","score":3}]},
  {"id":2,"title":"最近一周，你是否因为任务太多而感到喘不过气？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎每天","score":3}]},
  {"id":3,"title":"最近一周，你是否因为压力而情绪失控或易怒？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"非常频繁","score":3}]},
  {"id":4,"title":"最近一周，压力是否影响到你的睡眠或饮食？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]},
  {"id":5,"title":"最近一周，你是否有能力安排时间来放松自己？","options":[{"key":"A","text":"经常有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"很少","score":2},{"key":"D","text":"完全没有","score":3}]}
]'
WHERE `type` = 'PSS';

-- 可选：新增「睡眠质量自查」量表（对应 static/scales/5.json，当前 DB 中尚无该记录）
-- INSERT INTO `assessment` (`name`, `description`, `type`, `questions`) VALUES
-- ('睡眠质量自查', '用于了解近一周的入睡、夜间觉醒与整体睡眠质量。', 'SLEEP', '<复制 static/scales/5.json 的 questions 数组>');

-- 校验：执行后四套量表的题库应互不相同
-- SELECT id, name, type, LEFT(questions, 60) FROM assessment ORDER BY id;
