/**
 * 全局应用状态（ArkTS 状态管理 V2）—— 全 App 唯一的共享状态对象。
 *
 * 取代原先通过 AppStorage('mainTabIndex') + @StorageLink 做跨页通信的做法。
 * V2 中没有 @StorageLink，跨组件共享状态统一走 @ObservedV2 + AppStorageV2：
 * 任意组件拿到同一实例后，改属性即可被所有观察方感知。
 *
 * 【理解成一块公共白板】
 * 页面之间互相不认识，也不靠回调或传参通信。谁想通知别人，就往这块白板上写一笔；
 * 谁关心，就盯着对应字段看。三层机制缺一不可：
 *   1. @ObservedV2（类上）：声明这个类可以被观察。没有它，写上去也没人理；
 *   2. @Trace（字段上）：只有被标记的字段才具备通知能力。新增字段不要漏掉装饰器，
 *      否则会出现「改了但页面不刷新」这种最难查的问题；
 *   3. AppStorageV2.connect（见下方 appState()）：全局登记处。
 *      所有人用同一把钥匙 APP_STATE_KEY 去取，拿到的都是同一个实例。
 *
 * 文件下半部分（Navigation 路由助手）与「状态」无关，因为要操作挂在本对象上的
 * pathStack 才放在一起，详见该段落的注释。
 */
import { AppStorageV2 } from '@kit.ArkUI'
import { Logger } from '../utils/Logger'
import { ToastUtil } from '../utils/ToastUtil'

@ObservedV2
export class AppState {

  // 当前底部 Tab 下标。任意页面写入，MainPage 监听并驱动 Tabs 切换
  @Trace mainTabIndex: number = 0

  /**
   * 「我的」页刷新信号：从编辑资料等二级页返回时递增，MeView 监听后强制刷新。
   *
   * 为什么是「计数器」而不是 boolean 开关：布尔值重复设成同一个值，值没变，
   * 观察方收不到通知，第二次触发的同一件事就会失效。改成每次 +1，
   * 值必然变化，重复的同一件事也能触发刷新。
   * 本文件另外两个 Tick（diaryDetailRefreshTick、backPressedTick）同理。
   */
  @Trace meRefreshTick: number = 0

  /**
   * 系统底部手势条高度（vp）。
   *
   * 悬浮胶囊栏的下边距、以及各 Tab 页内容底部的预留空白都要叠加这个值，
   * 否则栏会压住系统手势条。由 EntryAbility 在 loadContent 之前同步写入，
   * 保证页面首帧就能读到；横竖屏切换时再通过 avoidAreaChange 更新，
   * 消费方均为 V2 组件，变化可被观察并触发重排。
   */
  @Trace bottomIndicatorVp: number = 0
  /** 顶部状态栏避让高度（vp），EntryAbility 从窗口避让区读出，AppPageHeader 等头部使用 */
  @Trace topAvoidVp: number = 0

  /**
   * 当前主题 id（对应 THEMES[].id，见 Theme.ets）。
   * 换主题只需改这个字段，brand() 的所有引用处会自动重渲染。
   * 取自 Preferences 的用户选择，默认晨雾蓝。
   */
  @Trace themeId: string = 'misty'

  /**
   * 当前是否深色模式。
   *
   * 中性色靠资源系统自动切深浅，但品牌色是我们自己的常量，
   * 必须在深浅两套色板间手动选一份，所以要单独记这个标记。
   * 由 EntryAbility.onConfigurationUpdate 跟随系统同步。
   */
  @Trace isDark: boolean = false

  /**
   * 日记详情刷新信号。
   *
   * 从编辑页保存后 pop 回详情页时，详情页一直在栈里不会重建，aboutToAppear 不触发；
   * 而 V2 组件不支持 onPageShow。所以改由 NavDestination.onShown 递增这个计数，
   * 页面侧用 @Monitor 监听并重新拉取详情。
   */
  @Trace diaryDetailRefreshTick: number = 0

  /**
   * 返回拦截桥接（上）：当前页面是否有未保存内容。
   *
   * V2 组件不支持 onBackPress，而 NavDestination.onBackPressed 在路由层、
   * 拿不到页面内的表单状态，所以由页面把「是否脏」写到这里，路由层读取后决定放行还是拦截。
   *
   * 与下面的 backPressedTick 是一对信号，合起来完成一次「握手」：
   *   ① 页面写脏(true) → ② 路由层读到脏、拦截返回并把 backPressedTick +1
   *   → ③ 页面收到 +1 弹确认框 → ④ 用户选择后页面清脏(false)、路由层放行。
   * 路由层不直接弹框，是因为确认文案和后续动作只有页面自己知道。
   */
  @Trace hasUnsavedChanges: boolean = false

