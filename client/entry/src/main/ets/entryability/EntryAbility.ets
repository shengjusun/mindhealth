import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';
import { AuthService } from '../core/auth/AppAuthService';
import { ApiService } from '../core/api/ApiService';
import { ScaleRepository } from '../core/repository/ScaleRepository';
import { SnapshotRepository } from '../core/repository/SnapshotRepository';
import { appState, resetRoute } from '../common/state/AppState';

const DOMAIN = 0x0000;

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
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 必须在 loadContent 之前同步完成：HomeView 等仍是 V1 组件，观察不到 @Trace 变化，
    // 只有首帧 build 时读到的值才有效，晚于页面渲染再写入对它们不生效
    this.syncBottomIndicator(windowStage);

    // 设置全屏模式
    windowStage.getMainWindow((err, mainWindow) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to obtain the main window. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      
      try {
        // 设置全屏模式 - 隐藏状态栏和导航栏
        mainWindow.setWindowLayoutFullScreen(true);

        // 系统栏内容颜色跟随当前配色模式（浅色黑字/深色白字）
        this.updateSystemBar(false);

        // 横竖屏切换、手势条显隐变化时重新同步；V2 组件（MainPage/MePage）会跟随重排
        mainWindow.on('avoidAreaChange', (data: window.AvoidAreaOptions) => {
          if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            appState().bottomIndicatorVp = EntryAvoidArea.toVp(data.area.bottomRect.height);
          }
        });
      } catch (error) {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full screen mode. Cause: %{public}s', JSON.stringify(error));
      }
    });

    this.initAndLoadPage(windowStage);
  }

  /**
   * 读取系统底部手势条高度，写入全局状态供悬浮胶囊栏避让。
   *
   * 悬浮栏用固定 96vp 时，在手势条较高或较低的机型上会分别偏小/偏大；
   * 这里拿到真实避让区高度，让栏和内容预留都跟着设备走。
   */
  private syncBottomIndicator(windowStage: window.WindowStage): void {
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      const avoidArea: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      appState().bottomIndicatorVp = EntryAvoidArea.toVp(avoidArea.bottomRect.height);
      hilog.info(DOMAIN, 'testTag', `Bottom indicator height: ${appState().bottomIndicatorVp}vp`);
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', `Failed to read avoid area. Cause: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 初始化服务并加载页面
   */
  private async initAndLoadPage(windowStage: window.WindowStage): Promise<void> {
    try {
      const authService = AuthService.getInstance();
      await authService.init(this.context);

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
          hilog.error(DOMAIN, 'testTag', '401 logout failed: %{public}s', JSON.stringify(err));
        }).finally(() => {
          redirecting = false;
        });
      });

      // 登录分流已移到 pages/Index：Navigation 模式下 @Entry 只剩 Index 一个，
      // 由它按登录状态 push MainPage / LoginPage
      hilog.info(DOMAIN, 'testTag', 'Loading page: pages/Index');

      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          // 加载失败时,重试加载唯一入口
          windowStage.loadContent('pages/Index', (err2) => {
            if (err2.code) {
              hilog.error(DOMAIN, 'testTag', 'Failed to load Index. Cause: %{public}s', JSON.stringify(err2));
            }
          });
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading pages/Index.');
      });
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', `Init failed: ${error}`);
      // 出错时直接加载唯一入口
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load Index. Cause: %{public}s', JSON.stringify(err));
        }
      });
    }
  }

  /**
   * 系统配色变化（跟随系统深色模式开关）时，同步刷新系统栏内容颜色
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    const isDark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    hilog.info(DOMAIN, 'testTag', 'colorMode changed, isDark=%{public}s', String(isDark));
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
        hilog.info(DOMAIN, 'testTag', 'System bar updated, isDark=%{public}s', String(isDark));
      });
    }).catch((err: Object) => {
      hilog.error(DOMAIN, 'testTag', 'Failed to update system bar: %{public}s', JSON.stringify(err));
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}