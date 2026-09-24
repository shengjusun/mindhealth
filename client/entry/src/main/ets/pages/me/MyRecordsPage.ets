import { appState, popRoute, pushRoute, pushRouteWithParam, resetRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { Dimension, ShadowStyle } from '../../common/constants/Theme'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'

const TAG = 'MyRecordsPage'

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

interface DiaryItem {
  id?: number
  title?: string
  content?: string
  emotion?: string
  intensity?: number
  event?: string
  createTime?: string
}

// 传给日记详情页的路由参数
interface DiaryDetailParams {
  id: number
  title: string
  content: string
  emotion: string
  intensity: number
  event: string
  createTime: string
}

// 传给主页的路由参数：指定落地 Tab
interface MainPageTabParams {
  tab: string
}

@ComponentV2
export struct MyRecordsPage {
  @Local currentTab: string = 'assessment'
  @Local assessmentRecords: AssessmentRecordItem[] = []
  @Local isAssessmentLoading: boolean = false
  @Local diaryRecords: DiaryItem[] = []
  @Local isDiaryLoading: boolean = false
  private authService: AuthService = AuthService.getInstance()

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }
    this.loadAssessmentRecords()
    this.loadDiaryRecords()
  }

  private safePush(routeName: string): void {
    try {
      pushRoute(routeName)
    } catch (error) {
      Logger.error(TAG, `跳转失败: ${JSON.stringify(error)}`)
    }
  }

  private switchTab(tab: string): void {
    this.currentTab = tab
  }

  private async loadAssessmentRecords(): Promise<void> {
    this.isAssessmentLoading = true

    try {
      const response = await this.apiService.getAssessmentResults()
      if (response.code === 200 && Array.isArray(response.data)) {
        this.assessmentRecords = response.data as AssessmentRecordItem[]
      } else {
        this.assessmentRecords = []
      }
    } catch (error) {
      Logger.error(TAG, `加载测评记录失败: ${JSON.stringify(error)}`)
      this.assessmentRecords = []
    } finally {
      this.isAssessmentLoading = false
    }
  }

  private async loadDiaryRecords(): Promise<void> {
    this.isDiaryLoading = true

    try {
      const response = await this.apiService.getDiaryList()
      if (response.code === 200 && Array.isArray(response.data)) {
        this.diaryRecords = response.data as DiaryItem[]
      } else {
        this.diaryRecords = []
      }
    } catch (error) {
      Logger.error(TAG, `加载日记记录失败: ${JSON.stringify(error)}`)
      this.diaryRecords = []
    } finally {
      this.isDiaryLoading = false
    }
  }

  private formatDateTime(text: string): string {
    if (!text || text.length === 0) {
      return ''
    }

    const tIndex: number = text.indexOf('T')
    if (tIndex > 0) {
      return text.substring(0, 16).replace('T', ' ')
    }

    return text
  }

  private getDiaryDateText(timeText: string): string {
    if (!timeText || timeText.length === 0) {
      return '今天'
    }
    const tIndex: number = timeText.indexOf('T')
    if (tIndex > 0) {
      return timeText.substring(0, tIndex)
    }
    return timeText
  }

  private getLevelBg(level: string): ResourceColor {
    if (level.indexOf('良好') >= 0) {
      return $r('app.color.tag_green')
    }
    if (level.indexOf('轻度') >= 0) {
      return $r('app.color.tag_orange')
    }
    if (level.indexOf('中度') >= 0) {
      return $r('app.color.tag_blue')
    }
    return $r('app.color.surface_soft')
  }

  private getLevelColor(level: string): ResourceColor {
    if (level.indexOf('良好') >= 0) {
      return $r('app.color.state_success')
    }
    if (level.indexOf('轻度') >= 0) {
      return $r('app.color.state_warning')
    }
    if (level.indexOf('中度') >= 0) {
      return $r('app.color.state_error')
    }
    return $r('app.color.text_secondary')
  }

  private goDiaryDetail(item: DiaryItem): void {
    const params: DiaryDetailParams = {
      id: item.id ?? 0,
      title: item.title ?? '',
      content: item.content ?? '',
      emotion: item.emotion ?? '',
      intensity: item.intensity ?? 0,
      event: item.event ?? '',
      createTime: item.createTime ?? ''
    }
    pushRouteWithParam('DiaryDetailPage', params)
  }

  build() {
    Column() {
      AppPageHeader({
        title: '我的记录',
        subtitle: '日记与测评记录',
        showBack: true
      })

      this.buildTabCard()

      if (this.currentTab === 'assessment') {
        this.buildAssessmentView()
      } else {
        this.buildDiaryView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildTabCard() {
    Row() {
      this.buildTabItem('测评记录', 'assessment')
      this.buildTabItem('日记记录', 'diary')
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 4,
      bottom: 10
    })
  }

  @Builder
  buildTabItem(title: string, tab: string) {
    Column() {
      Text(title)
        .fontSize(15)
        .fontWeight(this.currentTab === tab ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.currentTab === tab ? $r('app.color.theme_primary') : $r('app.color.text_secondary'))

      Row()
        .width(24)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.currentTab === tab ? $r('app.color.theme_primary') : Color.Transparent)
        .margin({ top: 8 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ right: tab === 'assessment' ? 6 : 0, left: tab === 'diary' ? 6 : 0 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.switchTab(tab)
    })
  }

  @Builder
  buildAssessmentView() {
    Scroll() {
      Column() {
        if (this.isAssessmentLoading) {
          this.buildLoadingCard('正在加载测评记录...')
        } else if (this.assessmentRecords.length === 0) {
          this.buildEmptyAssessmentCard()
        } else {
          ForEach(this.assessmentRecords, (item: AssessmentRecordItem, index: number) => {
            this.buildAssessmentRecordCard(item, index)
          })
        }

        Blank()
          .height(24)
      }
      .width('100%')
      .padding({
        left: Dimension.SpaceL,
        right: Dimension.SpaceL,
        top: 2,
        bottom: Dimension.SpaceXXL
      })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildDiaryView() {
    Scroll() {
      Column() {
        this.buildDiaryGuideCard()

        if (this.isDiaryLoading) {
          this.buildLoadingCard('正在加载日记记录...')
        } else if (this.diaryRecords.length === 0) {
          this.buildEmptyDiaryCard()
        } else {
          ForEach(this.diaryRecords, (item: DiaryItem, index: number) => {
            this.buildDiaryRecordCard(item, index)
          })
        }

        Blank()
          .height(24)
      }
      .width('100%')
      .padding({
        left: Dimension.SpaceL,
        right: Dimension.SpaceL,
        top: 2,
        bottom: Dimension.SpaceXXL
      })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  buildLoadingCard(message: string) {
    Column() {
      LoadingProgress()
        .width(32)
        .height(32)
        .color($r('app.color.theme_primary'))

      Text(message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(24)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(18)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildEmptyAssessmentCard() {
    Column() {
      Text('还没有测评记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('去完成一次测评后，记录会自动出现在这里。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })

      Button('去做测评')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.theme_primary'))
        // 主按钮：同色系轻微渐变 + 柔和主色阴影，提升点击欲望
        .linearGradient({
          angle: 135,
          colors: [[$r('app.color.theme_primary'), 0], [$r('app.color.primary_pressed'), 1]]
        })
        .borderRadius(Dimension.CardRadiusInner)
        .shadow(ShadowStyle.Button)
        .borderRadius(23)
        .margin({ top: 18 })
        .onClick(() => {
          // 回主框架并切到自查 Tab：MainPage 是栈底页面，
          // 先改全局 Tab 下标再出栈，MainPage 的 @Monitor 会驱动 Tabs 切换
          appState().mainTabIndex = 3
          popRoute()
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildEmptyDiaryCard() {
    Column() {
      Text('还没有日记记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('写下第一条日记后，它会安静地躺在这里。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })

      Button('去写日记')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.theme_primary'))
        // 主按钮：同色系轻微渐变 + 柔和主色阴影，提升点击欲望
        .linearGradient({
          angle: 135,
          colors: [[$r('app.color.theme_primary'), 0], [$r('app.color.primary_pressed'), 1]]
        })
        .borderRadius(Dimension.CardRadiusInner)
        .shadow(ShadowStyle.Button)
        .borderRadius(23)
        .margin({ top: 18 })
        .onClick(() => {
          this.safePush('pages/diary/DiaryEditPage')
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildDiaryGuideCard() {
    Column() {
      Text('日记记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('记录情绪不是为了评判自己，而是为了更温柔地理解自己。点击日记可查看和编辑。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildDiaryRecordCard(item: DiaryItem, index: number) {
    Column() {
      Row() {
        Text(item.emotion && item.emotion.length > 0 ? item.emotion : '情绪记录')
          .fontSize(12)
          .fontColor($r('app.color.theme_primary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.tag_blue'))
          .borderRadius(10)

        Blank()

        Text(this.getDiaryDateText(item.createTime ?? ''))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 10 })

      Text(item.title && item.title.length > 0 ? item.title : '未命名日记')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (item.content && item.content.length > 0) {
        Text(item.content)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: index === this.diaryRecords.length - 1 ? 0 : 12 })
    .onClick(() => {
      this.goDiaryDetail(item)
    })
  }

  @Builder
  buildAssessmentRecordCard(item: AssessmentRecordItem, index: number) {
    Column() {
      Row() {
        Text(item.assessmentTitle ? item.assessmentTitle : '心理测评')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Text(item.level ? item.level : '未知')
          .fontSize(12)
          .fontColor(this.getLevelColor(item.level ? item.level : ''))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(this.getLevelBg(item.level ? item.level : ''))
          .borderRadius(12)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Row() {
        Text(`得分：${item.score ?? 0}`)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.formatDateTime(item.createTime ? String(item.createTime) : ''))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 10 })

      Text(item.suggestion ? item.suggestion : '暂无建议')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(18)
    .margin({ bottom: index === this.assessmentRecords.length - 1 ? 0 : 14 })
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    resetRoute('LoginPage')
    return false
  }
}
