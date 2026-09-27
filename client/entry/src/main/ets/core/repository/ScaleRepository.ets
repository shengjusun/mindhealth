/**
 * 量表题库仓库
 *
 * 设计目标：心理测评必须能在弱网 / 断网环境下使用，所以题目一律「本地优先」。
 * 读取优先级（四级降级）：
 *   1. 内存缓存  —— 同一次会话内重复进入测评页零 IO
 *   2. 本地缓存  —— Preferences（上次联网拉到的最新版）
 *   3. 内置题库  —— rawfile/scales/*.json（打进 HAP，首次安装 / 从未联网也能用）
 *   4. 网络拉取  —— /api/assessment/manifest、/api/assessment/{id}/questions，成功即写回本地缓存
 *
 * 任何一步失败都继续降级而不是抛错，保证「拿不到网络也一定有题可做」。
 */
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'
import { util } from '@kit.ArkTS'
import { ApiService } from '../api/ApiService'
import { Logger } from '../../common/utils/Logger'
import { ScaleConfig } from '../../common/constants/AppConstants'
import { ScaleDetail, ScaleManifest, ScaleMeta } from '../../common/types/ScaleTypes'

const TAG = 'ScaleRepository'

export class ScaleRepository {
  private static instance: ScaleRepository

  // 应用上下文，在 EntryAbility 中注入，rawfile 读取和 Preferences 都依赖它
  private context: common.Context | null = null

  // 题库缓存专用的 Preferences 实例
  private store: preferences.Preferences | null = null

  private apiService: ApiService = ApiService.getInstance()

  // 一级缓存：内存
  private manifestCache: ScaleManifest | null = null
  private detailCache: Map<number, ScaleDetail> = new Map()

  // 最近一次题目来源（memory / cache / rawfile / network / none），仅用于排障
  private lastSource: string = 'none'

  // 量表列表缓存（与 manifestCache 同源，单独存一份避免每次遍历解析）
  private listCache: ScaleMeta[] | null = null

  // 静默刷新失败退避：失败后 60 秒内不再重试，
  // 避免后端挂掉 / 弱网时切 Tab 反复发起注定失败的请求
  private static readonly REFRESH_BACKOFF_MS: number = 60000
  private lastRefreshFailAt: number = 0

  static getInstance(): ScaleRepository {
    if (!ScaleRepository.instance) {
      ScaleRepository.instance = new ScaleRepository()
    }
    return ScaleRepository.instance
  }

  /**
   * 注入上下文。必须在 EntryAbility 启动时调用一次，
   * 否则 rawfile / Preferences 都拿不到，只能走网络。
   */
  async init(context: common.Context): Promise<void> {
    this.context = context
    await this.getStore()
    // 关键：用安装包内置题库给缓存打底。
    // 否则缓存只在「网络拉取成功」时才写入，首次联网若题目来自 rawfile，
    // 缓存会一直是空的，断网后就真的无题可出。
    await this.seedFromRawFile()
  }

