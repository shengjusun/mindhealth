import { ref } from 'vue'

const TOKEN_KEY = 'admin_token'
const NAME_KEY = 'admin_name'
const ROLE_KEY = 'admin_role'
const PWD_FLAG_KEY = 'admin_pwd_never_changed'

/**
 * 「从未改过初始密码」标记。
 * 用 ref 而不是每次读 localStorage，是为了改密后顶部提示条能立刻消失。
 */
const pwdNeverChanged = ref(localStorage.getItem(PWD_FLAG_KEY) === '1')

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function getAdminName(): string {
  return localStorage.getItem(NAME_KEY) || ''
}

export function getAdminRole(): string {
  return localStorage.getItem(ROLE_KEY) || ''
}

export function setAuth(
  token: string,
  name: string,
  role?: string,
  neverChangedPassword?: boolean,
): void {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(NAME_KEY, name)
  if (role) {
    localStorage.setItem(ROLE_KEY, role)
  } else {
    localStorage.removeItem(ROLE_KEY)
  }

  pwdNeverChanged.value = neverChangedPassword === true
  if (pwdNeverChanged.value) {
    localStorage.setItem(PWD_FLAG_KEY, '1')
  } else {
    localStorage.removeItem(PWD_FLAG_KEY)
  }
}

/** 账号是否从未改过初始密码，用于登录后提示尽快改密 */
export function isPasswordNeverChanged(): boolean {
  return pwdNeverChanged.value
}

/** 改密成功后调用，撤掉提示 */
export function markPasswordChanged(): void {
  localStorage.removeItem(PWD_FLAG_KEY)
  pwdNeverChanged.value = false
}

export function clearAuth(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(NAME_KEY)
  localStorage.removeItem(ROLE_KEY)
  localStorage.removeItem(PWD_FLAG_KEY)
  pwdNeverChanged.value = false
}

export function isLoggedIn(): boolean {
  return getToken() !== ''
}

/**
 * 当前登录账号是否超级管理员。
 * 只用来决定菜单项显不显示，真正的权限由后端 SecurityConfig + 控制器校验，
 * 前端不做安全边界。
 */
export function isSuperAdmin(): boolean {
  return getAdminRole().trim().toUpperCase() === 'SUPER_ADMIN'
}
