/**
 * 认证服务
 * 主要负责：
 * 1. 登录
 * 2. 保存登录状态
 * 3. 从本地恢复登录状态
 * 4. 把 token 同步给 ApiService，让后续接口请求能带 token
 */
import { hilog } from '@kit.PerformanceAnalysisKit'
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { http } from '@kit.NetworkKit'
import { ApiConfig  } from '../../common/constants/apiConfig'
import { ApiService } from '../api/ApiService'

const DOMAIN = 0xFF00
const TAG = 'AuthService'

export interface UserAuthInfo {
  uid: string
  displayName: string
  photoUrl: string
  email: string
  phoneNumber: string
  accessToken: string
  refreshToken: string
  isLoggedIn: boolean
}

export type LoginCallback = (success: boolean, userInfo?: UserAuthInfo, error?: string) => void

// 后端返回的用户结构
interface DbUser {
  id: number
  phone: string
  nickname: string
  avatar: string
}

// 登录请求体，字段要和后端接收的一致
interface LoginRequest {
  phone: string
  password: string
}

// 后端登录成功后 data 里的内容
interface LoginResponseData {
  token: string
  refreshToken: string
  userInfo: DbUser
}

// 后端统一返回结构
interface LoginResponse {
  code: number
  message: string
  data: LoginResponseData
}

// 前端自己整理后的登录结果
interface LoginResult {
  success: boolean
  user?: DbUser
  token?: string
  refreshToken?: string
  error?: string
}

export class AuthService {
  private static instance: AuthService

  // 当前登录用户信息，存在内存里
  private userInfo: UserAuthInfo | null = null

  // 用来操作 Preferences 本地存储
  private context: common.UIAbilityContext | null = null
  private preferencesStore: preferences.Preferences | null = null

  private constructor() {}

  // 单例：保证整个 App 用的是同一个 AuthService
  public static getInstance(): AuthService {
    if (!AuthService.instance) {
      AuthService.instance = new AuthService()
    }
    return AuthService.instance
  }

