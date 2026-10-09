// AI生成
/**
 * 轮询器：用于「提交测评后等待服务端 AI 分析」这类异步任务。
 * 设计要点：
 * - task 返回 true 表示任务完成，轮询自动停止；
 * - 一定有出口：超时回调 onTimeout，绝不让界面无限转圈；
 * - 组件卸载时务必 stop()，否则会留下游离定时器。
 */
import { onBeforeUnmount, ref } from 'vue'

export interface PollingOptions {
  /** 轮询间隔（ms），默认 2000 */
  interval?: number
  /** 总超时（ms），默认 60000 */
  timeout?: number
  /** 超时回调（给出失败出口，例如提示「稍后刷新查看」） */
  onTimeout?: () => void
  /** 任务出错时的回调；返回 void 表示继续重试 */
  onError?: (err: unknown) => void
}

export function usePolling(task: () => Promise<boolean>, options: PollingOptions = {}) {
  const { interval = 2000, timeout = 60000, onTimeout, onError } = options

  const active = ref(false)
  const stopped = ref(false)
  let timer: number | null = null
  let deadline = 0

  function clear(): void {
    if (timer !== null) {
      window.clearTimeout(timer)
      timer = null
    }
  }

  function stop(): void {
    stopped.value = true
    active.value = false
    clear()
  }

  async function tick(): Promise<void> {
    if (stopped.value) return
    if (Date.now() > deadline) {
      stop()
      onTimeout?.()
      return
    }
    try {
      const done = await task()
      if (done) {
        stop()
        return
      }
    } catch (err) {
      onError?.(err)
    }
    if (stopped.value) return
    timer = window.setTimeout(tick, interval)
  }

  function start(): void {
    stopped.value = false
    active.value = true
    deadline = Date.now() + timeout
    clear()
    timer = window.setTimeout(tick, interval)
  }

  onBeforeUnmount(stop)

  return { active, start, stop }
}
