const TOKEN_KEY = 'admin_token'
const NAME_KEY = 'admin_name'

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function getAdminName(): string {
  return localStorage.getItem(NAME_KEY) || ''
}

export function setAuth(token: string, name: string): void {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(NAME_KEY, name)
}

export function clearAuth(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(NAME_KEY)
}

export function isLoggedIn(): boolean {
  return getToken() !== ''
}