  // 初始化认证服务：保存 context，并尝试从本地恢复登录态
  public async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    try {
      await this.loadUserInfo()
      hilog.info(DOMAIN, TAG, 'AuthService 初始化完成')
    } catch (error) {
      hilog.error(DOMAIN, TAG, `AuthService 初始化失败: ${JSON.stringify(error)}`)
    }
  }


  /**
   * 登录入口
   * LoginPage 会把用户输入的手机号和密码传到这里
   */
  public async loginWithCredentials(
    phone: string,
    password: string,
    callback?: LoginCallback
  ): Promise<void> {
    try {
      hilog.info(DOMAIN, TAG, `开始登录: phone=${phone}`)

      // 先请求后端登录接口
      const result = await this.requestLogin(phone, password)

      // 再统一处理登录结果
      await this.handleLoginResult(result, callback)
    } catch (error) {
      const errorMsg = `登录流程异常: ${JSON.stringify(error)}`
      hilog.error(DOMAIN, TAG, errorMsg)
      callback?.(false, undefined, errorMsg)
    }
  }

  /**
   * 真正请求后端登录接口的方法
   * 这里是登录请求最核心的代码
   */
  private async requestLogin(phone: string, password: string): Promise<LoginResult> {
    // 创建鸿蒙 HTTP 请求对象，后面用它发请求
    const httpRequest = http.createHttp()

    try {
      // 组装登录请求参数，字段名要和后端 DTO 对上
      const loginData: LoginRequest = { phone, password }

      // 拼接完整登录地址：后端基础地址 + 登录接口路径
      const url = `${ApiConfig .API_BASE_URL}${ApiConfig .ENDPOINTS.LOGIN}`

      // 打印请求地址，方便看前端到底请求到哪里
      hilog.info(DOMAIN, TAG, `Login URL: ${url}`)

      // 调试用：只打印手机号，不打印密码，避免敏感信息泄露
      hilog.info(DOMAIN, TAG, `Login data: phone=${phone}`)

      // 真正发登录请求
      // 登录是提交数据，所以这里用 POST
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        // 把 ArkTS 对象转成 JSON 字符串传给后端
        extraData: JSON.stringify(loginData),
        connectTimeout: 10000,
        readTimeout: 10000
      })

      // 打印后端返回，方便联调时看状态码和返回内容
      hilog.info(DOMAIN, TAG, `Response code: ${response.responseCode}`)
      hilog.info(DOMAIN, TAG, `Response result: ${response.result}`)

      // 第一层判断：HTTP 状态码
      // 不是 200 说明请求层面就失败了，比如接口不存在、后端报错等
      if (response.responseCode !== 200) {
        return {
          success: false,
          error: `服务器错误: ${response.responseCode}`
        }
      }

      // 把后端返回的 JSON 字符串转成对象
      const result: LoginResponse = JSON.parse(response.result as string)

      // 第二层判断：业务 code
      // HTTP 200 只代表请求成功，不代表登录业务一定成功
      if (result.code === 200 && result.data) {
        // 这里只打印 token 长度，不直接打印完整 token
        hilog.info(DOMAIN, TAG, `登录接口返回成功, tokenLength=${(result.data.token || '').length}`)
        hilog.info(DOMAIN, TAG, `后端用户信息: ${JSON.stringify(result.data.userInfo)}`)

        // 把后端返回的内容整理成前端内部统一使用的 LoginResult
        return {
          success: true,
          user: result.data.userInfo,
          token: result.data.token,
          refreshToken: result.data.refreshToken
        }
      }

      // 业务失败，比如密码错误，就把后端 message 返回给页面
      return {
        success: false,
        error: result.message || '登录失败'
      }
    } catch (error) {
      // 网络异常、JSON 解析异常等都会进这里
      hilog.error(DOMAIN, TAG, `登录请求异常: ${JSON.stringify(error)}`)
      return {
        success: false,
        error: `网络错误: ${JSON.stringify(error)}`
      }
    } finally {
      try {
        // 请求结束后释放 httpRequest
        httpRequest.destroy()
      } catch (error) {
        hilog.warn(DOMAIN, TAG, `释放 httpRequest 失败: ${JSON.stringify(error)}`)
      }
    }
  }

  /**
   *  处理登录结果
   *  requestLogin 只负责请求后端
   *  这里负责把登录成功后的数据保存起来
   */
  private async handleLoginResult(result: LoginResult, callback?: LoginCallback): Promise<void> {
    if (result.success && result.user) {
      // 把后端用户信息转换成前端统一使用的 userInfo
      this.userInfo = {
        uid: result.user.id.toString(),
        displayName: result.user.nickname || '用户',
        photoUrl: result.user.avatar || '',
        email: '',
        phoneNumber: result.user.phone || '',
        accessToken: result.token || '',
        refreshToken: result.refreshToken || '',
        isLoggedIn: true
      }

      // 登录成功后，把 token 给 ApiService，后续请求接口要用
      this.syncTokenToApiService(this.userInfo.accessToken)

      // 把用户信息保存到本地，方便下次启动恢复登录态
      await this.saveUserInfo()

      hilog.info(DOMAIN, TAG, `登录成功: ${this.userInfo.displayName}`)
      callback?.(true, this.userInfo)
      return
    }

    hilog.error(DOMAIN, TAG, `登录失败: ${result.error}`)
    callback?.(false, undefined, result.error)
  }

  /**
   * 把 token 同步给 ApiService
   * AuthService 负责登录拿 token
   * ApiService 负责后续请求带 token
   */
  private syncTokenToApiService(token: string): void {
    ApiService.getInstance().setToken(token || '')
    hilog.info(DOMAIN, TAG, `ApiService token 已同步, tokenLength=${(token || '').length}`)
  }

  /**
   * 静默登录
   * 不是重新请求后端，而是检查内存里有没有已登录用户
   */
  public async silentLogin(): Promise<boolean> {
    try {
      if (this.userInfo && this.userInfo.isLoggedIn) {
        // 如果内存里有登录态，就重新同步 token 给 ApiService
        this.syncTokenToApiService(this.userInfo.accessToken)
        hilog.info(DOMAIN, TAG, '静默登录成功')
        return true
      }

      hilog.info(DOMAIN, TAG, '静默登录失败: 当前没有可用登录态')
      return false
    } catch (error) {
      hilog.error(DOMAIN, TAG, `静默登录异常: ${JSON.stringify(error)}`)
      return false
    }
  }

  /**
   * 退出登录
   * 清空内存、本地存储和 ApiService 里的 token
   */
  public async logout(): Promise<void> {
    try {
      this.userInfo = null
      this.syncTokenToApiService('')
      await this.clearUserInfo()
      hilog.info(DOMAIN, TAG, '退出登录成功')
    } catch (error) {
      hilog.error(DOMAIN, TAG, `退出登录失败: ${JSON.stringify(error)}`)
    }
  }

  // 获取当前用户信息
  public getUserInfo(): UserAuthInfo | null {
    return this.userInfo
  }

  // 更新用户信息，比如修改头像、昵称后同步本地
  public async updateUserInfo(userInfo: UserAuthInfo): Promise<void> {
    try {
      this.userInfo = userInfo
      this.syncTokenToApiService(this.userInfo.accessToken)
      await this.saveUserInfo()
      hilog.info(DOMAIN, TAG, '用户信息更新成功')
    } catch (error) {
      hilog.error(DOMAIN, TAG, `更新用户信息失败: ${JSON.stringify(error)}`)
    }
  }

  // 判断当前是否登录
  public isLoggedIn(): boolean {
    return this.userInfo?.isLoggedIn ?? false
  }

  // 获取当前 token
  public getAccessToken(): string {
    return this.userInfo?.accessToken ?? ''
  }

  /**
   * 保存用户信息到本地 Preferences
   * 用来支持 App 下次启动后恢复登录态
   */
  private async saveUserInfo(): Promise<void> {
    // 没有 context 或 userInfo，就没法保存
    if (!this.context || !this.userInfo) {
      return
    }

    try {
      // 获取 auth_store 这个本地存储
      if (!this.preferencesStore) {
        this.preferencesStore = await preferences.getPreferences(this.context, 'auth_store')
      }

      // 把 userInfo 转成 JSON 字符串保存
      await this.preferencesStore.put('user_info', JSON.stringify(this.userInfo))

      // flush 表示真正写入本地
      await this.preferencesStore.flush()

      hilog.info(DOMAIN, TAG, '用户信息已保存到本地')
    } catch (error) {
      hilog.error(DOMAIN, TAG, `保存用户信息失败: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 从本地加载用户信息
   * App 启动初始化 AuthService 时会调用
   */
  private async loadUserInfo(): Promise<void> {
    if (!this.context) {
      return
    }

    try {
      if (!this.preferencesStore) {
        this.preferencesStore = await preferences.getPreferences(this.context, 'auth_store')
      }

      const userInfoStr = await this.preferencesStore.get('user_info', '') as string
      if (!userInfoStr) {
        hilog.info(DOMAIN, TAG, '本地没有保存的用户信息')
        return
      }

      const restoredUserInfo = JSON.parse(userInfoStr) as UserAuthInfo

      if (!restoredUserInfo.accessToken || restoredUserInfo.accessToken.trim().length === 0) {
        hilog.warn(DOMAIN, TAG, '本地用户信息缺少 token，清理登录态')
        this.userInfo = null
        this.syncTokenToApiService('')
        await this.clearUserInfo()
        return
      }

      if (!restoredUserInfo.isLoggedIn) {
        hilog.warn(DOMAIN, TAG, '本地用户信息不是登录状态，清理登录态')
        this.userInfo = null
        this.syncTokenToApiService('')
        await this.clearUserInfo()
        return
      }

      this.userInfo = restoredUserInfo
      this.syncTokenToApiService(this.userInfo.accessToken)

      hilog.info(DOMAIN, TAG, `本地登录态恢复成功, tokenLength=${this.userInfo.accessToken.length}`)
    } catch (error) {
      hilog.error(DOMAIN, TAG, `加载本地用户信息失败: ${JSON.stringify(error)}`)

      this.userInfo = null
      this.syncTokenToApiService('')
      await this.clearUserInfo()
    }
  }

  /**
   * 清除本地用户信息
   * 退出登录时调用
   */
  private async clearUserInfo(): Promise<void> {
    if (!this.context) {
      return
    }

    try {
      if (!this.preferencesStore) {
        this.preferencesStore = await preferences.getPreferences(this.context, 'auth_store')
      }

      // 删除本地保存的 user_info
      await this.preferencesStore.delete('user_info')
      await this.preferencesStore.flush()

      hilog.info(DOMAIN, TAG, '本地用户信息已清除')
    } catch (error) {
      hilog.error(DOMAIN, TAG, `清除本地用户信息失败: ${JSON.stringify(error)}`)
    }
  }
}