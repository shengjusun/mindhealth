/**
 * 把「每天写日记」写进系统日历（Calendar Kit）。
 *
 * 与 DiaryReminder（系统代理提醒）互补：
 *   提醒负责「弹通知」，日历负责「用户在系统日历里能看到这个习惯、也能自己改」。
 *
 * 权限：READ_CALENDAR / WRITE_CALENDAR 是 user_grant，开关打开时运行时弹窗申请；
 *       用户拒绝则本功能静默降级（不影响提醒本身），由调用方提示。
 *
 * 幂等：以系统日历里的真实事件为准（getEvents 按标题匹配），
 *       开启前查重并清理，避免每天翻倍出现重复事件。
 */
import { calendarManager } from '@kit.CalendarKit'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { Logger } from './Logger'

const TAG = 'DiaryCalendar'

/** 日历事件标题，同时也是幂等匹配的依据（改动需同步 listOurs） */
const EVENT_TITLE = '写日记'

/** 每晚 21:30，事件持续 15 分钟 */
const EVENT_HOUR = 21
const EVENT_MINUTE = 30
const DURATION_MS = 15 * 60 * 1000

/** 日历权限：user_grant，需运行时申请 */
const CALENDAR_PERMISSIONS: Array<Permissions> = [
  'ohos.permission.READ_CALENDAR',
  'ohos.permission.WRITE_CALENDAR'
]

/** 用户拒绝日历授权时抛出的标记：调用方据此提示（不回滚提醒开关） */
export const ERR_CALENDAR_PERMISSION_DENIED = 'CALENDAR_PERMISSION_DENIED'

/** 申请日历读写权限；未全部授予返回 false */
async function requestCalendarPermission(context: common.UIAbilityContext): Promise<boolean> {
  const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager()
  const result = await atManager.requestPermissionsFromUser(context, CALENDAR_PERMISSIONS)
  // authResults 与传入的 permissions 一一对应：0 = 已授权
  const denied: number | undefined = result.authResults.find((r: number) => r !== 0)
  if (denied !== undefined) {
    Logger.warn(TAG, `日历权限未全部授予: ${JSON.stringify(result.authResults)}`)
    return false
  }
  return true
}

/** 取/建应用默认日历（不传 account，系统会挂到本应用名下） */
async function getOurCalendar(context: common.Context): Promise<calendarManager.Calendar> {
  const manager: calendarManager.CalendarManager = calendarManager.getCalendarManager(context)
  return manager.getCalendar()
}

/** 取出系统日历里所有本功能创建的事件；读取失败按「没有」处理 */
async function listOurs(calendar: calendarManager.Calendar): Promise<calendarManager.Event[]> {
  try {
    const all: calendarManager.Event[] = await calendar.getEvents()
    return all.filter((e: calendarManager.Event) => e.title === EVENT_TITLE)
  } catch (error) {
    Logger.warn(TAG, `读取日历事件失败: ${JSON.stringify(error)}`)
    return []
  }
}

/**
 * 开启：申请权限 → 清旧 → 建「每天 21:30」重复事件。
 * 用户拒绝日历授权时抛 ERR_CALENDAR_PERMISSION_DENIED。
 */
export async function enableDiaryCalendarEvent(context: common.UIAbilityContext): Promise<void> {
  const granted: boolean = await requestCalendarPermission(context)
  if (!granted) {
    throw new Error(ERR_CALENDAR_PERMISSION_DENIED)
  }

  const calendar: calendarManager.Calendar = await getOurCalendar(context)
  await cancelOurs(calendar)

  // 今天 21:30 作为重复起点，recurrenceRule=DAILY 往后每天重复
  const start = new Date()
  start.setHours(EVENT_HOUR, EVENT_MINUTE, 0, 0)
  const event: calendarManager.Event = {
    type: calendarManager.EventType.NORMAL,
    title: EVENT_TITLE,
    startTime: start.getTime(),
    endTime: start.getTime() + DURATION_MS,
    reminderTime: [0], // 事件开始时提醒
    recurrenceRule: {
      recurrenceFrequency: calendarManager.RecurrenceFrequency.DAILY
    }
  }
  const id: number = await calendar.addEvent(event)
  Logger.warn(TAG, `日历事件已创建 id=${id}（每天 ${EVENT_HOUR}:${EVENT_MINUTE}）`)
}

/** 关闭：把本功能创建的日历事件全部删除 */
export async function disableDiaryCalendarEvent(context: common.Context): Promise<void> {
  const calendar: calendarManager.Calendar = await getOurCalendar(context)
  await cancelOurs(calendar)
  Logger.warn(TAG, '日历事件已删除')
}

/** 查询系统日历里是否真的挂着本功能的事件（以系统为准；未授权按没有处理） */
export async function isDiaryCalendarEventActive(context: common.Context): Promise<boolean> {
  try {
    const calendar: calendarManager.Calendar = await getOurCalendar(context)
    const ours: calendarManager.Event[] = await listOurs(calendar)
    return ours.length > 0
  } catch (error) {
    return false
  }
}

/** 删除本功能创建的全部日历事件 */
async function cancelOurs(calendar: calendarManager.Calendar): Promise<void> {
  const ours: calendarManager.Event[] = await listOurs(calendar)
  for (const e of ours) {
    if (e.id !== undefined) {
      try {
        await calendar.deleteEvent(e.id)
      } catch (error) {
        Logger.warn(TAG, `删除日历事件失败 id=${e.id}: ${JSON.stringify(error)}`)
      }
    }
  }
}
