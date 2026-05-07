import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'

const TAG = 'DiaryEditPage'

interface AddDiaryRequest {
  title: string
  content: string
  emotion: string
  intensity: number
  event?: string
}

@Entry
@Component
struct DiaryEditPage {
  @State title: string = ''
  @State content: string = ''
  @State emotion: string = '平静'
  @State intensity: number = 5
  @State eventText: string = ''
  @State isSaving: boolean = false

  private apiService: ApiService = ApiService.getInstance()
  private authService: AuthService = AuthService.getInstance()

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }
  }

  private emotions: string[] = ['开心', '平静', '焦虑', '难过', '生气', '疲惫']

  private safeBack(): void {
    try {
      router.back()
    } catch (error) {
      Logger.error(TAG, `返回失败: ${JSON.stringify(error)}`)
    }
  }

  private showMessage(message: string): void {
    AlertDialog.show({
      title: '提示',
      message: message,
      primaryButton: {
        value: '知道了',
        action: () => {}
      }
    })
  }

  private hasFormContent(): boolean {
    return this.title.trim().length > 0 ||
      this.content.trim().length > 0 ||
      this.eventText.trim().length > 0 ||
      this.emotion !== '平静' ||
      this.intensity !== 5
  }

  onBackPress(): boolean {
    if (!this.hasFormContent()) {
      this.safeBack()
      return true
    }

    AlertDialog.show({
      title: '提示',
      message: '当前内容尚未保存，确定返回吗？',
      primaryButton: {
        value: '返回',
        action: () => {
          this.safeBack()
        }
      },
      secondaryButton: {
        value: '继续编辑',
        action: () => {}
      }
    })
    return true
  }

  private async saveDiary(): Promise<void> {
    if (this.title.trim().length === 0) {
      this.showMessage('标题不能为空')
      return
    }

    if (this.content.trim().length === 0) {
      this.showMessage('请输入日记内容')
      return
    }

    this.isSaving = true

    try {
      const payload: AddDiaryRequest = {
        title: this.title.trim(),
        content: this.content.trim(),
        emotion: this.emotion,
        intensity: this.intensity,
        event: this.eventText.trim()
      }

      const res = await this.apiService.addDiary(payload as Object)

      if (res.code === 200) {
        AlertDialog.show({
          title: '保存成功',
          message: '日记已保存',
          primaryButton: {
            value: '好的',
            action: () => {
              this.safeBack()
            }
          }
        })
      } else {
        this.showMessage(res.message ? res.message : '保存失败，请稍后重试')
      }
    } catch (error) {
      Logger.error(TAG, `保存日记失败: ${JSON.stringify(error)}`)
      this.showMessage('网络异常，请稍后重试')
    } finally {
      this.isSaving = false
    }
  }

  build() {
    Column() {
      AppPageHeader({
        title: '写日记',
        subtitle: '记录今天的感受',
        showBack: true
      })

      Scroll() {
        Column() {
          this.buildIntroCard()
          this.buildTitleCard()
          this.buildEmotionCard()
          this.buildEventCard()
          this.buildContentCard()
          this.buildSaveButton()

          Blank()
            .height(24)
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: Dimension.SpaceS,
          bottom: Dimension.SpaceXXL
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightTheme.Background)
  }

  @Builder
  buildIntroCard() {
    Column() {
      Text('把今天的情绪写下来')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')

      Text('不用写得很完美，只要真实记录此刻的感受、事件和变化就好。')
        .fontSize(14)
        .fontColor(LightTheme.TextSecondary)
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(LightTheme.Card)
    .borderRadius(18)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildTitleCard() {
    Column() {
      Text('标题')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')
        .margin({ bottom: 12 })

      TextInput({ placeholder: '给今天的日记起个标题', text: this.title })
        .width('100%')
        .height(Dimension.InputHeight)
        .fontSize(15)
        .backgroundColor(LightTheme.SurfaceSoft)
        .borderRadius(12)
        .onChange((value: string) => {
          this.title = value
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildEmotionCard() {
    Column() {
      Text('现在的情绪')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')
        .margin({ bottom: 12 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.emotions, (item: string) => {
          Button(item)
            .height(34)
            .fontSize(14)
            .fontColor(this.emotion === item ? '#FFFFFF' : LightTheme.TextSecondary)
            .backgroundColor(this.emotion === item ? LightTheme.Primary : LightTheme.SurfaceSoft)
            .borderRadius(17)
            .margin({ right: 8, bottom: 8 })
            .onClick(() => {
              this.emotion = item
            })
        })
      }
      .width('100%')

      Text(`情绪强度：${this.intensity}/10`)
        .fontSize(14)
        .fontColor(LightTheme.TextSecondary)
        .width('100%')
        .margin({ top: 12, bottom: 8 })

      Slider({
        value: this.intensity,
        min: 1,
        max: 10,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .onChange((value: number) => {
          this.intensity = Math.round(value)
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildEventCard() {
    Column() {
      Text('触发事件')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')
        .margin({ bottom: 12 })

      TextInput({ placeholder: '今天发生了什么？', text: this.eventText })
        .width('100%')
        .height(Dimension.InputHeight)
        .fontSize(15)
        .backgroundColor(LightTheme.SurfaceSoft)
        .borderRadius(12)
        .onChange((value: string) => {
          this.eventText = value
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildContentCard() {
    Column() {
      Text('日记内容')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')
        .margin({ bottom: 12 })

      TextArea({ placeholder: '写下你今天的感受、想法和状态变化...', text: this.content })
        .width('100%')
        .height(180)
        .fontSize(15)
        .fontColor(LightTheme.TextPrimary)
        .backgroundColor(LightTheme.SurfaceSoft)
        .borderRadius(12)
        .onChange((value: string) => {
          this.content = value
        })

      Text(`${this.content.length} 字`)
        .fontSize(12)
        .fontColor(LightTheme.TextTertiary)
        .width('100%')
        .textAlign(TextAlign.End)
        .margin({ top: 6 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildSaveButton() {
    Button(this.isSaving ? '保存中...' : '保存日记')
      .width('100%')
      .height(Dimension.ButtonHeight)
      .fontSize(16)
      .fontColor('#FFFFFF')
      .backgroundColor(this.isSaving ? LightTheme.TextTertiary : LightTheme.Primary)
      .borderRadius(24)
      .enabled(!this.isSaving)
      .onClick(() => {
        if (!this.isSaving) {
          this.saveDiary()
        }
      })
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}