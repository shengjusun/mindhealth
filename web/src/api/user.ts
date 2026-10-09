// AI生成
/** 用户 / 认证 / 头像 */
import { get, post, put, upload } from './http'
import type { LoginResponse, UpdateUserPayload, UserVO } from './types'

export function login(phone: string, password: string): Promise<LoginResponse> {
  return post<LoginResponse>('/user/login', { phone, password })
}

export function register(phone: string, password: string, confirmPassword: string): Promise<null> {
  return post<null>('/user/register', { phone, password, confirmPassword })
}

export function fetchUserInfo(): Promise<UserVO> {
  return get<UserVO>('/user/info')
}

export function updateUser(payload: UpdateUserPayload): Promise<UserVO> {
  return put<UserVO>('/user/update', payload)
}

/** 换绑手机号（注意：后端不校验 code） */
export function updatePhone(newPhone: string, code: string): Promise<UserVO> {
  return put<UserVO>('/user/phone', { newPhone, code })
}

/** 上传头像，返回形如 /api/uploads/avatars/{uuid}.{ext} 的路径 */
export function uploadAvatar(file: File): Promise<string> {
  return upload<string>('/user/avatar/upload', file)
}
