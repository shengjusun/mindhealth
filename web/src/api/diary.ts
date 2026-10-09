// AI生成
/** 情绪日记 */
import { get, post, put, remove } from './http'
import type { Diary, DiaryPayload } from './types'

export function createDiary(payload: DiaryPayload): Promise<Diary> {
  return post<Diary>('/diary', payload)
}

export function updateDiary(id: number, payload: DiaryPayload): Promise<Diary> {
  return put<Diary>(`/diary/${id}`, payload)
}

export function deleteDiary(id: number): Promise<null> {
  return remove<null>(`/diary/${id}`)
}

export function getDiary(id: number): Promise<Diary> {
  return get<Diary>(`/diary/${id}`)
}

export function listDiaries(): Promise<Diary[]> {
  return get<Diary[]>('/diary')
}
