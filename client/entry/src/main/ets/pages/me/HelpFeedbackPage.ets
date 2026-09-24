import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { Dimension } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { pasteboard } from '@kit.BasicServicesKit'

const TAG = 'HelpFeedbackPage'

// 提交反馈的请求体
interface FeedbackRequest {
  type: string
  content: string
}

@Entry
@Component
struct HelpFeedbackPage {
  @State feedbackText: string = ''
  @State isSubmitting: boolean = false

  private apiService: ApiService = ApiService.getInstance()

  private goBack(): void {
    router.back()
  }

  /**
   * 提交反馈到后端（POST /api/feedback，需登录）
   */
  private async submitFeedback(): Promise<void> {
    if (!this.feedbackText || this.feedbackText.trim().length === 0) {
      ToastUtil.show('请先输入反馈内容')
      return
    }
    if (this.isSubmitting) {
      return
    }

    this.isSubmitting = true
    try {
      const req: FeedbackRequest = {
        type: 'suggestion',
        content: this.feedbackText.trim()
      }
      const res = await this.apiService.submitFeedback(req)

      if (res.code === 200) {
        ToastUtil.show('反馈已提交，感谢你的建议')
        this.feedbackText = ''
      } else {
        ToastUtil.show(res.message ? res.message : '提交失败，请稍后重试')
      }
    } catch (error) {
      Logger.error(TAG, `提交反馈失败: ${JSON.stringify(error)}`)
      ToastUtil.show('网络异常，请稍后重试')
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column() {
          this.buildFAQCard()
          this.buildContactCard()
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
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildHeader() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.app_card'))
      .borderRadius(20)
      .onClick(() => {
        this.goBack()
      })

      Column() {
        Text('帮助与反馈')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('常见问题与意见提交')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
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
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildFAQCard() {
    Column() {
      Text('常见问题')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 14 })

      this.buildQuestionItem('测评结果会保存吗？', '会。每次提交的测评都会保存到你的账户，可在「我的 → 我的记录」里随时回看。')
      this.buildQuestionItem('日记可以修改或删除吗？', '可以。在日记列表点开任意一篇，进入详情页即可编辑或删除。')
      this.buildQuestionItem('遇到问题或想提建议怎么办？', '在下方输入框提交反馈，或者直接发邮件给开发者，都会认真看每一条。')
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(20)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildContactCard() {
    Column() {
      Text('联系我们')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 4 })

      Text('紧急问题也可以直接邮件联系开发者：')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ top: 8, bottom: 12 })

      Row() {
        Text('1073557926@qq.com')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.theme_primary'))
          .layoutWeight(1)

        Button('复制')
          .height(32)
          .fontSize(13)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.theme_primary'))
          .borderRadius(16)
          .padding({ left: 16, right: 16 })
          .onClick(() => {
            this.copyEmail()
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface_soft'))
      .borderRadius(12)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(20)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  private copyEmail(): void {
    try {
      const pasteData: pasteboard.PasteData = pasteboard.createData(
        pasteboard.MIMETYPE_TEXT_PLAIN, '1073557926@qq.com')
      pasteboard.getSystemPasteboard().setData(pasteData)
      ToastUtil.show('邮箱已复制，快去联系我们吧')
    } catch (error) {
      Logger.error(TAG, `复制邮箱失败: ${JSON.stringify(error)}`)
      ToastUtil.show('复制失败，请手动记录邮箱')
    }
  }

  @Builder
  buildQuestionItem(question: string, answer: string) {
    Column() {
      Text(question)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(answer)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
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
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 14 })

      Text('把你遇到的问题、想优化的地方或者页面建议写在这里。')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 12 })

      TextArea({
        text: this.feedbackText,
        placeholder: '请输入你的反馈内容'
      })
        .width('100%')
        .height(140)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(16)
        .padding(12)
        .onChange((value: string) => {
          this.feedbackText = value
        })

      Button(this.isSubmitting ? '提交中...' : '提交反馈')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor(this.isSubmitting ? $r('app.color.text_tertiary') : $r('app.color.theme_primary'))
        .borderRadius(23)
        .margin({ top: 16 })
        .enabled(!this.isSubmitting)
        .onClick(() => {
          this.submitFeedback()
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }
}