// AI生成
/**
 * 主题：深浅色「跟随系统 + 手动开关」双轨，外加品牌主题切换。
 * 三态 mode: auto | light | dark；主题 id: teal 青绿 | misty 晨雾蓝 | sunset 暖阳橙。
 * auto 会在 JS 中解析成实际明暗后仍显式写入 data-mode，
 * 使 CSS 只需处理 light/dark 两态，降低样式复杂度。
 */
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'

export type ThemeMode = 'auto' | 'light' | 'dark'
export type ThemeId = 'teal' | 'misty' | 'sunset'

export interface ThemeOption {
  id: ThemeId
  name: string
  desc: string
  /** 预览色（浅色主色） */
  swatch: string
}

export const THEME_OPTIONS: ThemeOption[] = [
  { id: 'teal', name: '青绿', desc: '清透治愈，默认', swatch: '#2f8f7b' },
  { id: 'misty', name: '晨雾蓝', desc: '安静柔和', swatch: '#6e93b8' },
  { id: 'sunset', name: '暖阳橙', desc: '温暖有光', swatch: '#c98b6e' },
]

const K_MODE = 'user_theme_mode'
const K_THEME = 'user_theme_id'

function readMode(): ThemeMode {
  const raw = localStorage.getItem(K_MODE)
  return raw === 'light' || raw === 'dark' || raw === 'auto' ? raw : 'auto'
}

function readTheme(): ThemeId {
  const raw = localStorage.getItem(K_THEME)
  return raw === 'misty' || raw === 'sunset' || raw === 'teal' ? raw : 'teal'
}

export const useThemeStore = defineStore('theme', () => {
  const mode = ref<ThemeMode>(readMode())
  const themeId = ref<ThemeId>(readTheme())
  const systemDark = ref(
    typeof window !== 'undefined' && window.matchMedia
      ? window.matchMedia('(prefers-color-scheme: dark)').matches
      : false,
  )

  const resolvedMode = computed<'light' | 'dark'>(() =>
    mode.value === 'auto' ? (systemDark.value ? 'dark' : 'light') : mode.value,
  )
  const isDark = computed(() => resolvedMode.value === 'dark')

  function apply(): void {
    const el = document.documentElement
    el.setAttribute('data-theme', themeId.value)
    el.setAttribute('data-mode', resolvedMode.value)
  }

  function persist(): void {
    try {
      localStorage.setItem(K_MODE, mode.value)
      localStorage.setItem(K_THEME, themeId.value)
    } catch {
      /* ignore */
    }
  }

  function setMode(next: ThemeMode): void {
    mode.value = next
    persist()
    apply()
  }

  /** 手动开关：在 light / dark 间切换（脱离 auto） */
  function toggle(): void {
    setMode(resolvedMode.value === 'dark' ? 'light' : 'dark')
  }

  function setThemeId(next: ThemeId): void {
    themeId.value = next
    persist()
    apply()
  }

  /** 监听系统深浅色变化（仅 auto 生效） */
  function watchSystem(): void {
    if (typeof window === 'undefined' || !window.matchMedia) return
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      systemDark.value = e.matches
      if (mode.value === 'auto') apply()
    })
  }

  return {
    mode,
    themeId,
    resolvedMode,
    isDark,
    setMode,
    toggle,
    setThemeId,
    apply,
    watchSystem,
  }
})
