-- ============================================================
-- 迁移脚本：题库 v2（每套量表独立阈值 + 12 题）+ 答题明细 + AI 分析
-- 适用库：mindhealth（MySQL 8）
-- 执行前请先备份数据库
--
-- 背景：旧题库的问题
--   1) id=1「情绪状态自评」与 id=6「心理韧性测试」的 5 道题完全复制粘贴，
--      韧性量表问的是「是否情绪低落」，属于症状筛查题，量表名与题目不符；
--   2) 6 套量表共用同一套阈值（<=3/8/12）和同样 4 句建议，测评结果千篇一律；
--   3) 韧性是正向指标，却被当成症状量表算，得分越高被判为「风险越高」；
--   4) 后端只收到一个客户端算好的总分，没有答题明细，无法做任何个性化分析。
--
-- 本脚本一次性解决 1~4。注意：ADD COLUMN 若列已存在会报错，可忽略该条继续。
-- ============================================================

-- ---------- 1. assessment 增加计分配置 ----------
-- scoring JSON 结构：{"bands":[{"max":8,"level":"...","suggestion":"..."}, ...]}
-- bands 按 max 升序，最后一条兜住剩余分数；每套量表各有一套，不再共用
ALTER TABLE `assessment`
    ADD COLUMN `scoring` TEXT NULL COMMENT '计分配置JSON: {bands:[{max,level,suggestion}]}' AFTER `questions`;

-- ---------- 2. assessment_result 增加答题明细与 AI 分析 ----------
ALTER TABLE `assessment_result`
    ADD COLUMN `answers_json` TEXT NULL COMMENT '答题明细JSON: [{questionId,optionKey,score}]' AFTER `suggestion`;
ALTER TABLE `assessment_result`
    ADD COLUMN `max_score` INT NULL COMMENT '本次量表满分，AI 分析需要分母' AFTER `score`;
ALTER TABLE `assessment_result`
    ADD COLUMN `ai_status` VARCHAR(20) NULL COMMENT 'AI分析状态: none/pending/success/failed' AFTER `answers_json`;
ALTER TABLE `assessment_result`
    ADD COLUMN `ai_analysis` TEXT NULL COMMENT 'AI分析结果JSON(结构化)' AFTER `ai_status`;
ALTER TABLE `assessment_result`
    ADD COLUMN `ai_error` VARCHAR(255) NULL COMMENT 'AI失败原因，用户可见可重试' AFTER `ai_analysis`;

-- ---------- 3. 重写 6 套量表（按 type 精确定位） ----------
-- 说明：全部改为 12 题 × 0-3 分 = 满分 36；
--       前 5 套为症状类（分越高越需关注），第 6 套「心理韧性」为正向类（分越高越好），
--       因此韧性使用「完全不符合→完全符合」的表述，并配一套方向相反的阈值。

