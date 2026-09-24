export function formatTime(value: string | null | undefined): string {
  if (!value) return '-'
  return value.replace('T', ' ').slice(0, 19)
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