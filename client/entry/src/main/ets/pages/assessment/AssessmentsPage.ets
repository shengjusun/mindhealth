import router from '@ohos.router'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension } from '../../common/constants/Theme'
import { LoadingComponent, EmptyComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { AuthService } from '../../core/auth/AppAuthService'
import { ScaleRepository } from '../../core/repository/ScaleRepository'
import { ScaleMeta } from '../../common/types/ScaleTypes'

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

// 状态自查视图：作为 MainPage 的 Tab 子组件使用（无底部导航）
@Component
export struct AssessmentsView {
  @State isLoading: boolean = true
  @State assessmentList: AssessmentItem[] = []

  private scaleRepo: ScaleRepository = ScaleRepository.getInstance()
  private authService: AuthService = AuthService.getInstance()

  aboutToAppear(): void {
    // 先校验登录态，未登录直接跳转登录页
    // 已登录后再加载状态自查列表，避免未登录时发起无效请求
    if (!this.ensureLogin()) {
      return
    }

    this.loadAssessments()
  }

  /**
   * 离线优先（SWR）：
   * 1. 先取本地列表（内存 → 缓存 → 内置 manifest）并立刻渲染，不等网络；
   * 2. 再后台静默刷新，成功才覆盖；失败一律吞掉，保留已渲染的本地列表。
   */
  private async loadAssessments(): Promise<void> {
    this.isLoading = true

    const local: ScaleMeta[] = await this.scaleRepo.getScaleList()
    this.assessmentList = this.toAssessmentItems(local)
    this.isLoading = false

    const fresh: ScaleMeta[] = await this.scaleRepo.refreshScaleList()
    if (fresh.length > 0) {
      this.assessmentList = this.toAssessmentItems(fresh)
    }
  }

  /**
   * 量表元数据转换成列表项，字段兼容 AssessmentsView 的展示逻辑
   */
  private toAssessmentItems(metas: ScaleMeta[]): AssessmentItem[] {
    const items: AssessmentItem[] = []
    for (const meta of metas) {
      items.push({
        id: meta.id,
        name: meta.name,
        description: meta.description,
        questionCount: meta.questionCount
      })
    }
    return items
  }

  private getItemTitle(item: AssessmentItem): string {
    if (item.title && item.title.length > 0) {
      return item.title
    }
    if (item.name && item.name.length > 0) {
      return item.name
    }
    return '状态自查'
  }

  private getItemDesc(item: AssessmentItem): string {
    if (item.description && item.description.length > 0) {
      return item.description
    }
    if (item.desc && item.desc.length > 0) {
      return item.desc
    }
    return '通过几个问题，快速了解自己当前的状态。'
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

  // 点击状态自查卡片后，直接进入答题页
  // 原来中间有 AssessmentDetailPage，现在去掉冗余详情页，链路更短：
  // AssessmentsPage → AssessmentQuestionPage
  private startAssessment(item: AssessmentItem): void {
    Logger.info(TAG, `点击自查项: ${JSON.stringify(item)}`)

    if (item.id === undefined || item.id === null || `${item.id}`.length === 0) {
      ToastUtil.show('当前自查项目暂不可用')
      return
    }

    router.pushUrl({
      url: 'pages/assessment/AssessmentQuestionPage',
      params: {
        id: Number(item.id),
        assessmentId: Number(item.id),
        title: this.getItemTitle(item),
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
        title: '状态自查'
      })

      if (this.isLoading) {
        LoadingComponent({
          message: '正在加载自查内容...',
          loadingSize: 36
        })
          .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            this.buildTopIntroCard()

            if (this.assessmentList.length === 0) {
              EmptyComponent({
                symbol: $r('sys.symbol.checkmark_clipboard'),
                icon: '📝',
                message: '暂时还没有可用自查'
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
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
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('自查不是贴标签，而是帮助你看见自己此刻的状态。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
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
          .fontColor($r('app.color.theme_primary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.tag_blue'))
          .borderRadius(10)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(this.getItemTitle(item))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(this.getItemDesc(item))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
        .width('100%')
        .margin({ top: 8, bottom: 14 })

      Row() {
        Text(this.getItemDuration(item))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))

        Blank()

        Button('开始自查')
          .height(34)
          .fontSize(14)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.theme_primary'))
          .borderRadius(18)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.startAssessment(item)
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: index === this.assessmentList.length - 1 ? 0 : 12 })
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}

// 兼容旧路由的独立入口（推荐入口为 pages/MainPage 的 Tab 容器）
@Entry
@Component
struct AssessmentsPage {
  build() {
    Column() {
      AssessmentsView()
    }
    .width('100%')
    .height('100%')
  }
}