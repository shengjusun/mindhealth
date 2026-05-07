/**
 * 头像服务
 * @description 管理用户头像的选择、验证、上传和显示
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

  private readonly MAX_FILE_SIZE: number = 5 * 1024 * 1024
  private readonly SUPPORTED_FORMATS: string[] = ['jpg', 'jpeg', 'png', 'webp']

  private constructor() {
    Logger.info(TAG, 'AvatarService初始化')
  }

  static getInstance(): AvatarService {
    if (!AvatarService.instance) {
      AvatarService.instance = new AvatarService()
    }
    return AvatarService.instance
  }

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

  validateImage(uri: string): ImageValidationResult {
    try {
      const extension = this.getFileExtension(uri)
      Logger.info(TAG, `文件扩展名: ${extension}`)

      if (!extension || !this.SUPPORTED_FORMATS.includes(extension.toLowerCase())) {
        return {
          valid: false,
          error: '不支持该图片格式,请选择JPG或PNG格式图片',
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

  async uploadAvatar(uri: string): Promise<UploadResult> {
    try {
      Logger.info(TAG, `开始上传头像: ${uri}`)

      const validation = this.validateImage(uri)
      if (!validation.valid) {
        return {
          success: false,
          errorCode: validation.errorCode,
          errorMessage: validation.error
        }
      }

      const authService = AuthService.getInstance()
      const userInfo = authService.getUserInfo()
      if (!userInfo || !userInfo.isLoggedIn) {
        return {
          success: false,
          errorCode: AvatarUploadErrorCode.UNAUTHORIZED,
          errorMessage: '请先登录后再更换头像'
        }
      }

      const apiService = ApiService.getInstance()
      const response = await apiService.uploadAvatar(uri)

      if (response.code === 200 && response.data) {
        const avatarUrl: string = response.data
        Logger.info(TAG, `上传成功: ${avatarUrl}`)

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

  getAvatarUrl(): string {
    const authService = AuthService.getInstance()
    const userInfo = authService.getUserInfo()
    return userInfo?.photoUrl || ''
  }

  private getFileExtension(uri: string): string {
    const lastDotIndex = uri.lastIndexOf('.')
    if (lastDotIndex === -1) {
      return ''
    }
    return uri.substring(lastDotIndex + 1).toLowerCase()
  }
}