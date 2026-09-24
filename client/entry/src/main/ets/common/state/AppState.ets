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

  /**
   * Navigation 路由栈：全 App 唯一，由 Index 根容器持有同一实例。
   * 不需要 @Trace —— 我们不观察它本身，只调用它的方法，栈变化由 Navigation 自己感知。
   */
  pathStack: NavPathStack = new NavPathStack()
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

// ===== Navigation 路由助手 =====
// 页面不再 import router，统一走这几个函数，后续要替换实现只改这一处。
// 目标页名必须与 resources/base/profile/route_map.json 中的 name 一致。

/** 入栈跳转 */
export function pushRoute(name: string): void {
  appState().pathStack.pushPath({ name: name })
}

/** 带参数入栈跳转，取代 router.pushUrl({ url, params }) */
export function pushRouteWithParam(name: string, param: Object): void {
  appState().pathStack.pushPath({ name: name, param: param })
}

/**
 * 替换栈顶。栈为空时退化成 push —— 401 拦截等场景可能早于 Index 建栈，
 * 此时 replacePath 会静默失败，所以这里兜底。
 */
export function replaceRoute(name: string): void {
  const stack: NavPathStack = appState().pathStack
  if (stack.size() > 0) {
    stack.replacePath({ name: name })
  } else {
    stack.pushPath({ name: name })
  }
}

/** 清空整个栈再跳转：登出、重新登录等需要重置导航历史的场景 */
export function resetRoute(name: string): void {
  const stack: NavPathStack = appState().pathStack
  stack.clear()
  stack.pushPath({ name: name })
}

/** 返回上一页。栈内只剩根页面时 pop 是安全的空操作 */
export function popRoute(): void {
  appState().pathStack.pop()
}
