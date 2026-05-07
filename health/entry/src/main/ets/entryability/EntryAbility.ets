import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { AuthService } from '../core/auth/AppAuthService';
import { router } from '@kit.ArkUI';

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
        
        // 设置窗口系统栏属性
        const systemBarProperties: window.SystemBarProperties = {
          statusBarColor: '#00000000',
          statusBarContentColor: '#000000',
          navigationBarColor: '#00000000',
          navigationBarContentColor: '#000000',
          isStatusBarLightIcon: false,
          isNavigationBarLightIcon: false
        };
        
        mainWindow.setWindowSystemBarProperties(systemBarProperties, (err) => {
          if (err.code) {
            hilog.error(DOMAIN, 'testTag', 'Failed to set the system bar properties. Cause: %{public}s', JSON.stringify(err));
            return;
          }
          hilog.info(DOMAIN, 'testTag', 'Succeeded in setting the system bar properties.');
        });
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

      // 检查登录状态,决定加载哪个页面
      const isLoggedIn = authService.isLoggedIn();
      const startPage = isLoggedIn ? 'pages/home/HomePageNew' : 'pages/auth/LoginPage';

      hilog.info(DOMAIN, 'testTag', `Loading page: ${startPage}`);

      windowStage.loadContent(startPage, (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          // 加载失败时,尝试加载登录页
          windowStage.loadContent('pages/auth/LoginPage', (err2) => {
            if (err2.code) {
              hilog.error(DOMAIN, 'testTag', 'Failed to load LoginPage. Cause: %{public}s', JSON.stringify(err2));
            }
          });
          return;
        }
        hilog.info(DOMAIN, 'testTag', `Succeeded in loading ${startPage}.`);
      });
    } catch (error) {
      hilog.error(DOMAIN, 'testTag', `Init failed: ${error}`);
      // 出错时直接加载登录页
      windowStage.loadContent('pages/auth/LoginPage', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load LoginPage. Cause: %{public}s', JSON.stringify(err));
        }
      });
    }
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