import { appState, AppState, popRoute, pushRoute, pushRouteWithParam, resetRoute } from '../../common/state/AppState'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'
import { brand, BrandPalette, Dimension, Motion, ShadowStyle, ThemeDef, THEMES } from '../../common/constants/Theme'
import { common, bundleManager } from '@kit.AbilityKit'
import { fileIo } from '@kit.CoreFileKit'
import { AppSettings } from '../../common/utils/AppSettings'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { notificationManager } from '@kit.NotificationKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { disableDailyReminder, enableDailyReminder, isDailyReminderActive } from '../../common/utils/DiaryReminder'
import { AppButton } from '../../common/components/AppButton'

const TAG = 'SettingsPage'

@ComponentV2
export struct SettingsPage {
  // 开关持久化到 Preferences，重启后保留
  @Local notificationEnabled: boolean = true
  @Local diaryReminderEnabled: boolean = true
  @Local cacheSize: string = '计算中...'
  @Local versionText: string = 'v1.0.0'

  // 观察全局主题状态：切主题后本页选中态要跟着变，且预览要跟随深浅色
  @Local state: AppState = appState()

  authService: AuthService = AuthService.getInstance()

  aboutToAppear(): void {
    const context = getContext(this) as common.Context
    AppSettings.getBoolean(context, 'notificationEnabled', true).then((value: boolean) => {
      this.notificationEnabled = value
      this.syncNotificationPermission()
    })
    AppSettings.getBoolean(context, 'diaryReminderEnabled', true).then((value: boolean) => {
      this.diaryReminderEnabled = value
      // 与系统真实状态对齐：偏好开着但系统里没有（重装/被系统清理），补建；
      // 偏好关了但系统里还挂着，取消。以系统为准，偏好只代表用户意愿。
      isDailyReminderActive().then((active: boolean) => {
        if (value && !active) {
          enableDailyReminder(getContext(this) as common.UIAbilityContext).catch((err: BusinessError) => {
            Logger.warn(TAG, `启动时补建日记提醒失败: ${JSON.stringify(err)}`)
          })
        } else if (!value && active) {
          disableDailyReminder().catch((err: BusinessError) => {
            Logger.warn(TAG, `启动时清理日记提醒失败: ${JSON.stringify(err)}`)
          })
        }
      })
    })
    this.refreshCacheSize()
    this.loadVersion()
  }

  /** 进页时与系统真实授权对齐：用户在系统设置里关了通知，这里不能还显示开着 */
  private syncNotificationPermission(): void {
    notificationManager.isNotificationEnabled().then((sysEnabled: boolean) => {
      if (!sysEnabled && this.notificationEnabled) {
        this.notificationEnabled = false
        AppSettings.setBoolean(getContext(this) as common.Context, 'notificationEnabled', false)
      }
    }).catch((error: BusinessError) => {
      Logger.warn(TAG, `读取通知授权状态失败: ${error.code} ${error.message}`)
    })
  }

