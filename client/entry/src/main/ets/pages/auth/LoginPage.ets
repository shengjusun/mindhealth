import { appState, AppState, pushRoute } from '../../common/state/AppState'
import { AuthService } from '../../core/auth/AppAuthService'
import { replaceRoute } from '../../common/state/AppState'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension, ShadowStyle } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { window } from '@kit.ArkUI'
import { HuaweiIdService } from '../../core/auth/HuaweiIdService'
import { loginComponentManager, LoginWithHuaweiIDButton } from '@kit.AccountKit'
import { BusinessError } from '@kit.BasicServicesKit'

const TAG = 'LoginPage'

@ComponentV2
export struct LoginPage {
  @Local phone: string = ''
  @Local password: string = ''
  @Local isLoading: boolean = false
  @Local isHuaweiLoading: boolean = false

  // 用于 @Monitor 监听路由层转发过来的返回手势
  @Local state: AppState = appState()
  private authService: AuthService = AuthService.getInstance()
  // 华为官方登录按钮控制器：按钮被点击时通过它回调授权凭证
  private huaweiIdButtonController: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController()
  // 官方按钮参数：华为品牌圆形图标样式，跟随系统深浅色
  private huaweiButtonParams: loginComponentManager.LoginWithHuaweiIDButtonParams = {
    style: loginComponentManager.Style.ICON_RED,
    supportDarkMode: true
  }

  aboutToAppear(): void {
    // 系统栏颜色由 EntryAbility 统一按深浅色模式管理，页面不再各自覆盖
    if (this.authService.isLoggedIn()) {
      try {
        replaceRoute('MainPage')
      } catch (error) {
        Logger.error(TAG, `已登录跳转首页失败: ${JSON.stringify(error)}`)
      }
    }

    // 注册官方按钮点击回调：组件内部完成华为授权后直接返回凭证
    this.huaweiIdButtonController.onClickLoginWithHuaweiIDButton(
      (error: BusinessError, data: loginComponentManager.HuaweiIDCredential) => {
        if (error) {
          this.isHuaweiLoading = false
          const message: string = HuaweiIdService.mapErrorCode(error.code)
          if (message === '已取消华为账号登录') {
            return
          }
          Logger.error(TAG, `华为授权失败: code=${error.code}`)
          ToastUtil.show(message)
          return
        }

        const authorizationCode: string = data?.authorizationCode ?? ''
        if (authorizationCode.length === 0) {
          this.isHuaweiLoading = false
          ToastUtil.show('未获取到华为登录凭证')
          return
        }

        this.isHuaweiLoading = true
        this.authService.loginWithHuaweiCode(authorizationCode,
          (success: boolean, userInfo?: Object, error?: string) => {
            this.isHuaweiLoading = false
            if (success) {
              Logger.info(TAG, '华为账号登录成功')
              this.afterLoginSuccess()
            } else {
              Logger.error(TAG, `华为登录失败: ${error}`)
              if (error && error.indexOf('已取消') >= 0) {
                return
              }
              ToastUtil.show(error ? error : '华为登录失败')
            }
          })
      })
  }

  /**
   * 登录成功统一出口：两条登录路径共用
   */
  private afterLoginSuccess(): void {
    try {
      replaceRoute('MainPage')
    } catch (error) {
      Logger.error(TAG, `登录成功后跳转失败: ${JSON.stringify(error)}`)
      ToastUtil.show('跳转首页失败')
    }
  }

