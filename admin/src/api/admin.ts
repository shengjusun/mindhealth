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
}

export function login(username: string, password: string): Promise<LoginResult> {
  return post<LoginResult>('/admin/login', { username, password })
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
}): Promise<PageResult<FeedbackRow>> {
  // 后端 handled 是 Integer（0/1），不能直接传布尔值
  const query: Record<string, unknown> = { page: params.page, size: params.size }
  if (params.handled !== undefined) {
    query.handled = params.handled ? 1 : 0
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
