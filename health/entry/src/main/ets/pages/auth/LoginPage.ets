import router from '@ohos.router'
import { AuthService } from '../../core/auth/AppAuthService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { window } from '@kit.ArkUI'

const TAG = 'LoginPage'

@Entry
@Component
struct LoginPage {
  @State phone: string = ''
  @State password: string = ''
  @State isLoading: boolean = false
  private authService: AuthService = AuthService.getInstance()

  aboutToAppear(): void {
    window.getLastWindow(getContext(this), (err, win) => {
      if (err || !win) {
        Logger.error(TAG, `设置系统栏失败: ${JSON.stringify(err)}`)
        return
      }

      win.setWindowSystemBarProperties({
        statusBarContentColor: '#EAF3F8',
        navigationBarContentColor: '#EAF3F8'
      })
    })

    if (this.authService.isLoggedIn()) {
      try {
        router.replaceUrl({ url: 'pages/home/HomePageNew' })
      } catch (error) {
        Logger.error(TAG, `已登录跳转首页失败: ${JSON.stringify(error)}`)
      }
    }
  }

  onBackPress(): boolean {
    try {
      window.getLastWindow(getContext(this)).then((win) => {
        win.minimize()
      })
    } catch (error) {
      Logger.error(TAG, `最小化窗口失败: ${JSON.stringify(error)}`)
    }
    return true
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
    .backgroundColor(LightTheme.Background)
  }

  @Builder
  buildWelcomeCard() {
    Column() {
      Row() {
        Text('欢迎回来')
          .fontSize(12)
          .fontColor(LightTheme.Primary)
          .padding({
            left: 10,
            right: 10,
            top: 5,
            bottom: 5
          })
          .backgroundColor(LightTheme.TagBlue)
          .borderRadius(12)
      }
      .margin({ bottom: 16 })

      Text('欢迎来到轻心')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')

      Text('记录情绪、温柔陪伴、慢慢变好')
        .fontSize(14)
        .fontColor(LightTheme.TextSecondary)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(LightTheme.Card)
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  @Builder
  buildLoginForm() {
    Column() {
      Text('手机号')
        .fontSize(Dimension.FontM)
        .fontColor(LightTheme.TextSecondary)
        .width('100%')
        .margin({ bottom: 8 })

      TextInput({ placeholder: '请输入手机号', text: this.phone })
        .width('100%')
        .height(Dimension.InputHeight)
        .type(InputType.PhoneNumber)
        .fontSize(Dimension.FontL)
        .backgroundColor(LightTheme.SurfaceSoft)
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.phone = value
        })
        .margin({ bottom: 16 })

      Text('密码')
        .fontSize(Dimension.FontM)
        .fontColor(LightTheme.TextSecondary)
        .width('100%')
        .margin({ bottom: 8 })

      TextInput({ placeholder: '请输入密码', text: this.password })
        .width('100%')
        .height(Dimension.InputHeight)
        .type(InputType.Password)
        .fontSize(Dimension.FontL)
        .backgroundColor(LightTheme.SurfaceSoft)
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.password = value
        })
        .margin({ bottom: 4 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(LightTheme.Card)
    .borderRadius(20)
  }

  @Builder
  buildActionArea() {
    Column() {
      Button(this.isLoading ? '登录中...' : '立即登录')
        .width('100%')
        .height(Dimension.ButtonHeight)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(LightTheme.TextWhite)
        .backgroundColor(this.isLoading ? LightTheme.TextTertiary : LightTheme.Primary)
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => {
          if (!this.isLoading) {
            this.handleLogin()
          }
        })
        .margin({ top: 20, bottom: 16 })

      Row() {
        Text('还没有账号？')
          .fontSize(14)
          .fontColor(LightTheme.TextSecondary)

        Row() {
          Text('去注册')
            .fontSize(14)
            .fontColor(LightTheme.Primary)
            .fontWeight(FontWeight.Medium)
        }
        .padding({
          left: 12,
          right: 12,
          top: 8,
          bottom: 8
        })
        .backgroundColor(LightTheme.TagBlue)
        .borderRadius(16)
        .margin({ left: 8 })
        .onClick(() => {
          this.goToRegister()
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  private goToRegister(): void {
    try {
      router.pushUrl({ url: 'pages/auth/RegisterPage' })
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

            try {
              // 登录成功后替换到首页，避免返回登录页
              router.replaceUrl({ url: 'pages/home/HomePageNew' })
            } catch (jumpError) {
              Logger.error(TAG, `登录成功后跳转失败: ${JSON.stringify(jumpError)}`)
              this.showToast('跳转首页失败')
            }
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
    AlertDialog.show({
      title: '提示',
      message: message,
      primaryButton: {
        value: '知道了',
        action: () => {
        }
      }
    })
  }
}