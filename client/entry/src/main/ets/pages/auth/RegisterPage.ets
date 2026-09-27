import { appState, popRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { brand, Dimension, ShadowStyle } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { AppButton } from '../../common/components/AppButton'

const TAG = 'RegisterPage'

interface RegisterRequest {
  phone: string
  password: string
  confirmPassword: string
}

@ComponentV2
export struct RegisterPage {
  @Local phone: string = ''
  @Local password: string = ''
  @Local confirmPassword: string = ''
  @Local isLoading: boolean = false

  private apiService: ApiService = ApiService.getInstance()

  /** 任一注册字段非空即视为"有未提交内容"（驱动路由层返回拦截，审计 C-5-1） */
  private updateRegisterDirty(): boolean {
    const dirty: boolean = this.phone.trim().length > 0 || this.password.length > 0 || this.confirmPassword.length > 0
    appState().hasUnsavedChanges = dirty
    return dirty
  }

  aboutToDisappear(): void {
    appState().hasUnsavedChanges = false
  }

  @Monitor('state.backPressedTick')
  onBackIntercepted(): void {
    if (!this.updateRegisterDirty()) {
      return
    }
    AlertDialog.show({
      title: '放弃注册？',
      message: '返回后已填写的内容将不会保留',
      primaryButton: {
        value: '继续填写',
        action: () => {}
      },
      secondaryButton: {
        value: '放弃',
        action: () => {
          appState().hasUnsavedChanges = false
          popRoute()
        }
      }
    })
  }

  // 原 onBackPress 只是 popRoute() 后 return true，与系统默认返回行为完全等价；
  // V2 组件不支持该生命周期，直接移除，返回行为不变。

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
        .align(Alignment.TopStart)
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
          .fontColor(brand().primary)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(brand().tagBlue)
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
    .shadow(ShadowStyle.Card)
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
          this.updateRegisterDirty()
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
          this.updateRegisterDirty()
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
          this.updateRegisterDirty()
        })
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
      AppButton({
        label: this.isLoading ? '注册中...' : '立即注册',
        kind: 'primary',
        block: true,
        loading: this.isLoading,
        active: !this.isLoading,
        outerMargin: { top: 20, bottom: 16 },
        onPress: () => {
          this.handleRegister()
        }
      })

      Row() {
        Text('已经有账号？')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Row() {
          Text('去登录')
            .fontSize(14)
            .fontColor(brand().primary)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor(brand().tagBlue)
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
        appState().hasUnsavedChanges = false
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
      this.showToast('网络好像不太顺畅，稍后再试试')
    }
  }

  private showToast(message: string): void {
    ToastUtil.show(message)
  }
}