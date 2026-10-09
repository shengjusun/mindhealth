import type { Directive } from 'vue'

/**
 * 滚动揭示指令。
 *
 *   <div v-reveal>...</div>                 进入视口时淡入上移
 *   <div v-reveal="i * 70">...</div>        错峰：延迟 i*70ms（列表用）
 *   <div v-reveal.left>...</div>            方向变体：left / right / scale / fade
 *
 * 设计取舍：
 *   · 全站共用一个 IntersectionObserver（而不是每个元素一个），减少回调与内存；
 *   · 只播一次，触发后立刻 unobserve，避免来回滚动反复闪动；
 *   · prefers-reduced-motion 下直接落到终态，不做位移与淡入。
 */

const REDUCED =
  typeof window !== 'undefined' &&
  window.matchMedia?.('(prefers-reduced-motion: reduce)').matches === true

let observer: IntersectionObserver | null = null

function getObserver(): IntersectionObserver {
  if (observer) return observer
  observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue
        entry.target.classList.add('reveal--in')
        observer?.unobserve(entry.target)
      }
    },
    // 视口下方留 6% 余量：元素刚露头就播，避免"滚到了还没动"
    { threshold: 0.1, rootMargin: '0px 0px -6% 0px' }
  )
  return observer
}

type RevealValue = number | undefined

export const vReveal: Directive<HTMLElement, RevealValue> = {
  mounted(el, binding) {
    el.classList.add('reveal')

    // 方向修饰符：v-reveal.left
    for (const mod of Object.keys(binding.modifiers)) {
      el.classList.add(`reveal--${mod}`)
    }

    if (REDUCED) {
      el.classList.add('reveal--in')
      return
    }

    if (typeof binding.value === 'number' && binding.value > 0) {
      el.style.setProperty('--reveal-delay', `${binding.value}ms`)
    }

    getObserver().observe(el)
  },
  unmounted(el) {
    observer?.unobserve(el)
  },
}
