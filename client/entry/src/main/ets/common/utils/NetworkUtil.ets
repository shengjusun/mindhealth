import { connection } from '@kit.NetworkKit'
import { Logger } from './Logger'

const TAG = 'NetworkUtil'

/**
 * 网络连通性工具。
 *
 * 用来把笼统的「请求失败」进一步区分为「设备断网」还是「网络/服务侧问题」，
 * 这样提示才能说人话，而不是把错误码直接甩给用户。
 *
 * 依赖 ohos.permission.GET_NETWORK_INFO（已在 module.json5 声明）。
 */
export class NetworkUtil {
  /**
   * 设备当前是否有可用网络（默认网络是否已连接）。
   * 检测本身抛异常时保守返回 true：不武断判定为断网，
   * 交由后续请求的真实结果决定提示内容，避免误报。
   */
  static isNetworkAvailable(): boolean {
    try {
      return connection.hasDefaultNetSync()
    } catch (error) {
      Logger.warn(TAG, `检测网络状态失败: ${JSON.stringify(error)}`)
      return true
    }
  }

  /** 网络是否不可用，语义更直观 */
  static isNetworkUnavailable(): boolean {
    return !NetworkUtil.isNetworkAvailable()
  }
}