  /**
   * 用 rawfile 内置题库初始化 Preferences 缓存。
   * 已有的缓存不覆盖，只补齐缺失的量表。
   */
  private async seedFromRawFile(): Promise<void> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      Logger.warn(TAG, '播种失败：Preferences 不可用')
      return
    }

    const manifest: ScaleManifest | null = await this.getManifestLocal()
    const ids: number[] = []
    if (manifest && Array.isArray(manifest.scales)) {
      for (const meta of manifest.scales) {
        ids.push(meta.id)
      }
    }
    // 内置清单缺失或登记不全（例如 5.json 没进清单）时，兜底扫 1~20
    if (ids.length === 0) {
      for (let i = 1; i <= 20; i++) {
        ids.push(i)
      }
    }

    let seeded: number = 0
    for (const id of ids) {
      const detail: ScaleDetail | null = await this.readScaleFromRawFile(id)
      if (!detail) {
        continue
      }
      const exists: string = await this.readCacheText(id)
      if (exists.length > 0) {
        continue
      }
      await this.writeDetailCache(id, detail)
      seeded++
    }
    Logger.info(TAG, `内置题库播种完成，新增 ${seeded} 套`)
  }

  // ------------------------------------------------------------------ 对外接口

  /**
   * 获取量表清单（本地优先，不阻塞网络）
   * 返回 null 表示本地与网络都拿不到，调用方需要做空态处理
   */
  async getManifest(): Promise<ScaleManifest | null> {
    return this.getManifestLocal()
  }

  /**
   * 获取量表列表（Offline-First，供自查列表页使用）
   * 降级链路：内存 → Preferences 缓存 → rawfile 内置 manifest → 网络
   * 网络只在本地全空时才兜底触发，且失败静默返回空数组，绝不向 UI 抛错。
   */
  async getScaleList(): Promise<ScaleMeta[]> {
    const local: ScaleMeta[] = await this.getScaleListLocal()
    if (local.length > 0) {
      Logger.info(TAG, `量表列表命中本地，共 ${local.length} 套`)
      return local
    }
    // 本地都没有（极端情况：内置清单缺失且缓存被清），才走一次网络。
    // 这里必须绕过退避：本地真为空时还得靠它去拉，被退避挡住就只能显示空态了
    return this.refreshScaleList(false)
  }

  /**
   * SWR 的 revalidate 步骤：静默刷新列表。
   * 成功则返回最新列表并写缓存；失败返回空数组，调用方据此保留本地数据不变。
   */
  async refreshScaleList(respectBackoff: boolean = true): Promise<ScaleMeta[]> {
    if (respectBackoff && this.isRefreshBackedOff()) {
      Logger.info(TAG, '静默刷新退避中，跳过本次请求')
      return []
    }

    try {
      const manifest: ScaleManifest | null = await this.fetchManifestFromNetwork()
      if (manifest && Array.isArray(manifest.scales) && manifest.scales.length > 0) {
        this.manifestCache = manifest
        this.listCache = manifest.scales
        await this.writeManifestCache(manifest)
        // 列表刷新顺带把新增 / 变更的量题目同步下来
        await this.syncScalesFromManifest(manifest)
        Logger.info(TAG, `量表列表静默刷新成功，共 ${manifest.scales.length} 套`)
        this.markRefreshSucceeded()
        return manifest.scales
      }
      Logger.warn(TAG, '量表列表静默刷新：网络返回为空')
    } catch (error) {
      Logger.warn(TAG, `量表列表静默刷新失败（已忽略）: ${JSON.stringify(error)}`)
    }

    this.markRefreshFailed()
    return []
  }

  // ------------------------------------------------------------------ 静默刷新退避

  /** 距上次静默刷新失败是否还在退避窗口内 */
  private isRefreshBackedOff(): boolean {
    return this.lastRefreshFailAt > 0
      && (Date.now() - this.lastRefreshFailAt) < ScaleRepository.REFRESH_BACKOFF_MS
  }

  private markRefreshFailed(): void {
    this.lastRefreshFailAt = Date.now()
  }

  private markRefreshSucceeded(): void {
    this.lastRefreshFailAt = 0
  }

  /**
   * 只从本地取列表：内存 → Preferences 缓存 → rawfile 内置 manifest
   */
  private async getScaleListLocal(): Promise<ScaleMeta[]> {
    if (this.listCache && this.listCache.length > 0) {
      return this.listCache
    }

    const manifest: ScaleManifest | null = await this.getManifestLocal()
    if (manifest && Array.isArray(manifest.scales) && manifest.scales.length > 0) {
      this.listCache = manifest.scales
      return this.listCache
    }
    return []
  }

  /**
   * 按清单同步题目：只补本地没有或版本落后的量表
   */
  private async syncScalesFromManifest(manifest: ScaleManifest): Promise<void> {
    for (const meta of manifest.scales ?? []) {
      const cached: string = await this.readCacheText(meta.id)
      if (cached.length > 0 && !await this.isStale(meta.id)) {
        continue
      }
      await this.syncScaleFromNetwork(meta.id)
    }
  }

  /**
   * 获取单套量表题目（本地优先，本地没有才走网络）
   */
  async getScale(id: number): Promise<ScaleDetail | null> {
    const local: ScaleDetail | null = await this.getScaleLocal(id)
    if (local) {
      return local
    }
    return this.syncScaleFromNetwork(id)
  }

  /**
   * 只从本地取，绝不发网络请求。
   * 断网保底场景（如离线模式开关）用这个。
   */
  async getScaleOffline(id: number): Promise<ScaleDetail | null> {
    return this.getScaleLocal(id)
  }

  /**
   * 后台静默刷新：拉清单 → 版本变了或缓存过期 → 逐套更新。
   * 全程 try/catch，失败不影响启动。
   */
  async refreshFromNetwork(): Promise<void> {
    if (this.isRefreshBackedOff()) {
      Logger.info(TAG, '静默刷新退避中，跳过本次请求')
      return
    }

    try {
      const remote: ScaleManifest | null = await this.fetchManifestFromNetwork()
      if (!remote) {
        this.markRefreshFailed()
        return
      }

      // 远端清单为空 = 后端题库未发布 / 接口异常（静态题库缺失时 manifest 恒为
      // version 0、scales []）。这种情况绝不能覆盖本地：一旦写进去，
      // 内存与缓存里的量表会被清空，自查页直接空白，且内置题库也救不回来。
      if (!Array.isArray(remote.scales) || remote.scales.length === 0) {
        Logger.warn(TAG, `远端清单为空（version=${remote.version}），保留本地题库不覆盖`)
        this.markRefreshFailed()
        return
      }

      const local: ScaleManifest | null = await this.getManifestLocal()
      const versionChanged: boolean = !local || local.version !== remote.version

      await this.writeManifestCache(remote)

      const metas: ScaleMeta[] = remote.scales ?? []
      for (const meta of metas) {
        // 版本没变且缓存没过期就跳过，避免每次启动都拉全量题库
        if (!versionChanged && !await this.isStale(meta.id) && await this.getScaleLocal(meta.id)) {
          continue
        }
        await this.syncScaleFromNetwork(meta.id)
      }
      Logger.info(TAG, `题库刷新完成，共 ${metas.length} 套`)
      this.markRefreshSucceeded()
    } catch (error) {
      Logger.warn(TAG, `题库后台刷新失败: ${JSON.stringify(error)}`)
      this.markRefreshFailed()
    }
  }

  /**
   * 按清单把全部量表拉到本地（首次联网预热用）
   */
  async prefetchAll(): Promise<void> {
    const manifest: ScaleManifest | null = await this.getManifest()
    if (!manifest) {
      return
    }
    for (const meta of manifest.scales ?? []) {
      await this.syncScaleFromNetwork(meta.id)
    }
  }

  /**
   * 清空本地题库缓存（调试 / 题库紧急回滚时用）
   */
  async clearCache(): Promise<void> {
    this.manifestCache = null
    this.detailCache.clear()
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return
    }
    try {
      await store.clear()
      await store.flush()
    } catch (error) {
      Logger.warn(TAG, `清空题库缓存失败: ${JSON.stringify(error)}`)
    }
  }

  // ------------------------------------------------------------------ 本地读取

  private async getManifestLocal(): Promise<ScaleManifest | null> {
    if (this.manifestCache) {
      return this.manifestCache
    }

    const store: preferences.Preferences | null = await this.getStore()
    if (store) {
      try {
        const cached: string = await store.get(ScaleConfig.KEY_MANIFEST, '') as string
        if (cached.length > 0) {
          const parsed: ScaleManifest = JSON.parse(cached) as ScaleManifest
          // 缓存里若是一份空清单（历史版本拉到过后端未发布的 manifest），
          // 不能当作有效数据返回，否则自查页会一直空白且无法自愈。
          if (Array.isArray(parsed.scales) && parsed.scales.length > 0) {
            this.manifestCache = parsed
            return this.manifestCache
          }
          Logger.warn(TAG, '本地清单缓存为空，回落内置清单')
        }
      } catch (error) {
        Logger.warn(TAG, `解析本地清单缓存失败: ${JSON.stringify(error)}`)
      }
    }

    // 缓存没有或无效，回落到安装包内置清单
    const raw: string | null = this.readRawFile(ScaleConfig.MANIFEST_FILE)
    if (raw) {
      try {
        const parsed: ScaleManifest = JSON.parse(raw) as ScaleManifest
        this.manifestCache = parsed
        // 顺手把内置清单写回缓存：既省掉下次启动再读一次 rawfile，
        // 也让被空清单污染过的老设备能自动恢复到可用状态。
        await this.writeManifestCache(parsed)
        return this.manifestCache
      } catch (error) {
        Logger.warn(TAG, `解析内置清单失败: ${JSON.stringify(error)}`)
      }
    }
    return null
  }

  private async getScaleLocal(id: number): Promise<ScaleDetail | null> {
    const memory: ScaleDetail | undefined = this.detailCache.get(id)
    if (memory) {
      this.lastSource = 'memory'
      Logger.info(TAG, `量表 ${id} 命中内存缓存`)
      return memory
    }

    const cached: string = await this.readCacheText(id)
    if (cached.length > 0) {
      try {
        const detail: ScaleDetail = JSON.parse(cached) as ScaleDetail
        this.detailCache.set(id, detail)
        this.lastSource = 'cache'
        Logger.info(TAG, `量表 ${id} 命中本地缓存`)
        return detail
      } catch (error) {
        Logger.warn(TAG, `解析量表 ${id} 本地缓存失败: ${JSON.stringify(error)}`)
      }
    }

    // 回落到安装包内置题库
    const detail: ScaleDetail | null = await this.readScaleFromRawFile(id)
    if (detail) {
      this.detailCache.set(id, detail)
      this.lastSource = 'rawfile'
      Logger.info(TAG, `量表 ${id} 命中内置题库`)
      return detail
    }

    this.lastSource = 'none'
    Logger.warn(TAG, `量表 ${id} 本地三处均未命中（内存/缓存/内置）`)
    return null
  }

  /**
   * 只从 Preferences 缓存读取原始文本，不做解析
   */
  private async readCacheText(id: number): Promise<string> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return ''
    }
    try {
      return await store.get(ScaleConfig.KEY_PREFIX_DETAIL + id, '') as string
    } catch (error) {
      Logger.warn(TAG, `读取量表 ${id} 缓存失败: ${JSON.stringify(error)}`)
      return ''
    }
  }

  /**
   * 只从 rawfile 内置题库读取
   */
  private async readScaleFromRawFile(id: number): Promise<ScaleDetail | null> {
    const raw: string | null = this.readRawFile(`${ScaleConfig.RAWFILE_DIR}/${id}.json`)
    if (!raw) {
      return null
    }
    try {
      return JSON.parse(raw) as ScaleDetail
    } catch (error) {
      Logger.warn(TAG, `解析内置量表 ${id} 失败: ${JSON.stringify(error)}`)
      return null
    }
  }

  /**
   * 读取 rawfile 并解码成字符串
   * rawfile 是只读资源，直接打进 HAP，是断网兜底的最后一道防线
   */
  private readRawFile(fileName: string): string | null {
    if (!this.context) {
      Logger.error(TAG, `读取内置资源失败 ${fileName}：Context 未注入`)
      return null
    }
    try {
      const bytes: Uint8Array = this.context.resourceManager.getRawFileContentSync(fileName)
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8')
      const text: string = decoder.decodeToString(bytes)
      if (text.length === 0) {
        Logger.error(TAG, `内置资源 ${fileName} 内容为空`)
        return null
      }
      return text
    } catch (error) {
      Logger.error(TAG, `读取内置资源失败 ${fileName}: ${JSON.stringify(error)}`)
      return null
    }
  }

  /**
   * 排障用：把各级数据源的可用性拼成一行文本，
   * 断网出问题时可以直接在页面上看到是哪一级挂了，不必抓 logcat。
   */
  async getDiagnostics(id: number): Promise<string> {
    const parts: string[] = []
    parts.push(`ctx=${this.context ? 'Y' : 'N'}`)
    parts.push(`store=${this.store ? 'Y' : 'N'}`)
    parts.push(`cache=${(await this.readCacheText(id)).length > 0 ? 'Y' : 'N'}`)
    parts.push(`rawfile=${this.readRawFile(`${ScaleConfig.RAWFILE_DIR}/${id}.json`) ? 'Y' : 'N'}`)
    parts.push(`manifest=${this.readRawFile(ScaleConfig.MANIFEST_FILE) ? 'Y' : 'N'}`)
    parts.push(`src=${this.lastSource}`)
    parts.push(`id=${id}`)
    return parts.join(' ')
  }

  // ------------------------------------------------------------------ 网络同步

  private async fetchManifestFromNetwork(): Promise<ScaleManifest | null> {
    try {
      // 走静默档（8 秒超时）：这是后台刷新，不该占着连接等满 60 秒
      const res = await this.apiService.getScaleManifestSilent()
      if (res.code !== 200) {
        Logger.warn(TAG, `拉取量表清单失败 code=${res.code}`)
        return null
      }
      const parsed: Object | null = this.coerceJson(res.data)
      if (!parsed) {
        return null
      }
      return parsed as ScaleManifest
    } catch (error) {
      Logger.warn(TAG, `拉取量表清单异常: ${JSON.stringify(error)}`)
      return null
    }
  }

  private async syncScaleFromNetwork(id: number): Promise<ScaleDetail | null> {
    try {
      // 走静默档（8 秒超时）：同上，后台补题目不进前台超时
      const res = await this.apiService.getScaleQuestionsSilent(id)
      if (res.code !== 200) {
        Logger.warn(TAG, `拉取量表 ${id} 失败 code=${res.code}`)
        return null
      }
      const parsed: Object | null = this.coerceJson(res.data)
      if (!parsed) {
        return null
      }
      const detail: ScaleDetail = parsed as ScaleDetail
      // 后端返回的 JSON 里 id 可能缺失，这里兜底补上，避免后续按 id 取缓存错位
      detail.id = id
      this.detailCache.set(id, detail)
      await this.writeDetailCache(id, detail)
      this.lastSource = 'network'
      return detail
    } catch (error) {
      Logger.warn(TAG, `拉取量表 ${id} 异常: ${JSON.stringify(error)}`)
      return null
    }
  }

  /**
   * 兼容后端两种返回形态：
   *  - data 是对象（正常 JSON 序列化）
   *  - data 是字符串（后端 Service 返回的是 JSON 文本，被二次编码）
   * 统一转成对象，避免后端改返回类型时客户端崩溃。
   */
  private coerceJson(data: Object): Object | null {
    if (data === null || data === undefined) {
      return null
    }
    if (typeof data === 'string') {
      try {
        return JSON.parse(data as string) as Object
      } catch (error) {
        Logger.warn(TAG, `二次解析题库 JSON 失败: ${JSON.stringify(error)}`)
        return null
      }
    }
    return data
  }

  // ------------------------------------------------------------------ 本地写入

  private async writeManifestCache(manifest: ScaleManifest): Promise<void> {
    this.manifestCache = manifest
    this.listCache = Array.isArray(manifest.scales) ? manifest.scales : null
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return
    }
    try {
      await store.put(ScaleConfig.KEY_MANIFEST, JSON.stringify(manifest))
      await store.flush()
    } catch (error) {
      Logger.warn(TAG, `写入清单缓存失败: ${JSON.stringify(error)}`)
    }
  }

  private async writeDetailCache(id: number, detail: ScaleDetail): Promise<void> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return
    }
    try {
      await store.put(ScaleConfig.KEY_PREFIX_DETAIL + id, JSON.stringify(detail))
      await store.put(ScaleConfig.KEY_PREFIX_UPDATED_AT + id, Date.now())
      await store.flush()
    } catch (error) {
      Logger.warn(TAG, `写入量表 ${id} 缓存失败: ${JSON.stringify(error)}`)
    }
  }

  private async isStale(id: number): Promise<boolean> {
    const store: preferences.Preferences | null = await this.getStore()
    if (!store) {
      return true
    }
    try {
      const updatedAt: number = await store.get(ScaleConfig.KEY_PREFIX_UPDATED_AT + id, 0) as number
      return Date.now() - updatedAt > ScaleConfig.CACHE_TTL
    } catch (error) {
      return true
    }
  }

  // ------------------------------------------------------------------ Preferences

  private async getStore(): Promise<preferences.Preferences | null> {
    if (this.store) {
      return this.store
    }
    if (!this.context) {
      Logger.warn(TAG, '未注入 Context，题库缓存不可用，仅能读内置题库')
      return null
    }
    try {
      this.store = await preferences.getPreferences(this.context, ScaleConfig.PREFERENCES_NAME)
      return this.store
    } catch (error) {
      Logger.warn(TAG, `打开题库缓存失败: ${JSON.stringify(error)}`)
      return null
    }
  }
}
