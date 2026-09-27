import { pushRouteWithParam, resetRoute } from '../../common/state/AppState'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { brand, Dimension, FontLevel, ShadowStyle } from '../../common/constants/Theme'
import { AppChip } from '../../common/components/AppChip'
import { appState } from '../../common/state/AppState'
import { LoadingComponent, EmptyComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { AuthService } from '../../core/auth/AppAuthService'
import { ScaleRepository } from '../../core/repository/ScaleRepository'
import { ScaleMeta } from '../../common/types/ScaleTypes'
import { AppButton } from '../../common/components/AppButton'

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

// 传给自查答题页的路由入参
// ArkTS 不允许直接传未声明类型的对象字面量（arkts-no-untyped-obj-literals），所以显式声明
interface AssessmentQuestionRouteParam {
  id: number
  assessmentId: number
  title: string
  questionCount: number
  duration: string
}

// 状态自查视图：作为 MainPage 的 Tab 子组件使用（无底部导航）
@ComponentV2
export struct AssessmentsView {
  @Local isLoading: boolean = true
  @Local assessmentList: AssessmentItem[] = []

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

    try {
      const local: ScaleMeta[] = await this.scaleRepo.getScaleList()
      this.assessmentList = this.toAssessmentItems(local)
      Logger.info(TAG, `自查列表本地加载完成，共 ${this.assessmentList.length} 项`)
    } catch (error) {
      Logger.error(TAG, `加载自查列表失败: ${JSON.stringify(error)}`)
    } finally {
      // 本地到位就清 loading（异常也要清，否则页面永远停在加载中，连空态都出不来）。
      // 关键：静默刷新绝不能挡在这个 finally 之前 —— 后端不可用时它会挂满整个网络超时，
      // 本地 1 毫秒就拿到的数据，用户要盯着转圈几十秒。
      this.isLoading = false
    }

    // 后台静默刷新：不 await，数据回来再覆盖列表；失败保留已渲染的本地数据
    this.refreshInBackground()
  }

  /** 后台静默刷新列表，成功后覆盖已渲染的本地数据 */
  private async refreshInBackground(): Promise<void> {
    try {
      const fresh: ScaleMeta[] = await this.scaleRepo.refreshScaleList()
      if (fresh.length > 0) {
        this.assessmentList = this.toAssessmentItems(fresh)
        Logger.info(TAG, `自查列表静默刷新完成，共 ${this.assessmentList.length} 项`)
      }
    } catch (error) {
      Logger.warn(TAG, `自查列表静默刷新失败（保留本地数据）: ${JSON.stringify(error)}`)
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

    const questionParam: AssessmentQuestionRouteParam = {
      id: Number(item.id),
      assessmentId: Number(item.id),
      title: this.getItemTitle(item),
      questionCount: item.questionCount !== undefined
        ? item.questionCount
        : (item.totalQuestions !== undefined ? item.totalQuestions : 0),
      duration: this.getItemDuration(item)
    }
    pushRouteWithParam('AssessmentQuestionPage', questionParam)
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
            // 底部留出悬浮胶囊栏的高度
            bottom: Dimension.pillSafeArea(appState().bottomIndicatorVp)
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildTopIntroCard() {
    Column() {
      // HTML 设计稿：说明卡无装饰元素（原 🫧 装饰 emoji 已删）
      Text('用几分钟，更了解现在的自己')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('自查不是给你贴标签，而是帮你看清此刻的状态。')
        .fontSize(FontLevel.Body)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
        .width('100%')
        .margin({ top: Dimension.SpaceS })
    }
    .width('100%')
    .padding(Dimension.CardPaddingHero)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.HeroCardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: Dimension.SpaceXXL })
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
    // HTML quiz-card：min-height 176 等高，chip 右上
    Column() {
      Row() {
        Blank()

        AppChip({
          label: this.getItemQuestionCount(item),
          kind: 'primary'
        })
      }
      .width('100%')
      .margin({ bottom: Dimension.SpaceM })

      Text(this.getItemTitle(item))
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(this.getItemDesc(item))
        .fontSize(FontLevel.Body)
        .fontColor($r('app.color.text_tertiary'))
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ minHeight: 44 })
        .width('100%')
        .margin({ top: Dimension.SpaceS, bottom: Dimension.SpaceL })

      Row() {
        Text(this.getItemDuration(item))
          .fontSize(FontLevel.Caption)
          .fontColor($r('app.color.text_quaternary'))

        Blank()

        // 产品温度：邀请式文案（用户拍板的候选）
        AppButton({
          label: '开始了解自己',
          kind: 'primary',
          onPress: () => {
            this.startAssessment(item)
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .constraintSize({ minHeight: 176 })
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: index === this.assessmentList.length - 1 ? 0 : Dimension.SpaceXXL })
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    resetRoute('LoginPage')
    return false
  }
}

