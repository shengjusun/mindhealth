/**
 * 全局应用状态（ArkTS 状态管理 V2）
 *
 * 取代原先通过 AppStorage('mainTabIndex') + @StorageLink 做跨页通信的做法。
 * V2 中没有 @StorageLink，跨组件共享状态统一走 @ObservedV2 + AppStorageV2：
 * 任意组件拿到同一实例后，改属性即可被所有观察方感知。
 *
 * 注意：只有被 @Trace 装饰的字段才具备观察能力，新增字段不要漏掉装饰器。
 */
import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class AppState {
  // 当前底部 Tab 下标。任意页面写入，MainPage 监听并驱动 Tabs 切换
  @Trace mainTabIndex: number = 0

  // 「我的」页刷新信号：从编辑资料等二级页返回时递增，MeView 监听后强制刷新
  @Trace meRefreshTick: number = 0
}

const APP_STATE_KEY: string = 'appState'

/**
 * 获取全局单例。首次调用时创建并挂到 AppStorageV2，之后始终复用同一实例。
 */
export function appState(): AppState {
  const state: AppState | undefined =
    AppStorageV2.connect(AppState, APP_STATE_KEY, () => new AppState())
  // 已传入默认构造器，正常不会返回 undefined；兜底返回新实例避免空指针
  return state as AppState
}
