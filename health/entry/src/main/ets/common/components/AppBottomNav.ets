import router from '@ohos.router'
import { LightTheme, Dimension, ShadowStyle } from '../constants/Theme'

// 底部导航每一项的数据结构
export interface BottomNavItem {
  id: string       // 当前 tab 的唯一标识，比如 home、diary、me
  icon: string     // 图标，这里暂时用 emoji 表示
  label: string    // 底部显示的文字
  targetUrl: string // 点击后跳转的目标页面
}

@Component
export struct AppBottomNav {
  // 父页面传进来的当前选中 tab
  // 比如首页传 home，我的页面传 me
  @Prop currentTab: string = ''

  // 底部导航数据
  // 后续如果要新增 tab，只需要在这里加一项
  private navItems: BottomNavItem[] = [
    { id: 'home', icon: '🏠', label: '首页', targetUrl: 'pages/home/HomePageNew' },
    { id: 'chat', icon: '💬', label: '树洞', targetUrl: 'pages/ai/AIChatPage' },
    { id: 'diary', icon: '📔', label: '日记', targetUrl: 'pages/diary/MoodDiaryPage' },
    { id: 'assess', icon: '📋', label: '自查', targetUrl: 'pages/assessment/AssessmentsPage' },
    { id: 'me', icon: '👤', label: '我的', targetUrl: 'pages/me/MePage' }
  ]

  // 点击底部导航时触发
  private handleNavClick(item: BottomNavItem): void {
    // 如果点击的是当前页面，就不重复跳转
    if (this.currentTab === item.id) {
      return
    }

    // 底部一级导航使用 replaceUrl，避免页面栈不断堆叠
    router.replaceUrl({ url: item.targetUrl })
  }

  build() {
    Row() {
      // 根据 navItems 数组循环渲染 5 个底部导航项
      ForEach(this.navItems, (item: BottomNavItem) => {
        Column() {
          Column() {
            Text(item.icon)
              .fontSize(this.currentTab === item.id ? 22 : 21)
              .opacity(this.currentTab === item.id ? 1 : 0.72)

            Text(item.label)
              .fontSize(Dimension.FontXS)
              .fontColor(this.currentTab === item.id ? LightTheme.NavActive : LightTheme.NavInactive)
              .fontWeight(this.currentTab === item.id ? FontWeight.Medium : FontWeight.Normal)
              .margin({ top: 2 })
          }
          .width(58)
          .height(52)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          // 当前 tab 选中时，给图标和文字整体加背景色
          .backgroundColor(this.currentTab === item.id ? '#EAF3FF' : Color.Transparent)
          .borderRadius(18)
        }
        .width('20%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => {
          this.handleNavClick(item)
        })
      })
    }
    .width('100%')
    .height(Dimension.BottomNavHeight)
    .backgroundColor(LightTheme.NavBackground)
    .borderRadius({ topLeft: 18, topRight: 18 })
    .shadow(ShadowStyle.Light)
  }
}