/**
 * 华为账号登录服务（Account Kit / Login Kit）
 * 职责单一：拉起华为账号授权，拿一次性 authorizationCode
 * 换 token、建账号、签发系统 JWT 全部由后端完成（见 /api/user/huawei/login）
 */
import { authentication } from '@kit.AccountKit'
import { bundleManager } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0xFF00
const TAG = 'HuaweiIdService'

export class HuaweiIdService {
  /**
   * 把授权失败的错误码映射成用户能看懂的话（错误码见 @hms.core.account.LoginComponent / authentication 文档）
   */
  public static mapErrorCode(code: number): string {
    if (code === 1001502012) {
      // 用户主动取消授权，不打扰
      return '已取消华为账号登录'
    }
    if (code === 1001502001) {
      return '请先登录华为账号'
    }
    if (code === 1001502003) {
      // PARAMETER_INVALID: clientId 或签名指纹校验失败
      return '华为登录配置未生效：请确认 AGC 已添加本应用公钥指纹并开通账号服务'
    }
    if (code === 1001502002 || code === 1001502014 || code === 1001500001) {
      // 应用未开通账号服务 / scope 未申请 / 签名校验失败，属于配置问题
      return '华为登录暂不可用，请检查 AGC 账号服务配置与应用签名'
    }
    if (code === 1001502005) {
      return '网络异常，请检查网络后重试'
    }
    return `华为账号授权失败(${code})，请稍后重试`
  }
  /**
   * 诊断：读取包内 module.json5 的 client_id metadata
   * 用于区分「App 未携带 client_id」和「AGC 侧指纹/服务未配置」两类问题
   */
  private static logClientIdDiagnostics(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION |
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA)
      let found: string = ''
      const modules = info.appInfo?.metadataArray ?? []
      for (let i = 0; i < modules.length; i++) {
        const list = modules[i].metadata
        for (let j = 0; j < list.length; j++) {
          if (list[j].name === 'client_id' && list[j].value.length > 0) {
            found = list[j].value
          }
        }
      }
      if (found.length > 0) {
        hilog.info(DOMAIN, TAG,
          `诊断: 包内 client_id=${found.substring(0, 6)}****${found.substring(found.length - 4)}（已携带）`)
      } else {
        hilog.error(DOMAIN, TAG, '诊断: 包内未找到 client_id metadata！请确认 module.json5 已配置 client_id 并重新构建安装')
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, `诊断: 读取 client_id 失败: ${JSON.stringify(e)}`)
    }
  }

  /**
   * 拉起华为账号授权，返回一次性 authorizationCode
   * 注意：code 只能用一次，且由后端在 AGC 配对的 client_id/secret 下消费
   * 前提：AGC 已开通账号服务、已添加签名证书公钥指纹，应用用签名包装在真机
   * 必须在 ArkUI 页面上下文中调用（forceAuthorization 时会拉起授权 UI）
   */
  public static async getAuthorizationCode(): Promise<string> {
    HuaweiIdService.logClientIdDiagnostics()

    // scope 申请 openid（拿到用户唯一标识即可，最小权限）
    const provider = new authentication.HuaweiIDProvider()
    const request: authentication.AuthorizationWithHuaweiIDRequest =
      provider.createAuthorizationWithHuaweiIDRequest()
    request.scopes = ['openid']
    request.forceAuthorization = true

    try {
      hilog.info(DOMAIN, TAG, '开始拉起华为账号授权')
      const controller: authentication.AuthenticationController =
        new authentication.AuthenticationController()
      const data: authentication.AuthorizationWithHuaweiIDResponse =
        await controller.executeRequest(request) as authentication.AuthorizationWithHuaweiIDResponse

      const credential = data.data
      const code: string = credential?.authorizationCode ?? ''
      if (code.length === 0) {
        hilog.error(DOMAIN, TAG, '授权成功但未返回 authorizationCode')
        throw new Error('未获取到华为登录凭证')
      }

      hilog.info(DOMAIN, TAG, '华为账号授权成功, codeLength=' + code.length)
      return code
    } catch (error) {
      const bizError = error as BusinessError
      hilog.error(DOMAIN, TAG, `华为账号授权失败: code=${bizError.code}, message=${bizError.message}`)
      throw new Error(HuaweiIdService.mapErrorCode(bizError.code))
    }
  }
}
