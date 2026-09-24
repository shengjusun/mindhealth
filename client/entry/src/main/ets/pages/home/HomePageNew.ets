import router from '@ohos.router'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'
import { ApiService } from '../../core/api/ApiService'

const TAG = 'HomePageNew'

interface HomeQuickAction {
  id: string
  icon: Resource
  title: string
  subtitle: string
  targetUrl: string
  tagColor: ResourceColor
  tagBackground: ResourceColor
}

interface AssessmentRecordItem {
  id?: number
  userId?: number
  assessmentId?: number
  assessmentTitle?: string
  score?: number
  level?: string
  suggestion?: string
  createTime?: string
}

interface AssessmentListResponse {
  code?: number
  message?: string
  data?: AssessmentRecordItem[]
  timestamp?: number
}

// 首页视图：作为 MainPage 的 Tab 子组件使用（无底部导航，状态常驻）
@Component
export struct HomeView {
  @State greetingText: string = '今天也要照顾好自己'
  @State moodTip: string = '允许自己慢一点，也是一种成长。'
  @State latestAssessment: AssessmentRecordItem | null = null
  @State isAssessmentLoading: boolean = false

  private authService: AuthService = AuthService.getInstance()
  private apiService: ApiService = ApiService.getInstance()

  private quickActions: HomeQuickAction[] = [
    {
      id: 'chat',
      icon: $r('sys.symbol.message'),
      title: '轻心树洞',
      subtitle: '把今天的想法慢慢说出来',
      targetUrl: 'pages/ai/AIChatPage',
      tagColor: $r('app.color.theme_primary'),
      tagBackground: $r('app.color.tag_blue')
    },
    {
      id: 'diary',
      icon: $r('sys.symbol.book_pages'),
      title: '心情日记',
      subtitle: '记录今天的心情与生活片段',
      targetUrl: 'pages/diary/MoodDiaryPage',
      tagColor: $r('app.color.theme_secondary'),
      tagBackground: $r('app.color.tag_green')
    },
    {
      id: 'assessment',
      icon: $r('sys.symbol.checkmark_clipboard'),
      title: '状态自查',
      subtitle: '简单记录今天的生活状态',
      targetUrl: 'pages/assessment/AssessmentsPage',
      tagColor: $r('app.color.state_warning'),
      tagBackground: $r('app.color.tag_orange')
    },
    {
      id: 'article',
      icon: $r('sys.symbol.doc_text'),
      title: '生活小贴士',
      subtitle: '看看适合今天的温柔提醒',
      targetUrl: 'pages/article/ArticlesPage',
      tagColor: $r('app.color.theme_primary'),
      tagBackground: $r('app.color.tag_blue')
    }
  ]

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }

    this.loadLatestAssessment()
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    AlertDialog.show({
      title: '请先登录',
      message: '当前页面需要登录后才能访问',
      primaryButton: {
        value: '去登录',
        action: () => {
          try {
            router.clear()
          } catch (error) {
            Logger.error(TAG, `清空路由失败: ${JSON.stringify(error)}`)
          }

          router.replaceUrl({
            url: 'pages/auth/LoginPage'
          })
        }
      }
    })

    return false
  }

  private async loadLatestAssessment(): Promise<void> {
    this.isAssessmentLoading = true

    try {
      const rawResult = await this.apiService.getAssessmentResults() as Object

      if (Array.isArray(rawResult)) {
        const list = rawResult as AssessmentRecordItem[]
        this.latestAssessment = list.length > 0 ? list[0] : null
      } else {
        const wrapped = rawResult as AssessmentListResponse
        if (wrapped.code === 200 && wrapped.data && Array.isArray(wrapped.data)) {
          this.latestAssessment = wrapped.data.length > 0 ? wrapped.data[0] : null
        } else {
          this.latestAssessment = null
        }
      }
    } catch (error) {
      Logger.error(TAG, `加载最近状态记录失败: ${JSON.stringify(error)}`)
      this.latestAssessment = null
    } finally {
      this.isAssessmentLoading = false
    }
  }

  private safePush(url: string): void {
    try {
      router.pushUrl({
        url: url
      })
    } catch (error) {
      Logger.error(TAG, `跳转失败: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 快捷入口点击：一级 Tab 功能直接切 Tab（保留各页状态），其余跳二级页
   */
  private openQuickAction(item: HomeQuickAction): void {
    if (item.id === 'chat') {
      AppStorage.setOrCreate('mainTabIndex', 1)
      return
    }
    if (item.id === 'diary') {
      AppStorage.setOrCreate('mainTabIndex', 2)
      return
    }
    if (item.id === 'assessment') {
      AppStorage.setOrCreate('mainTabIndex', 3)
      return
    }
    this.safePush(item.targetUrl)
  }

  private formatTime(text: string): string {
    if (!text || text.length === 0) {
      return '刚刚完成'
    }

    const tIndex: number = text.indexOf('T')
    if (tIndex > 0) {
      return text.substring(0, 16).replace('T', ' ')
    }

    if (text.length >= 16) {
      return text.substring(0, 16)
    }

    return text
  }

  private getLevelBg(level: string): ResourceColor {
    if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
      return $r('app.color.tag_green')
    }

    if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0) {
      return $r('app.color.tag_orange')
    }

    if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
      return $r('app.color.tag_orange')
    }

    return $r('app.color.tag_blue')
  }

  private getLevelColor(level: string): ResourceColor {
    if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
      return $r('app.color.theme_secondary')
    }

    if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0) {
      return $r('app.color.state_warning')
    }

    if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
      return $r('app.color.state_error')
    }

    return $r('app.color.theme_primary')
  }

  private getDisplayLevel(level: string): string {
    if (!level || level.length === 0) {
      return '已记录'
    }

    if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
      return '状态稳定'
    }

    if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0) {
      return '有点起伏'
    }

    if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
      return '需要放慢'
    }

    return level
  }

  private getDisplayTitle(title: string): string {
    if (!title || title.length === 0) {
      return '状态自查'
    }

    if (title.indexOf('焦虑') >= 0 || title.indexOf('紧张') >= 0) {
      return '紧张感记录'
    }

    if (title.indexOf('抑郁') >= 0 || title.indexOf('低落') >= 0) {
      return '低落感记录'
    }

    if (title.indexOf('压力') >= 0) {
      return '压力感受记录'
    }

    if (title.indexOf('睡眠') >= 0) {
      return '睡眠状态记录'
    }

    if (title.indexOf('韧性') >= 0) {
      return '状态恢复力记录'
    }

    if (title.indexOf('心理') >= 0 || title.indexOf('测评') >= 0 || title.indexOf('筛查') >= 0) {
      return '状态自查'
    }

    return title
  }

  private getSuggestionText(text: string): string {
    if (!text || text.length === 0) {
      return '继续留意自己的生活节奏，慢慢调整就好。'
    }

    return text
      .replace('心理', '状态')
      .replace('测评', '记录')
      .replace('治疗', '调整')
      .replace('诊断', '判断')
      .replace('焦虑', '紧张感')
      .replace('抑郁', '低落感')
  }

  private getScoreText(): string {
    if (!this.latestAssessment) {
      return '--'
    }

    if (this.latestAssessment.score === undefined || this.latestAssessment.score === null) {
      return '--'
    }

    return String(this.latestAssessment.score)
  }

  build() {
    Column() {
      AppPageHeader({
        title: '轻心',
        subtitle: '记录心情，也记录生活'
      })

      Scroll() {
        Column() {
          this.buildHeroCard()
          this.buildLatestAssessmentCard()
          this.buildQuickActionSection()
          this.buildDailySuggestionCard()
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 6,
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

  // ===== 以下为构建器 =====

  @Builder
  buildHeroCard() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text('今日心情')
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
          .margin({ bottom: 14 })

          Text(this.greetingText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(32)

          Text('慢下来，先和自己待一会儿。')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })

          Row() {
            Text('今日小提醒')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))

            Blank()

            Text('轻呼吸')
              .fontSize(12)
              .fontColor($r('app.color.theme_primary'))
              .padding({
                left: 10,
                right: 10,
                top: 4,
                bottom: 4
              })
              .backgroundColor($r('app.color.tag_blue'))
              .borderRadius(12)
          }
          .width('100%')
          .margin({
            top: 18,
            bottom: 10
          })

          Text(this.moodTip)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(22)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(22)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(20)
    .margin({ bottom: 18 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildLatestAssessmentCard() {
    Column() {
      Row() {
        Text('最近一次状态记录')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        Text('查看记录')
          .fontSize(12)
          .fontColor($r('app.color.theme_primary'))
          .onClick(() => {
            this.safePush('pages/me/MyRecordsPage')
          })
      }
      .width('100%')
      .margin({ bottom: 14 })

      if (this.isAssessmentLoading) {
        Text('正在加载状态记录...')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      } else if (this.latestAssessment) {
        Row() {
          Column() {
            Text(this.getDisplayTitle(this.latestAssessment.assessmentTitle ? this.latestAssessment.assessmentTitle : ''))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .width('100%')

            Text(`完成时间：${this.formatTime(this.latestAssessment.createTime ? this.latestAssessment.createTime : '')}`)
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
              .margin({ top: 8 })

            Text(this.getSuggestionText(this.latestAssessment.suggestion ? this.latestAssessment.suggestion : ''))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(22)
              .width('100%')
              .margin({ top: 12 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Column() {
            Text(this.getScoreText())
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text('分数')
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 4 })

            Text(this.getDisplayLevel(this.latestAssessment.level ? this.latestAssessment.level : ''))
              .fontSize(12)
              .fontColor(this.getLevelColor(this.latestAssessment.level ? this.latestAssessment.level : ''))
              .padding({
                left: 10,
                right: 10,
                top: 5,
                bottom: 5
              })
              .backgroundColor(this.getLevelBg(this.latestAssessment.level ? this.latestAssessment.level : ''))
              .borderRadius(12)
              .margin({ top: 12 })
          }
          .width(88)
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')

        Row() {
          Button('查看记录')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.theme_primary'))
            .backgroundColor($r('app.color.surface_soft'))
            .borderRadius(21)
            .onClick(() => {
              this.safePush('pages/me/MyRecordsPage')
            })

          Blank()
            .width(12)

          Button('再记一次')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r('app.color.text_on_primary'))
            .backgroundColor($r('app.color.theme_primary'))
            .borderRadius(21)
            .onClick(() => {
              AppStorage.setOrCreate('mainTabIndex', 3)
            })
        }
        .width('100%')
        .margin({ top: 16 })
      } else {
        Text('你还没有状态记录，先做一次简单自查，首页就会展示你的最近状态。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
          .width('100%')

        Button('去做自查')
          .width('100%')
          .height(42)
          .fontSize(14)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.theme_primary'))
          .borderRadius(21)
          .margin({ top: 16 })
          .onClick(() => {
            AppStorage.setOrCreate('mainTabIndex', 3)
          })
      }
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(20)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildQuickActionSection() {
    Column() {
      Row() {
        Text('常用功能')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        Text('快速进入')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        this.buildQuickActionCard(this.quickActions[0], true)
        this.buildQuickActionCard(this.quickActions[1], false)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        this.buildQuickActionCard(this.quickActions[2], true)
        this.buildQuickActionCard(this.quickActions[3], false)
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  @Builder
  buildQuickActionCard(item: HomeQuickAction, withRightMargin: boolean) {
    Column() {
      Row() {
        Row() {
          SymbolGlyph(item.icon)
            .fontSize(15)
            .fontColor([item.tagColor])
        }
        .width(32)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(item.tagBackground)
        .borderRadius(16)

        Blank()

        Text('›')
          .fontSize(18)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 14 })

      Text(item.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(item.subtitle)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('48%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(18)
    .margin({ right: withRightMargin ? '4%' : 0 })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openQuickAction(item)
    })
  }

  @Builder
  buildDailySuggestionCard() {
    Column() {
      Text('今日小提醒')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      Column() {
        this.buildSuggestionItem('休息', '如果今天有些累，试着早点休息。', true)
        this.buildSuggestionItem('记录', '把一个让你在意的念头写下来。', true)
        this.buildSuggestionItem('鼓励', '给自己一句不带评判的鼓励。', false)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.app_card'))
      .borderRadius(18)
    }
    .width('100%')
  }

  @Builder
  buildSuggestionItem(tag: string, text: string, showDivider: boolean) {
    Column() {
      Row() {
        Text(tag)
          .fontSize(12)
          .fontColor($r('app.color.theme_primary'))
          .padding({
            left: 10,
            right: 10,
            top: 4,
            bottom: 4
          })
          .backgroundColor($r('app.color.tag_blue'))
          .borderRadius(10)
          .margin({ right: 10 })

        Text(text)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
          .lineHeight(22)
      }
      .width('100%')
      .padding({
        top: 8,
        bottom: 8
      })

      if (showDivider) {
        Divider()
          .width('100%')
          .height(1)
          .color($r('app.color.app_divider'))
          .margin({
            top: 2,
            bottom: 2
          })
      }
    }
    .width('100%')
  }
}

// 兼容旧路由的独立入口（推荐入口为 pages/MainPage 的 Tab 容器）
@Entry
@Component
struct HomePageNew {
  build() {
    Column() {
      HomeView()
    }
    .width('100%')
    .height('100%')
  }
}