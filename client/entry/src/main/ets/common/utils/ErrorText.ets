import { NetworkUtil } from './NetworkUtil'

/**
 * 错误文案统一出口。
 *
 * 请求层与页面层不再各自拼「请求失败: 500」「上传失败: 403」这类技术措辞，
 * 一律从这里取人类可读文案，保证全 App 提示口径一致、对用户友好。
 *
 * 文案分层：
 *   - 网络类：按当前是否断网区分「断网」与「网络不畅」；
 *   - 服务类：服务端 5xx；
 *   - 通用类：其余请求失败 / 数据解析失败 / 操作失败；
 *   - 登录类：登录态失效统一登出。
 */
export class ErrorText {
  /** 网络不畅：设备能联网，但请求没通（超时、后端未启动、连接被拒等） */
  static network(): string {
    return NetworkUtil.isNetworkAvailable()
      ? '网络好像不太顺畅，请稍后重试'
      : '网络好像断了，请检查网络连接后重试'
  }

  /** 按 HTTP 状态码给通用文案（仅用于非 200 且非 401/403 的情况） */
  static byHttpCode(httpCode: number): string {
    if (httpCode >= 500) {
      return ErrorText.server()
    }
    return ErrorText.request()
  }

  /** 服务端异常（5xx） */
  static server(): string {
    return '服务暂时不可用，请稍后再试'
  }

  /** 通用请求失败 */
  static request(): string {
    return '请求没成功，请稍后再试'
  }

  /** 响应数据解析失败 */
  static parse(): string {
    return '数据加载失败，请稍后再试'
  }

  /** 通用操作失败（如上传、保存等主动操作） */
  static action(): string {
    return '操作失败，请稍后再试'
  }

  /** 登录态失效（无业务说明可展示时） */
  static loginExpired(): string {
    return '登录已过期，请重新登录'
  }
}