  private loadVersion(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      if (info.versionName && info.versionName.length > 0) {
        this.versionText = `v${info.versionName}`
      }
    } catch (error) {
      Logger.warn(TAG, `读取版本信息失败: ${JSON.stringify(error)}`)
    }
  }

  private goBack(): void {
    popRoute()
  }

  /**
   * 消息提醒开关：打开时向系统申请通知授权；拒绝过一次后系统不再弹窗，
   * 这里回弹开关并提示去系统设置。关闭只是应用内不再提醒，无需系统调用。
   */
  private async toggleNotification(enabled: boolean): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext

    if (!enabled) {
      this.notificationEnabled = false
      AppSettings.setBoolean(context, 'notificationEnabled', false)
      return
    }

    try {
      await notificationManager.requestEnableNotification(context)
      this.notificationEnabled = true
      AppSettings.setBoolean(context, 'notificationEnabled', true)
    } catch (error) {
      const err = error as BusinessError
      Logger.warn(TAG, `通知授权未通过: ${err.code} ${err.message}`)
      this.notificationEnabled = false
      AppSettings.setBoolean(context, 'notificationEnabled', false)
      ToastUtil.showLong('未获得通知权限，可在系统设置中为轻心开启通知')
    }
  }

  /**
   * 日记提醒开关 —— 真正落到系统代理提醒（reminderAgentManager），
   * 不只是存偏好：注册/取消失败时回滚开关并提示，避免「开关开着但提醒发不出来」。
   */
  private toggleDiaryReminder(enabled: boolean): void {
    this.diaryReminderEnabled = enabled
    AppSettings.setBoolean(getContext(this) as common.Context, 'diaryReminderEnabled', enabled)

    const ctx = getContext(this) as common.UIAbilityContext
    if (enabled) {
      enableDailyReminder(ctx).then(() => {
        ToastUtil.show('已开启，每晚 21:30 提醒你写日记')
      }).catch((err: BusinessError) => {
        // 回滚：开关和偏好都退回关，避免「看着开了、实际没注册」
        this.diaryReminderEnabled = false
        AppSettings.setBoolean(ctx, 'diaryReminderEnabled', false)
        ToastUtil.showLong('开启失败：需要在系统设置中允许轻心发送通知')
        Logger.warn(TAG, `开启日记提醒失败: ${JSON.stringify(err)}`)
      })
    } else {
      disableDailyReminder().then(() => {
        ToastUtil.show('已关闭日记提醒')
      }).catch((err: BusinessError) => {
        Logger.warn(TAG, `关闭日记提醒失败: ${JSON.stringify(err)}`)
      })
    }
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
      Logger.warn(TAG, `统计目录大小失败: ${JSON.stringify(error)}`)
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
      Logger.warn(TAG, `清理目录失败: ${JSON.stringify(error)}`)
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

  /** 内容型说明改为详情页承载（批次 6）：可滚动、可复查，未来扩用户协议/开源许可直接加 type */
  private openContent(title: string, type: string): void {
    const params: Record<string, string> = { 'title': title, 'type': type }
    pushRouteWithParam('ContentPage', params)
  }

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column() {
          this.buildThemeCard()
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

  /** 账号操作放在设置页尾部（与微信/QQ/淘宝布局惯例一致），「我的」页专注内容入口 */
  @Builder
  buildLogoutButton() {
    AppButton({
      label: '退出登录',
      kind: 'primary',
      danger: true,
      block: true,
      onPress: () => {
        this.handleLogout()
      }
    })
  }

  private handleLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出登录吗？',
      primaryButton: {
        value: '确定',
        action: async () => {
          try {
            await this.authService.logout()
            // 登出后清空导航栈，避免返回键回退到已登出账号的页面
            resetRoute('LoginPage')
          } catch (error) {
            Logger.error(TAG, `退出登录失败: ${JSON.stringify(error)}`)
          }
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
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
      .shadow(ShadowStyle.Card)
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
      top: this.state.topAvoidVp > 0 ? this.state.topAvoidVp + 8 : 22,
      bottom: 10
    })
    .backgroundColor($r('app.color.app_background'))
  }

  /** 切换主题：animateTo 让全 App 颜色渐变过渡而非跳变（动效令牌 emphasized） */
  private selectTheme(id: string): void {
    if (this.state.themeId === id) {
      return
    }
    this.getUIContext().animateTo({ duration: Motion.Slow, curve: Motion.emphasized }, () => {
      this.state.themeId = id
    })
    AppSettings.setString(getContext(this) as common.Context, 'themeId', id)
  }

  // 下面两个是取值方法而不是 @Builder 里的局部变量：
  // ArkTS 的 @Builder 内只允许 UI 组件语法，写 const 声明会编译失败。

  /** 预览用当前深浅模式下真正生效的那份色板，所见即所得 */
  private paletteOf(def: ThemeDef): BrandPalette {
    return this.state.isDark ? def.dark : def.light
  }

  private isSelected(def: ThemeDef): boolean {
    return this.state.themeId === def.id
  }

  @Builder
  buildThemeCard() {
    Column() {
      Text('外观主题')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 6 })

      Text('切换后全 App 立即生效，深浅色仍跟随系统')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 14 })

      ForEach(THEMES, (def: ThemeDef, index: number) => {
        this.buildThemeOption(def, index === THEMES.length - 1)
      }, (def: ThemeDef) => def.id)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildThemeOption(def: ThemeDef, isLast: boolean) {
    Row() {
      Row() {
        // 圆点用「22×22 容器 + 11 半圆角」画，而不是 Circle().fill()：
        // Circle 的 fill 重载是 @since 26，而本项目 compatibleSdkVersion 为 22，
        // 低版本设备上取不到颜色（编译只告警不报错）；backgroundColor 是通用属性，全版本可用
        Row()
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor(this.paletteOf(def).primary)
        Row()
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor(this.paletteOf(def).primaryPressed)
          .margin({ left: -6 })
        Row()
          .width(22)
          .height(22)
          .borderRadius(11)
          .backgroundColor(this.paletteOf(def).tagBlue)
          .margin({ left: -6 })
      }
      .margin({ right: 14 })

      Column() {
        Text(def.name)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)

        Text(def.desc)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.isSelected(def)) {
        Text('✓')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.paletteOf(def).primary)
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(Dimension.CardRadiusInner)
    .borderWidth(this.isSelected(def) ? 2 : 0)
    .borderColor(this.paletteOf(def).primary)
    .backgroundColor(this.isSelected(def) ? this.paletteOf(def).tagBlue : Color.Transparent)
    .margin({ bottom: isLast ? 0 : 10 })
    .onClick(() => {
      this.selectTheme(def.id)
    })
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
          .selectedColor(brand().primary)
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
          .selectedColor(brand().primary)
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
        this.openContent('隐私说明', 'privacy')
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
        this.openContent('关于项目', 'about')
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
}

