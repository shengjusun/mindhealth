export function formatTime(value: string | null | undefined): string {
  if (!value) return '-'
  return value.replace('T', ' ').slice(0, 19)
}

/**
 * 后端角色值 → 界面文案。
 * 库里 role 是自由文本列，历史数据可能不是这两个值，认不出时原样展示，
 * 避免以前那样把 SUPER_ADMIN 直接显示成英文。
 */
export function formatRole(role: string | null | undefined): string {
  if (!role) return '管理员账号'
  const value = role.trim().toUpperCase()
  if (value === 'SUPER_ADMIN') return '超级管理员'
  if (value === 'ADMIN') return '管理员'
  return role
}

export function formatQuestionCount(raw: string | null | undefined): number {
  if (!raw) return 0
  try {
    const arr = JSON.parse(raw)
    return Array.isArray(arr) ? arr.length : 0
  } catch {
    return 0
  }
}
