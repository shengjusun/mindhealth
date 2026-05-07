import { http } from '@kit.NetworkKit'
import { Logger } from '../../common/utils/Logger'

const TAG: string = 'AiChatService'

// 这里先放你的模型服务 Key，后续建议迁移到 Spring Boot 后端代理
const AI_API_KEY: string = 'sk-e7cfd567912f4ce9b7f7e09d1e637267'
const AI_API_URL: string = 'https://api.deepseek.com/v1/chat/completions'
const AI_MODEL: string = 'deepseek-chat'

export interface AiChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

interface AiChatRequestBody {
  model: string
  messages: AiChatMessage[]
  temperature: number
  max_tokens: number
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
  id?: string
  object?: string
  created?: number
  model?: string
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
   * 发送 AI 对话请求
   * 成功时返回 assistant 回复内容
   * 失败时抛出 Error，由页面统一提示
   */
  public async sendMessage(messages: AiChatMessage[]): Promise<string> {
    const apiKey: string = AI_API_KEY

    if (apiKey.length === 0) {
      throw new Error('AI 服务 Key 为空，请先填写真实 Key')
    }

    const requestBody: AiChatRequestBody = {
      model: AI_MODEL,
      messages: messages,
      temperature: 0.7,
      max_tokens: 500
    }

    const httpRequest: http.HttpRequest = http.createHttp()

    try {
      Logger.info(TAG, `AI 请求消息数: ${messages.length}`)

      const response: http.HttpResponse = await httpRequest.request(AI_API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`
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
   * 解析模型服务错误信息
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
      return `AI 请求失败，HTTP状态码=${responseCode}，返回=${responseText}`
    }
  }
}