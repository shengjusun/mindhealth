/**
 * 头像服务
 * @description 管理用户头像的选择、验证、上传和显示
 *
 * 头像主链路：
 * ProfileEditPage 点击更换头像
 * → AvatarService.selectAvatar 选择图片
 * → AvatarService.validateImage 校验格式和大小
 * → AvatarService.uploadAvatar 调用 ApiService 上传文件
 * → 上传成功后 updateLocalAvatar 同步 AuthService
 * → AuthService.updateUserInfo 更新内存 userInfo，并保存到 Preferences
 */

import { picker, fileIo } from '@kit.CoreFileKit'
import { Logger } from '../../common/utils/Logger'
import { ApiService } from '../api/ApiService'
import { AuthService } from '../auth/AppAuthService'
import {
  ImageValidationResult,
  UploadResult,
  AvatarUploadErrorCode
} from '../../common/types/Types'

const TAG = 'AvatarService'

export class AvatarService {
  private static instance: AvatarService

  // 头像上传限制：最大 5MB，只允许常见图片格式。
  private readonly MAX_FILE_SIZE: number = 5 * 1024 * 1024
  private readonly SUPPORTED_FORMATS: string[] = ['jpg', 'jpeg', 'png', 'webp']

  private constructor() {
    Logger.info(TAG, 'AvatarService初始化')
  }

  // 单例：保证整个 App 使用同一个 AvatarService。
  static getInstance(): AvatarService {
    if (!AvatarService.instance) {
      AvatarService.instance = new AvatarService()
    }
    return AvatarService.instance
  }

  /**
   * 选择头像图片
   *
   * 作用：
   * 1. 打开系统图片选择器；
   * 2. 限制只能选择图片；
   * 3. 最多选择 1 张；
   * 4. 返回图片 uri，后续上传时用这个 uri 读取本地文件。
   */
  async selectAvatar(): Promise<string> {
    try {
      Logger.info(TAG, '打开图片选择器')

      const photoPicker = new picker.PhotoViewPicker()
      const photoSelectOptions: picker.PhotoSelectOptions = new picker.PhotoSelectOptions()
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE
      photoSelectOptions.maxSelectNumber = 1

      const result: picker.PhotoSelectResult = await photoPicker.select(photoSelectOptions)

      if (result && result.photoUris && result.photoUris.length > 0) {
        const uri = result.photoUris[0]
        Logger.info(TAG, `选择图片: ${uri}`)
        return uri
      }

      Logger.info(TAG, '用户取消选择')
      return ''
    } catch (error) {
      Logger.error(TAG, `选择图片失败: ${JSON.stringify(error)}`)
      return ''
    }
  }

  /**
   * 上传前校验图片
   *
   * 作用：
   * 1. 校验文件后缀是否属于 jpg / jpeg / png / webp；
   * 2. 校验文件大小是否超过 5MB；
   * 3. 不符合要求时直接返回错误，不再请求后端。
   */
  validateImage(uri: string): ImageValidationResult {
    try {
      const extension = this.getFileExtension(uri)
      Logger.info(TAG, `文件扩展名: ${extension}`)

      if (!extension || !this.SUPPORTED_FORMATS.includes(extension.toLowerCase())) {
        return {
          valid: false,
          error: '不支持该图片格式,请选择JPG/PNG/WebP格式图片',
          errorCode: AvatarUploadErrorCode.INVALID_FORMAT
        }
      }

      const stat: fileIo.Stat = fileIo.statSync(uri)
      const fileSize: number = stat.size
      Logger.info(TAG, `文件大小: ${fileSize} bytes`)

      if (fileSize > this.MAX_FILE_SIZE) {
        return {
          valid: false,
          error: '图片大小超过限制,请选择小于5MB的图片',
          errorCode: AvatarUploadErrorCode.FILE_TOO_LARGE
        }
      }

      return { valid: true }
    } catch (error) {
      Logger.error(TAG, `验证图片失败: ${JSON.stringify(error)}`)
      return {
        valid: false,
        error: '图片验证失败',
        errorCode: AvatarUploadErrorCode.INVALID_FORMAT
      }
    }
  }

