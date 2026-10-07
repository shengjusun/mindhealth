/**
 * 动态数据本地快照仓库（弱网降级）
 *
 * 设计目标：日记 / 测评记录 / 用户资料这类「动态数据」断网时不能白屏，
 * 所以页面一律先渲染上一次成功加载的快照，再后台静默刷新（SWR）。
 *
 * 职责边界：
 *   - 只做只读快照的存取，不参与任何写操作（离线新增日记等不在范围内）
 *   - 存后端原始返回结构，页面沿用已有的类型转换，无需为缓存新增类型
 *   - 任何读写失败都记录日志并降级返回空，绝不向上抛异常
 *
 * 容量约束：日记快照最多 20 条，且序列化后字节数超过上限会从尾部继续截断，
 * 避免 Preferences 被大对象撑爆。
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { Logger } from '../../common/utils/Logger'
import { SnapshotConfig } from '../../common/constants/AppConstants'

const TAG = 'SnapshotRepository'

export class SnapshotRepository {
  private static instance: SnapshotRepository

  private context: common.Context | null = null
  private store: preferences.Preferences | null = null

  static getInstance(): SnapshotRepository {
    if (!SnapshotRepository.instance) {
      SnapshotRepository.instance = new SnapshotRepository()
    }
    return SnapshotRepository.instance
  }

  /**
   * 注入上下文。在 EntryAbility 启动时调用一次；未注入时读写全部降级为空。
   */
  async init(context: common.Context): Promise<void> {
    this.context = context
    await this.getStore()
  }

  private async getStore(): Promise<preferences.Preferences | null> {
    if (this.store) {
      return this.store
    }
    if (!this.context) {
      Logger.error(TAG, 'Preferences 不可用：Context 未注入')
      return null
    }
    try {
      this.store = await preferences.getPreferences(this.context, SnapshotConfig.PREFERENCES_NAME)
      return this.store
    } catch (error) {
      Logger.error(TAG, `打开快照缓存失败: ${JSON.stringify(error)}`)
      return null
    }
  }

  // ===================== 读取 =====================

  /**
   * 日记列表快照。没有快照返回 null，由页面决定空态
   */
  async getDiaryList(): Promise<Object[] | null> {
    return this.readList(SnapshotConfig.KEY_DIARY_LIST)
  }

  async getDiaryTimestamp(): Promise<number> {
    return this.readTimestamp(SnapshotConfig.KEY_DIARY_TS)
  }

  async getAssessmentResults(): Promise<Object[] | null> {
    return this.readList(SnapshotConfig.KEY_ASSESSMENT_LIST)
  }

  async getAssessmentTimestamp(): Promise<number> {
    return this.readTimestamp(SnapshotConfig.KEY_ASSESSMENT_TS)
  }

  /**
   * 日记总数快照。日记列表会被截断到 20 条，所以总数必须单独存。
   * 没有快照返回 null，由页面区分「0 条」与「没有快照」。
   */
  async getDiaryCount(): Promise<number | null> {
    return this.readNumber(SnapshotConfig.KEY_DIARY_COUNT)
  }

  async getAssessmentCount(): Promise<number | null> {
    return this.readNumber(SnapshotConfig.KEY_ASSESSMENT_COUNT)
  }

  async getUserProfile(): Promise<Object | null> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return null
    }
    try {
      const cached: string = await store.get(SnapshotConfig.KEY_USER_PROFILE, '') as string
      if (cached.length === 0) {
        return null
      }
      return JSON.parse(cached) as Object
    } catch (error) {
      Logger.error(TAG, `读取用户资料快照失败: ${JSON.stringify(error)}`)
      return null
    }
  }

  async getUserTimestamp(): Promise<number> {
    return this.readTimestamp(SnapshotConfig.KEY_USER_TS)
  }

  private async readList(key: string): Promise<Object[] | null> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return null
    }
    try {
      const cached: string = await store.get(key, '') as string
      if (cached.length === 0) {
        return null
      }
      const parsed: Object = JSON.parse(cached) as Object
      return Array.isArray(parsed) ? parsed as Object[] : null
    } catch (error) {
      Logger.error(TAG, `读取快照失败 ${key}: ${JSON.stringify(error)}`)
      return null
    }
  }

  private async readTimestamp(key: string): Promise<number> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return 0
    }
    try {
      return await store.get(key, 0) as number
    } catch (error) {
      Logger.error(TAG, `读取快照时间失败 ${key}: ${JSON.stringify(error)}`)
      return 0
    }
  }

  private async readNumber(key: string): Promise<number | null> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return null
    }
    try {
      const has: boolean = await store.has(key)
      if (!has) {
        return null
      }
      return await store.get(key, 0) as number
    } catch (error) {
      Logger.error(TAG, `读取快照数值失败 ${key}: ${JSON.stringify(error)}`)
      return null
    }
  }

  // ===================== 写入 =====================

  /**
   * 写日记快照：先按条数上限截断，再按字节上限截断，最后落盘。
   * 写入失败必须记录日志，不允许静默失败。
   */
  async saveDiaryList(list: Object[]): Promise<void> {
    const text: string = SnapshotRepository.serializeWithLimit(list, SnapshotConfig.DIARY_MAX_COUNT)
    await this.write(SnapshotConfig.KEY_DIARY_LIST, SnapshotConfig.KEY_DIARY_TS, text, list.length)
    await this.writeCount(SnapshotConfig.KEY_DIARY_COUNT, list.length)
  }

  async saveAssessmentResults(list: Object[]): Promise<void> {
    // 后端 /assessment/results 返回完整实体行，answers_json（逐题明细）与 ai_analysis
    // （AI 长文）会让单条记录达到 12KB+，直接序列化必然超出 MAX_BYTES 且截断救不回来
    // （裁到 0 条才能达标），表现为快照永远写入失败、离线降级对测评记录失效。
    // 快照只服务展示：这里投影出 UI 实际读取的字段后再走截断落盘。
    const slim: Object[] = list.map((item: Object): Object => SnapshotRepository.projectAssessmentRecord(item))
    const text: string = SnapshotRepository.serializeWithLimit(slim, SnapshotConfig.ASSESSMENT_MAX_COUNT)
    await this.write(SnapshotConfig.KEY_ASSESSMENT_LIST, SnapshotConfig.KEY_ASSESSMENT_TS,
      text, slim.length)
    await this.writeCount(SnapshotConfig.KEY_ASSESSMENT_COUNT, list.length)
  }

  async saveUserProfile(profile: Object): Promise<void> {
    await this.write(SnapshotConfig.KEY_USER_PROFILE, SnapshotConfig.KEY_USER_TS,
      JSON.stringify(profile), 1)
  }

  private async write(key: string, tsKey: string, text: string, originCount: number): Promise<void> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      Logger.error(TAG, `写入快照失败 ${key}：Preferences 不可用`)
      return
    }

    const bytes: number = SnapshotRepository.utf8ByteLength(text)
    if (bytes > SnapshotConfig.MAX_BYTES) {
      Logger.error(TAG, `写入快照失败 ${key}：截断后仍有 ${bytes} 字节，超过上限 ${SnapshotConfig.MAX_BYTES}`)
      return
    }

    try {
      await store.put(key, text)
      await store.put(tsKey, Date.now())
      await store.flush()
      Logger.info(TAG, `快照已写入 ${key}，${originCount} 条 / ${bytes} 字节`)
    } catch (error) {
      Logger.error(TAG, `写入快照失败 ${key}: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 只更新统计数字。MePage 拿到的日记接口可能是 { total, records } 包装结构，
   * 无法直接当数组存，所以总数单独落盘，避免被 20 条截断影响。
   */
  async saveCounts(diaryCount: number, assessmentCount: number): Promise<void> {
    await this.writeCount(SnapshotConfig.KEY_DIARY_COUNT, diaryCount)
    await this.writeCount(SnapshotConfig.KEY_ASSESSMENT_COUNT, assessmentCount)
  }

  private async writeCount(key: string, count: number): Promise<void> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return
    }
    try {
      await store.put(key, count)
      await store.flush()
    } catch (error) {
      Logger.error(TAG, `写入快照统计失败 ${key}: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 登出时清空全部快照，避免多账号串显
   */
  async clearAll(): Promise<void> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return
    }
    try {
      await store.clear()
      await store.flush()
      Logger.info(TAG, '快照已清空（登出）')
    } catch (error) {
      Logger.error(TAG, `清空快照失败: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 测评记录快照字段白名单：只保留列表卡与首页最近状态卡实际读取的字段。
   * 已知消费方：MyRecordsPage / HomePageNew（assessmentTitle/score/level/suggestion/createTime）、
   * HomePageNew（aiStatus，空响应防护判断）；id 保留——记录卡进结果详情要按它跳转。
   */
  private static projectAssessmentRecord(item: Object): Object {
    const src = item as Record<string, Object>
    const out: Record<string, Object> = {}
    const keep: string[] = ['id', 'assessmentTitle', 'score', 'level', 'suggestion', 'createTime', 'aiStatus']
    for (const key of keep) {
      if (src[key] !== undefined && src[key] !== null) {
        out[key] = src[key]
      }
    }
    return out
  }

  // ===================== 工具 =====================

  /**
   * 序列化并做双重截断：先限制条数，再从尾部逐条丢弃直到字节数达标。
   * 极端情况（单条就超限）会返回空数组的序列化结果，由调用方决定如何处理。
   */
  private static serializeWithLimit(list: Object[], maxCount: number): string {
    let items: Object[] = list.length > maxCount ? list.slice(0, maxCount) : list
    let text: string = JSON.stringify(items)

    while (items.length > 0 && SnapshotRepository.utf8ByteLength(text) > SnapshotConfig.MAX_BYTES) {
      items = items.slice(0, items.length - 1)
      text = JSON.stringify(items)
    }

    if (items.length < list.length) {
      Logger.warn(TAG, `快照已按条数截断：${list.length} 条 -> ${items.length} 条`)
    }
    return text
  }

  /**
   * 手动计算 UTF-8 字节数，避免依赖 TextEncoder 的接口差异
   */
  private static utf8ByteLength(text: string): number {
    let bytes: number = 0
    for (let i = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i)
      if (code < 0x80) {
        bytes += 1
      } else if (code < 0x800) {
        bytes += 2
      } else if (code >= 0xD800 && code <= 0xDBFF) {
        // 代理对，按 4 字节计，跳过低位
        bytes += 4
        i++
      } else {
        bytes += 3
      }
    }
    return bytes
  }

  /**
   * 把快照时间戳转成「更新于 X 前」文案。
   * 快照必须让用户知情，所以展示旧数据时一定要带上这个标注。
   */
  static formatAgoText(timestamp: number): string {
    if (timestamp <= 0) {
      return ''
    }

    const diff: number = Date.now() - timestamp
    if (diff < 60 * 1000) {
      return '更新于刚刚'
    }
    if (diff < 60 * 60 * 1000) {
      return `更新于 ${Math.floor(diff / (60 * 1000))} 分钟前`
    }
    if (diff < 24 * 60 * 60 * 1000) {
      return `更新于 ${Math.floor(diff / (60 * 60 * 1000))} 小时前`
    }
    return `更新于 ${Math.floor(diff / (24 * 60 * 60 * 1000))} 天前`
  }
}
