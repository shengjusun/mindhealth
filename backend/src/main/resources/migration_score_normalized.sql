-- 评分机制重构：0-100 状态分（越高越健康）
-- 症状量表（1-5）极性反转：积极选项得高分；正向量表（6）直接归一
-- bands 阈值迁移到 0-100（25/50/75/100），历史结果行同步归一并重映射档位
USE mindhealth;

UPDATE assessment SET scoring = '{"polarity":"symptom","bands":[{"max":25,"level":"明显困扰","suggestion":"最近一周你的情绪困扰程度较高。请优先照顾好自己的休息与饮食，并尽快联系可信任的人或专业心理支持；如果出现伤害自己的念头，请立即拨打心理援助热线。"},{"max":50,"level":"中度困扰","suggestion":"最近一周情绪困扰比较明显，已经影响到日常生活。建议主动减少不必要的消耗，多和信任的人聊一聊，必要时预约一次心理咨询。"},{"max":75,"level":"轻度波动","suggestion":"最近一周你的情绪出现了轻度波动，可能和作息、压力或具体事件有关。建议先保证睡眠和运动，并把情绪记进日记，观察哪些情境容易触发。"},{"max":100,"level":"状态平稳","suggestion":"最近一周你的情绪整体平稳，没有明显困扰。可以继续保持规律的作息和记录习惯，这会帮你更早察觉情绪变化。"}]}' WHERE id = 1;
UPDATE assessment SET scoring = '{"polarity":"symptom","bands":[{"max":25,"level":"压力过载","suggestion":"最近一周你的压力已接近或超出承受范围。请优先减负而不是硬撑，尽快向身边人求助；如果身体出现明显不适，建议同时就医排查。"},{"max":50,"level":"压力偏高","suggestion":"最近一周压力已经比较明显，可能伴随睡眠或情绪变化。建议主动和上级、家人沟通调整任务量，并安排一次真正断开的休息。"},{"max":75,"level":"轻度压力","suggestion":"最近一周你有一些压力积累。建议把任务按优先级拆小，先完成最要紧的一件；每天留 20 分钟不被打扰的放松时间。"},{"max":100,"level":"压力较低","suggestion":"最近一周你承受的压力在可应对范围内。可以继续保持现有的节奏，同时留一点固定的放松时间作为缓冲。"}]}' WHERE id = 2;
UPDATE assessment SET scoring = '{"polarity":"symptom","bands":[{"max":25,"level":"焦虑明显","suggestion":"最近一周你的焦虑程度较高，若伴随明显的躯体症状（心悸、胸闷、呼吸困难），建议先就医排除身体原因，同时寻求专业心理支持。"},{"max":50,"level":"焦虑偏高","suggestion":"最近一周焦虑反应比较明显，可能已经影响工作或睡眠。建议规律作息、减少咖啡因，并把焦虑的具体内容和频率记录下来，这会是咨询时很有用的材料。"},{"max":75,"level":"轻度焦虑","suggestion":"最近一周你有一些焦虑反应。建议减少睡前的信息刺激，把担心的事写在纸上而不是反复在脑中过；如果某个场合让你回避，尝试先短时间暴露而不是完全躲开。"},{"max":100,"level":"焦虑不明显","suggestion":"最近一周你的紧张感在常见范围内。可以在容易紧张的时刻试几次缓慢的腹式呼吸（吸 4 秒、呼 6 秒），作为日常调节手段。"}]}' WHERE id = 3;
UPDATE assessment SET scoring = '{"polarity":"symptom","bands":[{"max":25,"level":"低落较重","suggestion":"最近一周你的低落程度较高。请把「尽快寻求专业帮助」放在第一位，同时联系可信任的人陪伴自己。如果出现伤害自己的想法，请立即拨打心理援助热线或前往医院急诊。"},{"max":50,"level":"低落较明显","suggestion":"最近一周低落情绪比较明显，且可能已影响到兴趣或精力。建议尽快和信任的人谈一谈，并预约专业心理咨询做一次系统评估。"},{"max":75,"level":"轻度低落","suggestion":"最近一周你出现了轻度情绪低落。建议先从最容易改变的一件事入手（比如固定起床时间、每天出门走 20 分钟），并把感受写进日记，观察一周的变化。"},{"max":100,"level":"情绪较稳定","suggestion":"最近一周你的情绪比较稳定。继续保持规律作息、适度运动和与人保持联系，这些是预防情绪下滑最有效的日常习惯。"}]}' WHERE id = 4;
UPDATE assessment SET scoring = '{"polarity":"symptom","bands":[{"max":25,"level":"睡眠质量较差","suggestion":"最近一周你的睡眠质量较差。长期睡眠不足会明显加重情绪问题，建议尽快就医排查（如睡眠呼吸问题、焦虑抑郁相关的失眠），不建议自行长期使用助眠药物。"},{"max":50,"level":"睡眠问题明显","suggestion":"最近一周睡眠问题比较明显，且可能已经影响情绪和白天状态。建议连续记录一周的入睡/醒来时间，找出规律后再调整；如果持续超过三周，建议就医评估。"},{"max":75,"level":"轻度睡眠问题","suggestion":"最近一周你的睡眠出现了一些问题。睡前 1 小时建议离开屏幕、把担心的事写下来留到第二天；白天补觉控制在 20 分钟以内，避免打乱夜间睡意。"},{"max":100,"level":"睡眠良好","suggestion":"最近一周你的睡眠质量不错。建议固定起床时间（比固定入睡时间更有效），并把卧室的光线和温度保持稳定，帮助维持现在的状态。"}]}' WHERE id = 5;
UPDATE assessment SET scoring = '{"polarity":"positive","bands":[{"max":25,"level":"韧性偏弱","suggestion":"目前你在面对挫折时较容易感到吃力，这通常和近期的疲惫或支持不足有关，而不是你的能力问题。建议先从「保证睡眠 + 找到 1 个可以倾诉的人」这两件事开始。"},{"max":50,"level":"韧性中等","suggestion":"你有一定的恢复能力，但在压力集中时容易被打乱节奏。可以刻意练习把大问题拆成今天就能完成的一小步，并及时记录已经解决掉的事，强化「我能处理」的经验。"},{"max":75,"level":"韧性较好","suggestion":"你面对困难时整体能保持稳定并找到办法。可以进一步发挥这项优势：把有效的应对方式写下来形成自己的清单，在状态差的时候直接照着做。"},{"max":100,"level":"韧性良好","suggestion":"你在面对挫折和变化时恢复能力很强。留意不要让「我扛得住」变成长期独自硬撑——主动求助本身也是韧性的表现。"}]}' WHERE id = 6;

