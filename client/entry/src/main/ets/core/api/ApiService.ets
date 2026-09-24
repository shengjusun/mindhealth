import { ApiConfig  } from '../../common/constants/apiConfig'
import { Logger } from '../../common/utils/Logger'
import { http } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit'

// 日志标签，用来标记日志来自 ApiService 模块
const TAG = 'ApiService'

// 后端统一响应结构
// T 表示 data 的具体类型，不同接口返回的数据类型可能不同
interface ApiResponse<T> {
  code: number
  message: string
  data: T
  timestamp: number
}

// 登录请求体
// 注意：当前项目主登录链路主要走 AuthService，这里保留是为了兼容普通接口封装
interface LoginData {
  phone: string
  password: string
}

export class ApiService {
  private static instance: ApiService

  // 后端基础地址，统一从 ApiConfig  读取
  private baseUrl: string = ApiConfig .API_BASE_URL

  // 当前登录用户的 token
  // 登录成功后由 AuthService 调用 setToken 同步过来
  private token: string = ''

  // 登录态失效回调（由 EntryAbility 注入，避免与 AuthService 循环依赖）
  private authExpiredHandler: (() => void) | null = null

  private constructor() {
    Logger.info(TAG, 'ApiService初始化')
  }

  // 单例：保证整个 App 使用同一个 ApiService
  // 这样 token 只需要保存一份，所有页面请求接口都能共用
  static getInstance(): ApiService {
    if (!ApiService.instance) {
      ApiService.instance = new ApiService()
    }
    return ApiService.instance
  }

  // AuthService 登录成功后，会调用这个方法把 token 同步过来
  setToken(token: string): void {
    this.token = token
  }

  // 注入 401 处理：token 过期时清登录态并回登录页
  setAuthExpiredHandler(handler: () => void): void {
    this.authExpiredHandler = handler
  }

  /**
   * 通用请求方法
   * 所有普通业务接口最终都会走到这里
   *
   * method：请求方法，比如 GET / POST / PUT / DELETE
   * endpoint：接口路径，比如 /api/diary
   * data：请求体，POST / PUT 时一般会传
   */
  private async request<T>(
    method: http.RequestMethod,
    endpoint: string,
    data?: Object
  ): Promise<ApiResponse<T>> {
    // 把鸿蒙 http 的回调形式，包装成 Promise，方便外部用 async/await 调用
    return new Promise<ApiResponse<T>>((resolve, reject) => {
      let httpRequest: http.HttpRequest | null = null

      try {
        // 创建鸿蒙 HTTP 请求对象
        httpRequest = http.createHttp()

        // 拼接完整接口地址：后端基础地址 + 接口路径
        const url = this.baseUrl + endpoint

        // 统一请求配置
        const options: http.HttpRequestOptions = {
          method: method,
          header: {
            'Content-Type': 'application/json',
            // 业务接口统一带 token，后端通过 token 判断当前用户身份
            'Authorization': `Bearer ${this.token}`
          },
          connectTimeout: 60000,
          readTimeout: 60000
        }

        // 如果有请求体，就把对象转成 JSON 字符串传给后端
        if (data) {
          options.extraData = JSON.stringify(data)
        }

        Logger.info(TAG, `请求: ${method} ${url}`)

        // 真正发请求的地方
        httpRequest.request(url, options, (err, response) => {
          try {
            // err 表示网络层异常，比如 IP 不通、后端没启动、连接超时等
            if (err) {
              Logger.error(TAG, `请求失败: ${JSON.stringify(err)}`)
              reject(new Error(`请求失败: ${err.message || '未知错误'}`))
              return
            }

            // 第一层判断：HTTP 状态码
            // responseCode 为 200，表示请求通信成功
            if (response.responseCode === 200) {
              try {
                // 把后端返回的 JSON 字符串解析成统一响应对象
                const result = JSON.parse(response.result as string) as ApiResponse<T>
                Logger.info(TAG, `请求成功: ${JSON.stringify(result)}`)

                // 统一处理登录态失效：清登录态并回登录页
                // 结果仍返回给调用方，按 code!==200 的既有逻辑展示 message
                if (result.code === 401) {
                  Logger.warn(TAG, '登录态已失效（401），触发统一登出')
                  this.authExpiredHandler?.()
                }

                // resolve 表示 Promise 成功，把结果返回给调用方
                resolve(result)
              } catch (parseError) {
                // JSON 解析失败，说明后端返回结构可能不是预期 JSON
                Logger.error(TAG, `解析响应失败: ${JSON.stringify(parseError)}`)
                reject(new Error('解析响应失败'))
              }
            } else {
              // HTTP 状态码不是 200，比如 401、404、500
              Logger.error(TAG, `请求失败: ${response.responseCode}`)
              reject(new Error(`请求失败: ${response.responseCode}`))
            }
          } finally {
            // 请求结束后释放 httpRequest
            httpRequest?.destroy()
          }
        })
      } catch (error) {
        // 捕获创建请求对象、拼接参数等同步异常
        httpRequest?.destroy()
        const err = error as Error
        Logger.error(TAG, `请求异常: ${err.message}`)
        reject(err)
      }
    })
  }

