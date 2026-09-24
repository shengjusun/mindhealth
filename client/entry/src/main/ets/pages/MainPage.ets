import router from '@ohos.router'
import { HomeView } from './home/HomePageNew'
import { AIChatView } from './ai/AIChatPage'
import { MoodDiaryView } from './diary/MoodDiaryPage'
import { AssessmentsView } from './assessment/AssessmentsPage'
import { MeView } from './me/MePage'
import { Dimension } from '../common/constants/Theme'
import { AuthService } from '../core/auth/AppAuthService'
import { Logger } from '../common/utils/Logger'

const TAG = 'MainPage'

// 与 Tab 顺序一一对应（可通过 AppStorage 'mainTabIndex' 从任意视图切换）
interface MainTabItem {
  id: string
  icon: Resource // 系统符号图标（SymbolGlyph），引用 SDK 内置符号库
  label: string
}

@Entry
@Component
struct MainPage {
  // 双向绑定 AppStorage：任何页面/视图写入该 key 即可切换 Tab
  @StorageLink('mainTabIndex') @Watch('onTabIndexChanged') currentTabIndex: number = 0
  // 「我的」页刷新信号：从编辑资料等二级页返回时强制刷新
  @State meRefreshTick: number = 0

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
        this.currentTabIndex = index
      }
    }
  }

  onPageShow(): void {
    // 从二级页（编辑资料/写日记等）返回时刷新「我的」页数据
    this.meRefreshTick++
  }

  onTabIndexChanged(): void {
    Logger.info(TAG, `Tab 切换到 index=${this.currentTabIndex}`)
  }

  build() {
    Column() {
      Tabs({
        barPosition: BarPosition.End,
        index: this.currentTabIndex,
        controller: this.tabController
      }) {
        TabContent() {
          HomeView()
        }
        .tabBar(this.tabBarItem(0, this.tabs[0]))

        TabContent() {
          AIChatView()
        }
        .tabBar(this.tabBarItem(1, this.tabs[1]))

        TabContent() {
          MoodDiaryView()
        }
        .tabBar(this.tabBarItem(2, this.tabs[2]))

        TabContent() {
          AssessmentsView()
        }
        .tabBar(this.tabBarItem(3, this.tabs[3]))

        TabContent() {
          MeView({ refreshTick: this.meRefreshTick })
        }
        .tabBar(this.tabBarItem(4, this.tabs[4]))
      }
      .width('100%')
      .layoutWeight(1)
      .scrollable(true)
      .barHeight(Dimension.BottomNavHeight)
      .barMode(BarMode.Fixed)
      .onChange((index: number) => {
        this.currentTabIndex = index
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  tabBarItem(targetIndex: number, item: MainTabItem) {
    Column() {
      Column() {
        SymbolGlyph(item.icon)
          .fontSize(this.currentTabIndex === targetIndex ? 24 : 23)
          .fontColor([this.currentTabIndex === targetIndex
            ? $r('app.color.nav_active')
            : $r('app.color.nav_inactive')])
          .opacity(this.currentTabIndex === targetIndex ? 1 : 0.8)

        Text(item.label)
          .fontSize(Dimension.FontXS)
          .fontColor(this.currentTabIndex === targetIndex ? $r('app.color.nav_active') : $r('app.color.nav_inactive'))
          .fontWeight(this.currentTabIndex === targetIndex ? FontWeight.Medium : FontWeight.Normal)
          .margin({ top: 2 })
      }
      .width(58)
      .height(Dimension.BottomNavHeight - 2)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.currentTabIndex === targetIndex ? $r('app.color.tag_blue') : Color.Transparent)
      .borderRadius(18)
    }
    .width('20%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
