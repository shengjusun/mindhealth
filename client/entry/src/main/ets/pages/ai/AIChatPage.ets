import { AppPageHeader } from '../../common/components/AppPageHeader'
import { brand, Dimension, FontLevel, Motion } from '../../common/constants/Theme'
import { appState } from '../../common/state/AppState'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'
import { resetRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { AppButton } from '../../common/components/AppButton'
import { promptAction } from '@kit.ArkUI'

const TAG = 'AIChatPage'

// 空历史时展示的欢迎语；清空记录后也要复位到它
const WELCOME_TEXT: string = '你好呀，我是轻心。你可以把今天发生的事慢慢说给我听。'

interface ChatMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  timeText: string
}

// 后端 POST /api/ai/chat 的请求体，对应后端 AIChatRequest
interface AIChatRequest {
  content: string
}

// 后端 POST /api/ai/chat 返回的 data 结构
interface AIChatReply {
  response: string
}

// 后端 GET /api/ai/history 返回的 data 项，对应后端 AIChat 实体
interface AIChatRecord {
  id: number
  userId: number
  content: string
  aiResponse: string
  createTime: string
}

// 树洞聊天视图：作为 MainPage 的 Tab 子组件使用（消息状态常驻不丢失）
@ComponentV2
export struct AIChatView {
  @Local isLoading: boolean = false
  @Local isThinking: boolean = false
  @Local inputText: string = ''
  @Local messageList: ChatMessage[] = [
    {
      id: 'welcome',
      role: 'assistant',
      content: WELCOME_TEXT,
      timeText: '刚刚'
    }
  ]

