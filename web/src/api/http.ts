// AI生成
/**
 * HTTP 客户端（移植自 admin/src/api/http.ts，按 C 端场景调整）。
 *
 * 与 admin 的差异：
 * 1) 提示用自研 toast（不依赖 Element Plus）；toast 是独立 reactive 单例，无循环依赖。
 * 2) 401/403 → 清会话 + 跳登录（带 redirect）。token 过期本期不实现刷新，仅预留钩子。
 * 3) 增加 upload() 处理 multipart（头像上传）。
 */
import axios, { type AxiosInstance, type AxiosResponse } from 'axios'
import { clearSession, getToken } from '../utils/session'
import { toast } from '../utils/toast'
import type { ApiEnvelope } from './types'

const http: AxiosInstance = axios.create({
  baseURL: '/api',
  timeout: 15000,
})

http.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

/** token 过期刷新钩子：本期不实现，留位以便后续接入 refreshToken */
export type RefreshHandler = () => Promise<boolean>
let refreshHandler: RefreshHandler | null = null
export function setRefreshHandler(handler: RefreshHandler | null): void {
  refreshHandler = handler
}

async function sessionExpired(status: number): Promise<void> {
  const { default: router } = await import('../router')
  const current = router.currentRoute.value

  // 登录/注册页本身没有登录态，这里的 401/403 是请求被后端拒绝，如实报状态码即可
  if (current.path === '/login' || current.path === '/register') {
    toast.error(`请求被拒绝（HTTP ${status}），请确认后端服务已启动并包含最新代码`)
    return
  }

  clearSession()
  toast.error('登录已失效，请重新登录')
  void router.replace({ path: '/login', query: { redirect: current.fullPath } })
}

function unwrap<T>(body: ApiEnvelope<T>): T {
  return body.data
}

http.interceptors.response.use(
  (response: AxiosResponse) => {
    const body = response.data as ApiEnvelope<unknown> | undefined
    if (body && typeof body === 'object' && typeof body.code === 'number') {
      if (body.code === 200) {
        return unwrap(body) as unknown as AxiosResponse
      }
      if (body.code === 401) {
        void sessionExpired(401)
        return Promise.reject(new Error(body.message || '登录已失效'))
      }
      // 业务错误：HTTP 200 + body.code != 200，统一弹提示
      toast.error(body.message || '请求失败')
      return Promise.reject(new Error(body.message || '请求失败'))
    }
    return response.data
  },
  async (error) => {
    const status = error?.response?.status
    if (status === 401 || status === 403) {
      if (refreshHandler) {
        const ok = await refreshHandler().catch(() => false)
        if (ok) {
          return http.request(error.config)
        }
      }
      await sessionExpired(status)
    } else if (error?.code === 'ECONNABORTED') {
      toast.error('请求超时，请确认后端服务是否已启动')
    } else {
      toast.error(error?.response?.data?.message || '网络异常，请稍后重试')
    }
    return Promise.reject(error)
  },
)

export function get<T>(url: string, params?: Record<string, unknown>): Promise<T> {
  return http.get(url, { params }) as unknown as Promise<T>
}

export function post<T>(url: string, data?: unknown): Promise<T> {
  return http.post(url, data) as unknown as Promise<T>
}

export function put<T>(url: string, data?: unknown, params?: Record<string, unknown>): Promise<T> {
  return http.put(url, data, { params }) as unknown as Promise<T>
}

export function remove<T>(url: string): Promise<T> {
  return http.delete(url) as unknown as Promise<T>
}

/** 文件上传（头像等）。返回后端 data（通常是访问路径字符串） */
export function upload<T>(url: string, file: File, field = 'file'): Promise<T> {
  const form = new FormData()
  form.append(field, file)
  return http.post(url, form, {
    headers: { 'Content-Type': 'multipart/form-data' },
    timeout: 30000,
  }) as unknown as Promise<T>
}

export default http
