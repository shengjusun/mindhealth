import router from '@ohos.router'
import { AuthService } from '../../core/auth/AppAuthService'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'SettingsPage'
const DOMAIN = 0xFF00

@Entry
@Component
struct SettingsPage {
  @State notificationEnabled: boolean = true
  @State diaryReminderEnabled: boolean = true
  @State cacheSize: string = '12.6 MB'

  authService: AuthService = AuthService.getInstance()

  private goBack(): void {
    router.back()
  }

  private toggleNotification(): void {
    this.notificationEnabled = !this.notificationEnabled
  }

  private toggleDiaryReminder(): void {
    this.diaryReminderEnabled = !this.diaryReminderEnabled
  }

  private clearCache(): void {
    this.cacheSize = '0 KB'
    AlertDialog.show({
      title: '清理完成',
      message: '缓存已清理完成。',
      primaryButton: {
        value: '知道了',
        action: () => {}
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
            router.replaceUrl({ url: 'pages/auth/LoginPage' })
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
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Text('←')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .onClick(() => {
        this.goBack()
      })

      Column() {
        Text('设置')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Text('账号与通用配置')
          .fontSize(11)
          .fontColor('#8B95A7')
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
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildAccountCard() {
    Column() {
      Text('账号设置')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Column() {
          Text('个人资料')
            .fontSize(15)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)

          Text('修改昵称、头像、手机号等信息')
            .fontSize(12)
            .fontColor('#8B95A7')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor('#C0C6D4')
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/me/ProfileEditPage' })
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  @Builder
  buildPreferenceCard() {
    Column() {
      Text('通用偏好')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Column() {
          Text('消息提醒')
            .fontSize(15)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)

          Text('接收系统通知与服务提醒')
            .fontSize(12)
            .fontColor('#8B95A7')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.notificationEnabled ? '已开启' : '已关闭')
          .fontSize(13)
          .fontColor(this.notificationEnabled ? LightTheme.Primary : '#9CA3AF')
      }
      .width('100%')
      .padding({ top: 4, bottom: 12 })
      .onClick(() => {
        this.toggleNotification()
      })

      Divider()
        .width('100%')
        .height(1)
        .color('#EEF1F5')

      Row() {
        Column() {
          Text('日记提醒')
            .fontSize(15)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)

          Text('每天提醒你记录今日情绪')
            .fontSize(12)
            .fontColor('#8B95A7')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.diaryReminderEnabled ? '已开启' : '已关闭')
          .fontSize(13)
          .fontColor(this.diaryReminderEnabled ? LightTheme.Primary : '#9CA3AF')
      }
      .width('100%')
      .padding({ top: 12, bottom: 4 })
      .onClick(() => {
        this.toggleDiaryReminder()
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  @Builder
  buildSupportCard() {
    Column() {
      Text('存储与支持')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Column() {
          Text('清理缓存')
            .fontSize(15)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)

          Text('释放本地缓存空间')
            .fontSize(12)
            .fontColor('#8B95A7')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.cacheSize)
          .fontSize(13)
          .fontColor('#8B95A7')
      }
      .width('100%')
      .padding({ top: 4, bottom: 12 })
      .onClick(() => {
        this.clearCache()
      })

      Divider()
        .width('100%')
        .height(1)
        .color('#EEF1F5')

      Row() {
        Column() {
          Text('隐私说明')
            .fontSize(15)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)

          Text('查看数据使用与隐私说明')
            .fontSize(12)
            .fontColor('#8B95A7')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor('#C0C6D4')
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
      .onClick(() => {
        this.showPrivacyDialog()
      })

      Divider()
        .width('100%')
        .height(1)
        .color('#EEF1F5')

      Row() {
        Column() {
          Text('关于项目')
            .fontSize(15)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)

          Text('了解项目背景与功能简介')
            .fontSize(12)
            .fontColor('#8B95A7')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(20)
          .fontColor('#C0C6D4')
      }
      .width('100%')
      .padding({ top: 12, bottom: 4 })
      .onClick(() => {
        this.showAboutDialog()
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  @Builder
  buildVersionCard() {
    Column() {
      Text('版本信息')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 14 })

      Row() {
        Text('当前版本')
          .fontSize(14)
          .fontColor('#6B7280')

        Blank()

        Text('v1.0.0-demo')
          .fontSize(14)
          .fontColor('#1F2937')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row() {
        Text('说明')
          .fontSize(14)
          .fontColor('#6B7280')

        Blank()

        Text('实习面试演示版')
          .fontSize(14)
          .fontColor('#1F2937')
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  @Builder
  buildLogoutButton() {
    Button('退出登录')
      .width('100%')
      .height(Dimension.ButtonHeight)
      .fontSize(16)
      .fontColor('#E05A5A')
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .onClick(() => {
        this.confirmLogout()
      })
  }
}