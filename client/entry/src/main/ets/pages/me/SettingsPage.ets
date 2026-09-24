import { popRoute, pushRoute, resetRoute } from '../../common/state/AppState'
import { AuthService } from '../../core/auth/AppAuthService'
import { Dimension, ShadowStyle } from '../../common/constants/Theme'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common, bundleManager } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { AppSettings } from '../../common/utils/AppSettings'
import { ToastUtil } from '../../common/utils/ToastUtil'

const TAG = 'SettingsPage'
const DOMAIN = 0xFF00

@ComponentV2
export struct SettingsPage {
  // 开关持久化到 Preferences，重启后保留
  @Local notificationEnabled: boolean = true
  @Local diaryReminderEnabled: boolean = true
  @Local cacheSize: string = '计算中...'
  @Local versionText: string = 'v1.0.0'

  authService: AuthService = AuthService.getInstance()

  aboutToAppear(): void {
    const context = getContext(this) as common.Context
    AppSettings.getBoolean(context, 'notificationEnabled', true).then((value: boolean) => {
      this.notificationEnabled = value
    })
    AppSettings.getBoolean(context, 'diaryReminderEnabled', true).then((value: boolean) => {
      this.diaryReminderEnabled = value
    })
    this.refreshCacheSize()
    this.loadVersion()
  }