  private authService: AuthService = AuthService.getInstance()
  private apiService: ApiService = ApiService.getInstance()
  // 消息列表滚动控制器：新消息到达后自动滚到底部
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }
    // 进页面即回填服务端历史；拉不到就静默降级，只留欢迎语
    this.loadHistory()
  }

  private makeMessageId(prefix: string): string {
    return prefix + '_' + Date.now().toString() + '_' + Math.floor(Math.random() * 100000).toString()
  }

  private appendMessages(items: ChatMessage[]): void {
    // 状态变化包进 animateTo，配合气泡上的 .transition 实现弹入
    this.getUIContext().animateTo({ duration: Motion.Normal, curve: Motion.springStandard }, () => {
      this.messageList = this.messageList.concat(items)
    })
    // 等布局完成后再滚动到底部，带动画更自然
    setTimeout(() => {
      this.listScroller.scrollToIndex(this.messageList.length - 1, true)
    }, 100)
  }

  build() {
    Column() {
      AppPageHeader({
        title: '轻心树洞',
        subtitle: '把想法慢慢说出来',
        actionText: '放下这些话',
        onAction: () => {
          this.handleClearHistory()
        }
      })

      List({ scroller: this.listScroller }) {
        ForEach(this.messageList, (item: ChatMessage) => {
          ListItem() {
            this.buildMessageItem(item)
          }
        }, (item: ChatMessage) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({
        left: 16,
        right: 16,
        top: 10,
        bottom: 10
      })
      .scrollBar(BarState.Off)

      if (this.isThinking) {
        this.buildThinkingView()
      }

      this.buildInputArea()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildAvatarBubble(text: string, bgColor: ResourceColor, fontColor: ResourceColor) {
    Row() {
      Text(text)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(fontColor)
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor(bgColor)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    // HTML：头像与气泡顶端对齐 + 2vp 微调
    .margin({ top: 2 })
  }

  @Builder
  buildThinkingView() {
    Row() {
      this.buildAvatarBubble('轻', brand().tagBlue, brand().primary)

      Row() {
        Text('轻心正在思考')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        LoadingProgress()
          .width(14)
          .height(14)
          .color(brand().primary)
          .margin({ left: 8 })
      }
      .backgroundColor($r('app.color.app_card'))
      .padding({
        left: Dimension.SpaceL,
        right: Dimension.SpaceL,
        top: Dimension.SpaceM,
        bottom: Dimension.SpaceM
      })
      .borderRadius(Dimension.RadiusL)
      .margin({ left: Dimension.SpaceM })
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      bottom: 8
    })
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  buildMessageItem(item: ChatMessage) {
    Row() {
      if (item.role === 'assistant') {
        this.buildAvatarBubble('轻', brand().tagBlue, brand().primary)

        // HTML msg-bubble：max-width 74%、radius 16、左上角收小成"说话方向"
        Text(item.content)
          .fontSize(16)
          .lineHeight(26)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.app_card'))
          .padding({
            left: Dimension.SpaceL,
            right: Dimension.SpaceL,
            top: Dimension.SpaceM,
            bottom: Dimension.SpaceM
          })
          .borderRadius({
            topLeft: Dimension.RadiusXS,
            topRight: Dimension.RadiusL,
            bottomLeft: Dimension.RadiusL,
            bottomRight: Dimension.RadiusL
          })
          .constraintSize({ maxWidth: '74%' })
          .margin({ left: Dimension.SpaceM })
      } else {
        Blank()
          .layoutWeight(1)

        Text(item.content)
          .fontSize(16)
          .lineHeight(26)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor(brand().primary)
          .padding({
            left: Dimension.SpaceL,
            right: Dimension.SpaceL,
            top: Dimension.SpaceM,
            bottom: Dimension.SpaceM
          })
          .borderRadius({
            topLeft: Dimension.RadiusL,
            topRight: Dimension.RadiusXS,
            bottomLeft: Dimension.RadiusL,
            bottomRight: Dimension.RadiusL
          })
          .constraintSize({ maxWidth: '74%' })
          .margin({ right: Dimension.SpaceM })

        this.buildAvatarBubble('我', brand().primary, $r('app.color.text_on_primary'))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(item.role === 'assistant' ? FlexAlign.Start : FlexAlign.End)
    .margin({ bottom: Dimension.SpaceL })
    // 新消息从下方弹入、退场淡出（transition 在 appendMessages 的 animateTo 中触发）
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 12 })),
      TransitionEffect.OPACITY
    ).animation({ curve: Motion.springStandard }))
  }

  @Builder
  buildInputArea() {
    Row() {
      TextInput({
        text: this.inputText,
        placeholder: this.isLoading ? '轻心正在回复中...' : '输入你想说的话...'
      })
        .layoutWeight(1)
        .height(Dimension.InputHeight)
        .fontSize(FontLevel.Body)
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(Dimension.RadiusFull)
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL
        })
        .onChange((val: string) => {
          this.inputText = val
        })

      // 图标型主按钮（HTML 例外类）：44×44 圆形主色底
      AppButton({
        label: '发',
        kind: 'icon',
        outerMargin: { left: 10 },
        loading: this.isLoading,
        active: !this.isLoading,
        onPress: () => {
          this.handleSend()
        }
      })
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: Dimension.SpaceM,
      bottom: Dimension.SpaceL
    })
    // 原来是硬编码 Color.White，深色模式下是一块惨白；改用资源色随深浅色切换
    .backgroundColor($r('app.color.app_surface'))
    // 输入区是固定底栏，需要整体抬到悬浮胶囊栏上方，否则被栏盖住
    .margin({ bottom: Dimension.PillHeight + Dimension.pillMarginBottom(appState().bottomIndicatorVp) })
  }

  private async handleSend(): Promise<void> {
    if (this.isLoading) {
      promptAction.showToast({
        message: '轻心正在回复中',
        duration: 2000
      })
      return
    }

    const text: string = this.inputText.trim()

    if (text.length === 0) {
      promptAction.showToast({
        message: '请输入内容',
        duration: 2000
      })
      return
    }

    const userMsg: ChatMessage = {
      id: this.makeMessageId('user'),
      role: 'user',
      content: text,
      timeText: '刚刚'
    }

    this.inputText = ''
    this.isLoading = true
    this.isThinking = true

    this.appendMessages([userMsg])

    try {
      Logger.info(TAG, `准备请求 AI 服务，内容长度=${text.length}`)

      // 后端 AIChatRequest 只接收 content；system prompt 与对话上下文由后端负责
      const reqBody: AIChatRequest = { content: text }
      const res = await this.apiService.sendMessage(reqBody)

      // 后端统一以 HTTP 200 返回，业务失败体现在 code != 200（如 400 请求过于频繁）
      if (res.code !== 200) {
        throw new Error(res.message && res.message.length > 0 ? res.message : 'AI 请求失败')
      }

      const reply: AIChatReply = res.data as AIChatReply
      const fullReply: string = reply && reply.response ? reply.response : ''

      Logger.info(TAG, `AI 回复长度=${fullReply.length}`)

      const replyText: string = fullReply.trim().length > 0
        ? fullReply.trim()
        : '我刚刚有点没想好，可以再和我说一遍吗？'

      const aiMsg: ChatMessage = {
        id: this.makeMessageId('assistant'),
        role: 'assistant',
        content: replyText,
        timeText: '刚刚'
      }

      this.appendMessages([aiMsg])
    } catch (error) {
      // 如实透出失败原因：后端限流会返回「请求过于频繁」这类 message，
      // 比笼统的「发送失败」更能让用户判断该稍等还是该检查网络
      const errText: string = error instanceof Error && error.message.length > 0
        ? error.message
        : '我刚刚没有连接上服务，可以稍后再试一下。'

      Logger.error(TAG, `AI请求出错: ${errText}`)

      const errorMsg: ChatMessage = {
        id: this.makeMessageId('assistant_error'),
        role: 'assistant',
        content: errText,
        timeText: '刚刚'
      }

      this.appendMessages([errorMsg])

      promptAction.showToast({
        message: errText,
        duration: 3000
      })
    } finally {
      this.isLoading = false
      this.isThinking = false
    }
  }

  /**
   * 拉取服务端历史并回填消息列表。
   *
   * 失败或为空一律静默降级：历史拉不到不是用户需要处理的错误，
   * 保留欢迎语即可，不弹任何提示打断聊天。
   */
  private async loadHistory(): Promise<void> {
    try {
      const res = await this.apiService.getChatHistory()

      if (res.code !== 200 || !Array.isArray(res.data)) {
        return
      }

      const records: AIChatRecord[] = res.data as AIChatRecord[]

      if (records.length === 0) {
        return
      }

      // 后端未保证顺序，这里按 createTime 升序，保证时间线是对的
      records.sort((a: AIChatRecord, b: AIChatRecord): number => {
        const left: string = a.createTime ? String(a.createTime) : ''
        const right: string = b.createTime ? String(b.createTime) : ''
        if (left === right) {
          return 0
        }
        return left < right ? -1 : 1
      })

      const history: ChatMessage[] = []

      for (let i = 0; i < records.length; i++) {
        const record: AIChatRecord = records[i]
        const timeText: string = this.formatHistoryTime(record.createTime)

        // 一条记录含一问一答，拆成 user / assistant 两条消息
        if (record.content && record.content.length > 0) {
          history.push({
            id: `history_user_${record.id}`,
            role: 'user',
            content: record.content,
            timeText: timeText
          })
        }

        if (record.aiResponse && record.aiResponse.length > 0) {
          history.push({
            id: `history_ai_${record.id}`,
            role: 'assistant',
            content: record.aiResponse,
            timeText: timeText
          })
        }
      }

      if (history.length === 0) {
        return
      }

      this.messageList = history

      setTimeout(() => {
        this.listScroller.scrollToIndex(this.messageList.length - 1, false)
      }, 100)
    } catch (error) {
      Logger.error(TAG, `加载历史失败，保留欢迎语: ${JSON.stringify(error)}`)
    }
  }

  /** 后端 createTime 形如 2026-09-26T20:29:44，这里裁成 MM-DD HH:mm */
  private formatHistoryTime(createTime: string): string {
    const raw: string = createTime ? String(createTime) : ''

    if (raw.length < 16) {
      return ''
    }

    return `${raw.substring(5, 10)} ${raw.substring(11, 16)}`
  }

  /** 产品温度：确认式清空（此前点击立即删除且无确认，审计 5-1） */
  private handleClearHistory(): void {
    AlertDialog.show({
      title: '放下这些话？',
      message: '清空后聊天不会保留，我们可以从新的一段开始。',
      primaryButton: {
        value: '再想想',
        action: () => {}
      },
      secondaryButton: {
        value: '放下',
        action: () => {
          this.doClearHistory()
        }
      }
    })
  }

  private async doClearHistory(): Promise<void> {
    try {
      const res = await this.apiService.deleteChatHistory()

      if (res.code !== 200) {
        promptAction.showToast({
          message: res.message && res.message.length > 0 ? res.message : '清空失败，请稍后重试',
          duration: 2000
        })
        return
      }

      this.messageList = [
        {
          id: 'welcome',
          role: 'assistant',
          content: WELCOME_TEXT,
          timeText: '刚刚'
        }
      ]

      promptAction.showToast({
        message: '已清空',
        duration: 2000
      })
    } catch (error) {
      const errText: string = error instanceof Error && error.message.length > 0
        ? error.message
        : '清空失败，请稍后重试'

      Logger.error(TAG, `清空历史失败: ${errText}`)

      promptAction.showToast({
        message: errText,
        duration: 3000
      })
    }
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    resetRoute('LoginPage')

    return false
  }
}

