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

  /** 顶部避让：优先窗口避让区高度，读不到（预览器等）回退旧值 14 */
  private topInset(): number {
    const avoid: number = appState().topAvoidVp
    return avoid > 0 ? avoid : 14
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

      if (this.actionText && this.actionText.length > 0) {
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