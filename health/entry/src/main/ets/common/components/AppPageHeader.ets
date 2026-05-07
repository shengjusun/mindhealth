import router from '@ohos.router'
import { LightTheme, Dimension } from '../constants/Theme'

@Component
export struct AppPageHeader {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop showBack: boolean = false
  @Prop actionText: string = ''
  @Prop useDefaultBack: boolean = true

  private handleBack(): void {
    if (!this.useDefaultBack) {
      return
    }

    try {
      router.back()
    } catch (error) {
      console.error(`AppPageHeader back error: ${JSON.stringify(error)}`)
    }
  }

  build() {
    Row() {
      if (this.showBack) {
        Row() {
          Text('←')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(LightTheme.TextPrimary)
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .borderRadius(20)
        .backgroundColor('#FFFFFF')
        .onClick(() => {
          this.handleBack()
        })
      } else {
        Blank()
          .width(40)
      }

      Column() {
        Text(this.title)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightTheme.TextPrimary)

        if (this.subtitle && this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(11)
            .fontColor('#8B95A7')
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      if (this.actionText && this.actionText.length > 0) {
        Text(this.actionText)
          .width(40)
          .fontSize(12)
          .fontColor(LightTheme.Primary)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.End)
      } else {
        Blank()
          .width(40)
      }
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 14,
      bottom: 10
    })
    .backgroundColor(LightTheme.Background)
  }
}