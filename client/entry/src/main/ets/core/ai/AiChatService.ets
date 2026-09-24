import { http } from '@kit.NetworkKit'
import { Logger } from '../../common/utils/Logger'

const TAG: string = 'AiChatService'

// AI 请求走 AGC 云函数中转站，DeepSeek Key 只存在云端环境变量里，不在客户端
// 部署方法见 docs/AGC-创建配置指南.md 第五章
const AI_PROXY_URL: string = ''   // 填云函数 HTTP 触发器 URL，如 https://xxxx.cloudfunctions.cn/qingxin-ai-proxy
const AI_APP_KEY: string = ''     // 与云函数环境变量 APP_ACCESS_KEY 保持一致

export interface AiChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

interface AiChatRequestBody {
  messages: AiChatMessage[]
}

interface AiChatChoiceMessage {
  role?: string
  content: string
}

interface AiChatChoice {
  index?: number
  message: AiChatChoiceMessage
  finish_reason?: string
}

interface AiChatResponse {
  choices: AiChatChoice[]
}

interface AiChatErrorDetail {
  message?: string
  type?: string
  code?: string
}

interface AiChatErrorResponse {
  error?: AiChatErrorDetail
  message?: string
}

export class AiChatService {
  private static instance: AiChatService

  private constructor() {}

  public static getInstance(): AiChatService {
    if (!AiChatService.instance) {
      AiChatService.instance = new AiChatService()
    }
    return AiChatService.instance
  }

  /**
   * 发送 AI 对话请求（经云端中转）
   * 成功时返回 assistant 回复内容
   * 失败时抛出 Error，由页面统一提示
   */
  public async sendMessage(messages: AiChatMessage[]): Promise<string> {
    if (AI_PROXY_URL.length === 0 || AI_APP_KEY.length === 0) {
      throw new Error('AI 中转站未配置，请按 docs/AGC-创建配置指南.md 部署后填写')
    }

    const requestBody: AiChatRequestBody = {
      messages: messages
    }

    const httpRequest: http.HttpRequest = http.createHttp()

    try {
      Logger.info(TAG, `AI 请求消息数: ${messages.length}`)

      const response: http.HttpResponse = await httpRequest.request(AI_PROXY_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'X-App-Key': AI_APP_KEY
        },
        extraData: JSON.stringify(requestBody),
        connectTimeout: 30000,
        readTimeout: 60000
      })

      const responseText: string = response.result ? String(response.result) : ''

      Logger.info(TAG, `AI HTTP状态码: ${response.responseCode}`)

      if (response.responseCode !== 200) {
        const errorMessage: string = this.parseErrorMessage(response.responseCode, responseText)
        throw new Error(errorMessage)
      }

      const parsed: AiChatResponse = JSON.parse(responseText) as AiChatResponse

      if (!parsed.choices || parsed.choices.length === 0) {
        throw new Error('AI 服务返回为空，没有 choices')
      }

      const content: string = parsed.choices[0].message.content

      if (!content || content.length === 0) {
        throw new Error('AI 回复内容为空')
      }

      return content
    } catch (error) {
      const errorMessage: string = error instanceof Error ? error.message : JSON.stringify(error)
      Logger.error(TAG, `AI 请求异常: ${errorMessage}`)
      throw new Error(errorMessage)
    } finally {
      try {
        httpRequest.destroy()
      } catch (destroyError) {
        Logger.error(TAG, `销毁 AI httpRequest 失败: ${JSON.stringify(destroyError)}`)
      }
    }
  }

  /**
   * 解析中转站/模型服务错误信息
   */
  private parseErrorMessage(responseCode: number, responseText: string): string {
    if (!responseText || responseText.length === 0) {
      return `AI 请求失败，HTTP状态码=${responseCode}`
    }

    try {
      const errObj: AiChatErrorResponse = JSON.parse(responseText) as AiChatErrorResponse

      if (errObj.error && errObj.error.message) {
        return errObj.error.message
      }

      if (errObj.message) {
        return errObj.message
      }

      return `AI 请求失败，HTTP状态码=${responseCode}`
    } catch (parseError) {
      return `AI 请求失败，HTTP状态码=${responseCode}`
    }
  }
}
