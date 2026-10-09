// AI生成
/**
 * 状态测评。
 * 注意：后端多个 data 是「JSON 字符串」，这里统一 parse 成结构体，
 * 视图层不接触字符串；算分与等级判定完全由服务端负责，前端只消费。
 */
import { get, post } from './http'
import type { AnswerItem, Assessment, AssessmentManifest, AssessmentPaper, AssessmentResult } from './types'
import { parseJson } from '../utils/format'

const EMPTY_MANIFEST: AssessmentManifest = { version: '', updatedAt: '', scales: [] }

/** 测评清单（含题量与版本，用于列表页） */
export async function fetchManifest(): Promise<AssessmentManifest> {
  const raw = await get<unknown>('/assessment/manifest')
  return parseJson<AssessmentManifest>(raw, EMPTY_MANIFEST)
}

/** 原始量表表（一般不用，留作兜底） */
export function listAssessments(): Promise<Assessment[]> {
  return get<Assessment[]>('/assessment/list')
}

/** 取一份可作答的完整试卷（题目 + 选项已解析） */
export async function fetchPaper(id: number): Promise<AssessmentPaper> {
  const raw = await get<unknown>(`/assessment/${id}/questions`)
  return parseJson<AssessmentPaper>(raw, {
    id,
    name: '',
    type: '',
    description: '',
    version: '',
    maxScore: 100,
    scoring: null,
    questions: [],
  })
}

/** 提交答卷（不传 score，服务端按题库重算） */
export function submitAssessment(assessmentId: number, answers: AnswerItem[]): Promise<AssessmentResult> {
  return post<AssessmentResult>('/assessment/submit', { assessmentId, answers })
}

/** 我的测评记录 */
export function fetchResults(): Promise<AssessmentResult[]> {
  return get<AssessmentResult[]>('/assessment/results')
}

/** 单条记录（AI 分析轮询用） */
export function fetchResult(id: number): Promise<AssessmentResult> {
  return get<AssessmentResult>(`/assessment/result/${id}`)
}

/** 重新触发 AI 分析 */
export function analyzeResult(id: number): Promise<boolean> {
  return post<boolean>(`/assessment/result/${id}/analyze`)
}
