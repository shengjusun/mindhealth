// AI生成
/**
 * 展示格式化 + 情绪/等级「温度翻译层」。
 * 翻译层与客户端 AssessmentTone 对齐：不评判、描述状态、给温柔提示。
 */

/** 日记情绪枚举（与客户端 DiaryEditPage 一致，默认「平静」） */
export const EMOTIONS = ['开心', '平静', '焦虑', '难过', '生气', '疲惫'] as const
export type Emotion = (typeof EMOTIONS)[number]

const EMOTION_EMOJI: Record<string, string> = {
  开心: '😊',
  平静: '😌',
  焦虑: '😰',
  难过: '😔',
  生气: '😠',
  疲惫: '😪',
}

export function emotionEmoji(emotion: string): string {
  return EMOTION_EMOJI[emotion] ?? '🙂'
}

/** 情绪名 → 标签语义色（开心→success、焦虑→warning、生气→danger、平静→primary、其余→plain） */
export function emotionKind(emotion: string): 'success' | 'warning' | 'danger' | 'primary' | 'plain' {
  const e = emotion ?? ''
  if (e.includes('开心')) return 'success'
  if (e.includes('焦虑')) return 'warning'
  if (e.includes('生气')) return 'danger'
  if (e.includes('平静')) return 'primary'
  return 'plain'
}

/** 情绪强度 0~10 → 描述语 */
export function softIntensity(intensity?: number | null): string {
  if (intensity === undefined || intensity === null) return '情绪强度未知'
  if (intensity <= 3) return '情绪很平稳'
  if (intensity <= 6) return '情绪有些波动'
  if (intensity <= 8) return '情绪比较强烈'
  return '情绪很强烈'
}

/** 后端等级词 → 温度话术 */
export function softLevel(level: string): string {
  if (!level) return '已记录'
  if (level.includes('良好') || level.includes('稳定')) return '状态平稳'
  if (level.includes('轻度') || level.includes('起伏')) return '有点起伏'
  if (level.includes('中度') || level.includes('较高') || level.includes('明显')) return '需要放慢'
  return level
}

/** 后端等级词 → 标签语义色 */
export function softLevelKind(level: string): 'success' | 'warning' | 'danger' | 'plain' {
  if (!level) return 'plain'
  if (level.includes('良好') || level.includes('稳定')) return 'success'
  if (level.includes('中度') || level.includes('较高') || level.includes('明显')) return 'danger'
  if (level.includes('轻度') || level.includes('起伏') || level.includes('波动')) return 'warning'
  return 'plain'
}

/** 风险等级 → 中文标签 */
export function riskLabel(risk: string): string {
  if (risk === 'high') return '需要关注'
  if (risk === 'medium') return '建议留意'
  return '状态良好'
}

// ---------------------------------------------------------------- 时间

/** 后端时间串形如 2026-09-29T10:00:00（无时区本地时间），直接解析即可，不要按 UTC 处理 */
function toDate(value?: string | null): Date | null {
  if (!value) return null
  const normalized = value.replace(' ', 'T')
  const d = new Date(normalized)
  return Number.isNaN(d.getTime()) ? null : d
}

function pad(n: number): string {
  return n < 10 ? `0${n}` : `${n}`
}

/** 2026-09-29 10:00 */
export function formatDateTime(value?: string | null): string {
  const d = toDate(value)
  if (!d) return ''
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/** 2026-09-29 */
export function formatDate(value?: string | null): string {
  const d = toDate(value)
  if (!d) return ''
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

/** 09-29 10:00 */
export function formatShort(value?: string | null): string {
  const d = toDate(value)
  if (!d) return ''
  return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/** 相对时间：刚刚 / 5 分钟前 / 昨天 10:00 / 09-29 10:00 */
export function fromNow(value?: string | null): string {
  const d = toDate(value)
  if (!d) return ''
  const diff = Date.now() - d.getTime()
  if (diff < 60_000) return '刚刚'
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)} 分钟前`
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)} 小时前`
  const today = new Date()
  const isYesterday =
    d.getFullYear() === today.getFullYear() &&
    d.getMonth() === today.getMonth() &&
    today.getDate() - d.getDate() === 1
  if (isYesterday) return `昨天 ${pad(d.getHours())}:${pad(d.getMinutes())}`
  return formatDateTime(value)
}

/** 按空行切段（文章正文是纯文本，不做 markdown / v-html 渲染） */
export function toParagraphs(text?: string | null): string[] {
  if (!text) return []
  return text
    .split(/\n\s*\n/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0)
}

/** 安全解析 JSON 字符串（后端多个字段是 JSON 串），失败返回 fallback */
export function parseJson<T>(raw: unknown, fallback: T): T {
  if (raw === null || raw === undefined || raw === '') return fallback
  if (typeof raw === 'object') return raw as T
  if (typeof raw !== 'string') return fallback
  try {
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}
