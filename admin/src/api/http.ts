import axios, { type AxiosInstance, type AxiosResponse } from 'axios'
import { ElMessage } from 'element-plus'
import { clearAuth, getToken } from '../auth'

interface ApiEnvelope<T> {
  code: number
  message: string
  data: T
}

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

async function sessionExpired(message: string): Promise<void> {
  clearAuth()
  ElMessage.error(message)
  const { router } = await import('../router')
  const current = router.currentRoute.value
  if (current.path !== '/login') {
    router.replace({ path: '/login', query: { redirect: current.fullPath } })
  }
}

http.interceptors.response.use(
  (response: AxiosResponse) => {
    const body = response.data as ApiEnvelope<unknown> | undefined
    if (body && typeof body === 'object' && typeof body.code === 'number') {
      if (body.code === 200) {
        return body.data as unknown as AxiosResponse
      }
      if (body.code === 401) {
        void sessionExpired('登录已失效，请重新登录')
        return Promise.reject(new Error(body.message || '登录已失效'))
      }
      ElMessage.error(body.message || '请求失败')
      return Promise.reject(new Error(body.message || '请求失败'))
    }
    return response.data
  },
  async (error) => {
    const status = error?.response?.status
    // 当前后端未配置 AuthenticationEntryPoint，令牌失效返回 403；两种都按会话失效处理
    if (status === 401 || status === 403) {
      await sessionExpired('登录已失效，请重新登录')
    } else if (error?.code === 'ECONNABORTED') {
      ElMessage.error('请求超时，请确认后端服务是否已启动')
    } else {
      ElMessage.error(error?.response?.data?.message || '网络异常，请稍后重试')
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