-- 3.1 情绪状态自评
UPDATE `assessment` SET
  `name` = '情绪状态自评',
  `description` = '帮助你了解最近一周的整体情绪状态，包含情绪低落、烦躁、兴趣与精力等方面，适合日常自查。',
  `scoring` = '{"bands":[{"max":8,"level":"状态平稳","suggestion":"最近一周你的情绪整体平稳，没有明显困扰。可以继续保持规律的作息和记录习惯，这会帮你更早察觉情绪变化。"},{"max":16,"level":"轻度波动","suggestion":"最近一周你的情绪出现了轻度波动，可能和作息、压力或具体事件有关。建议先保证睡眠和运动，并把情绪记进日记，观察哪些情境容易触发。"},{"max":24,"level":"中度困扰","suggestion":"最近一周情绪困扰比较明显，已经影响到日常生活。建议主动减少不必要的消耗，多和信任的人聊一聊，必要时预约一次心理咨询。"},{"max":36,"level":"明显困扰","suggestion":"最近一周你的情绪困扰程度较高。请优先照顾好自己的休息与饮食，并尽快联系可信任的人或专业心理支持；如果出现伤害自己的念头，请立即拨打心理援助热线。"}]}',
  `questions` = '[
{"id":1,"title":"最近一周，你是否经常感到情绪低落或提不起劲？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":2,"title":"最近一周，你对自己以往感兴趣的事情还有热情吗？","options":[{"key":"A","text":"和以前一样","score":0},{"key":"B","text":"热情少了一些","score":1},{"key":"C","text":"明显提不起兴趣","score":2},{"key":"D","text":"完全没有兴趣","score":3}]},
{"id":3,"title":"最近一周，你是否容易因为小事而烦躁、发脾气？","options":[{"key":"A","text":"几乎不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎每天都烦躁","score":3}]},
{"id":4,"title":"最近一周，你的心情起伏大吗？","options":[{"key":"A","text":"比较稳定","score":0},{"key":"B","text":"偶尔起伏","score":1},{"key":"C","text":"起伏明显","score":2},{"key":"D","text":"一直难以平静","score":3}]},
{"id":5,"title":"最近一周，你是否容易感到委屈或想哭？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":6,"title":"最近一周，你是否觉得很难从负面情绪里走出来？","options":[{"key":"A","text":"不会，很快能调整","score":0},{"key":"B","text":"需要一点时间","score":1},{"key":"C","text":"要很久才能缓过来","score":2},{"key":"D","text":"一直走不出来","score":3}]},
{"id":7,"title":"最近一周，你做事时是否难以集中注意力？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"非常严重","score":3}]},
{"id":8,"title":"最近一周，你是否经常感到莫名的疲惫？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":9,"title":"最近一周，你对自己的未来是否感到模糊或没把握？","options":[{"key":"A","text":"比较清晰","score":0},{"key":"B","text":"偶尔会迷茫","score":1},{"key":"C","text":"经常感到迷茫","score":2},{"key":"D","text":"完全没有方向","score":3}]},
{"id":10,"title":"最近一周，你是否会刻意回避与人的交流？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎都回避","score":3}]},
{"id":11,"title":"最近一周，你是否觉得很难让自己放松下来？","options":[{"key":"A","text":"很容易放松","score":0},{"key":"B","text":"偶尔难以放松","score":1},{"key":"C","text":"经常难以放松","score":2},{"key":"D","text":"一直紧绷着","score":3}]},
{"id":12,"title":"最近一周，你是否觉得情绪影响到了工作或学习？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]}
]'
WHERE `type` = 'emotion';