  // GET 请求，一般用于查询数据
  async get<T>(endpoint: string): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.GET, endpoint)
  }

  // POST 请求，一般用于新增或提交数据
  async post<T>(endpoint: string, data: Object): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.POST, endpoint, data)
  }

  // PUT 请求，一般用于修改数据
  async put<T>(endpoint: string, data: Object): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.PUT, endpoint, data)
  }

  // DELETE 请求，一般用于删除数据
  async delete<T>(endpoint: string): Promise<ApiResponse<T>> {
    return this.request<T>(http.RequestMethod.DELETE, endpoint)
  }

  // 保留的登录方法
  // 当前项目主登录链路走 AuthService.loginWithCredentials
  async login(phone: string, password: string): Promise<ApiResponse<Object>> {
    const loginData: LoginData = { phone: phone, password: password }
    return this.post<Object>(ApiConfig .ENDPOINTS.LOGIN, loginData)
  }

  // 注册
  async register(data: Object): Promise<ApiResponse<Object>> {
    return this.post<Object>(ApiConfig .ENDPOINTS.REGISTER, data)
  }

  // 获取当前用户信息
  async getUserInfo(): Promise<ApiResponse<Object>> {
    return this.get<Object>(ApiConfig .ENDPOINTS.USER_INFO)
  }

  // 修改用户信息
  async updateUserInfo(data: Object): Promise<ApiResponse<Object>> {
    return this.put<Object>(ApiConfig .ENDPOINTS.UPDATE_USER, data)
  }

  /**
   * 上传头像
   * 头像上传和普通 JSON 请求不同，这里单独封装 multipart/form-data
   * 面试时不主动展开，知道它是文件上传接口即可
   */
  async uploadAvatar(imageUri: string): Promise<ApiResponse<string>> {
    return new Promise<ApiResponse<string>>((resolve, reject) => {
      let httpRequest: http.HttpRequest | null = null

      try {
        httpRequest = http.createHttp()

        const url = this.baseUrl + ApiConfig .ENDPOINTS.AVATAR_UPLOAD
        Logger.info(TAG, `上传头像: ${url}`)

        // 读取本地图片文件
        const file: fileIo.File = fileIo.openSync(imageUri, fileIo.OpenMode.READ_ONLY)
        const stat: fileIo.Stat = fileIo.statSync(imageUri)
        const fileSize: number = stat.size
        const fileBuffer: ArrayBuffer = new ArrayBuffer(fileSize)
        fileIo.readSync(file.fd, fileBuffer)
        fileIo.closeSync(file)

        // 从路径中取出文件名
        let fileName: string = 'avatar.jpg'
        const lastSlashIndex: number = imageUri.lastIndexOf('/')
        if (lastSlashIndex >= 0 && lastSlashIndex < imageUri.length - 1) {
          fileName = imageUri.substring(lastSlashIndex + 1)
        }

        // 根据文件后缀判断 MIME 类型
        let mimeType: string = 'image/jpeg'
        const lowerName: string = fileName.toLowerCase()
        if (lowerName.endsWith('.png')) {
          mimeType = 'image/png'
        } else if (lowerName.endsWith('.webp')) {
          mimeType = 'image/webp'
        } else if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
          mimeType = 'image/jpeg'
        }

        // multipart/form-data 的分隔符
        const boundary: string = '----HarmonyBoundary' + new Date().getTime()

        // multipart 第一段：文件说明信息
        const part1: string =
          '--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="file"; filename="' + fileName + '"\r\n' +
            'Content-Type: ' + mimeType + '\r\n\r\n'

        // multipart 结束段
        const part2: string = '\r\n--' + boundary + '--\r\n'

        // 字符串转字节数组，用来拼接 multipart 请求体
        const stringToUint8Array = (str: string): Uint8Array => {
          const arr: number[] = []
          for (let i = 0; i < str.length; i++) {
            arr.push(str.charCodeAt(i) & 0xff)
          }
          return new Uint8Array(arr)
        }

        const part1Bytes: Uint8Array = stringToUint8Array(part1)
        const fileBytes: Uint8Array = new Uint8Array(fileBuffer)
        const part2Bytes: Uint8Array = stringToUint8Array(part2)

        // 计算完整请求体长度，并把三段内容拼到一起
        const totalLength: number = part1Bytes.length + fileBytes.length + part2Bytes.length
        const bodyBytes: Uint8Array = new Uint8Array(totalLength)

        bodyBytes.set(part1Bytes, 0)
        bodyBytes.set(fileBytes, part1Bytes.length)
        bodyBytes.set(part2Bytes, part1Bytes.length + fileBytes.length)

        const options: http.HttpRequestOptions = {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'multipart/form-data; boundary=' + boundary,
            'Authorization': `Bearer ${this.token}`
          },
          connectTimeout: 60000,
          readTimeout: 60000,
          extraData: bodyBytes.buffer
        }

        // 真正发送头像上传请求
        httpRequest.request(url, options, (err, response) => {
          try {
            if (err) {
              Logger.error(TAG, `上传失败: ${JSON.stringify(err)}`)
              reject(new Error(`上传失败: ${err.message || '未知错误'}`))
              return
            }

            if (response.responseCode === 200) {
              try {
                const result = JSON.parse(response.result as string) as ApiResponse<string>
                Logger.info(TAG, `上传成功: ${JSON.stringify(result)}`)
                resolve(result)
              } catch (parseError) {
                Logger.error(TAG, `解析响应失败: ${JSON.stringify(parseError)}`)
                reject(new Error('解析响应失败'))
              }
            } else {
              Logger.error(TAG, `上传失败: ${response.responseCode}, result=${response.result}`)
              reject(new Error(`上传失败: ${response.responseCode}`))
            }
          } finally {
            httpRequest?.destroy()
          }
        })
      } catch (error) {
        httpRequest?.destroy()
        const err = error as Error
        Logger.error(TAG, `上传异常: ${err.message}`)
        reject(err)
      }
    })
  }

  // 查询日记列表
  async getDiaryList(): Promise<ApiResponse<Object[]>> {
    return this.get<Object[]>(ApiConfig .ENDPOINTS.DIARY_LIST)
  }

  // 查询单条日记详情
  async getDiaryDetail(id: string): Promise<ApiResponse<Object>> {
    return this.get<Object>(`${ApiConfig .ENDPOINTS.DIARY_LIST}/${id}`)
  }

  // 新增日记
  async addDiary(data: Object): Promise<ApiResponse<Object>> {
    return this.post<Object>(ApiConfig .ENDPOINTS.DIARY_ADD, data)
  }

  // 修改日记
  async updateDiary(id: string, data: Object): Promise<ApiResponse<Object>> {
    return this.put<Object>(`${ApiConfig .ENDPOINTS.DIARY_UPDATE}/${id}`, data)
  }

  // 删除日记
  async deleteDiary(id: string): Promise<ApiResponse<Object>> {
    return this.delete<Object>(`${ApiConfig .ENDPOINTS.DIARY_DELETE}/${id}`)
  }

  // 获取测评列表
  async getAssessmentList(): Promise<ApiResponse<Object[]>> {
    return this.get<Object[]>(ApiConfig .ENDPOINTS.ASSESSMENT_LIST)
  }

  // 提交测评
  async submitAssessment(data: Object): Promise<ApiResponse<Object>> {
    return this.post<Object>(ApiConfig .ENDPOINTS.ASSESSMENT_SUBMIT, data)
  }


  // 发送 AI 对话消息
  async sendMessage(data: Object): Promise<ApiResponse<Object>> {
    return this.post<Object>(ApiConfig .ENDPOINTS.CHAT_SEND, data)
  }

  // 获取 AI 对话历史
  async getChatHistory(userId: string): Promise<ApiResponse<Object[]>> {
    return this.get<Object[]>(`${ApiConfig .ENDPOINTS.CHAT_HISTORY}?userId=${userId}`)
  }

  // 获取文章列表，可按分类筛选
  async getArticleList(category?: string): Promise<ApiResponse<Object[]>> {
    const url = category
      ? `${ApiConfig .ENDPOINTS.ARTICLE_LIST}?category=${category}`
      : ApiConfig .ENDPOINTS.ARTICLE_LIST
    return this.get<Object[]>(url)
  }

  // 获取文章详情
  async getArticleDetail(id: string): Promise<ApiResponse<Object>> {
    return this.get<Object>(`${ApiConfig .ENDPOINTS.ARTICLE_DETAIL}/${id}`)
  }

  // 查询当前用户的测评结果列表
  // 首页最近测评卡片会用到这个接口
  async getAssessmentResults(): Promise<ApiResponse<Object[]>> {
    return this.get<Object[]>(ApiConfig .ENDPOINTS.ASSESSMENT_RESULTS)
  }

  // 量表清单（静态题库接口，后端 permitAll，未登录也能拉）
  async getScaleManifest(): Promise<ApiResponse<Object>> {
    return this.get<Object>(ApiConfig.ENDPOINTS.SCALE_MANIFEST)
  }

  // 单套量表题目（静态题库接口，后端 permitAll）
  // 注意：后端目前返回的是 JSON 字符串，ScaleRepository 里做了二次解析兼容
  async getScaleQuestions(id: number): Promise<ApiResponse<Object>> {
    return this.get<Object>(`${ApiConfig.ENDPOINTS.SCALE_QUESTIONS}/${id}/questions`)
  }

  // 提交用户反馈
  async submitFeedback(data: Object): Promise<ApiResponse<Object>> {
    return this.post<Object>('/api/feedback', data)
  }
}