/**
 * 头像上传相关类型（AvatarService 专用）
 *
 * 说明：本文件历史上堆放了大量「预期要用」的核心类型（UserInfo/ChatMessage/
 * CommunityPost 等），实际从未被引用；各页面与仓库层用的都是自己定义的接口
 * （AssessmentRecordItem、DiaryItem 等，见 pages/ 与 repository/）。死类型已
 * 裁剪，只保留真实使用方 AvatarService 引用的三个符号。新类型建议就近定义
 * 在使用方文件里，不要再往这里堆。
 */

/**
 * 图片验证结果接口
 */
export interface ImageValidationResult {
  valid: boolean;                // 是否有效
  error?: string;                // 错误信息
  errorCode?: AvatarUploadErrorCode; // 错误码
}

/**
 * 头像上传错误码枚举
 */
export enum AvatarUploadErrorCode {
  FILE_TOO_LARGE = 'AVATAR_001',     // 文件过大
  INVALID_FORMAT = 'AVATAR_002',     // 格式不支持
  UPLOAD_FAILED = 'AVATAR_003',      // 上传失败
  NETWORK_ERROR = 'AVATAR_004',      // 网络错误
  UNAUTHORIZED = 'AVATAR_005'        // 未授权
}

/**
 * 上传结果接口
 */
export interface UploadResult {
  success: boolean;              // 是否成功
  avatarUrl?: string;            // 头像URL
  errorCode?: string;            // 错误码
  errorMessage?: string;         // 错误信息
}
