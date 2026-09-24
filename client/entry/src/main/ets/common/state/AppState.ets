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
   * 系统底部手势条高度（vp）。
   *
   * 悬浮胶囊栏的下边距、以及各 Tab 页内容底部的预留空白都要叠加这个值，
   * 否则栏会压住系统手势条。由 EntryAbility 在 loadContent 之前同步写入，
   * 保证页面首帧就能读到；横竖屏切换时再通过 avoidAreaChange 更新。
   *
   * 注意：只有 V2 组件能观察 @Trace 变化并重排，V1 组件（HomeView 等）只能拿到首帧的值。
   */
  @Trace bottomIndicatorVp: number = 0

  /**
   * 日记详情刷新信号。
   *
   * 从编辑页保存后 pop 回详情页时，详情页一直在栈里不会重建，aboutToAppear 不触发；
   * 而 V2 组件不支持 onPageShow。所以改由 NavDestination.onShown 递增这个计数，
   * 页面侧用 @Monitor 监听并重新拉取详情。
   */
  @Trace diaryDetailRefreshTick: number = 0

  /**
   * 返回拦截桥接（上）：当前页面是否有未保存内容。
   *
   * V2 组件不支持 onBackPress，而 NavDestination.onBackPressed 在路由层、
   * 拿不到页面内的表单状态，所以由页面把「是否脏」写到这里，路由层读取后决定放行还是拦截。
   */
  @Trace hasUnsavedChanges: boolean = false

  /**
   * 返回拦截桥接（下）：路由层拦截到返回手势时递增。
   *
   * 不让路由层直接弹确认框，是因为确认文案和后续动作（保存 / 放弃 / 最小化窗口）
   * 是页面自己的事。页面用 @Monitor 监听这个计数后执行自己的逻辑。
   */
  @Trace backPressedTick: number = 0

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
