import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want, wantConstant } from '@kit.AbilityKit';
import { Logger } from '../common/utils/Logger'
import { display, window } from '@kit.ArkUI';
import { AuthService } from '../core/auth/AppAuthService';
import { ApiService } from '../core/api/ApiService';
import { ScaleRepository } from '../core/repository/ScaleRepository';
import { SnapshotRepository } from '../core/repository/SnapshotRepository';
import { appState, resetRoute } from '../common/state/AppState';
import { AppSettings } from '../common/utils/AppSettings';
import { ApiConfig, setApiBaseUrl } from '../common/constants/apiConfig';
import { cardTargetToTab, CONTINUE_KEY, ContinueState, isStateRestoreLaunch, packContinueState, unpackContinueState } from '../common/utils/ContinueState';

const TAG = 'EntryAbility';

/**
 * 窗口避让区返回的是 px，而 Theme 里的常量和所有样式统一用 vp，这里做换算。
 */
class EntryAvoidArea {
  static toVp(px: number): number {
    try {
      const density: number = display.getDefaultDisplaySync().densityPixels;
      return density > 0 ? px / density : 0;
    } catch (error) {
      return 0;
    }
  }
}

export default class EntryAbility extends UIAbility {
  /**
   * 源端搬过来的接续状态，先暂存在这里。
   *
   * 【为什么不直接在 onCreate 里写 appState()】
   * onCreate 早于 UI 建立，而主题还要等 initAndLoadPage 从本机 Preferences 读回来
   * （异步，见 143 行附近）。若在 onCreate 就落值，会被那次读取覆盖掉。
   * 所以这里只「解包暂存」，真正落值放到「读回本机偏好之后」，避开这个竞态。
   */
  private pendingContinue: ContinueState | null = null

  /**
   * loadContent 幂等保护。
   * 正常启动走 onWindowStageCreate、接续启动走 onWindowStageRestore，两者理论上互斥；
   * 但兜底起见：万一两个都走到，loadContent 也绝不能执行两次。
   */
  private pageLoaded: boolean = false

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      Logger.error(TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }

    // 接续 / 故障恢复（冷启动）：只解包暂存，落值在 initAndLoadPage 里做
    if (isStateRestoreLaunch(launchParam)) {
      this.pendingContinue = unpackContinueState(want)
      Logger.warn(TAG, `onCreate: 恢复启动（接续/故障恢复），已解析=${this.pendingContinue !== null}`);
    } else {
      // 服务卡片快捷入口（冷启动）：与接续共用同一条「落到指定 Tab」的通道
      this.pendingContinue = this.readCardTarget(want)
      if (this.pendingContinue !== null) {
        Logger.warn(TAG, `onCreate: 卡片快捷入口 → tab=${this.pendingContinue.mainTabIndex}`);
      }
    }

