// AI生成
/**
 * 树洞 AI 陪伴聊天。
 * 后端限流：每用户 10 次/分钟，超限返回 code 400「请求过于频繁，请稍后再试」。
 */
import { get, post, remove } from './http'
import type { AIChat, AiChatResponse } from './types'

export function chat(content: string): Promise<AiChatResponse> {
  return post<AiChatResponse>('/ai/chat', { content })
}

export function fetchChatHistory(): Promise<AIChat[]> {
  return get<AIChat[]>('/ai/history')
}

export function clearChatHistory(): Promise<boolean> {
  return remove<boolean>('/ai/history')
}
