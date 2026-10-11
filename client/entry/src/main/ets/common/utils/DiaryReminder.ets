/**
 * 每日写日记提醒（系统代理提醒）。
 *
 * 【为什么用 reminderAgentManager 而不是普通通知】
 * 普通通知只有 App 在前台/保活时才能发；而「每晚 21:30 提醒写日记」必须
 * 在 App 退后台甚至被杀之后也能准点触发 —— 这正是系统代理提醒的职责：
 * 注册一次，由系统代为准点发出，App 不需要常驻。
 *
 * 【幂等策略 —— 以系统为准】
 * 以「系统里挂着的有效提醒」为准（getValidReminders 按标题匹配），
 * 开启前先清掉旧的再建，避免重复注册出好几条；
 * Preferences 里那个开关只负责「用户想不想」，不代表系统真实状态。
 *
 * 【标题即身份】REMINDER_TITLE 同时是幂等匹配的依据：
 * 改文案必须同步改 listOurs 的匹配逻辑，否则会翻倍注册。
 */
import reminderAgentManager from '@ohos.reminderAgentManager'
import notificationManager from '@ohos.notificationManager'
import common from '@ohos.app.ability.common'
import { Logger } from './Logger'

const TAG = 'DiaryReminder'

/** 提醒标题，同时也是幂等匹配的依据（改动需同步 listOurs） */
const REMINDER_TITLE = '今天的心情，值得记一笔'
const REMINDER_CONTENT = '花一分钟，写下今天的心情吧'

/** 每晚 21:30 */
const REMINDER_HOUR = 21
const REMINDER_MINUTE = 30

/** 1~7 = 周一到周日（SDK 注释原文），全选即每天 */
const WEEK_ALL: number[] = [1, 2, 3, 4, 5, 6, 7]

/** 用户拒绝通知授权时抛出的标记：调用方据此回滚开关并提示 */
export const ERR_NOTIFICATION_DENIED = 'NOTIFICATION_DENIED'

/**
 * 开启每日提醒：确保通知授权 → 清旧 → 建新。
 * 用户拒绝通知授权时抛 ERR_NOTIFICATION_DENIED。
 */
export async function enableDailyReminder(context: common.UIAbilityContext): Promise<void> {
  // 提醒最终以通知形态弹出；通知没开的话提醒注册了也收不到
  let notificationOn: boolean = await notificationManager.isNotificationEnabled()
  if (!notificationOn) {
    // ⭐ 不能用 requestEnableNotification()：
    //    SDK 注释原文 —— 用户拒绝过一次授权后，这个 API 就**永远不再弹框**，
    //    直接抛 1600004（Notification disabled）。表现就是「开关永远打不开」（真机复现）。
    //    改走系统的通知设置半模态面板（@since 20），由用户在里面打开。
    await notificationManager.openNotificationSettings(context)
    notificationOn = await notificationManager.isNotificationEnabled()
    if (!notificationOn) {
      Logger.warn(TAG, '用户关闭通知设置面板时仍未开启通知')
      throw new Error(ERR_NOTIFICATION_DENIED)
    }
  }

  await cancelOurs()

  const alarm: reminderAgentManager.ReminderRequestAlarm = {
    reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM,
    hour: REMINDER_HOUR,
    minute: REMINDER_MINUTE,
    daysOfWeek: WEEK_ALL,
    title: REMINDER_TITLE,
    content: REMINDER_CONTENT
  }
  const id: number = await reminderAgentManager.publishReminder(alarm)
  Logger.warn(TAG, `每日提醒已创建 id=${id}（每天 ${REMINDER_HOUR}:${REMINDER_MINUTE}）`)
}

/** 关闭每日提醒：把系统里属于本功能的提醒全部取消 */
export async function disableDailyReminder(): Promise<void> {
  await cancelOurs()
  Logger.warn(TAG, '每日提醒已取消')
}

/** 查询系统里是否真的挂着本功能的提醒（以系统为准，不信任偏好值） */
export async function isDailyReminderActive(): Promise<boolean> {
  const ours: reminderAgentManager.ReminderInfo[] = await listOurs()
  return ours.length > 0
}

/**
 * 取出系统里所有本功能注册的提醒；读取失败按「没有」处理。
 * 必须用 getAllValidReminders（返回 ReminderInfo，带 reminderId）——
 * 老的 getValidReminders 返回的 ReminderRequest 上没有 id，取消时拿不到凭证。
 */
async function listOurs(): Promise<reminderAgentManager.ReminderInfo[]> {
  try {
    const all: reminderAgentManager.ReminderInfo[] = await reminderAgentManager.getAllValidReminders()
    return all.filter((r: reminderAgentManager.ReminderInfo) => r.reminderReq.title === REMINDER_TITLE)
  } catch (error) {
    Logger.warn(TAG, `读取系统提醒失败: ${JSON.stringify(error)}`)
    return []
  }
}

/** 取消本功能注册的全部提醒 */
async function cancelOurs(): Promise<void> {
  const ours: reminderAgentManager.ReminderInfo[] = await listOurs()
  for (const r of ours) {
    try {
      await reminderAgentManager.cancelReminder(r.reminderId)
    } catch (error) {
      Logger.warn(TAG, `取消提醒失败 id=${r.reminderId}: ${JSON.stringify(error)}`)
    }
  }
}
