// AI生成
/** 意见反馈 */
import { post } from './http'
import type { FeedbackPayload } from './types'

export function submitFeedback(payload: FeedbackPayload): Promise<boolean> {
  return post<boolean>('/feedback', payload)
}