  /**
   * V2 组件不支持 onBackPress —— 编译器不报错，但运行时不会触发，属于静默失效。
   * 改由 NavDestination.onBackPressed 递增 AppState.backPressedTick，这里监听后最小化窗口。
   * 登录页是栈底页面，返回应当最小化而不是退出 App。
   */
  @Monitor('state.backPressedTick')
  onBackPressed(): void {
    try {
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        win.minimize()
      })
    } catch (error) {
      Logger.error(TAG, `最小化窗口失败: ${JSON.stringify(error)}`)
    }
  }

  build() {
    Column() {
      AppPageHeader({
        title: '登录',
        subtitle: '欢迎回到轻心',
        showBack: false
      })

      Scroll() {
        Column() {
          this.buildWelcomeCard()
          this.buildLoginForm()
          this.buildActionArea()
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 6,
          bottom: Dimension.SpaceXL
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildWelcomeCard() {
    Column() {
      Row() {
        Text('欢迎回来')
          .fontSize(12)
          .fontColor($r('app.color.theme_primary'))
          .padding({
            left: 10,
            right: 10,
            top: 5,
            bottom: 5
          })
          .backgroundColor($r('app.color.tag_blue'))
          .borderRadius(12)
      }
      .margin({ bottom: 16 })

      Text('欢迎来到轻心')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('记录情绪、温柔陪伴、慢慢变好')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  @Builder
  buildLoginForm() {
    Column() {
      Text('手机号')
        .fontSize(Dimension.FontM)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      TextInput({ placeholder: '请输入手机号', text: this.phone })
        .width('100%')
        .height(Dimension.InputHeight)
        .type(InputType.PhoneNumber)
        .fontSize(Dimension.FontL)
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.phone = value
        })
        .margin({ bottom: 16 })

      Text('密码')
        .fontSize(Dimension.FontM)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      TextInput({ placeholder: '请输入密码', text: this.password })
        .width('100%')
        .height(Dimension.InputHeight)
        .type(InputType.Password)
        .fontSize(Dimension.FontL)
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.password = value
        })
        .margin({ bottom: 4 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
  }

  @Builder
  buildActionArea() {
    Column() {
      Button(this.isLoading ? '登录中...' : '立即登录')
        .width('100%')
        .height(Dimension.ButtonHeight)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor(this.isLoading ? $r('app.color.text_tertiary') : $r('app.color.theme_primary'))
        .borderRadius(24)
        .enabled(!this.isLoading && !this.isHuaweiLoading)
        .onClick(() => {
          if (!this.isLoading) {
            this.handleLogin()
          }
        })
        .margin({ top: 20, bottom: 16 })

      Row() {
        Text('还没有账号？')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Row() {
          Text('去注册')
            .fontSize(14)
            .fontColor($r('app.color.theme_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .padding({
          left: 12,
          right: 12,
          top: 8,
          bottom: 8
        })
        .backgroundColor($r('app.color.tag_blue'))
        .borderRadius(16)
        .margin({ left: 8 })
        .onClick(() => {
          this.goToRegister()
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // 分隔线 + 第三方登录入口
      Row() {
        Divider()
          .color($r('app.color.app_divider'))
          .strokeWidth(1)
          .layoutWeight(1)

        Text('其他登录方式')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ left: 12, right: 12 })

        Divider()
          .color($r('app.color.app_divider'))
          .strokeWidth(1)
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 28, bottom: 20 })

      // 第三方登录：华为官方品牌图标按钮
      Column() {
        LoginWithHuaweiIDButton({
          params: this.huaweiButtonParams,
          controller: this.huaweiIdButtonController
        })
          .enabled(!this.isLoading && !this.isHuaweiLoading)
          .opacity(this.isLoading ? 0.5 : 1)

        Text('华为账号登录')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
  }

  private goToRegister(): void {
    try {
      pushRoute('RegisterPage')
    } catch (error) {
      Logger.error(TAG, `跳转注册页失败: ${JSON.stringify(error)}`)
      this.showToast('打开注册页失败')
    }
  }

  /**
   * 登录按钮点击后的处理逻辑
   * 页面只负责校验输入和调用 AuthService
   * 真正请求后端在 AuthService.requestLogin 里完成
   */
  private async handleLogin(): Promise<void> {
    // 去掉手机号和密码前后的空格
    const phoneValue: string = this.phone.trim()
    const passwordValue: string = this.password.trim()

    // 手机号不能为空
    if (phoneValue.length === 0) {
      this.showToast('请输入手机号')
      return
    }

    // 校验手机号格式，避免明显错误的请求发到后端
    if (!/^1[3-9]\d{9}$/.test(phoneValue)) {
      this.showToast('手机号格式不正确')
      return
    }

    // 密码不能为空
    if (passwordValue.length === 0) {
      this.showToast('请输入密码')
      return
    }

    // 进入登录中状态，按钮会禁用，防止重复点击
    this.isLoading = true

    try {
      await this.authService.loginWithCredentials(
        phoneValue,
        passwordValue,
        (success: boolean, userInfo?: Object, error?: string) => {
          // 无论成功失败，请求结束后都恢复按钮状态
          this.isLoading = false

          if (success) {
            Logger.info(TAG, '登录成功')
            this.afterLoginSuccess()
          } else {
            // AuthService 会把失败原因通过 callback 传回来
            Logger.error(TAG, `登录失败: ${error}`)
            this.showToast(error ? error : '登录失败')
          }
        }
      )
    } catch (error) {
      // 兜底异常处理，避免按钮一直处于 loading 状态
      this.isLoading = false
      Logger.error(TAG, `登录异常: ${JSON.stringify(error)}`)
      this.showToast('网络异常，请稍后重试')
    }
  }

  private showToast(message: string): void {
    ToastUtil.show(message)
  }
}

