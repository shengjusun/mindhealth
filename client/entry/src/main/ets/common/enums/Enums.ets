/**
 * 枚举类型定义
 * @description 定义应用中使用的所有枚举类型
 */

/**
 * 用户性别枚举
 */
export enum Gender {
  UNKNOWN = 0,  // 未知
  MALE = 1,      // 男性
  FEMALE = 2     // 女性
}

/**
 * 情绪类型枚举
 */
export enum EmotionType {
  HAPPY = 'happy',         // 开心
  SAD = 'sad',             // 难过
  ANXIOUS = 'anxious',     // 焦虑
  ANGRY = 'angry',         // 愤怒
  CALM = 'calm',           // 平静
  EXCITED = 'excited',     // 兴奋
  TIRED = 'tired',         // 疲惫
  CONFUSED = 'confused'    // 困惑
}

/**
 * 心理风险等级枚举
 */
export enum RiskLevel {
  LOW = 'low',           // 低风险
  MEDIUM = 'medium',     // 中风险
  HIGH = 'high',         // 高风险
  CRISIS = 'crisis'      // 危机
}

/**
 * 消息类型枚举
 */
export enum MessageType {
  TEXT = 'text',         // 文本消息
  IMAGE = 'image',       // 图片消息
  EMOTION = 'emotion',   // 表情消息
  SYSTEM = 'system'      // 系统消息
}

/**
 * 消息发送状态枚举
 */
export enum MessageStatus {
  SENDING = 'sending',     // 发送中
  SENT = 'sent',           // 已发送
  DELIVERED = 'delivered', // 已送达
  READ = 'read',           // 已读
  FAILED = 'failed'        // 发送失败
}

/**
 * 测评状态枚举
 */
export enum AssessmentStatus {
  NOT_STARTED = 'not_started',  // 未开始
  IN_PROGRESS = 'in_progress',  // 进行中
  COMPLETED = 'completed',      // 已完成
  EXPIRED = 'expired'           // 已过期
}

/**
 * 量表类型枚举
 */
export enum ScaleType {
  SCL_90 = 'scl_90',     // SCL-90症状自评量表
  SDS = 'sds',           // SDS抑郁自评量表
  SAS = 'sas',           // SAS焦虑自评量表
  PSS_10 = 'pss_10'      // PSS-10知觉压力量表
}

/**
 * 社区内容状态枚举
 */
export enum ContentStatus {
  DRAFT = 'draft',           // 草稿
  PENDING = 'pending',       // 待审核
  APPROVED = 'approved',     // 已通过
  REJECTED = 'rejected',     // 已拒绝
  DELETED = 'deleted'        // 已删除
}

/**
 * 通知类型枚举
 */
export enum NotificationType {
  CHAT_MESSAGE = 'chat_message',           // 对话消息
  EMOTION_REMINDER = 'emotion_reminder',   // 情绪记录提醒
  ASSESSMENT_REPORT = 'assessment_report', // 测评报告
  COMMUNITY_REPLY = 'community_reply',     // 社区回复
  SYSTEM_NOTICE = 'system_notice'          // 系统通知
}

/**
 * 生物识别类型枚举
 */
export enum BiometricType {
  FINGERPRINT = 'fingerprint',  // 指纹
  FACE = 'face',                // 面容
  NONE = 'none'                 // 无
}

/**
 * 网络状态枚举
 */
export enum NetworkStatus {
  CONNECTED = 'connected',     // 已连接
  DISCONNECTED = 'disconnected', // 未连接
  WEAK = 'weak'                // 弱网
}

/**
 * 主题模式枚举
 */
export enum ThemeMode {
  LIGHT = 'light',   // 浅色模式
  DARK = 'dark',     // 深色模式
  AUTO = 'auto'      // 跟随系统
}

/**
 * 语言枚举
 */
export enum Language {
  ZH_CN = 'zh_CN',  // 简体中文
  EN_US = 'en_US'   // 英文
}

/**
 * 设备类型枚举
 */
export enum DeviceType {
  PHONE = 'phone',     // 手机
  TABLET = 'tablet',   // 平板
  WATCH = 'watch',     // 手表
  TV = 'tv',           // 电视
  UNKNOWN = 'unknown'  // 未知
}

/**
 * 权限状态枚举
 */
export enum PermissionStatus {
  GRANTED = 'granted',     // 已授权
  DENIED = 'denied',       // 已拒绝
  PROMPT = 'prompt'        // 需提示
}
