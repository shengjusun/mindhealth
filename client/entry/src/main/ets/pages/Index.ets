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
 */
@Entry
@ComponentV2
struct Index {
  private stack: NavPathStack = appState().pathStack

  aboutToAppear(): void {
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
    .hideNavBar(true)
    .backgroundColor($r('app.color.app_background'))
  }
}
