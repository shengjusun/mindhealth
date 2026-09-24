import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AuthService } from '../core/auth/AppAuthService';
import { ApiService } from '../core/api/ApiService';
import { ScaleRepository } from '../core/repository/ScaleRepository';
import { SnapshotRepository } from '../core/repository/SnapshotRepository';
import { resetRoute } from '../common/state/AppState';

const DOMAIN = 0x0000;

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
      } catch (error) {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full screen mode. Cause: %{public}s', JSON.stringify(error));
      }
    });

    this.initAndLoadPage(windowStage);
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