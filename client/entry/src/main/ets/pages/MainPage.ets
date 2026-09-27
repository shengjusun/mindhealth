import { HomeView } from './home/HomePageNew'
import { AIChatView } from './ai/AIChatPage'
import { MoodDiaryView } from './diary/MoodDiaryPage'
import { AssessmentsView } from './assessment/AssessmentsPage'
import { MeView } from './me/MePage'
import { brand, Dimension } from '../common/constants/Theme'
import { appState, AppState } from '../common/state/AppState'
import { HdsTabs, HdsTabsController, hdsMaterial } from '@kit.UIDesignKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'

interface MainTabItem {
  icon: Resource
  iconFill: Resource
  label: string
}

/**
 * 主框架：华为官方 HdsTabs 浮动栏（UIDesignKit）
 * - ADAPTIVE 系统材质：官方的沉浸光感底，替代手绘毛玻璃胶囊
 * - 选中态（填充图标/主色/官方动效）由 HdsTabs 自带，无需自绘滑块
 * - 底部间距沿用动态避让：pillMarginBottom(手势条高度)
 */
@ComponentV2
export struct MainPage {
  @Local state: AppState = appState()
  private tabsController: HdsTabsController = new HdsTabsController()

  private tabs: MainTabItem[] = [
    { icon: $r('sys.symbol.house'), iconFill: $r('sys.symbol.house_fill'), label: '首页' },
    { icon: $r('sys.symbol.message'), iconFill: $r('sys.symbol.message_fill'), label: '树洞' },
    { icon: $r('sys.symbol.book_pages'), iconFill: $r('sys.symbol.book_pages_fill'), label: '日记' },
    { icon: $r('sys.symbol.checkmark_clipboard'), iconFill: $r('sys.symbol.checkmark_clipboard_fill'), label: '自查' },
    { icon: $r('sys.symbol.person'), iconFill: $r('sys.symbol.person_fill'), label: '我的' }
  ]

  @Monitor('state.mainTabIndex')
  onMainTabIndexChanged(): void {
    // 页面侧直接改 appState().mainTabIndex（跨页切 Tab）时，驱动 HdsTabs 切换
    this.tabsController.changeIndex(this.state.mainTabIndex)
  }

  build() {
    HdsTabs({ controller: this.tabsController }) {
      TabContent() {
        HomeView()
      }
      .tabBar(this.tabBar(0))

      TabContent() {
        AIChatView()
      }
      .tabBar(this.tabBar(1))

      TabContent() {
        MoodDiaryView()
      }
      .tabBar(this.tabBar(2))

      TabContent() {
        AssessmentsView()
      }
      .tabBar(this.tabBar(3))

      TabContent() {
        MeView()
      }
      .tabBar(this.tabBar(4))
    }
    .barOverlap(true)
    .barPosition(BarPosition.End)
    .vertical(false)
    // 用户偏好：小一点、扁一点、再往下移（少占空间）
    .barHeight(Dimension.PillHeight)
    .barWidth(320)
    // 浮动栏：底部动态避让手势条 + ADAPTIVE 系统材质（沉浸光感）
    .barFloatingStyle({
      barBottomMargin: Dimension.pillMarginBottom(this.state.bottomIndicatorVp),
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
    .onChange((index: number) => {
      if (index >= 0 && index < this.tabs.length) {
        this.state.mainTabIndex = index
      }
    })
    .width('100%')
    .height('100%')
  }

  /** 官方 BottomTabBarStyle：未选中描边符号 t3 色，选中同族填充符号跟当前主题主色 */
  private tabBar(index: number): BottomTabBarStyle {
    const item: MainTabItem = this.tabs[index]
    const selected: boolean = this.state.mainTabIndex === index
    const normalIcon: SymbolGlyphModifier = new SymbolGlyphModifier(item.icon)
      .fontColor([$r('app.color.text_tertiary')])
    const selectedIcon: SymbolGlyphModifier = new SymbolGlyphModifier(item.iconFill)
      .fontColor([brand().primary])
    return new BottomTabBarStyle(
      {
        normal: normalIcon,
        selected: selected ? selectedIcon : normalIcon
      },
      item.label
    )
  }
}
