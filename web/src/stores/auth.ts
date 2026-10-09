// AI生成
/** 登录态。持久化在 localStorage，内存态由 Pinia 持有。 */
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as userApi from '../api/user'
import type { UserInfo, UserVO } from '../api/types'
import { clearSession, getToken, getUser, setSession, setUser as persistUser } from '../utils/session'

interface AuthStateUser {
  id: number
  phone: string
  nickname: string
  avatar: string
}

function pickUser(source: UserInfo | UserVO): AuthStateUser {
  return {
    id: source.id,
    phone: source.phone,
    nickname: source.nickname,
    avatar: source.avatar ?? '',
  }
}

export const useAuthStore = defineStore('auth', () => {
  const token = ref(getToken())
  const user = ref<AuthStateUser | null>(getUser())

  const isLoggedIn = computed(() => token.value.length > 0)
  const displayName = computed(() => user.value?.nickname || '朋友')
  const avatar = computed(() => user.value?.avatar || '')

  function applySession(newToken: string, refreshToken: string, info: UserInfo): void {
    setSession(newToken, refreshToken, info)
    token.value = newToken
    user.value = pickUser(info)
  }

  async function login(phone: string, password: string): Promise<void> {
    const res = await userApi.login(phone, password)
    applySession(res.token, res.refreshToken, res.userInfo)
  }

  async function register(phone: string, password: string, confirmPassword: string): Promise<void> {
    await userApi.register(phone, password, confirmPassword)
  }

  function logout(): void {
    clearSession()
    token.value = ''
    user.value = null
  }

  /** 拉取最新资料并同步到本地（资料修改后调用） */
  async function refreshProfile(): Promise<UserVO> {
    const info = await userApi.fetchUserInfo()
    user.value = pickUser(info)
    persistUser({
      id: info.id,
      phone: info.phone,
      nickname: info.nickname,
      avatar: info.avatar ?? '',
    })
    return info
  }

  return { token, user, isLoggedIn, displayName, avatar, login, register, logout, refreshProfile, applySession }
})
