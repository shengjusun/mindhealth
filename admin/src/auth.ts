const TOKEN_KEY = 'admin_token'
const NAME_KEY = 'admin_name'
const ROLE_KEY = 'admin_role'

export function getToken(): string {
  return localStorage.getItem(TOKEN_KEY) || ''
}

export function getAdminName(): string {
  return localStorage.getItem(NAME_KEY) || ''
}

export function getAdminRole(): string {
  return localStorage.getItem(ROLE_KEY) || ''
}

export function setAuth(token: string, name: string, role?: string): void {
  localStorage.setItem(TOKEN_KEY, token)
  localStorage.setItem(NAME_KEY, name)
  if (role) {
    localStorage.setItem(ROLE_KEY, role)
  } else {
    localStorage.removeItem(ROLE_KEY)
  }
}

export function clearAuth(): void {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(NAME_KEY)
  localStorage.removeItem(ROLE_KEY)
}

export function isLoggedIn(): boolean {
  return getToken() !== ''
}
