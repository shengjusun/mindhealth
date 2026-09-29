import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { Logger } from '../common/utils/Logger'
import { display, window } from '@kit.ArkUI';
import { AuthService } from '../core/auth/AppAuthService';
import { ApiService } from '../core/api/ApiService';
import { ScaleRepository } from '../core/repository/ScaleRepository';
import { SnapshotRepository } from '../core/repository/SnapshotRepository';
import { appState, resetRoute } from '../common/state/AppState';
import { AppSettings } from '../common/utils/AppSettings';
import { ApiConfig, setApiBaseUrl } from '../common/constants/apiConfig';

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
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      Logger.error(TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    Logger.info(TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    Logger.info(TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    Logger.info(TAG, '%{public}s', 'Ability onWindowStageCreate');

    // 必须在 loadContent 之前同步完成：HomeView 等仍是 V1 组件，观察不到 @Trace 变化，
    // 只有首帧 build 时读到的值才有效，晚于页面渲染再写入对它们不生效
    // （此时全屏尚未生效，值可能偏小——全屏回调里会再同步一次真实值）
    this.syncAvoidAreas(windowStage.getMainWindowSync());
    // 同理：首帧就得知道深色模式，否则品牌色会取错那一套色板
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

    this.initAndLoadPage(windowStage);
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
      // 必须放在最前面 —— ApiService 是单例，一旦被 getInstance() 创建就会按当时的地址发请求。
      setApiBaseUrl(await AppSettings.getString(this.context, 'api_base_url', ''));
      Logger.info(TAG, `后端地址: ${ApiConfig.API_BASE_URL}`);

      const authService = AuthService.getInstance();
      await authService.init(this.context);

      // 恢复用户选择的主题。必须在 loadContent 之前：晚于首帧再改会让页面
      // 先用默认色渲染、再跳成用户主题，肉眼可见地闪一下。
      appState().themeId = await AppSettings.getString(this.context, 'themeId', 'misty');

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