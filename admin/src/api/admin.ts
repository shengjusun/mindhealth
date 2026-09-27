import { get, post, put, remove } from './http'

export interface AdminStats {
  userCount: number
  diaryCount: number
  assessmentResultCount: number
  feedbackUnhandled: number
  feedbackTotal: number
}

export interface AdminUser {
  id: number
  phone: string | null
  nickname: string
  gender: string | null
  age: number | null
  avatar: string | null
  isHuaweiUser: boolean
  deleted: number
  /** 该用户已写日记数（仅列表接口返回） */
  diaryCount?: number
  createTime: string
}

export interface DiaryRow {
  id: number
  userId: number
  author: string
  title: string
  content: string
  emotion: string
  intensity: number | null
  createTime: string
}

export interface AssessmentRow {
  id: number
  name: string
  type: string
  description: string
  questions: string
  createTime: string
  updateTime: string
}

export interface FeedbackRow {
  id: number
  userId: number
  author: string
  type: string
  content: string
  contact: string | null
  isHandled: boolean
  handledTime: string | null
  createTime: string
}

export interface PageResult<T> {
  total: number
  records: T[]
}

export interface LoginResult {
  token: string
  username: string
  role?: string
  /** 该账号从未改过初始密码（create_time == update_time） */
  pwdNeverChanged?: boolean
}

export interface CaptchaResult {
  captchaId: string
  code: string
  expireSeconds: number
}

/**
 * 获取图形验证码。
 * 字符明文返回是为了前端用 DOM 逐字符渲染（倾斜/变色/干扰线）；
 * 真正的校验在后端，前端只是显示层。
 */
export function fetchCaptcha(): Promise<CaptchaResult> {
  return get<CaptchaResult>('/admin/captcha')
}

/**
 * 登录。失败过一次后必须带上验证码 —— 后端会独立校验，
 * 不带或带错都会直接被拒，所以这里不能省。
 */
export function login(
  username: string,
  password: string,
  captcha?: { captchaId: string; captchaCode: string },
): Promise<LoginResult> {
  return post<LoginResult>('/admin/login', {
    username,
    password,
    captchaId: captcha?.captchaId,
    captchaCode: captcha?.captchaCode,
  })
}

export function fetchStats(): Promise<AdminStats> {
  return get<AdminStats>('/admin/stats')
}

export function fetchUsers(params: {
  page: number
  size: number
  keyword?: string
}): Promise<PageResult<AdminUser>> {
  return get<PageResult<AdminUser>>('/admin/users', params as unknown as Record<string, unknown>)
}

export function addUser(data: Record<string, unknown>): Promise<unknown> {
  return post('/admin/users', data)
}

export function updateUser(id: number, data: Record<string, unknown>): Promise<unknown> {
  return put(`/admin/users/${id}`, data)
}

export function setUserStatus(id: number, deleted: number): Promise<unknown> {
  return put(`/admin/users/${id}/status`, undefined, { deleted })
}

export function resetUserPassword(id: number, password: string): Promise<unknown> {
  return put(`/admin/users/${id}/password`, { password })
}

export function deleteUser(id: number): Promise<unknown> {
  return remove(`/admin/users/${id}`)
}

export function fetchDiaries(params: {
  page: number
  size: number
  keyword?: string
  /** 指定用户；不传则为全站视图（管理端界面不再使用，保留给排查场景） */
  userId?: number
}): Promise<PageResult<DiaryRow>> {
  return get<PageResult<DiaryRow>>('/admin/diaries', params as unknown as Record<string, unknown>)
}

export function deleteDiary(id: number): Promise<unknown> {
  return remove(`/admin/diaries/${id}`)
}

export function fetchAssessments(): Promise<AssessmentRow[]> {
  return get<AssessmentRow[]>('/admin/assessments')
}

export function addAssessment(data: Record<string, unknown>): Promise<unknown> {
  return post('/admin/assessments', data)
}

export function updateAssessment(id: number, data: Record<string, unknown>): Promise<unknown> {
  return put(`/admin/assessments/${id}`, data)
}

export function deleteAssessment(id: number): Promise<unknown> {
  return remove(`/admin/assessments/${id}`)
}

export function fetchFeedbacks(params: {
  page: number
  size: number
  handled?: boolean
  /** 匹配内容 / 联系方式 / 类型 */
  keyword?: string
}): Promise<PageResult<FeedbackRow>> {
  // 后端 handled 是 Integer（0/1），不能直接传布尔值
  const query: Record<string, unknown> = { page: params.page, size: params.size }
  if (params.handled !== undefined) {
    query.handled = params.handled ? 1 : 0
  }
  if (params.keyword) {
    query.keyword = params.keyword
  }
  return get<PageResult<FeedbackRow>>('/admin/feedbacks', query)
}

export function handleFeedback(id: number): Promise<unknown> {
  return put(`/admin/feedbacks/${id}/handle`)
}

export function deleteFeedback(id: number): Promise<unknown> {
  return remove(`/admin/feedbacks/${id}`)
}

