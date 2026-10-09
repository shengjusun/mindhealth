<template>
  <span ref="el" class="countup">{{ display }}</span>
</template>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'

/**
 * 数字滚动：进入视口后从 0 递增到目标值。
 *
 * 取舍：
 *   · 用 requestAnimationFrame 手写缓动（easeOutCubic），不引第三方库；
 *   · 只在「值已就绪 + 已进入视口」两个条件同时满足时才跑，
 *     因为数据是异步来的，组件挂载时往往还是 0；
 *   · prefers-reduced-motion 下直接落终值，不做递增。
 */
const props = withDefaults(
  defineProps<{
    value: number
    prefix?: string
    suffix?: string
    duration?: number
    decimals?: number
  }>(),
  { prefix: '', suffix: '', duration: 900, decimals: 0 }
)

const el = ref<HTMLElement | null>(null)
const display = ref('')

const reduced =
  typeof window !== 'undefined' &&
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

let raf = 0
let seen = false
let running = false

function fmt(n: number): string {
  return `${props.prefix}${n.toFixed(props.decimals)}${props.suffix}`
}

function run(): void {
  cancelAnimationFrame(raf)
  const to = props.value

  if (reduced || props.duration <= 0) {
    display.value = fmt(to)
    return
  }

  running = true
  // 用第一帧的时间戳当起点，而不是 performance.now()：
  // rAF 回调拿到的帧时间可能早于「请求 rAF 那一刻」，两者相减会得到负进度，
  // 再喂进 easeOutCubic 就会算出负数（曾出现 "-33 份" 这种显示）。
  let start = 0
  const tick = (now: number) => {
    if (start === 0) start = now
    const raw = (now - start) / props.duration
    const p = Math.min(1, Math.max(0, raw)) // 上下都要夹
    const eased = 1 - Math.pow(1 - p, 3) // easeOutCubic
    display.value = fmt(to * eased)
    if (p < 1) {
      raf = requestAnimationFrame(tick)
    } else {
      display.value = fmt(to)
      running = false
    }
  }
  raf = requestAnimationFrame(tick)
}

let io: IntersectionObserver | null = null

function maybeStart(): void {
  if (!seen || running) return
  if (!Number.isFinite(props.value)) return
  run()
}

onMounted(() => {
  display.value = fmt(props.value) // 先占位，避免首帧空白

  if (reduced) {
    seen = true
    return
  }

  io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue
        seen = true
        io?.disconnect()
        io = null
        maybeStart()
      }
    },
    { threshold: 0.4 }
  )
  if (el.value) io.observe(el.value)
})

// 数据异步到位后重新触发（挂载时值往往还是 0）
watch(() => props.value, () => maybeStart())

onBeforeUnmount(() => {
  cancelAnimationFrame(raf)
  io?.disconnect()
})
</script>

<style scoped>
.countup {
  font-variant-numeric: tabular-nums; /* 数字等宽，滚动时不左右抖 */
}
</style>
