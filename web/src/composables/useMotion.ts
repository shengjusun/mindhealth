import type { Directive } from 'vue'

/**
 * 两个轻量动效指令（都只在鼠标/滚动这类"有输入"时才动，空闲不耗资源）。
 *
 *   v-tilt            鼠标在元素上移动时做 3D 微倾斜
 *   v-tilt="4"        指定最大倾角（度，默认 6）
 *   v-parallax="0.08" 滚动时按 speed 位移（正数向下、负数向上）
 *
 * 共同约定：
 *   · transform 全部在 rAF 里写，避免 mousemove/scroll 高频触发样式重算；
 *   · 离开时把 transform 清空，不留残余；
 *   · prefers-reduced-motion 下**完全不注册**监听。
 */

const REDUCED =
  typeof window !== 'undefined' &&
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

interface Cleanup {
  __motionCleanup?: () => void
}

/* ------------------------------------------------------------------ 3D 倾斜 */
export const vTilt: Directive<HTMLElement, number | undefined> = {
  mounted(el, binding) {
    if (REDUCED) return

    const max = typeof binding.value === 'number' ? binding.value : 6
    let raf = 0

    el.style.transition = 'transform 260ms cubic-bezier(0.34, 1.56, 0.64, 1)'
    el.style.transformStyle = 'preserve-3d'

    const onMove = (ev: MouseEvent) => {
      const r = el.getBoundingClientRect()
      if (!r.width || !r.height) return
      const px = (ev.clientX - r.left) / r.width - 0.5
      const py = (ev.clientY - r.top) / r.height - 0.5
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        el.style.transform =
          `perspective(900px) rotateY(${(px * max).toFixed(2)}deg) ` +
          `rotateX(${(-py * max).toFixed(2)}deg) translateY(-4px)`
      })
    }

    const onLeave = () => {
      cancelAnimationFrame(raf)
      el.style.transform = ''
    }

    el.addEventListener('mousemove', onMove)
    el.addEventListener('mouseleave', onLeave)

    ;(el as HTMLElement & Cleanup).__motionCleanup = () => {
      el.removeEventListener('mousemove', onMove)
      el.removeEventListener('mouseleave', onLeave)
      cancelAnimationFrame(raf)
      el.style.transform = ''
      el.style.transition = ''
      el.style.transformStyle = ''
    }
  },
  unmounted(el) {
    ;(el as HTMLElement & Cleanup).__motionCleanup?.()
  },
}

/* ------------------------------------------------------------------ 视差 */
export const vParallax: Directive<HTMLElement, number | undefined> = {
  mounted(el, binding) {
    if (REDUCED) return

    const speed = typeof binding.value === 'number' ? binding.value : 0.08
    let raf = 0

    const apply = () => {
      const y = window.scrollY || window.pageYOffset || 0
      el.style.transform = `translate3d(0, ${(y * speed).toFixed(2)}px, 0)`
    }

    const onScroll = () => {
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(apply)
    }

    el.style.willChange = 'transform'
    window.addEventListener('scroll', onScroll, { passive: true })
    apply()

    ;(el as HTMLElement & Cleanup).__motionCleanup = () => {
      window.removeEventListener('scroll', onScroll)
      cancelAnimationFrame(raf)
      el.style.transform = ''
      el.style.willChange = ''
    }
  },
  unmounted(el) {
    ;(el as HTMLElement & Cleanup).__motionCleanup?.()
  },
}
