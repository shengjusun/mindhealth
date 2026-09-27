/**
 * 数据库配置
 */

// API端点接口
interface ApiEndpoints {
  // 用户相关
  LOGIN: string;
  REGISTER: string;
  HUAWEI_LOGIN: string; // 华为账号登录
  USER_INFO: string;
  UPDATE_USER: string;
  AVATAR_UPLOAD: string; // 头像上传

  // 日记相关
  DIARY_LIST: string;
  DIARY_ADD: string;
  DIARY_UPDATE: string;
  DIARY_DELETE: string;

  // 测评相关
  ASSESSMENT_LIST: string;
  ASSESSMENT_SUBMIT: string;
  ASSESSMENT_RESULT: string;
  ASSESSMENT_RESULTS: string;
  /** 单条结果，用于轮询 AI 解读：/api/assessment/result/{id} */
  ASSESSMENT_RESULT_DETAIL: string;

  // 量表题库（静态化接口，后端已 permitAll）
  SCALE_MANIFEST: string;
  SCALE_QUESTIONS: string;

  // AI对话相关
  CHAT_SEND: string;
  CHAT_HISTORY: string;

  // 文章相关
  ARTICLE_LIST: string;
  ARTICLE_DETAIL: string;
}

/**
 * 默认后端地址。演示 / 换网络环境时改这里 —— 现场最常改的一行。
 */
const DEFAULT_API_BASE_URL: string = 'http://REMOVED:9000';

export class ApiConfig  {

  /**
   * ⚠️ 演示 / 换网络环境时改上面的 DEFAULT_API_BASE_URL。
   *
   * 这个字段不再是 readonly：EntryAbility 启动时会尝试从 Preferences 的
   * api_base_url 读取覆盖值（现场临时切后端不必重新打包），读不到就保持默认值。
   */
  static API_BASE_URL: string = DEFAULT_API_BASE_URL;

  // API端点
  static readonly ENDPOINTS: ApiEndpoints = {
    // 用户相关
    LOGIN: '/api/user/login',
    REGISTER: '/api/user/register',
    HUAWEI_LOGIN: '/api/user/huawei/login',
    USER_INFO: '/api/user/info',
    UPDATE_USER: '/api/user/update',
    AVATAR_UPLOAD: '/api/user/avatar/upload',

    // 日记相关
    DIARY_LIST: '/api/diary',
    DIARY_ADD: '/api/diary',
    DIARY_UPDATE: '/api/diary',
    DIARY_DELETE: '/api/diary',

    // 测评相关
    ASSESSMENT_LIST: '/api/assessment/list',
    ASSESSMENT_SUBMIT: '/api/assessment/submit',
    ASSESSMENT_RESULT: '/api/assessment',
    ASSESSMENT_RESULTS: '/api/assessment/results',
    // 注意：不能复用 ASSESSMENT_RESULT（/api/assessment/{id} 是「按 id 取量表」，
    // 与「按 id 取测评结果」是两个接口）
    ASSESSMENT_RESULT_DETAIL: '/api/assessment/result',

    // 量表题库（静态化接口，后端已 permitAll）
    SCALE_MANIFEST: '/api/assessment/manifest',
    SCALE_QUESTIONS: '/api/assessment',

    // AI对话相关
    CHAT_SEND: '/api/ai/chat',
    CHAT_HISTORY: '/api/ai/history',

    // 文章相关
    ARTICLE_LIST: '/api/article/list',
    ARTICLE_DETAIL: '/api/article/detail'
  };
}

/**
 * 设置运行期后端地址。
 *
 * 传空串（或只有空白）表示恢复默认值。由 EntryAbility 启动时从 Preferences
 * 的 api_base_url 读取后调用，必须在任何 ApiService 实例创建之前完成。
 */
export function setApiBaseUrl(url: string): void {
  const trimmed: string = url ? url.trim() : '';
  ApiConfig.API_BASE_URL = trimmed.length > 0 ? trimmed : DEFAULT_API_BASE_URL;
}
