import { appState, popRoute, pushRoute, pushRouteWithParam, resetRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { brand, Dimension, FontLevel, ShadowStyle, Motion } from '../../common/constants/Theme'
import { AppChip } from '../../common/components/AppChip'
import { softLevel, softLevelKind, emotionChipKind } from '../../common/utils/AssessmentTone'
import { AppButton } from '../../common/components/AppButton'
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

// 传给结果回放页的路由参数
interface AssessmentResultParams {
  resultId: number
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
  // 网络失败标记：把"加载失败"和"还没有记录"区分开（审计 C-1-7）
  @Local assessmentLoadError: boolean = false
  @Local diaryLoadError: boolean = false
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
        this.assessmentLoadError = false
      } else {
        this.assessmentRecords = []
        this.assessmentLoadError = true
      }
    } catch (error) {
      Logger.error(TAG, `加载测评记录失败: ${JSON.stringify(error)}`)
      this.assessmentRecords = []
      this.assessmentLoadError = true
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
        this.diaryLoadError = false
      } else {
        this.diaryRecords = []
        this.diaryLoadError = true
      }
    } catch (error) {
      Logger.error(TAG, `加载日记记录失败: ${JSON.stringify(error)}`)
      this.diaryRecords = []
      this.diaryLoadError = true
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

  // 测评卡与日记卡交互对齐：卡片可点进详情（UX 走查 P1-3）
  private goResultDetail(item: AssessmentRecordItem): void {
    if (item.id === undefined || item.id === null || item.id <= 0) {
      return
    }
    const params: AssessmentResultParams = { resultId: item.id }
    pushRouteWithParam('AssessmentResultPage', params)
  }

  build() {
    Column() {
      AppPageHeader({
        title: '我的记录',
        subtitle: '心情与状态的足迹',
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
    // 官方分段控件形态：bg-subtle 胶囊 + 选中段主色底白字（与资料编辑性别分段同款语言）
    // 外层补与列表卡一致的左右边距，避免分段控件贴屏幕边
    Column() {
      Row() {
        this.buildTabItem('状态足迹', 'assessment')
        this.buildTabItem('心情日记', 'diary')
      }
      .width('100%')
      .height(36)
      .padding(2)
      .borderRadius(Dimension.RadiusFull)
      .backgroundColor($r('app.color.surface_soft'))
    }
    .width('100%')
    .padding({ left: Dimension.SpaceL, right: Dimension.SpaceL })
    .margin({ bottom: Dimension.SpaceL })
  }

  @Builder
  buildTabItem(title: string, tab: string) {
    Text(title)
      .fontSize(FontLevel.Body)
      .fontWeight(this.currentTab === tab ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.currentTab === tab ? $r('app.color.text_on_primary') : $r('app.color.text_tertiary'))
      .backgroundColor(this.currentTab === tab ? brand().primary : Color.Transparent)
      .textAlign(TextAlign.Center)
      .layoutWeight(1)
      .height(32)
      .borderRadius(Dimension.RadiusFull)
      .animation({ curve: Motion.springEmphasized })
      .onClick(() => {
        this.switchTab(tab)
      })
  }

  @Builder
  buildErrorCard(message: string, retry: () => void) {
    // 错误卡：与空态卡同款容器语言，明确告知"失败"而非伪装成空（审计 C-1-7）
    Column() {
      SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
        .fontSize(44)
        .fontColor([$r('app.color.text_tertiary')])
        .margin({ bottom: 12 })

      Text(message)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 6 })

      Text('检查网络后重试')
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ bottom: 16 })

      AppButton({
        label: '重试',
        kind: 'secondary',
        onPress: retry
      })
    }
    .width('100%')
    .padding(24)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildAssessmentView() {
    Scroll() {
      Column() {
        if (this.isAssessmentLoading) {
          this.buildLoadingCard('正在整理状态足迹...')
        } else if (this.assessmentLoadError) {
          this.buildErrorCard('状态足迹加载失败', (): void => {
            this.loadAssessmentRecords()
          })
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
    .align(Alignment.TopStart)
  }

  @Builder
  buildDiaryView() {
    Scroll() {
      Column() {
        this.buildDiaryGuideCard()

        if (this.isDiaryLoading) {
          this.buildLoadingCard('正在整理心情日记...')
        } else if (this.diaryLoadError) {
          this.buildErrorCard('心情日记加载失败', (): void => {
            this.loadDiaryRecords()
          })
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
    .align(Alignment.TopStart)
  }

  @Builder
  buildLoadingCard(message: string) {
    Column() {
      LoadingProgress()
        .width(32)
        .height(32)
        .color(brand().primary)

      Text(message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(24)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(18)
    .shadow(ShadowStyle.Card)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildEmptyAssessmentCard() {
    Column() {
      Text('还没有状态足迹')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('去了解一次自己，足迹就会留在这里。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })

      AppButton({
        label: '去做自查',
        kind: 'primary',
        block: true,
        outerMargin: { top: 18 },
        onPress: () => {
          // 回主框架并切到自查 Tab：MainPage 是栈底页面，
          // 先改全局 Tab 下标再出栈，MainPage 的 @Monitor 会驱动 Tabs 切换
          appState().mainTabIndex = 3
          popRoute()
        }
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
      Text('还没有心情日记')
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

      AppButton({
        label: '去写日记',
        kind: 'primary',
        block: true,
        outerMargin: { top: 18 },
        onPress: () => {
          this.safePush('DiaryEditPage')
        }
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
      Text('心情日记')
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
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
        AppChip({
          label: item.emotion && item.emotion.length > 0 ? item.emotion : '情绪记录',
          kind: emotionChipKind(item.emotion ?? '')
        })

        Blank()

        Text(this.getDiaryDateText(item.createTime ?? ''))
          .fontSize(FontLevel.Caption)
          .fontColor($r('app.color.text_quaternary'))
      }
      .width('100%')
      .margin({ bottom: Dimension.SpaceS })

      Text(item.title && item.title.length > 0 ? item.title : '未命名日记')
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (item.content && item.content.length > 0) {
        Text(item.content)
          .fontSize(FontLevel.Body)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: Dimension.Space2XS })
      }
    }
    .width('100%')
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: index === this.diaryRecords.length - 1 ? 0 : Dimension.SpaceXXL })
    .onClick(() => {
      this.goDiaryDetail(item)
    })
  }

  @Builder
  buildAssessmentRecordCard(item: AssessmentRecordItem, index: number) {
    // 对齐首页状态卡：标题 + 分数主角，建议灰块，chip + 日期收底
    Column() {
      Row() {
        Text(item.assessmentTitle ? item.assessmentTitle : '心理测评')
          .fontSize(FontLevel.SectionTitle)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        Row() {
          Text(`${item.score ?? 0}`)
            .fontSize(FontLevel.Stat)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text('分')
            .fontSize(FontLevel.Caption)
            .fontColor($r('app.color.text_quaternary'))
            .margin({ left: 2 })
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(item.suggestion ? item.suggestion : '暂无建议')
        .fontSize(FontLevel.Body)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
        .width('100%')
        .padding(Dimension.CardPaddingInner)
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(Dimension.RadiusM)
        .margin({ top: Dimension.SpaceM })

      Row() {
        AppChip({
          label: softLevel(item.level ? item.level : ''),
          kind: softLevelKind(item.level ? item.level : '')
        })

        Blank()

        Text(this.formatDateTime(item.createTime ? String(item.createTime) : ''))
          .fontSize(FontLevel.Caption)
          .fontColor($r('app.color.text_quaternary'))
      }
      .width('100%')
      .margin({ top: Dimension.SpaceM })
    }
    .width('100%')
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: index === this.assessmentRecords.length - 1 ? 0 : Dimension.SpaceXXL })
    .onClick(() => {
      this.goResultDetail(item)
    })
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    resetRoute('LoginPage')
    return false
  }
}
