import { AppPageHeader } from '../../common/components/AppPageHeader'
import { LightTheme } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'
import router from '@ohos.router'
import { AiChatService, AiChatMessage } from '../../core/ai/AiChatService'
import { AppBottomNav } from '../../common/components/AppBottomNav'
import { promptAction } from '@kit.ArkUI'

const TAG = 'AIChatPage'

interface ChatMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  timeText: string
}

@Entry
@Component
struct AIChatPage {
  @State currentTab: string = 'chat'
  @State isLoading: boolean = false
  @State isThinking: boolean = false
  @State inputText: string = ''
  @State messageList: ChatMessage[] = [
    {
      id: 'welcome',
      role: 'assistant',
      content: '你好呀，我是轻心。你可以把今天发生的事慢慢说给我听。',
      timeText: '刚刚'
    }
  ]

  private authService: AuthService = AuthService.getInstance()
  private aiChatService: AiChatService = AiChatService.getInstance()

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }
  }

  private makeMessageId(prefix: string): string {
    return prefix + '_' + Date.now().toString() + '_' + Math.floor(Math.random() * 100000).toString()
  }

  private appendMessages(items: ChatMessage[]): void {
    this.messageList = this.messageList.concat(items)
  }

  build() {
    Column() {
      AppPageHeader({
        title: '轻心树洞',
        subtitle: '把想法慢慢说出来'
      })

      List() {
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

      AppBottomNav({
        currentTab: this.currentTab
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightTheme.Background)
  }

  @Builder
  buildAvatarBubble(text: string, bgColor: ResourceColor, fontColor: ResourceColor) {
    Row() {
      Text(text)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(fontColor)
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .backgroundColor(bgColor)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  buildThinkingView() {
    Row() {
      this.buildAvatarBubble('轻', '#EAF3FF', '#007ACC')

      Text('轻心正在思考...')
        .fontSize(14)
        .fontColor(LightTheme.TextSecondary)
        .backgroundColor('#F0F0F0')
        .padding(12)
        .borderRadius(12)
        .margin({ left: 10 })
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
        this.buildAvatarBubble('轻', '#EAF3FF', '#007ACC')

        Column() {
          Text(item.content)
            .fontSize(16)
            .fontColor('#1F2937')
            .backgroundColor('#F0F0F0')
            .padding(12)
            .borderRadius(12)
            .maxLines(1000)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 10 })
      } else {
        Blank()
          .layoutWeight(1)

        Column() {
          Text(item.content)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor('#007ACC')
            .padding(12)
            .borderRadius(12)
            .maxLines(1000)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.End)
        .margin({ right: 10 })

        this.buildAvatarBubble('我', '#007ACC', Color.White)
      }
    }
    .width('100%')
    .justifyContent(item.role === 'assistant' ? FlexAlign.Start : FlexAlign.End)
    .margin({
      top: 10,
      bottom: 10
    })
  }

  @Builder
  buildInputArea() {
    Row() {
      TextInput({
        text: this.inputText,
        placeholder: this.isLoading ? '轻心正在回复中...' : '输入你想说的话...'
      })
        .layoutWeight(1)
        .height(44)
        .backgroundColor('#F5F5F5')
        .borderRadius(22)
        .padding({
          left: 14,
          right: 14
        })
        .onChange((val: string) => {
          this.inputText = val
        })

      Button('发')
        .width(44)
        .height(44)
        .fontSize(14)
        .fontColor(Color.White)
        .backgroundColor(this.isLoading ? '#A0A8B8' : '#007ACC')
        .borderRadius(22)
        .margin({ left: 10 })
        .enabled(!this.isLoading)
        .onClick(() => {
          if (!this.isLoading) {
            this.handleSend()
          }
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Color.White)
  }

  private buildAiChatMessages(currentUserMsg: ChatMessage): AiChatMessage[] {
    const systemPrompt: string =
      '你是“轻心”的生活陪伴助手，语气温暖、耐心、自然。你的任务是陪用户聊日常、整理心情、记录想法和提供轻量的生活建议。' +
        '你不能提供医疗诊断、心理疾病判断、治疗建议或专业心理咨询结论。' +
        '如果用户表达严重伤害自己或他人的想法，要温和建议用户立刻联系身边可信任的人或当地紧急求助渠道。' +
        '回复要简短、具体、温和，尽量不超过 200 字。'

    const messages: AiChatMessage[] = [
      {
        role: 'system',
        content: systemPrompt
      }
    ]

    for (let i = 0; i < this.messageList.length; i++) {
      const msg = this.messageList[i]

      if (msg.id === 'welcome') {
        continue
      }

      if (msg.id.indexOf('assistant_error') === 0) {
        continue
      }

      if (!msg.content || msg.content.trim().length === 0) {
        continue
      }

      messages.push({
        role: msg.role,
        content: msg.content
      })
    }

    messages.push({
      role: 'user',
      content: currentUserMsg.content
    })

    return messages
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

    const messages: AiChatMessage[] = this.buildAiChatMessages(userMsg)

    this.inputText = ''
    this.isLoading = true
    this.isThinking = true

    this.appendMessages([userMsg])

    try {
      Logger.info(TAG, `准备请求 AI 服务，上下文条数=${messages.length}`)

      const fullReply: string = await this.aiChatService.sendMessage(messages)

      Logger.info(TAG, `AI 回复内容=${fullReply}`)

      const replyText: string = fullReply && fullReply.trim().length > 0
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
      const errText: string = error instanceof Error ? error.message : JSON.stringify(error)

      Logger.error(TAG, `AI请求出错: ${errText}`)

      const errorMsg: ChatMessage = {
        id: this.makeMessageId('assistant_error'),
        role: 'assistant',
        content: '我刚刚没有连接上服务，可以稍后再试一下。',
        timeText: '刚刚'
      }

      this.appendMessages([errorMsg])

      promptAction.showToast({
        message: 'AI 请求失败',
        duration: 3000
      })
    } finally {
      this.isLoading = false
      this.isThinking = false
    }
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({
      url: 'pages/auth/LoginPage'
    })

    return false
  }
}