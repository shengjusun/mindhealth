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
import { appState } from '../common/state/AppState'

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
}

@Builder
export function RegisterPageBuilder() {
  NavDestination() {
    RegisterPage()
  }
  .hideTitleBar(true)
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
  }
}

@Builder
export function AssessmentQuestionPageBuilder() {
  AssessmentQuestionRoute()
}