    Logger.info(TAG, '%{public}s', 'Ability onCreate');
  }

  /**
   * 单实例热启动：对端本来就开着这个 App 时接续过来走这里（launchType=singleton）。
   * 此时 UI 已就绪，可以直接落值。
   */
  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    // 两个来源共用一条落地通道：接续/故障恢复走 wantParam，卡片走 cardTarget
    let state: ContinueState | null = null
    if (isStateRestoreLaunch(launchParams)) {
      state = unpackContinueState(want)
      if (state === null) {
        Logger.warn(TAG, 'onNewWant: 恢复启动但数据不可用，按普通启动处理');
        return;
      }
    } else {
      state = this.readCardTarget(want)
    }

    if (state === null) {
      return;
    }

    appState().mainTabIndex = state.mainTabIndex;
    appState().themeId = state.themeId;
    // 主题同时写回本机偏好，否则用户下次冷启动又变回本机旧主题
    AppSettings.setString(this.context, 'themeId', state.themeId);

    // 未登录时不能把 MainPage 压到登录页上面 —— 那会让人不登录就看到主界面
    if (AuthService.getInstance().isLoggedIn()) {
      // 本方案只接力到「主 Tab」：把可能残留的二级页面清掉，
      // 否则对端可能停在上次没退出的详情/编辑页，接续过去看到的是个中间态。
      resetRoute('MainPage');
    }

    Logger.warn(TAG, `onNewWant: 恢复/卡片跳转 tab=${state.mainTabIndex}, theme=${state.themeId}`);
  }

  /**
   * 服务卡片快捷入口：读 want 里的 cardTarget，转成「落哪个 Tab」。
   * 返回 null 表示这次启动不是卡片点击（调用方继续走别的分支）。
   * 与接续/故障恢复共用 pendingContinue 通道 —— 落地逻辑（设 mainTabIndex）完全一样。
   */
  private readCardTarget(want: Want): ContinueState | null {
    const raw: Object | undefined = want.parameters ? want.parameters['cardTarget'] : undefined;
    if (raw === undefined || raw === null) {
      return null;
    }
    const tab: number = cardTargetToTab(raw as string);
    if (tab < 0) {
      return null;
    }
    // 主题保持本机当前值不变 —— 卡片只是「去某个 Tab」，不携带主题
    return { mainTabIndex: tab, themeId: appState().themeId };
  }

  /**
   * 源端：系统发起接续时回调。在这里打包要搬走的数据，并决定同不同意迁移。
   * 返回值：AGREE 同意 / REJECT 拒绝 / MISMATCH 版本不匹配。
   */
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    const logged: boolean = AuthService.getInstance().isLoggedIn();
    Logger.warn(TAG, `onContinue: isLoggedIn=${logged}`);

    if (!logged) {
      // 源端自己都没登录，没有「当前位置」值得接力 —— 直接拒绝，
      // 免得把用户送到对端一个必须先登录的空壳里。
      return AbilityConstant.OnContinueResult.REJECT;
    }

    // ⭐ 关掉系统默认的「页面栈迁移」（默认 true = 自动把源端页面栈迁到对端）。
    //   ① 语义上就不该迁 —— 本方案只接力到主 Tab，二级页（编辑/新建）过去是空白中间态；
    //   ② 实测默认的页面栈恢复会让**对端卡死在启动窗口**：
    //      对端 onCreate 之后 onWindowStageCreate 不会被调用 → loadContent 不执行 →
    //      系统报 SetUIContent timeout → WINDOW_FROZEN_DETECTION（双真机复现）。
    //   关掉后对端走普通冷启动：Index 自己建栈 push MainPage，再按接续来的 tabIndex 切 Tab。
    wantParam[wantConstant.Params.SUPPORT_CONTINUE_PAGE_STACK_KEY] = false;

    wantParam[CONTINUE_KEY] = packContinueState();
    return AbilityConstant.OnContinueResult.AGREE;
  }

  /**
   * 故障恢复：进程被 JS 异常 / 冻结 / 崩溃杀死前，系统先调这里让应用保存现场；
   * 重启后的 onCreate 会以 launchReason = APP_RECOVERY 把这份数据带回来。
   * 与接续共用同一套打包逻辑和同一个 key —— 恢复代码完全复用，不另写一套。
   */
  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult {
    Logger.warn(TAG, `onSaveState: reason=${reason}`);
    if (reason === AbilityConstant.StateType.APP_RECOVERY && AuthService.getInstance().isLoggedIn()) {
      wantParam[CONTINUE_KEY] = packContinueState();
    }
    return AbilityConstant.OnSaveResult.ALL_AGREE;
  }

  onDestroy(): void {
    Logger.info(TAG, '%{public}s', 'Ability onDestroy');
  }

  /**
   * 窗口阶段初始化 —— onWindowStageCreate 与 onWindowStageRestore **共用**的收口。
   *
   * ⭐⭐ 这是接续卡启动页的**真正根因**：
   * SDK 注释原文（UIAbility.d.ts:415）——应用因迁移（接续）启动时，系统触发的是
   * **onWindowStageRestore() 而不是 onWindowStageCreate()**。
   * 如果只在 Create 里 loadContent，接续到另一台设备时对端永远不会执行 loadContent
   * → 界面卡死在启动窗口（系统报 SetUIContent timeout + WINDOW_FROZEN_DETECTION）。
   * 所以两个回调必须走同一套初始化，这里就是那个收口。
   */
  private setupWindowStage(windowStage: window.WindowStage): void {
    Logger.warn(TAG, 'setupWindowStage: start');

    // ⚠️ getMainWindowSync() 在窗口尚未就绪时会抛异常（编译器提示 "may throw"）。
    //    接续启动的窗口时序与正常启动不同，这里不能让异常中断后续 loadContent。
    //    拿不到就跳过这次预同步，下面异步 getMainWindow 回调里会再做完整同步。
    try {
      this.syncAvoidAreas(windowStage.getMainWindowSync());
    } catch (err) {
      Logger.error(TAG, 'getMainWindowSync failed, skip pre-sync (async will sync): %{public}s', JSON.stringify(err));
    }

    // 首帧就得知道深色模式，否则品牌色会取错那一套色板
    this.syncColorMode();

    // 设置全屏模式
    windowStage.getMainWindow((err, mainWindow) => {
      if (err.code) {
        Logger.error(TAG, 'Failed to obtain the main window. Cause: %{public}s', JSON.stringify(err));
        return;
      }

      try {
        // 设置全屏模式 - 隐藏状态栏和导航栏
        mainWindow.setWindowLayoutFullScreen(true);

        // 全屏生效后避让区才是真实值（顶部状态栏/底部手势条），再同步一次
        this.syncAvoidAreas(mainWindow);

        // 系统栏内容颜色跟随当前配色模式（浅色黑字/深色白字）
        this.updateSystemBar(appState().isDark);

        // 横竖屏切换、手势条显隐变化时重新同步；V2 组件（MainPage/MePage）会跟随重排
        mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
          if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            appState().bottomIndicatorVp = EntryAvoidArea.toVp(data.area.bottomRect.height);
          }
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            appState().topAvoidVp = EntryAvoidArea.toVp(data.area.topRect.height);
          }
        });
      } catch (error) {
        Logger.error(TAG, 'Failed to set full screen mode. Cause: %{public}s', JSON.stringify(error));
      }
    });

    // 幂等保护：loadContent 只允许执行一次（见 pageLoaded 注释）
    if (this.pageLoaded) {
      Logger.warn(TAG, 'setupWindowStage: 页面已加载，跳过重复 loadContent');
      return;
    }
    this.pageLoaded = true;

    // 哨兵：这行出现 = loadContent 一定会被调用
    Logger.warn(TAG, 'setupWindowStage: about to initAndLoadPage');
    this.initAndLoadPage(windowStage);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability（正常启动走这里）
    Logger.info(TAG, '%{public}s', 'Ability onWindowStageCreate');
    // 接续调试期临时用 warn（info 在 release 构建里被 Logger 的 debug 开关吞掉，hilog 里看不到）
    Logger.warn(TAG, 'onWindowStageCreate: start');
    this.setupWindowStage(windowStage);
  }

  /**
   * ⭐ 应用接续（迁移）启动时，系统走这里而**不是** onWindowStageCreate —— 见 setupWindowStage 注释。
   */
  onWindowStageRestore(windowStage: window.WindowStage): void {
    Logger.info(TAG, '%{public}s', 'Ability onWindowStageRestore');
    Logger.warn(TAG, 'onWindowStageRestore: start');
    this.setupWindowStage(windowStage);
  }

  /**
   * 同步顶部状态栏 / 底部手势条避让高度，写入全局状态供头部与浮动栏避让。
   *
   * 注意时机：全屏生效「前」读到的是普通布局的值（偏小），「后」才是真实值；
   * 因此启动时会调用两次（前 + setWindowLayoutFullScreen 回调里一次），
   * 横竖屏 / 手势条变化由 avoidAreaChange 监听兜底。
   */
  private syncAvoidAreas(mainWindow: window.Window): void {
    try {
      const bottomArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      appState().bottomIndicatorVp = EntryAvoidArea.toVp(bottomArea.bottomRect.height);

      const topArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      appState().topAvoidVp = EntryAvoidArea.toVp(topArea.topRect.height);
      Logger.info(TAG, `Avoid areas: top=${appState().topAvoidVp}vp bottom=${appState().bottomIndicatorVp}vp`);
    } catch (error) {
      Logger.error(TAG, `Failed to read avoid area. Cause: %{public}s`, JSON.stringify(error));
    }
  }

  /**
   * 启动时同步一次系统配色模式。
   *
   * onConfigurationUpdate 只在「变化」时触发，首次启动不会调，
   * 所以这里主动读一次，保证首帧的品牌色就取对浅/深那一套。
   */
  private syncColorMode(): void {
    try {
      appState().isDark =
        this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      Logger.info(TAG, `Initial color mode, isDark=${appState().isDark}`);
    } catch (error) {
      Logger.error(TAG, `Failed to read color mode. Cause: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 初始化服务并加载页面
   */
  private async initAndLoadPage(windowStage: window.WindowStage): Promise<void> {
    try {
      // 后端地址允许现场临时覆盖（演示时换网络不必重新打包）：
      // 读 Preferences 的 api_base_url，读不到就回退 apiConfig 里的默认值。
      // 必须放在最前面 —— ApiService 每次发请求时才现读 ApiConfig.API_BASE_URL
      // （ApiService 有意不把地址缓存到字段，见 ApiService.ets 顶部注释），
      // 所以要保证「第一个请求发出之前」地址已经就位，否则请求会打到默认/错误地址。
      setApiBaseUrl(await AppSettings.getString(this.context, 'api_base_url', ''));
      Logger.info(TAG, `后端地址: ${ApiConfig.API_BASE_URL}`);

      const authService = AuthService.getInstance();
      await authService.init(this.context);

      // 恢复用户选择的主题。必须在 loadContent 之前：晚于首帧再改会让页面
      // 先用默认色渲染、再跳成用户主题，肉眼可见地闪一下。
      appState().themeId = await AppSettings.getString(this.context, 'themeId', 'misty');

      // 接续（冷启动）：把源端搬过来的状态「盖」在本机偏好之上。
      // 位置很关键 —— 必须在上一步「读回本机主题」之后，反了会被本机旧值覆盖。
      if (this.pendingContinue !== null) {
        const cont: ContinueState = this.pendingContinue as ContinueState;
        this.pendingContinue = null;
        appState().mainTabIndex = cont.mainTabIndex;
        appState().themeId = cont.themeId;
        // 同时写回本机偏好，否则用户下次冷启动又变回本机旧主题
        await AppSettings.setString(this.context, 'themeId', cont.themeId);
        Logger.warn(TAG, `接续恢复(冷启动): tab=${cont.mainTabIndex}, theme=${cont.themeId}`);
      }

      // 量表题库：注入 Context，保证断网时能读本地缓存 / rawfile 内置题库
      const scaleRepo = ScaleRepository.getInstance();
      await scaleRepo.init(this.context);

      // 动态数据（日记/测评记录/用户资料）快照：断网时用于降级展示
      const snapshotRepo = SnapshotRepository.getInstance();
      await snapshotRepo.init(this.context);
      // 后台静默刷新题库，内部已兜底，失败不影响启动
      scaleRepo.refreshFromNetwork();

      // 注入 401 统一处理：token 过期时清登录态并回登录页
      const apiService = ApiService.getInstance();
      let redirecting = false;
      apiService.setAuthExpiredHandler(() => {
        if (redirecting) {
          return;
        }
        redirecting = true;
        authService.logout().then(() => {
          // 401：清空导航栈重回登录页，避免栈里残留已登出账号的页面
          resetRoute('LoginPage');
        }).catch((err: Object) => {
          Logger.error(TAG, '401 logout failed: %{public}s', JSON.stringify(err));
        }).finally(() => {
          redirecting = false;
        });
      });

      // 登录分流已移到 pages/Index：Navigation 模式下 @Entry 只剩 Index 一个，
      // 由它按登录状态 push MainPage / LoginPage
      Logger.info(TAG, 'Loading page: pages/Index');

      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          Logger.error(TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          // 加载失败时,重试加载唯一入口
          windowStage.loadContent('pages/Index', (err2) => {
            if (err2.code) {
              Logger.error(TAG, 'Failed to load Index. Cause: %{public}s', JSON.stringify(err2));
            }
          });
          return;
        }
        Logger.info(TAG, 'Succeeded in loading pages/Index.');
      });
    } catch (error) {
      Logger.error(TAG, `Init failed: ${error}`);
      // 出错时直接加载唯一入口
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          Logger.error(TAG, 'Failed to load Index. Cause: %{public}s', JSON.stringify(err));
        }
      });
    }
  }

  /**
   * 系统配色变化（跟随系统深色模式开关）时，同步刷新系统栏内容颜色
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    Logger.info(TAG, 'colorMode changed, isDark=%{public}s', String(isDark));
    // 中性色靠资源系统自动切，但品牌色（brand() 的色板）是我们自己的常量，
    // 必须手动在浅/深两套之间切，否则深色下按钮与标签仍是浅色版主色，压在深底上会发灰
    appState().isDark = isDark;
    this.updateSystemBar(isDark);
  }

  private updateSystemBar(isDark: boolean): void {
    window.getLastWindow(this.context).then((win) => {
      const systemBarProperties: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
        navigationBarColor: '#00000000',
        navigationBarContentColor: isDark ? '#FFFFFF' : '#000000',
        isStatusBarLightIcon: isDark,
        isNavigationBarLightIcon: isDark
      };
      win.setWindowSystemBarProperties(systemBarProperties).then(() => {
        Logger.info(TAG, 'System bar updated, isDark=%{public}s', String(isDark));
      });
    }).catch((err: Object) => {
      // 冷启动时窗口可能尚未就绪（1300002 window state abnormal），延迟重试一次
      Logger.warn(TAG, 'System bar not ready, retry once: %{public}s', JSON.stringify(err));
      setTimeout(() => {
        window.getLastWindow(this.context).then((win) => {
          win.setWindowSystemBarProperties({
            statusBarColor: '#00000000',
            statusBarContentColor: isDark ? '#FFFFFF' : '#000000',
            navigationBarColor: '#00000000',
            navigationBarContentColor: isDark ? '#FFFFFF' : '#000000',
            isStatusBarLightIcon: isDark,
            isNavigationBarLightIcon: isDark
          });
        }).catch((retryErr: Object) => {
          Logger.error(TAG, 'Failed to update system bar: %{public}s', JSON.stringify(retryErr));
        });
      }, 600);
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    Logger.info(TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    Logger.info(TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    Logger.info(TAG, '%{public}s', 'Ability onBackground');
  }
}