-- 3.2 压力水平测试
UPDATE `assessment` SET
  `name` = '压力水平测试',
  `description` = '评估最近一周学习、工作与生活带来的压力程度，帮助识别压力来源与身体反应。',
  `scoring` = '{"bands":[{"max":8,"level":"压力较低","suggestion":"最近一周你承受的压力在可应对范围内。可以继续保持现有的节奏，同时留一点固定的放松时间作为缓冲。"},{"max":16,"level":"轻度压力","suggestion":"最近一周你有一些压力积累。建议把任务按优先级拆小，先完成最要紧的一件；每天留 20 分钟不被打扰的放松时间。"},{"max":24,"level":"压力偏高","suggestion":"最近一周压力已经比较明显，可能伴随睡眠或情绪变化。建议主动和上级、家人沟通调整任务量，并安排一次真正断开的休息。"},{"max":36,"level":"压力过载","suggestion":"最近一周你的压力已接近或超出承受范围。请优先减负而不是硬撑，尽快向身边人求助；如果身体出现明显不适，建议同时就医排查。"}]}',
  `questions` = '[
{"id":1,"title":"最近一周，你是否感到手头的事情超出了自己能应对的范围？","options":[{"key":"A","text":"完全没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"一直如此","score":3}]},
{"id":2,"title":"最近一周，你是否因为任务太多而感到喘不过气？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎每天","score":3}]},
{"id":3,"title":"最近一周，你是否因为压力而变得急躁或容易发火？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"非常频繁","score":3}]},
{"id":4,"title":"最近一周，压力是否影响到你的睡眠或食欲？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]},
{"id":5,"title":"最近一周，你是否觉得自己没有时间休息或做喜欢的事？","options":[{"key":"A","text":"时间充足","score":0},{"key":"B","text":"偶尔没有时间","score":1},{"key":"C","text":"经常没有时间","score":2},{"key":"D","text":"完全没有时间","score":3}]},
{"id":6,"title":"最近一周，你是否感到身体紧绷、肩颈酸痛等压力反应？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":7,"title":"最近一周，你是否因为担心做不好而反复检查或拖延？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎每次都会","score":3}]},
{"id":8,"title":"最近一周，你是否很难在工作和生活之间划清界限？","options":[{"key":"A","text":"界限很清楚","score":0},{"key":"B","text":"偶尔会混在一起","score":1},{"key":"C","text":"经常混在一起","score":2},{"key":"D","text":"完全没有界限","score":3}]},
{"id":9,"title":"最近一周，你是否感到被期待或责任压得难以放松？","options":[{"key":"A","text":"没有这种感觉","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"一直有","score":3}]},
{"id":10,"title":"最近一周，你是否会因为小事而感到格外烦躁？","options":[{"key":"A","text":"很少","score":0},{"key":"B","text":"偶尔","score":1},{"key":"C","text":"经常","score":2},{"key":"D","text":"几乎每天","score":3}]},
{"id":11,"title":"最近一周，你是否觉得自己一直在硬撑？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"一直如此","score":3}]},
{"id":12,"title":"最近一周，你是否有办法安排时间来放松自己？","options":[{"key":"A","text":"经常能安排","score":0},{"key":"B","text":"偶尔能安排","score":1},{"key":"C","text":"很少能安排","score":2},{"key":"D","text":"完全安排不出来","score":3}]}
]'
WHERE `type` = 'stress';

-- 3.3 焦虑倾向筛查
UPDATE `assessment` SET
  `name` = '焦虑倾向筛查',
  `description` = '用于初步评估最近一周是否存在焦虑倾向与紧张反应，包含担心、躯体反应与回避行为。',
  `scoring` = '{"bands":[{"max":8,"level":"焦虑不明显","suggestion":"最近一周你的紧张感在常见范围内。可以在容易紧张的时刻试几次缓慢的腹式呼吸（吸 4 秒、呼 6 秒），作为日常调节手段。"},{"max":16,"level":"轻度焦虑","suggestion":"最近一周你有一些焦虑反应。建议减少睡前的信息刺激，把担心的事写在纸上而不是反复在脑中过；如果某个场合让你回避，尝试先短时间暴露而不是完全躲开。"},{"max":24,"level":"焦虑偏高","suggestion":"最近一周焦虑反应比较明显，可能已经影响工作或睡眠。建议规律作息、减少咖啡因，并把焦虑的具体内容和频率记录下来，这会是咨询时很有用的材料。"},{"max":36,"level":"焦虑明显","suggestion":"最近一周你的焦虑程度较高，若伴随明显的躯体症状（心悸、胸闷、呼吸困难），建议先就医排除身体原因，同时寻求专业心理支持。"}]}',
  `questions` = '[
{"id":1,"title":"最近一周，你是否经常感到紧张、不安或担心？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":2,"title":"最近一周，你是否会因为担心而难以放松下来？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"一直如此","score":3}]},
{"id":3,"title":"最近一周，你是否出现过心跳加快、手心出汗等身体反应？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"非常频繁","score":3}]},
{"id":4,"title":"最近一周，你是否会回避让你感到紧张的场合？","options":[{"key":"A","text":"不会回避","score":0},{"key":"B","text":"偶尔回避","score":1},{"key":"C","text":"经常回避","score":2},{"key":"D","text":"完全回避","score":3}]},
{"id":5,"title":"最近一周，担心的念头是否影响到你的工作或生活？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]},
{"id":6,"title":"最近一周，你是否会反复想到还没发生的最坏结果？","options":[{"key":"A","text":"很少","score":0},{"key":"B","text":"偶尔","score":1},{"key":"C","text":"经常","score":2},{"key":"D","text":"几乎停不下来","score":3}]},
{"id":7,"title":"最近一周，你是否很难让自己安静地待一会儿？","options":[{"key":"A","text":"可以安静下来","score":0},{"key":"B","text":"偶尔难以安静","score":1},{"key":"C","text":"经常坐不住","score":2},{"key":"D","text":"完全静不下来","score":3}]},
{"id":8,"title":"最近一周，你是否会因为不确定的事情而坐立不安？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"一直如此","score":3}]},
{"id":9,"title":"最近一周，你是否比平时更容易被吓到或惊跳？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"非常明显","score":3}]},
{"id":10,"title":"最近一周，你是否觉得喉咙发紧、呼吸不畅或胸口发闷？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":11,"title":"最近一周，你是否需要反复确认才能放心？","options":[{"key":"A","text":"不需要","score":0},{"key":"B","text":"偶尔需要","score":1},{"key":"C","text":"经常需要","score":2},{"key":"D","text":"几乎事事都要确认","score":3}]},
{"id":12,"title":"最近一周，担心是否让你难以入睡或夜里容易醒？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"偶尔影响","score":1},{"key":"C","text":"经常影响","score":2},{"key":"D","text":"几乎每晚都受影响","score":3}]}
]'
WHERE `type` = 'anxiety';

-- 3.4 抑郁情绪筛查
UPDATE `assessment` SET
  `name` = '抑郁情绪筛查',
  `description` = '用于初步识别最近一周是否存在持续低落、兴趣减退、精力下降等情况。本测评不是诊断工具。',
  `scoring` = '{"bands":[{"max":8,"level":"情绪较稳定","suggestion":"最近一周你的情绪比较稳定。继续保持规律作息、适度运动和与人保持联系，这些是预防情绪下滑最有效的日常习惯。"},{"max":16,"level":"轻度低落","suggestion":"最近一周你出现了轻度情绪低落。建议先从最容易改变的一件事入手（比如固定起床时间、每天出门走 20 分钟），并把感受写进日记，观察一周的变化。"},{"max":24,"level":"低落较明显","suggestion":"最近一周低落情绪比较明显，且可能已影响到兴趣或精力。建议尽快和信任的人谈一谈，并预约专业心理咨询做一次系统评估。"},{"max":36,"level":"低落较重","suggestion":"最近一周你的低落程度较高。请把「尽快寻求专业帮助」放在第一位，同时联系可信任的人陪伴自己。如果出现伤害自己的想法，请立即拨打心理援助热线或前往医院急诊。"}]}',
  `questions` = '[
{"id":1,"title":"最近一周，你是否感到情绪低落、开心不起来？","options":[{"key":"A","text":"几乎没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":2,"title":"最近一周，你对以前喜欢的事情还有兴趣吗？","options":[{"key":"A","text":"和以前一样","score":0},{"key":"B","text":"兴趣少了一些","score":1},{"key":"C","text":"明显没兴趣","score":2},{"key":"D","text":"完全提不起兴趣","score":3}]},
{"id":3,"title":"最近一周，你是否觉得自己没什么价值或容易自责？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"总是如此","score":3}]},
{"id":4,"title":"最近一周，你的食欲和精力怎么样？","options":[{"key":"A","text":"正常","score":0},{"key":"B","text":"稍微下降","score":1},{"key":"C","text":"明显下降","score":2},{"key":"D","text":"非常差","score":3}]},
{"id":5,"title":"最近一周，早晨醒来时你的心情如何？","options":[{"key":"A","text":"比较平静","score":0},{"key":"B","text":"有点低落","score":1},{"key":"C","text":"比较低落","score":2},{"key":"D","text":"非常低落","score":3}]},
{"id":6,"title":"最近一周，你是否觉得做事情比以前更费力、更慢？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":7,"title":"最近一周，你是否觉得未来没什么值得期待的？","options":[{"key":"A","text":"完全不觉得","score":0},{"key":"B","text":"偶尔会这样想","score":1},{"key":"C","text":"经常会这样想","score":2},{"key":"D","text":"一直这么觉得","score":3}]},
{"id":8,"title":"最近一周，你是否比平时更想一个人待着、不想说话？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎一直如此","score":3}]},
{"id":9,"title":"最近一周，你是否觉得自己是别人的负担？","options":[{"key":"A","text":"从没有","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"一直这么觉得","score":3}]},
{"id":10,"title":"最近一周，你是否觉得注意力很难集中、记不住事？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"非常严重","score":3}]},
{"id":11,"title":"最近一周，你是否觉得身体沉重、动起来很费劲？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天都有","score":3}]},
{"id":12,"title":"最近一周，你是否觉得生活缺少意义感？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"一直如此","score":3}]}
]'
WHERE `type` = 'depression';

-- 3.5 睡眠质量评估
UPDATE `assessment` SET
  `name` = '睡眠质量评估',
  `description` = '了解最近一周的入睡速度、夜间觉醒、睡眠时长与白天恢复情况。',
  `scoring` = '{"bands":[{"max":8,"level":"睡眠良好","suggestion":"最近一周你的睡眠质量不错。建议固定起床时间（比固定入睡时间更有效），并把卧室的光线和温度保持稳定，帮助维持现在的状态。"},{"max":16,"level":"轻度睡眠问题","suggestion":"最近一周你的睡眠出现了一些问题。睡前 1 小时建议离开屏幕、把担心的事写下来留到第二天；白天补觉控制在 20 分钟以内，避免打乱夜间睡意。"},{"max":24,"level":"睡眠问题明显","suggestion":"最近一周睡眠问题比较明显，且可能已经影响情绪和白天状态。建议连续记录一周的入睡/醒来时间，找出规律后再调整；如果持续超过三周，建议就医评估。"},{"max":36,"level":"睡眠质量较差","suggestion":"最近一周你的睡眠质量较差。长期睡眠不足会明显加重情绪问题，建议尽快就医排查（如睡眠呼吸问题、焦虑抑郁相关的失眠），不建议自行长期使用助眠药物。"}]}',
  `questions` = '[
{"id":1,"title":"最近一周，你通常需要多久才能入睡？","options":[{"key":"A","text":"30 分钟内","score":0},{"key":"B","text":"半小时到 1 小时","score":1},{"key":"C","text":"1~2 小时","score":2},{"key":"D","text":"超过 2 小时","score":3}]},
{"id":2,"title":"最近一周，你夜里是否会频繁醒来？","options":[{"key":"A","text":"几乎不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常醒来","score":2},{"key":"D","text":"几乎每晚都醒","score":3}]},
{"id":3,"title":"最近一周，早晨醒来后你是否感到休息够了？","options":[{"key":"A","text":"休息够了","score":0},{"key":"B","text":"勉强够","score":1},{"key":"C","text":"明显不够","score":2},{"key":"D","text":"非常疲惫","score":3}]},
{"id":4,"title":"最近一周，你是否会因为白天犯困而影响状态？","options":[{"key":"A","text":"没有","score":0},{"key":"B","text":"偶尔有","score":1},{"key":"C","text":"经常有","score":2},{"key":"D","text":"几乎每天","score":3}]},
{"id":5,"title":"最近一周，你的总体睡眠质量如何？","options":[{"key":"A","text":"很好","score":0},{"key":"B","text":"还可以","score":1},{"key":"C","text":"比较差","score":2},{"key":"D","text":"非常差","score":3}]},
{"id":6,"title":"最近一周，你每天实际的睡眠时长大约是？","options":[{"key":"A","text":"7 小时以上","score":0},{"key":"B","text":"6~7 小时","score":1},{"key":"C","text":"5~6 小时","score":2},{"key":"D","text":"少于 5 小时","score":3}]},
{"id":7,"title":"最近一周，你是否需要靠刷手机或看视频才能入睡？","options":[{"key":"A","text":"不需要","score":0},{"key":"B","text":"偶尔需要","score":1},{"key":"C","text":"经常需要","score":2},{"key":"D","text":"每次都要","score":3}]},
{"id":8,"title":"最近一周，你夜里醒来后是否很难再睡着？","options":[{"key":"A","text":"不会","score":0},{"key":"B","text":"偶尔会","score":1},{"key":"C","text":"经常会","score":2},{"key":"D","text":"几乎每次都很难再睡","score":3}]},
{"id":9,"title":"最近一周，你的入睡和起床时间是否规律？","options":[{"key":"A","text":"很规律","score":0},{"key":"B","text":"偶尔不规律","score":1},{"key":"C","text":"经常不规律","score":2},{"key":"D","text":"完全没规律","score":3}]},
{"id":10,"title":"最近一周，你是否会因为想事情而睡不着？","options":[{"key":"A","text":"很少","score":0},{"key":"B","text":"偶尔","score":1},{"key":"C","text":"经常","score":2},{"key":"D","text":"几乎每晚","score":3}]},
{"id":11,"title":"最近一周，睡眠问题是否已经影响到你的情绪？","options":[{"key":"A","text":"没有影响","score":0},{"key":"B","text":"轻微影响","score":1},{"key":"C","text":"明显影响","score":2},{"key":"D","text":"严重影响","score":3}]},
{"id":12,"title":"最近一周，你白天是否需要靠咖啡或提神饮品维持状态？","options":[{"key":"A","text":"不需要","score":0},{"key":"B","text":"偶尔需要","score":1},{"key":"C","text":"经常需要","score":2},{"key":"D","text":"每天都离不开","score":3}]}
]'
WHERE `type` = 'sleep';

-- 3.6 心理韧性测试（正向量表：分数越高韧性越好）
-- 注意：本题库全部为正向表述（「完全不符合 → 完全符合」），阈值方向与上面 5 套相反
UPDATE `assessment` SET
  `name` = '心理韧性测试',
  `description` = '评估面对挫折、压力和变化时的恢复能力与适应能力。这是正向指标，分数越高代表韧性越好。',
  `scoring` = '{"bands":[{"max":12,"level":"韧性偏弱","suggestion":"目前你在面对挫折时较容易感到吃力，这通常和近期的疲惫或支持不足有关，而不是你的能力问题。建议先从「保证睡眠 + 找到 1 个可以倾诉的人」这两件事开始。"},{"max":21,"level":"韧性中等","suggestion":"你有一定的恢复能力，但在压力集中时容易被打乱节奏。可以刻意练习把大问题拆成今天就能完成的一小步，并及时记录已经解决掉的事，强化「我能处理」的经验。"},{"max":28,"level":"韧性较好","suggestion":"你面对困难时整体能保持稳定并找到办法。可以进一步发挥这项优势：把有效的应对方式写下来形成自己的清单，在状态差的时候直接照着做。"},{"max":36,"level":"韧性良好","suggestion":"你在面对挫折和变化时恢复能力很强。留意不要让「我扛得住」变成长期独自硬撑——主动求助本身也是韧性的表现。"}]}',
  `questions` = '[
{"id":1,"title":"遇到困难时，我通常能找到可行的解决办法。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":2,"title":"即使事情不顺利，我也能坚持把事情做完。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":3,"title":"我能比较快地从挫折中恢复过来。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":4,"title":"面对突然的变化，我一般能调整自己适应过来。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":5,"title":"我相信自己有处理问题的能力。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":6,"title":"压力大的时候，我知道怎么让自己缓一缓。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":7,"title":"遇到难题时，我愿意向身边的人求助，而不是一个人硬扛。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":8,"title":"我能从过去的经历里总结出对自己有用的经验。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":9,"title":"即使结果不确定，我也愿意先去尝试。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":10,"title":"遇到麻烦时，我既能看到困难，也能想到可能的转机。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":11,"title":"我通常能保持相对稳定的情绪去面对麻烦。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]},
{"id":12,"title":"我对自己的未来保有基本的信心。","options":[{"key":"A","text":"完全不符合","score":0},{"key":"B","text":"比较不符合","score":1},{"key":"C","text":"比较符合","score":2},{"key":"D","text":"完全符合","score":3}]}
]'
WHERE `type` = 'resilience';

-- ---------- 4. 校验 ----------
-- 期望：6 行，questions 已更新为 12 题，scoring 非空
SELECT id, name, type, JSON_LENGTH(questions) AS qcount, (scoring IS NOT NULL) AS has_scoring
FROM assessment ORDER BY id;
