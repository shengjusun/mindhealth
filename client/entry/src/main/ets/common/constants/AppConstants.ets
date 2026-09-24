/**
 * 应用全局常量配置
 * @description 定义应用级别的常量配置
 *
 * 注意：接口地址与接口路径一律以 common/constants/apiConfig.ets 中的 ApiConfig 为准，
 * 本文件不再定义 ApiConfig，避免同名类造成冲突与误用。
 */

// 存储配置
export class StorageConfig {
  // 应用数据库库名
  static readonly DB_NAME: string = 'qingxin_ai_db';
  
  // 数据库版本
  static readonly DB_VERSION: number = 1;
  
  // Preferences文件名
  static readonly PREFERENCES_NAME: string = 'qingxin_ai_prefs';
  
  // 缓存最大容量(字节) - 500MB
  static readonly CACHE_MAX_SIZE: number = 500 * 1024 * 1024;
  
  // 图片缓存最大数量
  static readonly IMAGE_CACHE_MAX_COUNT: number = 100;
}

// 安全配置
export class SecurityConfig {
  // AES加密密钥别名
  static readonly AES_KEY_ALIAS: string = 'qingxin_ai_aes_key';
  
  // Token存储密钥
  static readonly TOKEN_KEY: string = 'auth_token';
  
  // RefreshToken存储密钥
  static readonly REFRESH_TOKEN_KEY: string = 'refresh_token';
  
  // 用户信息存储密钥
  static readonly USER_INFO_KEY: string = 'user_info';
  
  // 加密算法
  static readonly ENCRYPT_ALGORITHM: string = 'AES-256-GCM';
  
  // 密码哈希强度
  static readonly BCRYPT_SALT_ROUNDS: number = 12;
}

// 业务配置
export class BusinessConfig {
  // 验证码有效期(秒)
  static readonly VERIFY_CODE_EXPIRE: number = 300;
  
  // 密码最小长度
  static readonly PASSWORD_MIN_LENGTH: number = 8;
  
  // 密码最大长度
  static readonly PASSWORD_MAX_LENGTH: number = 20;
  
  // 昵称最小长度
  static readonly NICKNAME_MIN_LENGTH: number = 2;
  
  // 昵称最大长度
  static readonly NICKNAME_MAX_LENGTH: number = 20;
  
  // 头像最大大小(字节) - 5MB
  static readonly AVATAR_MAX_SIZE: number = 5 * 1024 * 1024;
  
  // 图片最大大小(字节) - 10MB
  static readonly IMAGE_MAX_SIZE: number = 10 * 1024 * 1024;
  
  // 对话历史加载条数
  static readonly CHAT_HISTORY_LOAD_COUNT: number = 100;
  
  // 对话上下文保留天数
  static readonly CHAT_CONTEXT_RETAIN_DAYS: number = 30;
  
  // 日记图片最大数量
  static readonly DIARY_IMAGE_MAX_COUNT: number = 9;
  
  // 社区帖子字数限制
  static readonly POST_MAX_LENGTH: number = 500;
  
  // 评论字数限制
  static readonly COMMENT_MAX_LENGTH: number = 200;
}

// 危机干预配置
export class CrisisConfig {
  // 全国心理援助热线
  static readonly NATIONAL_HOTLINE: string = '400-161-9995';
  
  // 北京心理援助热线
  static readonly BEIJING_HOTLINE: string = '010-82951332';
  
  // 上海心理援助热线
  static readonly SHANGHAI_HOTLINE: string = '021-12320-5';
  
  // 预警弹窗再次提醒间隔(毫秒) - 5分钟
  static readonly ALERT_REMIND_INTERVAL: number = 5 * 60 * 1000;
}

// 页面路由配置
export class RouterConfig {
  // 启动页
  static readonly PAGE_SPLASH: string = 'pages/SplashPage';
  
  // 登录页
  static readonly PAGE_LOGIN: string = 'pages/auth/LoginPage';
  
  // 首页
  static readonly PAGE_HOME: string = 'pages/home/HomePage';
  
  // AI对话页
  static readonly PAGE_CHAT: string = 'pages/ai/ChatPage';
  
  // 个人中心页
  static readonly PAGE_PROFILE: string = 'pages/me/ProfilePage';
  
  // 心理测评页
  static readonly PAGE_ASSESSMENT: string = 'pages/assessment/AssessmentPage';
  
  // 情绪日记页
  static readonly PAGE_DIARY: string = 'pages/diary/DiaryPage';
}
