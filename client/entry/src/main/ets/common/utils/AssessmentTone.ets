/**
 * 测评相关的「温度翻译层」：把后端判定词与量化值转成轻心的语气。
 * 三原则：不评判、描述状态、给可行动的温柔提示（对齐树洞 persona）。
 * 首页/结果页/记录卡共用，改这里全 App 生效。
 */

/** 后端等级词 → 温度话术（良好→平稳 / 轻度→有点起伏 / 中高→需要放慢） */
export function softLevel(level: string): string {
  if (!level || level.length === 0) {
    return '已记录'
  }
  if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
    return '状态平稳'
  }
  if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0) {
    return '有点起伏'
  }
  if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
    return '需要放慢'
  }
  return level
}

/** 情绪强度 0~10 → 描述语（去掉 X/10 的体检感） */
export function softIntensity(intensity: number): string {
  if (intensity === undefined || intensity === null) {
    return '情绪强度未知'
  }
  if (intensity <= 3) {
    return '情绪很平稳'
  }
  if (intensity <= 6) {
    return '情绪有些波动'
  }
  if (intensity <= 8) {
    return '情绪比较强烈'
  }
  return '情绪很强烈'
}

/** 后端等级词 → AppChip 语义变体（良好→success / 轻度→warning / 中高→danger） */
export function softLevelKind(level: string): string {
  if (!level || level.length === 0) {
    return 'plain'
  }
  if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
    return 'success'
  }
  if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
    return 'danger'
  }
  if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0 || level.indexOf('波动') >= 0) {
    return 'warning'
  }
  return 'plain'
}

/** 情绪名 → AppChip 语义变体（D5 映射：开心→success、平静→primary、难过/疲惫→灰、焦虑→warning、生气→danger） */
export function emotionChipKind(emotion: string): string {
  const e: string = emotion ?? ''
  if (e.indexOf('开心') >= 0) {
    return 'success'
  }
  if (e.indexOf('焦虑') >= 0) {
    return 'warning'
  }
  if (e.indexOf('生气') >= 0) {
    return 'danger'
  }
  if (e.indexOf('平静') >= 0) {
    return 'primary'
  }
  return 'plain'
}
