import { appState, popRoute } from '../state/AppState'
import { brand, Dimension, FontLevel } from '../constants/Theme'
import { Logger } from '../utils/Logger'

const TAG = 'AppPageHeader'

@ComponentV2
export struct AppPageHeader {
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param showBack: boolean = false
  @Param actionText: string = ''
  // 右上角图标按钮（如「我的」页的设置齿轮）：低频全局入口收进头部右上角是成熟 App 惯例，
  // 不占页面内容区的菜单位。与 actionText 二选一，同时传时图标优先；都不传则右侧占位对齐标题
  @Param actionIcon: Resource | undefined = undefined
  @Param useDefaultBack: boolean = true
  // 右上角文字的点击回调。默认空实现，老调用方不传即维持原来的纯展示行为
  @Param onAction: () => void = () => {}

  private handleAction(): void {
    this.onAction()
  }

  private handleBack(): void {
    if (!this.useDefaultBack) {
      return
    }

    try {
      popRoute()
    } catch (error) {
      Logger.error(TAG, `返回失败: ${JSON.stringify(error)}`)
    }
  }

  /** 顶部避让：状态栏高度 + 8vp 呼吸间距（紧贴状态栏太靠上）；读不到避让区（预览器等）回退 14+8 */
  private topInset(): number {
    const avoid: number = appState().topAvoidVp
    return (avoid > 0 ? avoid : 14) + 8
  }

  build() {
    Row() {
      if (this.showBack) {
        Row() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(22)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.handleBack()
        })
      } else {
        Blank()
          .width(40)
      }

      Column() {
        Text(this.title)
          .fontSize(FontLevel.SectionTitle)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))

        if (this.subtitle && this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      if (this.actionIcon !== undefined) {
        // 命中区域与左侧返回键一致（40×40），图标色随正文主色，深浅色模式自动跟随
        Row() {
          SymbolGlyph(this.actionIcon)
            .fontSize(22)
            .fontColor([$r('app.color.text_primary')])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.handleAction()
        })
      } else if (this.actionText && this.actionText.length > 0) {
        Text(this.actionText)
          .height(40)
          .fontSize(14)
          .fontColor(brand().primary)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.End)
          .onClick(() => {
            this.handleAction()
          })
      } else {
        Blank()
          .width(40)
      }
    }
    .width('100%')
    .height(this.topInset() + Dimension.HeaderHeight)
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: this.topInset(),
      bottom: 8
    })
    .backgroundColor($r('app.color.app_background'))
  }
}