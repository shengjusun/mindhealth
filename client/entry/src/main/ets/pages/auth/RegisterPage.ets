import { popRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'

const TAG = 'RegisterPage'

interface RegisterRequest {
  phone: string
  password: string
  confirmPassword: string
}

@Component
export struct RegisterPage {
  @State phone: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State isLoading: boolean = false

  private apiService: ApiService = ApiService.getInstance()

  onBackPress(): boolean {
    try {
      popRoute()
    } catch (error) {
      Logger.error(TAG, `返回登录页失败: ${JSON.stringify(error)}`)
    }
    return true
  }

  build() {
    Column() {
      AppPageHeader({
        title: '注册',
        subtitle: '创建你的轻心账号',
        showBack: true
      })

      Scroll() {
        Column() {
          this.buildWelcomeCard()
          this.buildRegisterForm()
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
        Text('新账号')
          .fontSize(12)
          .fontColor($r('app.color.theme_primary'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.tag_blue'))
          .borderRadius(12)
      }
      .margin({ bottom: 16 })

      Text('欢迎加入轻心')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('从今天开始，记录情绪、完成测评、慢慢看见自己的变化。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  @Builder
  buildRegisterForm() {
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
        .margin({ bottom: 16 })

      Text('确认密码')
        .fontSize(Dimension.FontM)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      TextInput({ placeholder: '请再次输入密码', text: this.confirmPassword })
        .width('100%')
        .height(Dimension.InputHeight)
        .type(InputType.Password)
        .fontSize(Dimension.FontL)
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.confirmPassword = value
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
  }

  @Builder
  buildActionArea() {
    Column() {
      Button(this.isLoading ? '注册中...' : '立即注册')
        .width('100%')
        .height(Dimension.ButtonHeight)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor(this.isLoading ? $r('app.color.text_tertiary') : $r('app.color.theme_primary'))
        .borderRadius(24)
        .enabled(!this.isLoading)
        .onClick(() => {
          if (!this.isLoading) {
            this.handleRegister()
          }
        })
        .margin({ top: 20, bottom: 16 })

      Row() {
        Text('已经有账号？')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Row() {
          Text('去登录')
            .fontSize(14)
            .fontColor($r('app.color.theme_primary'))
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor($r('app.color.tag_blue'))
        .borderRadius(16)
        .margin({ left: 8 })
        .onClick(() => {
          this.goToLogin()
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
  }

  private goToLogin(): void {
    try {
      popRoute()
    } catch (error) {
      Logger.error(TAG, `返回登录页失败: ${JSON.stringify(error)}`)
      this.showToast('返回登录页失败')
    }
  }

  private async handleRegister(): Promise<void> {
    const phoneValue: string = this.phone.trim()
    const passwordValue: string = this.password.trim()
    const confirmPasswordValue: string = this.confirmPassword.trim()

    if (phoneValue.length === 0) {
      this.showToast('请输入手机号')
      return
    }

    if (!/^1[3-9]\d{9}$/.test(phoneValue)) {
      this.showToast('手机号格式不正确')
      return
    }

    if (passwordValue.length === 0) {
      this.showToast('请输入密码')
      return
    }

    if (passwordValue.length < 6) {
      this.showToast('密码至少需要 6 位')
      return
    }

    if (confirmPasswordValue.length === 0) {
      this.showToast('请确认密码')
      return
    }

    if (passwordValue !== confirmPasswordValue) {
      this.showToast('两次输入的密码不一致')
      return
    }

    this.isLoading = true

    try {
      const payload: RegisterRequest = {
        phone: phoneValue,
        password: passwordValue,
        confirmPassword: confirmPasswordValue
      }

      const res = await this.apiService.register(payload)

      this.isLoading = false

      if (res.code === 200) {
        ToastUtil.showLong('注册成功，现在可以去登录了')
        try {
          popRoute()
        } catch (error) {
          Logger.error(TAG, `注册成功后返回登录页失败: ${JSON.stringify(error)}`)
        }
      } else {
        this.showToast(res.message ? res.message : '注册失败')
      }
    } catch (error) {
      this.isLoading = false
      Logger.error(TAG, `注册失败: ${JSON.stringify(error)}`)
      this.showToast('网络异常，请稍后重试')
    }
  }

  private showToast(message: string): void {
    ToastUtil.show(message)
  }
}