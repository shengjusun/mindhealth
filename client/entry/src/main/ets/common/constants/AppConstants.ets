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

// 量表题库缓存配置
export class ScaleConfig {
  // 量表缓存专用的 Preferences 文件名（与业务偏好分开，避免互相污染）
  static readonly PREFERENCES_NAME: string = 'scale_cache';

  // rawfile 中内置题库所在目录
  static readonly RAWFILE_DIR: string = 'scales';

  // rawfile 中量表清单文件名
  static readonly MANIFEST_FILE: string = 'scales/manifest.json';

  // 缓存 key：量表清单
  static readonly KEY_MANIFEST: string = 'scale_manifest';

  // 缓存 key 前缀：单套量表题目
  static readonly KEY_PREFIX_DETAIL: string = 'scale_detail_';

  // 缓存 key 前缀：单套量表缓存写入时间（用于判断是否需要后台刷新）
  static readonly KEY_PREFIX_UPDATED_AT: string = 'scale_updated_at_';

  // 缓存有效期（毫秒）- 7 天。过期只触发后台静默刷新，不影响离线可用
  static readonly CACHE_TTL: number = 7 * 24 * 60 * 60 * 1000;
}

// 动态数据本地快照配置（弱网降级）
// 只缓存「上一次成功加载的只读数据」，用于断网时不白屏；不参与任何写操作
export class SnapshotConfig {
  // 快照专用的 Preferences 文件名（与量表、偏好、登录信息分开）
  static readonly PREFERENCES_NAME: string = 'snapshot_cache';

  // 日记列表快照
  static readonly KEY_DIARY_LIST: string = 'snapshot_diary_list';
  static readonly KEY_DIARY_TS: string = 'snapshot_diary_ts';

  // 测评记录列表快照
  static readonly KEY_ASSESSMENT_LIST: string = 'snapshot_assessment_list';
  static readonly KEY_ASSESSMENT_TS: string = 'snapshot_assessment_ts';

  // 统计数字单独存：日记快照会被截断到 20 条，不能直接拿列表长度当总数
  static readonly KEY_DIARY_COUNT: string = 'snapshot_diary_count';
  static readonly KEY_ASSESSMENT_COUNT: string = 'snapshot_assessment_count';

  // 用户资料快照
  static readonly KEY_USER_PROFILE: string = 'snapshot_user_profile';
  static readonly KEY_USER_TS: string = 'snapshot_user_ts';

  // 日记快照最多保留条数（超出从尾部截断）
  static readonly DIARY_MAX_COUNT: number = 20;

  // 单条快照序列化后的字节上限（超出继续从尾部截断，直到满足）
  static readonly MAX_BYTES: number = 7000;

  // 超过这个时长认为快照「偏旧」，UI 需要标注数据时间；
  // 注意：过期只影响提示，绝不阻止读取，离线永远返回快照
  static readonly STALE_TTL: number = 24 * 60 * 60 * 1000;
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
