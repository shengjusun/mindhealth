import { LoginPage } from './auth/LoginPage'
import { MainPage } from './MainPage'
import { SettingsPage } from './me/SettingsPage'
import { ProfileEditPage } from './me/ProfileEditPage'
import { MyRecordsPage } from './me/MyRecordsPage'
import { HelpFeedbackPage } from './me/HelpFeedbackPage'
import { RegisterPage } from './auth/RegisterPage'
import { ArticlesPage } from './article/ArticlesPage'
import { ArticleDetailPage } from './ArticleDetailPage'
import { DiaryEditPage } from './diary/DiaryEditPage'
import { DiaryDetailPage } from './diary/DiaryDetailPage'
import { AssessmentQuestionPage } from './assessment/AssessmentQuestionPage'
import { ContentPage } from './ContentPage'
import { appState } from '../common/state/AppState'
import { ToastUtil } from '../common/utils/ToastUtil'

/**
 * 全 App 的路由出口（系统路由表 route_map.json 的 buildFunction 都指向本文件）
 *
 * 为什么集中在一个文件而不是每个页面各写一个 builder：
 * 1. NavDestination 的包装、标题栏、生命周期钩子是路由层的事，不该污染页面本体；
 * 2. 迁移期间页面本体完全不用改，只在末尾加 export 即可；
 * 3. 12 条路由集中在一处，加/删/改名一眼看全。
 *
 * 代价：首次进入任意页面会一次性加载本文件（页面数再翻倍时应改为按页拆分）。
 */

// ===== 主页面「再按一次退出」=====
//
// 状态放模块级，不放 MainPage 的组件字段：组件实例会随重渲染重建，实例字段会被重置，
// 武装标记活不到第二次按键。
// 也不走 backPressedTick + @Monitor 握手 —— 该链路在 Navigation 根页面 + HdsTabs 上
// 触发次数不稳定，实测要按四次才生效。
let mainPageExitArmed: boolean = false
let mainPageExitTimerId: number = -1

// 首次按下后 2 秒内再按才生效，超时自动解除武装
const EXIT_ARM_WINDOW_MS: number = 2000

/** 解除武装并清掉定时器。第二次按下、以及 2 秒超时都走这里 */
function disarmMainPageExit(): void {
  if (mainPageExitTimerId !== -1) {
    clearTimeout(mainPageExitTimerId)
    mainPageExitTimerId = -1
  }
  mainPageExitArmed = false
}

// ===== 无入参页面：直接包一层 NavDestination =====

@Builder
export function LoginPageBuilder() {
  NavDestination() {
    LoginPage()
  }
  .hideTitleBar(true)
  // 登录页是栈底页面，返回时最小化窗口而不是退出 App。
  // V2 组件不支持 onBackPress，所以拦截逻辑上移到路由层，具体动作由页面监听 tick 执行
  .onBackPressed(() => {
    appState().backPressedTick++
    return true
  })
}

@Builder
export function MainPageBuilder() {
  NavDestination() {
    MainPage()
  }
  .hideTitleBar(true)
  // onShown 取代原来的 onPageShow：从二级页返回 MainPage 时触发刷新。
  // 不能用 onReady —— 它只在首次入栈触发一次，返回场景不会触发。
  .onShown(() => {
    appState().meRefreshTick++
  })
  // 主页面是栈底：首次按提示并武装，2 秒内再按则放行交给系统（最小化到后台）。
  // 全部逻辑收在本文件，不经过 AppState / @Monitor —— 原因见文件上方的说明。
  .onBackPressed(() => {
    if (mainPageExitArmed) {
      disarmMainPageExit()
      return false
    }
    mainPageExitArmed = true
    ToastUtil.show('再按一次退出应用')
    mainPageExitTimerId = setTimeout(() => {
      disarmMainPageExit()
    }, EXIT_ARM_WINDOW_MS)
    return true
  })
}

@Builder
export function SettingsPageBuilder() {
  NavDestination() {
    SettingsPage()
  }
  .hideTitleBar(true)
}

@Builder
export function ProfileEditPageBuilder() {
  NavDestination() {
    ProfileEditPage()
  }
  .hideTitleBar(true)
  // 表单已修改时拦截返回，由页面弹「保存 / 放弃」确认；未修改则放行默认 pop
  .onBackPressed(() => {
    if (appState().hasUnsavedChanges) {
      appState().backPressedTick++
      return true
    }
    return false
  })
}

@Builder
export function MyRecordsPageBuilder() {
  NavDestination() {
    MyRecordsPage()
  }
  .hideTitleBar(true)
}