  /**
   * 上传头像主流程
   *
   * 业务链路：
   * 1. 先做本地图片校验；
   * 2. 再检查当前是否已登录；
   * 3. 调用 ApiService.uploadAvatar 真正上传文件；
   * 4. 后端返回头像地址后，同步本地 AuthService 用户信息；
   * 5. 返回 UploadResult 给页面层，页面层再决定是否重新 loadUserInfo 或弹窗提示。
   */
  async uploadAvatar(uri: string): Promise<UploadResult> {
    try {
      Logger.info(TAG, `开始上传头像: ${uri}`)

      // 第一步：本地校验，避免无效文件直接请求后端。
      const validation = this.validateImage(uri)
      if (!validation.valid) {
        return {
          success: false,
          errorCode: validation.errorCode,
          errorMessage: validation.error
        }
      }

      // 第二步：确认登录态。
      // 头像属于用户资料，必须知道当前用户是谁，所以未登录不能上传。
      const authService = AuthService.getInstance()
      const userInfo = authService.getUserInfo()
      if (!userInfo || !userInfo.isLoggedIn) {
        return {
          success: false,
          errorCode: AvatarUploadErrorCode.UNAUTHORIZED,
          errorMessage: '请先登录后再更换头像'
        }
      }

      // 第三步：调用 ApiService 上传文件。
      // 这里不直接写 multipart 细节，真正的文件读取、请求体拼接和 token 请求头由 ApiService.uploadAvatar 负责。
      const apiService = ApiService.getInstance()
      const response = await apiService.uploadAvatar(uri)

      if (response.code === 200 && response.data) {
        const avatarUrl: string = response.data
        Logger.info(TAG, `上传成功: ${avatarUrl}`)

        // 第四步：同步本地头像状态。
        // 这一步会更新 AuthService.userInfo.photoUrl，并通过 AuthService.updateUserInfo 保存到 Preferences。
        await this.updateLocalAvatar(avatarUrl)

        return {
          success: true,
          avatarUrl: avatarUrl
        }
      }

      Logger.error(TAG, `上传失败: ${response.message}`)
      return {
        success: false,
        errorCode: AvatarUploadErrorCode.UPLOAD_FAILED,
        errorMessage: response.message || '头像上传失败,请稍后重试'
      }
    } catch (error) {
      Logger.error(TAG, `上传头像异常: ${JSON.stringify(error)}`)
      return {
        success: false,
        errorCode: AvatarUploadErrorCode.NETWORK_ERROR,
        errorMessage: '网络连接失败,请检查网络后重试'
      }
    }
  }

  /**
   * 更新本地头像状态
   *
   * 注意：
   * 这里只负责更新 AuthService 里的用户头像信息；
   * 页面是否刷新头像，由 ProfileEditPage / MePage 的 @State avatarUrl 和 loadUserInfo 控制。
   *
   * AuthService.updateUserInfo 的作用：
   * 1. 更新内存里的 this.userInfo；
   * 2. 保存到 Preferences 的 user_info；
   * 3. 重新同步 token 给 ApiService。
   */
  async updateLocalAvatar(url: string): Promise<void> {
    try {
      const authService = AuthService.getInstance()
      const userInfo = authService.getUserInfo()

      if (userInfo) {
        userInfo.photoUrl = url
        await authService.updateUserInfo(userInfo)
        Logger.info(TAG, '本地头像状态已更新')
      }
    } catch (error) {
      Logger.error(TAG, `更新本地状态失败: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 获取当前本地头像地址
   *
   * 主要用于页面快速回显：
   * 页面可以先读 AuthService 里的 photoUrl，不必一进页面就等后端接口返回。
   */
  getAvatarUrl(): string {
    const authService = AuthService.getInstance()
    const userInfo = authService.getUserInfo()
    return userInfo?.photoUrl || ''
  }

  // 从 uri 中提取文件后缀，用于格式校验。
  private getFileExtension(uri: string): string {
    const lastDotIndex = uri.lastIndexOf('.')
    if (lastDotIndex === -1) {
      return ''
    }
    return uri.substring(lastDotIndex + 1).toLowerCase()
  }
}
