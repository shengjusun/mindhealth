/**
 * 全局 Toast 工具
 * 基于 promptAction.showToast 实现，替代各页面用 AlertDialog 凑合的提示方式
 */
import { promptAction } from '@kit.ArkUI'
import { Logger } from './Logger'

const TAG = 'ToastUtil'

export class ToastUtil {
  /**
   * 展示短 Toast（约 1.5 秒）
   */
  public static show(message: string): void {
    if (message === undefined || message.length === 0) {
      return
    }
    try {
      promptAction.showToast({
        message: message,
        duration: 1500,
        showMode: promptAction.ToastShowMode.TOP_MOST
      })
    } catch (error) {
      Logger.warn(TAG, `Toast 显示失败: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 展示长 Toast（约 3 秒），适合需要用户看清的提示
   */
  public static showLong(message: string): void {
    if (message === undefined || message.length === 0) {
      return
    }
    try {
      promptAction.showToast({
        message: message,
        duration: 3000,
        showMode: promptAction.ToastShowMode.TOP_MOST
      })
    } catch (error) {
      Logger.warn(TAG, `Toast 显示失败: ${JSON.stringify(error)}`)
    }
  }
}
