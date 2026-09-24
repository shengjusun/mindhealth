/**
 * 应用偏好设置持久化（Preferences）
 * 设置页开关等本地偏好的读写入口
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { Logger } from './Logger'

const TAG = 'AppSettings'
const STORE_NAME = 'app_settings'

export class AppSettings {
  private static store: preferences.Preferences | null = null

  private static async getStore(context: common.Context): Promise<preferences.Preferences> {
    if (!AppSettings.store) {
      AppSettings.store = await preferences.getPreferences(context, STORE_NAME)
    }
    return AppSettings.store
  }

  /**
   * 读取布尔偏好（读取失败时返回默认值，不影响 UI 展示）
   */
  public static async getBoolean(context: common.Context, key: string, defaultValue: boolean): Promise<boolean> {
    try {
      const store = await AppSettings.getStore(context)
      const value = await store.get(key, defaultValue) as boolean
      return value
    } catch (error) {
      Logger.warn(TAG, `读取设置失败 key=${key}: ${JSON.stringify(error)}`)
      return defaultValue
    }
  }

  /**
   * 写入布尔偏好
   */
  public static async setBoolean(context: common.Context, key: string, value: boolean): Promise<void> {
    try {
      const store = await AppSettings.getStore(context)
      await store.put(key, value)
      await store.flush()
    } catch (error) {
      Logger.warn(TAG, `写入设置失败 key=${key}: ${JSON.stringify(error)}`)
    }
  }
}
