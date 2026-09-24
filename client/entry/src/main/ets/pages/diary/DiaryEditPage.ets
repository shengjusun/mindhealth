import { popRoute, resetRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { AuthService } from '../../core/auth/AppAuthService'

const TAG = 'DiaryEditPage'

interface AddDiaryRequest {
  title: string
  content: string
  emotion: string
  intensity: number
  event?: string
}

@Component
export struct DiaryEditPage {
  // 路由入参。由 RouteBuilders 里的 DiaryEditRoute 在 onReady 拿到 param 后注入，
  // 所以页面 aboutToAppear 执行时它一定已经就位（取代 router.getParams()）
  routeParam: Record<string, Object> | undefined = undefined

  @State diaryId: number = 0
  @State isEditMode: boolean = false
  @State title: string = ''
  @State content: string = ''
  @State emotion: string = '平静'
  @State intensity: number = 5
  @State eventText: string = ''
  @State isSaving: boolean = false

  // 进入页面时的快照，用于判断编辑模式下内容是否被改动
  private savedSnapshot: string = ''

  private apiService: ApiService = ApiService.getInstance()
  private authService: AuthService = AuthService.getInstance()

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }

    // 详情页跳转过来会带 diaryId，进入编辑模式并预填
    const params = this.routeParam
    if (params && params['diaryId'] !== undefined && Number(params['diaryId']) > 0) {
      this.isEditMode = true
      this.diaryId = Number(params['diaryId'])
      this.title = (params['title'] as string | undefined) ?? ''
      this.content = (params['content'] as string | undefined) ?? ''
      this.emotion = (params['emotion'] as string | undefined) ?? '平静'
      this.intensity = (params['intensity'] as number | undefined) ?? 5
      this.eventText = (params['event'] as string | undefined) ?? ''
      this.savedSnapshot = this.buildSnapshot()
    }
  }

  private buildSnapshot(): string {
    return `${this.title}|${this.content}|${this.emotion}|${this.intensity}|${this.eventText}`
  }

  private emotions: string[] = ['开心', '平静', '焦虑', '难过', '生气', '疲惫']

  private safeBack(): void {
    try {
      popRoute()
    } catch (error) {
      Logger.error(TAG, `返回失败: ${JSON.stringify(error)}`)
    }
  }

  private showMessage(message: string): void {
    ToastUtil.show(message)
  }

  private hasFormContent(): boolean {
    if (this.isEditMode) {
      return this.buildSnapshot() !== this.savedSnapshot
    }
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

      // 编辑模式走更新接口，新建模式走新增接口
      const res = this.isEditMode
        ? await this.apiService.updateDiary(String(this.diaryId), payload as Object)
        : await this.apiService.addDiary(payload as Object)

      if (res.code === 200) {
        ToastUtil.show(this.isEditMode ? '日记已更新' : '日记已保存')
        this.safeBack()
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
        title: this.isEditMode ? '编辑日记' : '写日记',
        subtitle: this.isEditMode ? '每一次修改，都是对自己的理解' : '记录今天的感受',
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
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildIntroCard() {
    Column() {
      Text('把今天的情绪写下来')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('不用写得很完美，只要真实记录此刻的感受、事件和变化就好。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
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
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      TextInput({ placeholder: '给今天的日记起个标题', text: this.title })
        .width('100%')
        .height(Dimension.InputHeight)
        .fontSize(15)
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(12)
        .onChange((value: string) => {
          this.title = value
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildEmotionCard() {
    Column() {
      Text('现在的情绪')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.emotions, (item: string) => {
          Button(item)
            .height(34)
            .fontSize(14)
            .fontColor(this.emotion === item ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
            .backgroundColor(this.emotion === item ? $r('app.color.theme_primary') : $r('app.color.surface_soft'))
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
        .fontColor($r('app.color.text_secondary'))
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
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildEventCard() {
    Column() {
      Text('触发事件')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      TextInput({ placeholder: '今天发生了什么？', text: this.eventText })
        .width('100%')
        .height(Dimension.InputHeight)
        .fontSize(15)
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(12)
        .onChange((value: string) => {
          this.eventText = value
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildContentCard() {
    Column() {
      Text('日记内容')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      TextArea({ placeholder: '写下你今天的感受、想法和状态变化...', text: this.content })
        .width('100%')
        .height(180)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(12)
        .onChange((value: string) => {
          this.content = value
        })

      Text(`${this.content.length} 字`)
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .textAlign(TextAlign.End)
        .margin({ top: 6 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  @Builder
  buildSaveButton() {
    Button(this.isSaving ? '保存中...' : (this.isEditMode ? '保存修改' : '保存日记'))
      .width('100%')
      .height(Dimension.ButtonHeight)
      .fontSize(16)
      .fontColor($r('app.color.text_on_primary'))
      .backgroundColor(this.isSaving ? $r('app.color.text_tertiary') : $r('app.color.theme_primary'))
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

    resetRoute('LoginPage')
    return false
  }
}