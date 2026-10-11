/**
 * 应用接续（Continuity / 跨端迁移）的状态搬运。
 *
 * 【为什么需要这个文件】
 * 系统会帮我们恢复「页面栈」，但**不会**恢复我们自己的业务状态（AppState 里那些
 * @Trace 字段）。所以需要一套「源端打包 / 对端解包」的约定，收口在这里，
 * 避免字段名散落在 EntryAbility 里变成魔法字符串。
 *
 * 【刻意搬得很小】
 * 只搬「用户视角的当前位置」——主 Tab + 品牌主题。
 * 不搬二级页面（编辑/新建语义不明，接过去变空白页很怪）、不搬草稿正文、
 * 不搬 isDark（那是设备级偏好，手机深色 / 平板浅色是正常的）。
 *
 * 【传输形态】
 * wantParam 的值在不同系统版本下可能是「原样字符串」也可能是「原样对象」，
 * 解析时两种都试，失败一律降级为「按普通启动处理」，绝不让接续失败拖垮启动。
 */
import { AbilityConstant, Want } from '@kit.AbilityKit'
import { appState } from '../state/AppState'
import { Logger } from './Logger'

const TAG = 'ContinueState'

/** wantParam 里承载接续数据的自定义 key。刻意避开系统占用的键（version / targetDevice 等） */
export const CONTINUE_KEY: string = 'mhContinueState'

/**
 * 主 Tab 数量：必须与 `MainPage` 里的 `tabs` 数组长度一致。
 * 作用是把接续来的索引「夹」在合法区间 —— 脏数据不该让 Tab 切到不存在的位置。
 * ⚠️ 以后加/减主 Tab，这里要同步改。
 */
const MAIN_TAB_COUNT: number = 5

/** 主题默认值：与 AppState.themeId 的默认值保持一致 */
const DEFAULT_THEME_ID: string = 'misty'

/** 需要在设备间搬运的状态 */
export interface ContinueState {
  /** 源端当前所在的主 Tab 索引 */
  mainTabIndex: number
  /** 品牌主题 id（用户偏好，跟人走） */
  themeId: string
}

/**
 * 源端：把当前要搬运的状态打包成 JSON 字符串。
 * 放字符串而不是放对象 —— 这是官方示例的通行做法，跨版本最稳。
 */
export function packContinueState(): string {
  const payload: ContinueState = {
    mainTabIndex: appState().mainTabIndex,
    themeId: appState().themeId
  }
  return JSON.stringify(payload)
}

/**
 * 从 want 里解出接续状态。
 *
 * 返回 null 表示「本次不是接续启动」或「数据不可用」——
 * 两种情况对调用方是一样的处理：按普通启动走。
 */
export function unpackContinueState(want: Want): ContinueState | null {
  const raw: Object | undefined = want.parameters ? want.parameters[CONTINUE_KEY] : undefined
  if (raw === undefined || raw === null) {
    return null
  }

  // 两种传输形态都试：
  //   形态一 —— 源端写的是 JSON 字符串（我们自己的写法，正常情况下走这条）
  //   形态二 —— 个别系统版本会把值包成对象透传，这时退回 stringify 再解
  let parsed: Record<string, Object> | null = null
  try {
    parsed = JSON.parse(raw as string) as Record<string, Object>
  } catch (error) {
    try {
      parsed = JSON.parse(JSON.stringify(raw)) as Record<string, Object>
    } catch (inner) {
      Logger.warn(TAG, '接续数据解析失败，按普通启动处理')
      parsed = null
    }
  }

  if (parsed === null) {
    return null
  }

  const rawTab: Object | undefined = parsed.mainTabIndex
  const rawTheme: Object | undefined = parsed.themeId

  const tab: number = typeof rawTab === 'number' ? rawTab as number : 0
  const theme: string = typeof rawTheme === 'string' ? rawTheme as string : DEFAULT_THEME_ID

  return {
    // 夹到合法范围：脏数据不应该让 Tab 切到不存在的位置
    mainTabIndex: Math.max(0, Math.min(MAIN_TAB_COUNT - 1, Math.floor(tab))),
    themeId: theme.length > 0 ? theme : DEFAULT_THEME_ID
  }
}

/** 本次启动是否由「接续」触发 */
export function isContinuationLaunch(launchParam: AbilityConstant.LaunchParam): boolean {
  return launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION
}

/**
 * 本次启动是否需要恢复「搬运状态」—— 接续（CONTINUATION）与故障恢复（APP_RECOVERY）共用同一套
 * wantParam 数据和同一个 key，所以入口判断也共用这一个。
 */
export function isStateRestoreLaunch(launchParam: AbilityConstant.LaunchParam): boolean {
  return launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION
      || launchParam.launchReason === AbilityConstant.LaunchReason.APP_RECOVERY
}

// 服务卡片快捷入口的 target → 主 Tab 索引。
// 顺序必须与 MainPage 的 tabs 数组一致（0 首页 / 1 树洞 / 2 日记 / 3 自查 / 4 我的）。
const TAB_TREEHOLE: number = 1
const TAB_DIARY: number = 2
const TAB_ASSESS: number = 3
const TAB_ME: number = 4

/**
 * 卡片点击带过来的 cardTarget 字符串 → 主 Tab 索引；不认识的返回 -1（调用方忽略）。
 * 卡片与接续/故障恢复共用同一条「落到指定 Tab」的通道，这里只做映射。
 */
export function cardTargetToTab(target: string): number {
  if (target === 'treehole') return TAB_TREEHOLE
  if (target === 'diary') return TAB_DIARY
  if (target === 'assess') return TAB_ASSESS
  if (target === 'me') return TAB_ME
  return -1
}
