import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { LightTheme, Dimension } from '../../common/constants/Theme'
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

@Entry
@Component
struct MyRecordsPage {
  @State currentTab: string = 'assessment'
  @State assessmentRecords: AssessmentRecordItem[] = []
  @State isAssessmentLoading: boolean = false
  private authService: AuthService = AuthService.getInstance()


  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    this.loadAssessmentRecords()
    if (!this.ensureLogin) {
      return
    }
  }

  private safePush(url: string): void {
    try {
      router.pushUrl({ url: url })
    } catch (error) {
      Logger.error(TAG, `跳转失败: ${JSON.stringify(error)}`)
    }
  }

  private switchTab(tab: string): void {
    this.currentTab = tab
    if (tab === 'assessment') {
      this.loadAssessmentRecords()
    }
  }

  private unwrapAssessmentList(response: Object): AssessmentRecordItem[] {
    if (Array.isArray(response)) {
      return response as AssessmentRecordItem[]
    }

    const wrapped = response as Record<string, Object>
    if (wrapped['data'] && Array.isArray(wrapped['data'])) {
      return wrapped['data'] as AssessmentRecordItem[]
    }

    return []
  }

  private async loadAssessmentRecords(): Promise<void> {
    this.isAssessmentLoading = true

    try {
      const response = await this.apiService.getAssessmentResults()
      this.assessmentRecords = this.unwrapAssessmentList(response as Object)
    } catch (error) {
      Logger.error(TAG, `加载测评记录失败: ${JSON.stringify(error)}`)
      this.assessmentRecords = []
    } finally {
      this.isAssessmentLoading = false
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

  private getLevelBg(level: string): string {
    if (level.indexOf('良好') >= 0) {
      return '#EEF8F1'
    }
    if (level.indexOf('轻度') >= 0) {
      return '#FFF6E8'
    }
    if (level.indexOf('中度') >= 0) {
      return '#FFF1F3'
    }
    return '#F3F4F6'
  }

  private getLevelColor(level: string): string {
    if (level.indexOf('良好') >= 0) {
      return '#5E9C76'
    }
    if (level.indexOf('轻度') >= 0) {
      return '#D29A32'
    }
    if (level.indexOf('中度') >= 0) {
      return '#D46A7A'
    }
    return '#6B7280'
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
    .backgroundColor(LightTheme.Background)
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
        .fontColor(this.currentTab === tab ? LightTheme.Primary : '#8B95A7')

      Row()
        .width(24)
        .height(3)
        .borderRadius(2)
        .backgroundColor(this.currentTab === tab ? LightTheme.Primary : '#00000000')
        .margin({ top: 8 })
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
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
          this.buildLoadingCard()
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
        this.buildSimpleCard(
          '当前说明',
          '日记页已经能查看和新增内容。后面可以继续补真实列表聚合、搜索筛选和编辑删除。'
        )

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
  buildLoadingCard() {
    Column() {
      Text('正在加载测评记录...')
        .fontSize(14)
        .fontColor('#8B95A7')
    }
    .width('100%')
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  buildEmptyAssessmentCard() {
    Column() {
      Text('还没有测评记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')

      Text('去完成一次测评后，记录会自动出现在这里。')
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })

      Button('去做测评')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor(LightTheme.Primary)
        .borderRadius(23)
        .margin({ top: 18 })
        .onClick(() => {
          this.safePush('pages/assessment/AssessmentsPage')
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildDiaryGuideCard() {
    Column() {
      Text('日记记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')

      Text('记录情绪不是为了评判自己，而是为了更温柔地理解自己。')
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })

      Button('去写日记')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor(LightTheme.Primary)
        .borderRadius(23)
        .margin({ top: 18 })
        .onClick(() => {
          this.safePush('pages/diary/MoodDiaryPage')
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildAssessmentRecordCard(item: AssessmentRecordItem, index: number) {
    Column() {
      Row() {
        Text(item.assessmentTitle ? item.assessmentTitle : '心理测评')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')
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
          .fontColor('#4B5563')
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.formatDateTime(item.createTime ? String(item.createTime) : ''))
          .fontSize(12)
          .fontColor('#9CA3AF')
      }
      .width('100%')
      .margin({ bottom: 10 })

      Text(item.suggestion ? item.suggestion : '暂无建议')
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .margin({ bottom: index === this.assessmentRecords.length - 1 ? 0 : 14 })
  }

  @Builder
  buildSimpleCard(title: string, content: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 10 })

      Text(content)
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Start)
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}