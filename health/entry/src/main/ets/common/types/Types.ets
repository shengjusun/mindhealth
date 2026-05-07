/**
 * 核心类型定义
 * @description 定义应用中使用的核心数据类型
 */

/**
 * 用户信息接口
 */
export interface UserInfo {
  id: string;                    // 用户ID
  phone: string;                 // 手机号
  nickname: string;              // 昵称
  avatar: string;                // 头像URL
  gender: number;                // 性别
  birthday: string;              // 生日
  profession: string;            // 职业
  bio: string;                   // 个人简介
  createdAt: number;             // 创建时间
  updatedAt: number;             // 更新时间
}

/**
 * Token信息接口
 */
export interface TokenInfo {
  accessToken: string;           // 访问令牌
  refreshToken: string;          // 刷新令牌
  expiresIn: number;             // 过期时间(秒)
  tokenType: string;             // 令牌类型
}

/**
 * API响应接口
 */
export interface ApiResponse<T> {
  code: number;                  // 响应码
  message: string;               // 响应消息
  data: T;                       // 响应数据
  timestamp: number;             // 时间戳
}

/**
 * 分页请求参数接口
 */
export interface PageRequest {
  pageNum: number;               // 页码
  pageSize: number;              // 每页数量
  sortBy?: string;               // 排序字段
  sortOrder?: 'asc' | 'desc';    // 排序方式
}

/**
 * 分页响应数据接口
 */
export interface PageResponse<T> {
  list: T[];                     // 数据列表
  total: number;                 // 总数
  pageNum: number;               // 当前页码
  pageSize: number;              // 每页数量
  pages: number;                 // 总页数
}

/**
 * 对话消息接口
 */
export interface ChatMessage {
  id: string;                    // 消息ID
  conversationId: string;        // 会话ID
  senderId: string;              // 发送者ID
  receiverId: string;            // 接收者ID
  type: string;                  // 消息类型
  content: string;               // 消息内容
  status: string;                // 消息状态
  createdAt: number;             // 创建时间
  updatedAt: number;             // 更新时间
}

/**
 * 对话会话接口
 */
export interface Conversation {
  id: string;                    // 会话ID
  userId: string;                // 用户ID
  title: string;                 // 会话标题
  lastMessage: string;           // 最后一条消息
  lastMessageTime: number;       // 最后消息时间
  unreadCount: number;           // 未读消息数
  createdAt: number;             // 创建时间
  updatedAt: number;             // 更新时间
}

/**
 * 情绪日记接口
 */
export interface EmotionDiary {
  id: string;                    // 日记ID
  userId: string;                // 用户ID
  emotionType: string;           // 情绪类型
  emotionLevel: number;          // 情绪强度(1-10)
  content: string;               // 日记内容
  images: string[];              // 图片列表
  location?: string;             // 地点
  aiAnalysis?: string;           // AI分析结果
  createdAt: number;             // 创建时间
  updatedAt: number;             // 更新时间
}

/**
 * 心理测评接口
 */
export interface Assessment {
  id: string;                    // 测评ID
  userId: string;                // 用户ID
  scaleType: string;             // 量表类型
  scaleName: string;             // 量表名称
  status: string;                // 测评状态
  answers: AssessmentAnswer[];   // 答题列表
  result?: AssessmentResult;     // 测评结果
  startTime: number;             // 开始时间
  endTime?: number;              // 结束时间
  createdAt: number;             // 创建时间
}

/**
 * 测评答案接口
 */
export interface AssessmentAnswer {
  questionId: number;            // 题目ID
  questionText: string;          // 题目内容
  optionId: number;              // 选项ID
  optionText: string;            // 选项内容
  score: number;                 // 得分
}

/**
 * 测评结果接口
 */
export interface AssessmentResult {
  totalScore: number;            // 总分
  dimensionScores: Record<string, number>;  // 维度得分
  conclusion: string;            // 结论
  suggestion: string;            // 建议
  riskLevel: string;             // 风险等级
}

/**
 * 量表题目接口
 */
export interface ScaleQuestion {
  id: number;                    // 题目ID
  text: string;                  // 题目内容
  options: ScaleOption[];        // 选项列表
  dimension: string;             // 所属维度
  reverse: boolean;              // 是否反向计分
}

/**
 * 量表选项接口
 */
export interface ScaleOption {
  id: number;                    // 选项ID
  text: string;                  // 选项内容
  score: number;                 // 分值
}

/**
 * 科普文章接口
 */
export interface Article {
  id: string;                    // 文章ID
  title: string;                 // 标题
  summary: string;               // 摘要
  content: string;               // 内容
  coverImage: string;            // 封面图
  category: string;              // 分类
  tags: string[];                // 标签
  readCount: number;             // 阅读量
  likeCount: number;             // 点赞数
  isCollected: boolean;          // 是否收藏
  publishedAt: number;           // 发布时间
  createdAt: number;             // 创建时间
}

/**
 * 社区帖子接口
 */
export interface CommunityPost {
  id: string;                    // 帖子ID
  userId: string;                // 用户ID
  anonymousName: string;         // 匿名昵称
  anonymousAvatar: string;       // 匿名头像
  content: string;               // 内容
  images: string[];              // 图片列表
  tags: string[];                // 标签
  likeCount: number;             // 点赞数
  commentCount: number;          // 评论数
  isLiked: boolean;              // 是否点赞
  status: string;                // 状态
  createdAt: number;             // 创建时间
}

/**
 * 帖子评论接口
 */
export interface PostComment {
  id: string;                    // 评论ID
  postId: string;                // 帖子ID
  userId: string;                // 用户ID
  anonymousName: string;         // 匿名昵称
  anonymousAvatar: string;       // 匿名头像
  content: string;               // 内容
  replyTo?: string;              // 回复的评论ID
  likeCount: number;             // 点赞数
  isLiked: boolean;              // 是否点赞
  createdAt: number;             // 创建时间
}

/**
 * 设备信息接口
 */
export interface DeviceInfo {
  deviceId: string;              // 设备ID
  deviceType: string;            // 设备类型
  deviceName: string;            // 设备名称
  osVersion: string;             // 系统版本
  appVersion: string;            // 应用版本
  lastLoginTime: number;         // 最后登录时间
  ipAddress: string;             // IP地址
}

/**
 * 通知消息接口
 */
export interface Notification {
  id: string;                    // 通知ID
  type: string;                  // 通知类型
  title: string;                 // 标题
  content: string;               // 内容
  data?: string;                 // 附加数据
  isRead: boolean;               // 是否已读
  createdAt: number;             // 创建时间
}

/**
 * 错误信息接口
 */
export interface ErrorInfo {
  code: number;                  // 错误码
  message: string;               // 错误消息
  details?: string;              // 详细信息
  stack?: string;                // 堆栈信息
}

/**
 * 头像上传响应接口
 */
export interface AvatarUploadResponse {
  avatarUrl: string;             // 头像URL
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
 * 图片验证结果接口
 */
export interface ImageValidationResult {
  valid: boolean;                // 是否有效
  error?: string;                // 错误信息
  errorCode?: AvatarUploadErrorCode; // 错误码
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