-- 历史结果行：分数归一到 0-100
UPDATE assessment_result r JOIN assessment a ON a.id = r.assessment_id
SET r.score = IF(JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.polarity')) = 'positive',
                 ROUND(100 * r.score / GREATEST(r.max_score,1)),
                 100 - ROUND(100 * r.score / GREATEST(r.max_score,1))),
    r.max_score = 100
WHERE r.max_score > 0;

-- 历史结果行：按新 bands 重映射档位与建议
UPDATE assessment_result r JOIN assessment a ON a.id = r.assessment_id
SET r.level = CASE
        WHEN r.score <= 25 THEN JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[0].level'))
        WHEN r.score <= 50 THEN JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[1].level'))
        WHEN r.score <= 75 THEN JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[2].level'))
        ELSE JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[3].level')) END,
    r.suggestion = CASE
        WHEN r.score <= 25 THEN JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[0].suggestion'))
        WHEN r.score <= 50 THEN JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[1].suggestion'))
        WHEN r.score <= 75 THEN JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[2].suggestion'))
        ELSE JSON_UNQUOTE(JSON_EXTRACT(a.scoring,'$.bands[3].suggestion')) END;

-- 验证
SELECT id, assessment_id, score, max_score, level FROM assessment_result ORDER BY id DESC LIMIT 5;
