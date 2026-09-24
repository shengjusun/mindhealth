import router from '@ohos.router'
import { HomeView } from './home/HomePageNew'
import { AIChatView } from './ai/AIChatPage'
import { MoodDiaryView } from './diary/MoodDiaryPage'
import { AssessmentsView } from './assessment/AssessmentsPage'
import { MeView } from './me/MePage'
import { Dimension, ShadowStyle } from '../common/constants/Theme'
import { AuthService } from '../core/auth/AppAuthService'
import { Logger } from '../common/utils/Logger'
import { appState, AppState } from '../common/state/AppState'

const TAG = 'MainPage'

// 与 Tab 顺序一一对应（可通过 appState().mainTabIndex 从任意视图切换）
interface MainTabItem {
  id: string
  icon: Resource // 系统符号图标（SymbolGlyph），引用 SDK 内置符号库
  label: string
}

@Entry
@ComponentV2
struct MainPage {
  // 全局共享状态：任何页面/视图改 appState().mainTabIndex 即可切换 Tab
  @Local state: AppState = appState()

  private tabController: TabsController = new TabsController()
  private authService: AuthService = AuthService.getInstance()

  private tabs: MainTabItem[] = [
    { id: 'home', icon: $r('sys.symbol.house'), label: '首页' },
    { id: 'chat', icon: $r('sys.symbol.message'), label: '树洞' },
    { id: 'diary', icon: $r('sys.symbol.book_pages'), label: '日记' },
    { id: 'assess', icon: $r('sys.symbol.checkmark_clipboard'), label: '自查' },
    { id: 'me', icon: $r('sys.symbol.person'), label: '我的' }
  ]

  aboutToAppear(): void {
    // 登录守卫：未登录直接回登录页（App 内只在这里拦一次）
    if (!this.authService.isLoggedIn()) {
      try {
        router.replaceUrl({ url: 'pages/auth/LoginPage' })
      } catch (error) {
        Logger.error(TAG, `未登录跳转登录页失败: ${JSON.stringify(error)}`)
      }
      return
    }

    // 支持通过路由参数指定初始 Tab，如 replaceUrl('pages/MainPage', { tab: 'me' })
    const params = router.getParams() as Record<string, Object> | undefined
    if (params && params['tab'] !== undefined) {
      const tabId: string = String(params['tab'])
      const index = this.tabs.findIndex((item: MainTabItem) => item.id === tabId)
      if (index >= 0) {
        this.state.mainTabIndex = index
      }
    }
  }

  onPageShow(): void {
    // 从二级页（编辑资料/写日记等）返回时刷新「我的」页数据
    this.state.meRefreshTick++
  }

  @Monitor('state.mainTabIndex')
  onTabIndexChanged(): void {
    Logger.info(TAG, `Tab 切换到 index=${this.state.mainTabIndex}`)
  }

  build() {
    // Tabs 铺满整屏，胶囊栏叠在内容之上（内容会穿过栏下方，毛玻璃才有东西可模糊）
    Stack({ alignContent: Alignment.Bottom }) {
      Tabs({
        barPosition: BarPosition.End,
        index: this.state.mainTabIndex,
        controller: this.tabController
      }) {
        TabContent() {
          HomeView()
        }

        TabContent() {
          AIChatView()
        }

        TabContent() {
          MoodDiaryView()
        }

        TabContent() {
          AssessmentsView()
        }

        TabContent() {
          MeView()
        }
      }
      .width('100%')
      .height('100%')
      .scrollable(true)
      // 原生底部栏隐藏，改由 floatingTabBar 自己画
      .barHeight(0)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.state.mainTabIndex = index
      })

      this.floatingTabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  /**
   * 悬浮胶囊 Tab 栏
   * - 原生 bar 已隐藏，这里自己画一个浮在内容之上的胶囊，点击走 tabController.changeIndex
   * - backgroundBlurStyle 提供毛玻璃：内容滚动时从胶囊下方穿过，模糊才有效果
   * - 不再经过 .tabBar() 插槽，因此不存在 @LocalBuilder 内容被丢弃的问题
   */
  @Builder
  floatingTabBar() {
    Row() {
      ForEach(this.tabs, (item: MainTabItem, index: number) => {
        Column() {
          SymbolGlyph(item.icon)
            .fontSize(23)
            .fontColor([this.state.mainTabIndex === index
              ? $r('app.color.nav_active')
              : $r('app.color.nav_inactive')])

          Text(item.label)
            .fontSize(Dimension.FontXS)
            .fontColor(this.state.mainTabIndex === index
              ? $r('app.color.nav_active')
              : $r('app.color.nav_inactive'))
            .fontWeight(this.state.mainTabIndex === index ? FontWeight.Medium : FontWeight.Normal)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height(Dimension.PillHeight - 10)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius((Dimension.PillHeight - 10) / 2)
        .backgroundColor(this.state.mainTabIndex === index ? $r('app.color.tag_blue') : Color.Transparent)
        .onClick(() => {
          if (this.state.mainTabIndex !== index) {
            this.state.mainTabIndex = index
            this.tabController.changeIndex(index)
          }
        })
      }, (item: MainTabItem) => item.id)
    }
    .width('90%')
    .height(Dimension.PillHeight)
    .padding({ left: 6, right: 6 })
    .borderRadius(Dimension.PillHeight / 2)
    // 半透明底 + 背景模糊 = 毛玻璃；底色用资源色，深浅色模式各自成立
    .backgroundColor($r('app.color.pill_glass'))
    .backgroundBlurStyle(BlurStyle.Thin)
    .shadow(ShadowStyle.Pill)
    .margin({ bottom: Dimension.PillMarginBottom })
  }
}
