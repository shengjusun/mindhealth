// AI生成
/**
 * 会话持久化：只负责 localStorage 的读写原语。
 * 内存中的登录态由 stores/auth.ts 持有，这里不掺和响应式。
 */
import type { UserInfo } from '../api/types'

const K_TOKEN = 'lk_token'
const K_REFRESH = 'lk_refresh_token'
const K_USER = 'lk_user'

function read(key: string): string {
  try {
    return localStorage.getItem(key) ?? ''
  } catch {
    return ''
  }
}

function write(key: string, value: string): void {
  try {
    localStorage.setItem(key, value)
  } catch {
    /* 隐私模式等场景静默降级 */
  }
}

function drop(key: string): void {
  try {
    localStorage.removeItem(key)
  } catch {
    /* ignore */
  }
}

export function getToken(): string {
  return read(K_TOKEN)
}

export function getRefreshToken(): string {
  return read(K_REFRESH)
}

export function getUser(): UserInfo | null {
  const raw = read(K_USER)
  if (!raw) {
    return null
  }
  try {
    return JSON.parse(raw) as UserInfo
  } catch {
    return null
  }
}

export function setSession(token: string, refreshToken: string, user: UserInfo): void {
  write(K_TOKEN, token)
  write(K_REFRESH, refreshToken)
  write(K_USER, JSON.stringify(user))
}

export function setUser(user: UserInfo): void {
  write(K_USER, JSON.stringify(user))
}

export function clearSession(): void {
  drop(K_TOKEN)
  drop(K_REFRESH)
  drop(K_USER)
}