export interface AdminProfile {
  id: number
  username: string
  role: string | null
  createTime: string | null
}

export function fetchProfile(): Promise<AdminProfile> {
  return get<AdminProfile>('/admin/profile')
}

export function changePassword(oldPassword: string, newPassword: string): Promise<unknown> {
  return put('/admin/password', { oldPassword, newPassword })
}

/* ===== 仪表盘统计 ===== */

export interface TrendData {
  labels: string[]
  users: number[]
  diaries: number[]
  feedbacks: number[]
}

export interface DistributionItem {
  name: string
  value: number
}

export function fetchTrend(days = 14): Promise<TrendData> {
  return get<TrendData>('/admin/stats/trend', { days })
}

export function fetchEmotionDistribution(): Promise<DistributionItem[]> {
  return get<DistributionItem[]>('/admin/stats/emotion')
}

export function fetchFeedbackTypes(): Promise<DistributionItem[]> {
  return get<DistributionItem[]>('/admin/stats/feedback-types')
}

/* ===== 用户详情 ===== */

export interface UserDetail {
  user: AdminUser & { signature: string | null; updateTime: string | null }
  diaryCount: number
  feedbackCount: number
  assessmentCount: number
  chatCount: number
  recentDiaries: Array<{
    id: number
    title: string
    emotion: string | null
    intensity: number | null
    createTime: string
  }>
  assessmentResults: Array<{
    id: number
    title: string | null
    score: number | null
    level: string | null
    createTime: string
  }>
}

export function fetchUserDetail(id: number): Promise<UserDetail> {
  return get<UserDetail>(`/admin/users/${id}/detail`)
}

/* ===== 批量操作 ===== */

export type BatchType = 'user' | 'diary' | 'feedback'
export type BatchAction = 'delete' | 'enable' | 'disable' | 'handle'

export function batchOperate(
  type: BatchType,
  action: BatchAction,
  ids: number[],
): Promise<{ affected: number }> {
  return post<{ affected: number }>('/admin/batch', { type, action, ids })
}

/* ===== 管理员账号管理（仅 SUPER_ADMIN 可用，后端 SecurityConfig 已限定） ===== */

export type AdminRole = 'SUPER_ADMIN' | 'ADMIN'

export interface AdminAccount {
  id: number
  username: string
  role: AdminRole | string
  createTime: string | null
  updateTime: string | null
}

export function fetchAdmins(): Promise<AdminAccount[]> {
  return get<AdminAccount[]>('/admin/accounts')
}

export function createAdmin(data: {
  username: string
  password: string
  role: AdminRole
}): Promise<unknown> {
  return post('/admin/accounts', data)
}

/** 重置指定管理员的密码；不需要旧密码 */
export function resetAdminPassword(id: number, newPassword: string): Promise<unknown> {
  return put(`/admin/accounts/${id}/password`, { newPassword })
}

export function changeAdminRole(id: number, role: AdminRole): Promise<unknown> {
  return put(`/admin/accounts/${id}/role`, { role })
}

export function deleteAdmin(id: number): Promise<unknown> {
  return remove(`/admin/accounts/${id}`)
}

/* ===== 测评结果明细 ===== */

export interface AssessmentAnswerDetail {
  questionId: number
  title: string
  optionKey: string | null
  optionText: string | null
  score: number
  maxScore: number
}

export interface AssessmentAiAnalysis {
  summary?: string
  trend?: string
  riskLevel?: string
  needProfessionalHelp?: boolean
  dimensions?: Array<{ name?: string; level?: string; comment?: string }>
  suggestions?: Array<{ title?: string; detail?: string }>
  model?: string
  generatedAt?: string
}

export interface AssessmentResultRow {
  id: number
  userId: number
  author: string
  assessmentId: number
  assessmentTitle: string
  score: number | null
  maxScore: number | null
  level: string | null
  suggestion: string | null
  /** 逐题作答 JSON 字符串 */
  answersJson: string | null
  /** none / pending / success / failed */
  aiStatus: string | null
  aiAnalysis: string | null
  aiError: string | null
  createTime: string
}

export function fetchAssessmentResults(params: {
  page: number
  size: number
  userId?: number
  keyword?: string
}): Promise<PageResult<AssessmentResultRow>> {
  return get<PageResult<AssessmentResultRow>>(
    '/admin/assessment-results',
    params as unknown as Record<string, unknown>,
  )
}

/* ===== 管理员操作日志（后端限定 SUPER_ADMIN 可读） ===== */

export interface OperationLog {
  id: number
  adminId: number | null
  adminUsername: string | null
  method: string
  path: string
  action: string | null
  target: string | null
  ip: string | null
  status: number | null
  durationMs: number | null
  createTime: string
}

export function fetchOperationLogs(params: {
  page: number
  size: number
  keyword?: string
  adminId?: number
}): Promise<PageResult<OperationLog>> {
  return get<PageResult<OperationLog>>('/admin/logs', params as unknown as Record<string, unknown>)
}