  private loadVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      if (info.versionName && info.versionName.length > 0) {
        this.versionText = `v${info.versionName}`
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `读取版本信息失败: ${JSON.stringify(error)}`)
    }
  }

  private goBack(): void {
    popRoute()
  }

  private toggleNotification(enabled: boolean): void {
    this.notificationEnabled = enabled
    AppSettings.setBoolean(getContext(this) as common.Context, 'notificationEnabled', enabled)
  }

  private toggleDiaryReminder(enabled: boolean): void {
    this.diaryReminderEnabled = enabled
    AppSettings.setBoolean(getContext(this) as common.Context, 'diaryReminderEnabled', enabled)
  }

  /**
   * 计算应用缓存目录的真实大小（递归）
   */
  private getDirSize(path: string): number {
    let total: number = 0
    try {
      const names: string[] = fileIo.listFileSync(path)
      for (let i = 0; i < names.length; i++) {
        const childPath = `${path}/${names[i]}`
        const stat: fileIo.Stat = fileIo.statSync(childPath)
        if (stat.isDirectory()) {
          total += this.getDirSize(childPath)
        } else {
          total += stat.size
        }
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `统计目录大小失败: ${JSON.stringify(error)}`)
    }
    return total
  }

  private formatSize(bytes: number): string {
    if (bytes < 1024) {
      return `${bytes} B`
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  private refreshCacheSize(): void {
    const context = getContext(this) as common.Context
    const cacheDir: string = context.cacheDir
    this.cacheSize = this.formatSize(this.getDirSize(cacheDir))
  }

  /**
   * 递归删除目录内容（保留目录本身）
   */
  private clearDirContents(path: string): void {
    try {
      const names: string[] = fileIo.listFileSync(path)
      for (let i = 0; i < names.length; i++) {
        const childPath = `${path}/${names[i]}`
        const stat: fileIo.Stat = fileIo.statSync(childPath)
        if (stat.isDirectory()) {
          fileIo.rmdirSync(childPath)
        } else {
          fileIo.unlinkSync(childPath)
        }
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, `清理目录失败: ${JSON.stringify(error)}`)
    }
  }

  private clearCache(): void {
    AlertDialog.show({
      title: '清理缓存',
      message: `将清理 ${this.cacheSize} 的本地缓存，确定吗？`,
      primaryButton: {
        value: '取消',
        action: () => {
        }
      },
      secondaryButton: {
        value: '清理',
        action: () => {
          const context = getContext(this) as common.Context
          this.clearDirContents(context.cacheDir)
          this.refreshCacheSize()
          ToastUtil.show('缓存已清理')
        }
      }
    })
  }

  private showPrivacyDialog(): void {
    AlertDialog.show({
      title: '隐私说明',
      message: '本项目仅用于学习与演示，用户资料、日记内容和测评结果仅在授权范围内用于功能展示。',
      primaryButton: {
        value: '知道了',
        action: () => {}
      }
    })
  }

  private showAboutDialog(): void {
    AlertDialog.show({
      title: '关于项目',
      message: '这是一个基于 HarmonyOS NEXT + Spring Boot 3 + MySQL 的心理健康辅导项目，包含情绪记录、心理测评与 AI 陪伴功能。',
      primaryButton: {
        value: '知道了',
        action: () => {}
      }
    })
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出当前账号吗？',
      primaryButton: {
        value: '确定',
        action: async () => {
          try {
            await this.authService.logout()
            resetRoute('LoginPage')
          } catch (error) {
            hilog.error(DOMAIN, TAG, `退出登录失败: ${error}`)
          }
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column() {
          this.buildAccountCard()
          this.buildPreferenceCard()
          this.buildSupportCard()
          this.buildVersionCard()
          this.buildLogoutButton()

          Blank()
            .height(24)
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 8,
          bottom: Dimension.SpaceXXL
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
  buildHeader() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor($r('app.color.app_card'))
      .borderRadius(Dimension.CardRadius)
      .onClick(() => {
        this.goBack()
      })

      Column() {
        Text('设置')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('账号与通用配置')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Blank()
        .width(40)
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 14,
      bottom: 10
    })
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildAccountCard() {
    Column() {
      Text('账号设置')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Column() {
          Text('个人资料')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)

          Text('修改昵称、头像、手机号等信息')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .onClick(() => {
        pushRoute('ProfileEditPage')
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildPreferenceCard() {
    Column() {
      Text('通用偏好')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Column() {
          Text('消息提醒')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)

          Text('接收系统通知与服务提醒')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled })
          .selectedColor($r('app.color.theme_primary'))
          .onChange((isOn: boolean) => {
            this.toggleNotification(isOn)
          })
      }
      .width('100%')
      .padding({ top: 4, bottom: 12 })

      Divider()
        .width('100%')
        .height(1)
        .color($r('app.color.surface_soft'))

      Row() {
        Column() {
          Text('日记提醒')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)

          Text('每天提醒你记录今日情绪')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: this.diaryReminderEnabled })
          .selectedColor($r('app.color.theme_primary'))
          .onChange((isOn: boolean) => {
            this.toggleDiaryReminder(isOn)
          })
      }
      .width('100%')
      .padding({ top: 12, bottom: 4 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildSupportCard() {
    Column() {
      Text('存储与支持')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Column() {
          Text('清理缓存')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)

          Text('释放本地缓存空间')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.cacheSize)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .padding({ top: 4, bottom: 12 })
      .onClick(() => {
        this.clearCache()
      })

      Divider()
        .width('100%')
        .height(1)
        .color($r('app.color.surface_soft'))

      Row() {
        Column() {
          Text('隐私说明')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)

          Text('查看数据使用与隐私说明')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.showPrivacyDialog()
      })

      Divider()
        .width('100%')
        .height(1)
        .color($r('app.color.surface_soft'))

      Row() {
        Column() {
          Text('关于项目')
            .fontSize(15)
            .fontColor($r('app.color.text_primary'))
            .fontWeight(FontWeight.Medium)

          Text('了解项目背景与功能简介')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ top: 12, bottom: 4 })
      .onClick(() => {
        this.showAboutDialog()
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildVersionCard() {
    Column() {
      Text('版本信息')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Text('当前版本')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Blank()

        Text(this.versionText)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row() {
        Text('说明')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))

        Blank()

        Text('开发调试版')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildLogoutButton() {
    Button('退出登录')
      .width('100%')
      .height(Dimension.ButtonHeight)
      .fontSize(16)
      .fontColor($r('app.color.state_error'))
      .backgroundColor($r('app.color.app_card'))
      .borderRadius(18)
      .onClick(() => {
        this.confirmLogout()
      })
  }
}

