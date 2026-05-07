import router from '@ohos.router'
import { LightTheme, Dimension } from '../../common/constants/Theme'

@Entry
@Component
struct HelpFeedbackPage {
  @State feedbackText: string = ''

  private goBack(): void {
    router.back()
  }

  private submitFeedback(): void {
    if (!this.feedbackText || this.feedbackText.trim().length === 0) {
      AlertDialog.show({
        title: '提示',
        message: '请先输入反馈内容。',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
      return
    }

    AlertDialog.show({
      title: '提交成功',
      message: '反馈已提交。当前演示版先做本地提交提示，后续可接后端接口。',
      primaryButton: {
        value: '知道了',
        action: () => {}
      }
    })

    this.feedbackText = ''
  }

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column() {
          this.buildFAQCard()
          this.buildFeedbackCard()

          Blank()
            .height(24)
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 8,
          bottom: Dimension.SpaceXXL
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Text('←')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .onClick(() => {
        this.goBack()
      })

      Column() {
        Text('帮助与反馈')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Text('常见问题与意见提交')
          .fontSize(11)
          .fontColor('#8B95A7')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Blank()
        .width(40)
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 14,
      bottom: 10
    })
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildFAQCard() {
    Column() {
      Text('常见问题')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 14 })

      this.buildQuestionItem('为什么我的测评结果没有显示在记录里？', '当前版本测评结果还没有真正保存成历史记录，后续会补本地存储或后端保存。')
      this.buildQuestionItem('为什么日记数量有时不准确？', '这通常是统计口径或数据源不一致导致，后续会统一按真实日记数据统计。')
      this.buildQuestionItem('这个项目的目标是什么？', '这是一个用于实习面试展示的 HarmonyOS NEXT 全栈心理健康项目，重点展示前后端联调、页面能力和业务闭环。')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildQuestionItem(question: string, answer: string) {
    Column() {
      Text(question)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
        .width('100%')

      Text(answer)
        .fontSize(13)
        .fontColor('#6B7280')
        .lineHeight(21)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .margin({ bottom: 14 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildFeedbackCard() {
    Column() {
      Text('意见反馈')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 14 })

      Text('把你遇到的问题、想优化的地方或者页面建议写在这里。')
        .fontSize(13)
        .fontColor('#6B7280')
        .width('100%')
        .margin({ bottom: 12 })

      TextArea({
        text: this.feedbackText,
        placeholder: '请输入你的反馈内容'
      })
        .width('100%')
        .height(140)
        .fontSize(14)
        .fontColor('#1F2937')
        .backgroundColor('#F8FAFC')
        .borderRadius(16)
        .padding(12)
        .onChange((value: string) => {
          this.feedbackText = value
        })

      Button('提交反馈')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor(LightTheme.Primary)
        .borderRadius(23)
        .margin({ top: 16 })
        .onClick(() => {
          this.submitFeedback()
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }
}