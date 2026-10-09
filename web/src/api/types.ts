// AI生成
/**
 * 后端数据契约（严格对齐 backend 控制器实测形态，勿凭印象改）。
 * 多数接口信封为 ApiResponse{code,message,data}；
 * /user/info、/user/update、/user/phone、/user/avatar/upload 为 Result{...,timestamp}。
 * 但两者都含 code/message/data，拦截器按同一套规则归一化。
 */

export interface ApiEnvelope<T> {
  code: number
  message: string
  data: T
}

/* ------------------------------------------------------------------ 用户 */

export interface UserInfo {
  id: number
  phone: string
  nickname: string
  avatar: string
}

export interface LoginResponse {
  token: string
  refreshToken: string
  userInfo: UserInfo
}

export interface UserVO {
  id: number
  phone: string
  nickname: string
  age: number | null
  gender: 'male' | 'female' | 'hidden' | null
  avatar: string
  signature: string
  createTime: string
}

export interface UpdateUserPayload {
  nickname?: string
  age?: number | null
  gender?: 'male' | 'female' | 'hidden'
  avatar?: string
  signature?: string
}

/* ------------------------------------------------------------------ 日记 */

export interface Diary {
  id: number
  userId?: number
  title: string
  content: string
  emotion: string
  intensity: number
  event: string
  createTime: string
  updateTime?: string
}

export interface DiaryPayload {
  title: string
  content: string
  emotion: string
  intensity: number
  event?: string
}

/* ------------------------------------------------------------------ 文章 */

export interface ArticleVO {
  id: number
  title: string
  summary: string
  content: string
  category: string
  cover: string
  author: string
  createTime: string
  updateTime: string
}

/* ------------------------------------------------------------------ 测评 */

export interface AssessmentOption {
  key: string
  text: string
  score: number
}

export interface AssessmentQuestion {
  id: string
  title: string
  options: AssessmentOption[]
}

export interface Assessment {
  id: number
  name: string
  description: string
  type: string
  /** JSON 字符串，需 parse */
  questions: string
  /** JSON 字符串，需 parse */
  scoring: string
  createTime: string
  updateTime: string
}

export interface AssessmentPaper {
  id: number
  name: string
  type: string
  description: string
  version: string
  maxScore: number
  scoring: unknown
  questions: AssessmentQuestion[]
}

export interface ManifestScale {
  id: number
  name: string
  type: string
  description: string
  questionCount: number
  maxScore: number
  version: string
}

export interface AssessmentManifest {
  version: string
  updatedAt: string
  scales: ManifestScale[]
}

export type AiStatus = 'none' | 'pending' | 'success' | 'failed'

export interface AssessmentResult {
  id: number
  userId: number
  assessmentId: number
  assessmentTitle: string
  score: number
  maxScore: number
  level: string
  suggestion: string
  /** JSON 字符串 | null */
  answersJson: string | null
  aiStatus: AiStatus
  /** JSON 字符串 | null */
  aiAnalysis: string | null
  aiError: string | null
  createTime: string
}

export interface AnswerItem {
  questionId: string
  optionKey: string
}

export interface AiDimension {
  name: string
  level: string
  comment: string
}

export interface AiSuggestion {
  title: string
  detail: string
}

export interface AiAnalysis {
  summary: string
  trend: string
  riskLevel: 'low' | 'medium' | 'high'
  needProfessionalHelp: boolean
  dimensions: AiDimension[]
  suggestions: AiSuggestion[]
  model: string
  generatedAt: string
}

/* ------------------------------------------------------------------ AI 树洞 */

export interface AIChat {
  id: number
  userId: number
  content: string
  aiResponse: string
  createTime: string
}

export interface AiChatResponse {
  response: string
}

/* ------------------------------------------------------------------ 反馈 */

export type FeedbackType = 'bug' | 'suggestion' | 'other'

export interface FeedbackPayload {
  content: string
  type?: FeedbackType
  contact?: string
}
