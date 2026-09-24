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
  return get<PageResult<FeedbackRow>>('/admin/feedbacks', params as unknown as Record<string, unknown>)
}

export function handleFeedback(id: number): Promise<unknown> {
  return put(`/admin/feedbacks/${id}/handle`)
}

export function deleteFeedback(id: number): Promise<unknown> {
  return remove(`/admin/feedbacks/${id}`)
}