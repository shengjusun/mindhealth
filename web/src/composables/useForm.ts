// AI生成
/**
 * 极轻量表单校验。
 * 不引三方校验库：本项目表单都很小（登录/注册/资料/反馈），
 * 一个 reactive + 规则表足够，还能避免额外依赖与体积。
 */
import { reactive } from 'vue'

export interface FieldRule {
  /** 必填 */
  required?: boolean
  /** 最短长度 */
  min?: number
  /** 最长长度 */
  max?: number
  /** 正则（注意：不要带全局标志，避免 lastIndex 副作用） */
  pattern?: RegExp
  /** 自定义校验：返回错误文案，返回空串表示通过 */
  validate?: (value: string) => string
  /** 统一错误文案（未命中上述具体规则时使用） */
  message?: string
}

export type RulesOf<T extends string> = Partial<Record<T, FieldRule>>

export function useForm<T extends Record<string, string>>(initial: T, rules: RulesOf<keyof T & string> = {}) {
  const values = reactive({ ...initial }) as T
  const errors = reactive<Record<string, string>>({})
  const touched = reactive<Record<string, boolean>>({})

  function checkField(key: keyof T & string): string {
    const rule = rules[key]
    const value = (values[key] ?? '').trim()
    if (!rule) return ''
    if (rule.required && value.length === 0) return rule.message || '这一项不能为空'
    if (value.length > 0) {
      if (rule.min !== undefined && value.length < rule.min) return rule.message || `至少需要 ${rule.min} 个字符`
      if (rule.max !== undefined && value.length > rule.max) return rule.message || `最多 ${rule.max} 个字符`
      if (rule.pattern && !rule.pattern.test(value)) return rule.message || '格式不正确'
      if (rule.validate) {
        const msg = rule.validate(value)
        if (msg) return msg
      }
    }
    return ''
  }

  /** 校验单个字段并把结果落到 errors（供失焦时调用） */
  function validateField(key: keyof T & string): boolean {
    touched[key] = true
    const message = checkField(key)
    if (message) {
      errors[key] = message
      return false
    }
    delete errors[key]
    return true
  }

  /** 校验全部字段 */
  function validate(): boolean {
    let ok = true
    ;(Object.keys(values) as (keyof T & string)[]).forEach((key) => {
      if (!validateField(key)) ok = false
    })
    return ok
  }

  function reset(next?: Partial<T>): void {
    Object.assign(values, next ?? initial)
    ;(Object.keys(errors) as string[]).forEach((k) => delete errors[k])
    ;(Object.keys(touched) as string[]).forEach((k) => delete touched[k])
  }

  function setError(key: keyof T & string, message: string): void {
    errors[key] = message
  }

  function clearError(key: keyof T & string): void {
    delete errors[key]
  }

  /** 表单整体是否已有任何错误（用于按钮禁用等） */
  function hasError(): boolean {
    return Object.keys(errors).length > 0
  }

  return { values, errors, touched, validate, validateField, reset, setError, clearError, hasError }
}

/** 常用规则构造器 */
export const rules = {
  required: (message = '这一项不能为空'): FieldRule => ({ required: true, message }),
  phone: (): FieldRule => ({
    required: true,
    pattern: /^1\d{10}$/,
    message: '请输入 11 位手机号',
  }),
  password: (): FieldRule => ({
    required: true,
    min: 6,
    max: 32,
    message: '密码需为 6-32 位',
  }),
}
