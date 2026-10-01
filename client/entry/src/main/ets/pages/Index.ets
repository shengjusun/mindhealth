import { AuthService } from '../core/auth/AppAuthService'
import { appState } from '../common/state/AppState'
import { Logger } from '../common/utils/Logger'

const TAG = 'Index'

/**
 * 全 App 唯一的 @Entry 页面（Navigation 根容器）
 *
 * router 模式下每个页面都是 @Entry，靠 url 字符串跳转；
 * Navigation 模式下只剩这一个 @Entry，其余页面降级为 NavDestination，
 * 由 resources/base/profile/route_map.json 按 name 找到对应的 buildFunction 加载。
 *
 * 启动分流（登录/未登录）原先在 EntryAbility 的 loadContent 里做，
 * 现在搬到这里 —— 因为 loadContent 只能决定"加载哪个 @Entry"，而 @Entry 只剩一个了。
 *
 * 【一句话】这是全 App 唯一的大门：用户进来先看哪个页面，由这里决定。
 * 注意它并不 new 一个新栈，而是从 AppState 那块白板上取同一个 pathStack ——
 * 全 App 只有这一份栈，其他页面通过 AppState.ets 里的 pushRoute / popRoute 等函数操作它。
 */
@Entry
@ComponentV2
struct Index {
  // 不是 new 一个新栈，而是从白板上取「同一个」栈（AppStorageV2 全局单例）。
  // 全 App 只有这一份 pathStack，Index 是唯一持有它的组件。
  private stack: NavPathStack = appState().pathStack

  aboutToAppear(): void {
    this.pushStartRoute()
  }

  /**
   * 推入首屏页面。
   *
   * aboutToAppear 里 push 依赖 Navigation 此时已可用 —— 官方示例是这么写的，
   * 但个别机型/时序下可能发生在 Navigation 挂载之前而被丢弃，表现为首屏白屏。
   * 所以 Navigation 的 onAppear 里再兜底调一次；栈非空时直接返回，不会重复入栈。
   */
  private pushStartRoute(): void {
    if (this.stack.size() > 0) {
      return
    }
    const isLoggedIn: boolean = AuthService.getInstance().isLoggedIn()
    const startRoute: string = isLoggedIn ? 'MainPage' : 'LoginPage'

    Logger.info(TAG, `初始路由: ${startRoute}`)
    this.stack.pushPath({ name: startRoute })
  }

  build() {
    Navigation(this.stack) {
      // 根内容留空：首屏页面通过 pushPath 入栈显示
      Column() {
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    // 各页面头部由页面自己画（AppPageHeader），不叠加 Navigation 自带标题栏
    .hideNavBar(true)
    .backgroundColor($r('app.color.app_background'))
    .onAppear(() => {
      this.pushStartRoute()
    })
  }
}
