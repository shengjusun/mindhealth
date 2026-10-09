// AI生成
/**
 * 轻量全局提示（toast）。
 *
 * 刻意不放进 Pinia：http 拦截器需要 import 它，若它反过来 import router/store
 * 会形成循环依赖。用独立 reactive 单例最干净。
 */
import { reactive } from 'vue'

export type ToastKind = 'success' | 'error' | 'info' | 'warning'

export interface ToastItem {
  id: number
  kind: ToastKind
  message: string
}

let seed = 0

export const toasts = reactive<ToastItem[]>([])

export function pushToast(kind: ToastKind, message: string, duration = 2800): void {
  const id = ++seed
  toasts.push({ id, kind, message })
  window.setTimeout(() => dismissToast(id), duration)
}

export function dismissToast(id: number): void {
  const index = toasts.findIndex((t) => t.id === id)
  if (index >= 0) {
    toasts.splice(index, 1)
  }
}

export const toast = {
  success: (message: string) => pushToast('success', message),
  error: (message: string) => pushToast('error', message),
  warning: (message: string) => pushToast('warning', message),
  info: (message: string) => pushToast('info', message),
}