  /**
   * 返回拦截桥接（下）：路由层拦截到返回手势时递增。
   *
   * 不让路由层直接弹确认框，是因为确认文案和后续动作（保存 / 放弃 / 最小化窗口）
   * 是页面自己的事。页面用 @Monitor 监听这个计数后执行自己的逻辑。
   *
   * 与上面的 hasUnsavedChanges 配对使用，完整握手流程见该字段的注释。
   */
  @Trace backPressedTick: number = 0

  /**
   * Navigation 路由栈：全 App 唯一，由 Index 根容器持有同一实例。
   * 不需要 @Trace —— 我们不观察它本身，只调用它的方法，栈变化由 Navigation 自己感知。
   */
  pathStack: NavPathStack = new NavPathStack()
}

const APP_STATE_KEY: string = 'appState'

/**
 * 获取全局单例 —— 「拿白板」的入口。
 *
 * 首次调用时创建并挂到 AppStorageV2，之后始终复用同一实例。
 * 页面里到处出现的 appState().xxx = yyy，就是「往白板上写一笔」。
 */
export function appState(): AppState {
  const state: AppState | undefined =
    AppStorageV2.connect(AppState, APP_STATE_KEY, () => new AppState())
  // 已传入默认构造器，正常不会返回 undefined；兜底返回新实例避免空指针
  return state as AppState
}

// ===== Navigation 路由助手 =====
//
// 【先理解「页面栈」】App 的页面不是平铺的，是摞起来的（pathStack 就是这一摞）：
// 首页在底、用户看到的永远是栈顶那张、按返回 = 拿走栈顶、露出下面那张。
// 下面这几个函数，就是允许对这摞牌做的全部动作。
//
// 【为什么要包一层】页面不再 import router，统一走这几个函数 —— 目的是「收口」：
// 全 App 只有本文件直接操作 pathStack，后续替换路由实现（或统一加埋点、
// 加统计）只改这一处，不用挨个页面改。
//
// 目标页名必须与 resources/base/profile/route_map.json 中的 name 一致。

const ROUTE_TAG = 'AppState'

/**
 * 入栈跳转 —— 在栈顶放一张新牌。
 *
 * 页面名写错（例如写成 'pages/me/MyRecordsPage' 这种带目录前缀的形式）时，
 * pushPath 既不一定抛错、也不会真正入栈，表现为「按钮点了没反应」且没有任何提示。
 * 这类死按钮排查成本极高，所以这里主动校验栈是否真的增长了（跳之前记一次 size，
 * 跳之后再比一次），失败就报出来 —— 否则用户只会说「点了没反应」，拿不到任何线索。
 */
export function pushRoute(name: string): void {
  const stack: NavPathStack = appState().pathStack
  try {
    const sizeBefore: number = stack.size()
    stack.pushPath({ name: name })
    if (stack.size() === sizeBefore) {
      Logger.error(ROUTE_TAG, `路由跳转失败，页面名未注册: ${name}（须与 route_map.json 的 name 一致）`)
      ToastUtil.show('页面打开失败')
    }
  } catch (error) {
    Logger.error(ROUTE_TAG, `路由跳转异常: ${name}, ${JSON.stringify(error)}`)
    ToastUtil.show('页面打开失败')
  }
}

/** 带参数入栈跳转，取代 router.pushUrl({ url, params })；相当于放新牌时夹一张纸条 */
export function pushRouteWithParam(name: string, param: Object): void {
  appState().pathStack.pushPath({ name: name, param: param })
}

/**
 * 替换栈顶 —— 把栈顶那张牌换成另一张。
 * 典型场景：登录成功后把 LoginPage 换成 MainPage，用户按返回不该再回到登录页。
 *
 * 栈为空时退化成 push —— 401 拦截等场景可能早于 Index 建栈，
 * 此时没有「栈顶」可替换，replacePath 会静默失败（不报错、也没干活），
 * 用户会卡在原地，所以这里兜底。
 */
export function replaceRoute(name: string): void {
  const stack: NavPathStack = appState().pathStack
  if (stack.size() > 0) {
    stack.replacePath({ name: name })
  } else {
    stack.pushPath({ name: name })
  }
}

/**
 * 清空整个栈再跳转：登出、重新登录等需要重置导航历史的场景。
 * 与 replaceRoute 的区别：replace 只换栈顶一张，栈里其余的牌还在；
 * reset 把整摞扔掉，用户无法再通过返回回到登录前的页面。
 */
export function resetRoute(name: string): void {
  const stack: NavPathStack = appState().pathStack
  stack.clear()
  stack.pushPath({ name: name })
}

/** 拿走栈顶那张（返回上一页）。栈内只剩根页面时 pop 是安全的空操作，无需额外判断 */
export function popRoute(): void {
  appState().pathStack.pop()
}