@Builder
export function HelpFeedbackPageBuilder() {
  NavDestination() {
    HelpFeedbackPage()
  }
  .hideTitleBar(true)
  // 反馈内容未提交时拦截返回，由页面弹确认（审计 C-5-1）
  .onBackPressed(() => {
    if (appState().hasUnsavedChanges) {
      appState().backPressedTick++
      return true
    }
    return false
  })
}

@Builder
export function RegisterPageBuilder() {
  NavDestination() {
    RegisterPage()
  }
  .hideTitleBar(true)
  // 注册表单已填写时拦截返回，由页面弹确认
  .onBackPressed(() => {
    if (appState().hasUnsavedChanges) {
      appState().backPressedTick++
      return true
    }
    return false
  })
}

@Builder
export function ArticlesPageBuilder() {
  NavDestination() {
    ArticlesPage()
  }
  .hideTitleBar(true)
}

// ===== 有入参页面 =====
// router 时代靠 router.getParams() 读参；Navigation 下改由 NavDestination.onReady 提供。
// onReady 的触发时机晚于页面 aboutToAppear，所以不能直接把页面挂上去再回灌参数
// （会读到 undefined）。这里用一个中间组件：先等 onReady 拿到 param，再创建页面，
// 保证页面 aboutToAppear 执行时参数已就位。

@ComponentV2
struct DiaryEditRoute {
  @Local routeParam: Record<string, Object> | undefined = undefined
  @Local paramReady: boolean = false

  build() {
    NavDestination() {
      if (this.paramReady) {
        DiaryEditPage({ routeParam: this.routeParam })
      }
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.routeParam = ctx.pathInfo.param as Record<string, Object> | undefined
      this.paramReady = true
    })
    // 日记有内容时拦截返回，由页面弹确认；无内容则放行默认 pop
    .onBackPressed(() => {
      if (appState().hasUnsavedChanges) {
        appState().backPressedTick++
        return true
      }
      return false
    })
  }
}

@Builder
export function DiaryEditPageBuilder() {
  DiaryEditRoute()
}

@ComponentV2
struct DiaryDetailRoute {
  @Local routeParam: Record<string, Object> | undefined = undefined
  @Local paramReady: boolean = false

  build() {
    NavDestination() {
      if (this.paramReady) {
        DiaryDetailPage({ routeParam: this.routeParam })
      }
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.routeParam = ctx.pathInfo.param as Record<string, Object> | undefined
      this.paramReady = true
    })
    // V2 组件不支持 onPageShow：从编辑页保存返回本页面时不会重建，
    // 靠 onShown 递增计数，页面侧用 @Monitor 监听后刷新
    .onShown(() => {
      appState().diaryDetailRefreshTick++
    })
  }
}

@Builder
export function DiaryDetailPageBuilder() {
  DiaryDetailRoute()
}

@ComponentV2
struct ArticleDetailRoute {
  @Local routeParam: Record<string, Object> | undefined = undefined
  @Local paramReady: boolean = false

  build() {
    NavDestination() {
      if (this.paramReady) {
        ArticleDetailPage({ routeParam: this.routeParam })
      }
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.routeParam = ctx.pathInfo.param as Record<string, Object> | undefined
      this.paramReady = true
    })
  }
}

@Builder
export function ArticleDetailPageBuilder() {
  ArticleDetailRoute()
}

@ComponentV2
struct ContentRoute {
  @Local routeParam: Record<string, Object> | undefined = undefined
  @Local paramReady: boolean = false

  build() {
    NavDestination() {
      if (this.paramReady) {
        ContentPage({ routeParam: this.routeParam })
      }
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.routeParam = ctx.pathInfo.param as Record<string, Object> | undefined
      this.paramReady = true
    })
  }
}

@Builder
export function ContentPageBuilder() {
  ContentRoute()
}

@ComponentV2
struct AssessmentQuestionRoute {
  @Local routeParam: Record<string, Object> | undefined = undefined
  @Local paramReady: boolean = false

  build() {
    NavDestination() {
      if (this.paramReady) {
        AssessmentQuestionPage({ routeParam: this.routeParam })
      }
    }
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.routeParam = ctx.pathInfo.param as Record<string, Object> | undefined
      this.paramReady = true
    })
    // 答题中（已答任意一题且未出结果）拦截返回，由页面弹放弃确认
    .onBackPressed(() => {
      if (appState().hasUnsavedChanges) {
        appState().backPressedTick++
        return true
      }
      return false
    })
  }
}

@Builder
export function AssessmentQuestionPageBuilder() {
  AssessmentQuestionRoute()
}
