import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { AppBottomNav } from '../../common/components/AppBottomNav'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { LoadingComponent, EmptyComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'

const TAG = 'AssessmentsPage'

interface AssessmentItem {
  id?: number | string
  title?: string
  name?: string
  description?: string
  desc?: string
  questionCount?: number
  totalQuestions?: number
  duration?: string
}

@Entry
@Component
struct AssessmentsPage {
  @State currentTab: string = 'assess'
  @State isLoading: boolean = true
  @State hasError: boolean = false
  @State errorMessage: string = '加载失败'
  @State assessmentList: AssessmentItem[] = []

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    this.loadAssessments()
    if (!this.ensureLogin()) {
      return
    }
  }

  private async loadAssessments(): Promise<void> {
    this.isLoading = true
    this.hasError = false
    this.errorMessage = '加载失败'

    try {
      const res = await this.apiService.getAssessmentList()

      if (res.code === 200 && res.data && Array.isArray(res.data)) {
        this.assessmentList = res.data as AssessmentItem[]
        this.hasError = false
      } else {
        this.assessmentList = []
        this.hasError = true
        this.errorMessage = res.message ? res.message : '测评列表数据格式错误'
      }
    } catch (error) {
      Logger.error(TAG, `加载测评列表失败: ${JSON.stringify(error)}`)
      this.assessmentList = []
      this.hasError = true
      this.errorMessage = '网络异常，请稍后重试'
    } finally {
      this.isLoading = false
    }
  }

  private getItemTitle(item: AssessmentItem): string {
    if (item.title && item.title.length > 0) {
      return item.title
    }
    if (item.name && item.name.length > 0) {
      return item.name
    }
    return '心理测评'
  }

  private getItemDesc(item: AssessmentItem): string {
    if (item.description && item.description.length > 0) {
      return item.description
    }
    if (item.desc && item.desc.length > 0) {
      return item.desc
    }
    return '通过几个问题，快速了解自己当前的心理状态。'
  }

  private getItemQuestionCount(item: AssessmentItem): string {
    if (item.questionCount !== undefined) {
      return `${item.questionCount} 题`
    }
    if (item.totalQuestions !== undefined) {
      return `${item.totalQuestions} 题`
    }
    return '若干题'
  }

  private getItemDuration(item: AssessmentItem): string {
    if (item.duration && item.duration.length > 0) {
      return item.duration
    }
    return '约 3~5 分钟'
  }

  private goToAssessmentDetail(item: AssessmentItem): void {
    Logger.info(TAG, `点击测评项: ${JSON.stringify(item)}`)

    if (item.id === undefined || item.id === null || `${item.id}`.length === 0) {
      AlertDialog.show({
        title: '提示',
        message: '当前测评详情暂不可用',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
      return
    }

    router.pushUrl({
      url: 'pages/assessment/AssessmentDetailPage',
      params: {
        id: Number(item.id),
        title: this.getItemTitle(item),
        description: this.getItemDesc(item),
        questionCount: item.questionCount !== undefined
          ? item.questionCount
          : (item.totalQuestions !== undefined ? item.totalQuestions : 0),
        duration: this.getItemDuration(item)
      }
    })
  }

  build() {
    Column() {
      AppPageHeader({
        title: '心理测评'
      })

      if (this.isLoading) {
        LoadingComponent({
          message: '正在加载测评内容...',
          loadingSize: 36
        })
          .layoutWeight(1)
      } else if (this.hasError) {
        this.buildErrorView()
      } else {
        Scroll() {
          Column() {
            this.buildTopIntroCard()

            if (this.assessmentList.length === 0) {
              EmptyComponent({
                icon: '📝',
                message: '暂时还没有可用测评'
              })
                .height(320)
            } else {
              this.buildAssessmentList()
            }
          }
          .width('100%')
          .padding({
            left: Dimension.SpaceL,
            right: Dimension.SpaceL,
            top: Dimension.SpaceS,
            bottom: Dimension.SpaceXXL
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }

      AppBottomNav({
        currentTab: this.currentTab
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightTheme.Background)
  }

  @Builder
  buildErrorView() {
    Column() {
      Text('❌')
        .fontSize(64)
        .margin({ bottom: 16 })

      Text(this.errorMessage)
        .fontSize(16)
        .fontColor('#6B7280')
        .margin({ bottom: 16 })

      Button('重试')
        .height(40)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#4A9EFF')
        .borderRadius(20)
        .onClick(() => {
          this.loadAssessments()
        })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF8F0')
  }

  @Builder
  buildTopIntroCard() {
    Column() {
      Text('🫧')
        .fontSize(32)
        .margin({ bottom: 10 })

      Text('用几分钟，更了解现在的自己')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')

      Text('测评不是贴标签，而是帮助你看见自己此刻的状态。')
        .fontSize(14)
        .fontColor(LightTheme.TextSecondary)
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildAssessmentList() {
    Column() {
      ForEach(this.assessmentList, (item: AssessmentItem, index: number) => {
        this.buildAssessmentCard(item, index)
      })
    }
    .width('100%')
  }

  @Builder
  buildAssessmentCard(item: AssessmentItem, index: number) {
    Column() {
      Row() {

        Blank()

        Text(this.getItemQuestionCount(item))
          .fontSize(12)
          .fontColor(LightTheme.Primary)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(LightTheme.TagBlue)
          .borderRadius(10)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(this.getItemTitle(item))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')

      Text(this.getItemDesc(item))
        .fontSize(13)
        .fontColor(LightTheme.TextSecondary)
        .lineHeight(20)
        .width('100%')
        .margin({ top: 8, bottom: 14 })

      Row() {
        Text(this.getItemDuration(item))
          .fontSize(12)
          .fontColor(LightTheme.TextTertiary)

        Blank()

        Button('开始测评')
          .height(34)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor(LightTheme.Primary)
          .borderRadius(18)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.goToAssessmentDetail(item)
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: index === this.assessmentList.length - 1 ? 0 : 12 })
  }
  private authService: AuthService = AuthService.getInstance()

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}