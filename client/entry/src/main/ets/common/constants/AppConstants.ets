/**
 * 应用常量配置（已裁剪）
 *
 * 说明：历史上这里还定义过 StorageConfig / SecurityConfig / BusinessConfig /
 * CrisisConfig / RouterConfig 五个类，实际零引用（RouterConfig 指向的页面甚至
 * 早已改名或删除），已随死代码清理一并移除。只保留两个真实使用方引用的配置：
 * ScaleConfig（题库四级降级缓存，ScaleRepository 用）、SnapshotConfig（弱网
 * 快照，SnapshotRepository 用）。
 *
 * 注意：接口地址与接口路径一律以 common/constants/apiConfig.ets 中的 ApiConfig
 * 为准，本文件不定义 ApiConfig。
 */

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

  // 测评快照最多保留条数（投影后单条约 200 字节，20 条远在字节上限内）
  static readonly ASSESSMENT_MAX_COUNT: number = 20;

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
