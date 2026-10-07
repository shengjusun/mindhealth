import { ApiService } from '../../core/api/ApiService'
import { brand, Dimension, FontLevel, ShadowStyle } from '../../common/constants/Theme'
import { AppChip } from '../../common/components/AppChip'
import { softLevel, softLevelKind } from '../../common/utils/AssessmentTone'
import { AppButton } from '../../common/components/AppButton'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { appState, AppState } from '../../common/state/AppState'
import { Logger } from '../../common/utils/Logger'

const TAG = 'AssessmentResultPage'

const AI_POLL_INTERVAL_MS: number = 2000
const AI_POLL_MAX_TIMES: number = 15

// GET /assessment/result/{id} 的实体行。渲染只读，字段全部兜底
interface AssessmentResultDetail {
  id?: number
  assessmentTitle?: string
  score?: number
  maxScore?: number
  level?: string
  suggestion?: string
  aiStatus?: string
  aiAnalysis?: string
  aiError?: string
  createTime?: string
}

// aiAnalysis（后端 normalize 产出的 JSON 字符串）里本页渲染的字段
interface AiSuggestionItem {
  title?: string
  detail?: string
}

/**
 * 测评结果回放页：从「我的记录」的状态足迹卡片进入，按记录 id 回看单次测评。
 *
 * 数据一律现拉（GET /assessment/result/{id}）：本地快照为省容量做了字段投影，
 * 不含 AI 解读全文，所以本页不做离线降级，断网时明确给失败态。
 * aiStatus 为 failed / pending 停滞时提供「重新生成解读」出口——异步链路的失败
 * 必须可见、可重试（模块 4 的死状态 bug 教训）。
 */
@ComponentV2
export struct AssessmentResultPage {
  // 由路由壳在 onReady 拿到 param 后创建本页时回灌（与 DiaryEditPage 同款中间壳）
  @Param routeParam: Record<string, Object> | undefined = undefined

  @Local state: AppState = appState()

  @Local isLoading: boolean = true
  @Local hasError: boolean = false
  @Local errorMessage: string = '加载失败'

  @Local resultId: number = 0
  @Local assessmentTitle: string = '心理测评'
  @Local score: number = 0
  @Local maxScore: number = 100
  @Local level: string = ''
  @Local suggestion: string = ''
  @Local createTime: string = ''

  @Local aiStatus: string = ''
  @Local aiError: string = ''
  @Local aiSummary: string = ''
  @Local aiTrend: string = ''
  @Local aiSuggestions: AiSuggestionItem[] = []
  @Local isRetrying: boolean = false

  private apiService: ApiService = ApiService.getInstance()
  private pollTimerId: number = -1
  private pollCount: number = 0

  aboutToAppear(): void {
    const params: Record<string, Object> = this.routeParam ?? {}
    const idValue: Object | undefined = params['resultId']
    const id: number = Number(idValue ?? 0)
    if (id > 0) {
      this.resultId = id
      this.loadResult(true)
    } else {
      this.isLoading = false
      this.hasError = true
      this.errorMessage = '测评记录不存在'
    }
  }

  aboutToDisappear(): void {
    // 离开页面必须清轮询定时器，否则定时器会在后台继续打接口
    this.clearPollTimer()
  }

  private clearPollTimer(): void {
    if (this.pollTimerId !== -1) {
      clearTimeout(this.pollTimerId)
      this.pollTimerId = -1
    }
  }

  private async loadResult(showLoading: boolean): Promise<void> {
    if (showLoading) {
      this.isLoading = true
    }
    this.hasError = false

    try {
      const res = await this.apiService.getAssessmentResult(this.resultId)
      if (res.code !== 200 || !res.data) {
        // 后端业务失败走 HTTP 200 + 业务码，这个分支是常态而非异常，
        // 不能静默吞掉——否则页面停在空数据且没有重试入口
        this.isLoading = false
        this.hasError = true
        this.errorMessage = res.message && res.message.length > 0 ? res.message : '加载失败'
        return
      }

      this.applyResult(res.data as AssessmentResultDetail)
      this.isLoading = false
    } catch (error) {
      Logger.error(TAG, `加载测评详情失败: ${JSON.stringify(error)}`)
      this.isLoading = false
      this.hasError = true
      this.errorMessage = '网络不太顺畅，稍后再试试'
    }
  }

  private applyResult(data: AssessmentResultDetail): void {
    this.assessmentTitle = data.assessmentTitle && data.assessmentTitle.length > 0
      ? data.assessmentTitle : '心理测评'
    this.score = data.score ?? 0
    this.maxScore = data.maxScore ?? 100
    this.level = data.level ?? ''
    this.suggestion = data.suggestion ?? ''
    this.createTime = data.createTime ?? ''

    const status: string = data.aiStatus ?? ''
    this.aiStatus = status
    this.aiError = data.aiError ?? ''
    this.applyAiAnalysis(data.aiAnalysis)

    // 规则基线结果已经有了，AI 仍在生成中 → 进入轮询
    if (status === 'pending') {
      this.startAiPolling()
    } else {
      this.clearPollTimer()
    }
  }

  /** aiAnalysis 只保留约定字段（summary/trend/suggestions），解析失败静默降级为无解读 */
  private applyAiAnalysis(raw: string | undefined): void {
    this.aiSummary = ''
    this.aiTrend = ''
    this.aiSuggestions = []
    if (!raw || raw.length === 0) {
      return
    }
    try {
      const parsed = JSON.parse(raw) as Record<string, Object>
      const summary: Object | undefined = parsed['summary']
      if (typeof summary === 'string') {
        this.aiSummary = summary
      }
      const trend: Object | undefined = parsed['trend']
      if (typeof trend === 'string') {
        this.aiTrend = trend
      }
      const items: Object | undefined = parsed['suggestions']
      if (Array.isArray(items)) {
        const list: AiSuggestionItem[] = []
        for (const item of items as Object[]) {
          const rec = item as Record<string, Object>
          const title: Object | undefined = rec['title']
          const detail: Object | undefined = rec['detail']
          if (typeof title === 'string' && title.length > 0) {
            list.push({ title: title, detail: typeof detail === 'string' ? detail : '' })
          }
        }
        this.aiSuggestions = list
      }
    } catch (error) {
      Logger.warn(TAG, `解析 AI 解读失败: ${JSON.stringify(error)}`)
    }
  }

  /** 每 2 秒查一次，最多 15 次；窗口耗尽仍未产出则置 failed 给出口，不无限等待 */
  private startAiPolling(): void {
    this.clearPollTimer()
    this.pollCount = 0
    this.pollOnce()
  }

  private pollOnce(): void {
    this.pollCount++
    if (this.pollCount > AI_POLL_MAX_TIMES) {
      this.aiStatus = 'failed'
      this.aiError = '解读生成超时，可点击重试'
      return
    }
    this.pollTimerId = setTimeout(() => {
      this.silentRefreshAi()
    }, AI_POLL_INTERVAL_MS)
  }

  private async silentRefreshAi(): Promise<void> {
    try {
      const res = await this.apiService.getAssessmentResult(this.resultId)
      if (res.code !== 200 || !res.data) {
        // 与答题页轮询同口径：非 200 不静默 continue，置 failed 保留重试出口
        this.aiStatus = 'failed'
        this.aiError = res.message && res.message.length > 0 ? res.message : '查询解读结果失败，可点击重试'
        return
      }
      this.applyResult(res.data as AssessmentResultDetail)
      if (this.aiStatus === 'pending') {
        this.pollOnce()
      }
    } catch (error) {
      // 轮询中的瞬时网络异常不清链路：只当作本次未命中，继续下一轮
      Logger.warn(TAG, `轮询 AI 解读失败: ${JSON.stringify(error)}`)
      this.pollOnce()
    }
  }

  private async retryAi(): Promise<void> {
    if (this.isRetrying || this.resultId <= 0) {
      return
    }
    this.isRetrying = true
    this.aiStatus = 'pending'
    this.aiError = ''
    try {
      await this.apiService.retriggerAssessmentAi(this.resultId)
    } catch (error) {
      // 触发接口失败不终止流程：仍进轮询，若后端确实没重排任务，15 次后会回到 failed
      Logger.warn(TAG, `触发重新生成失败: ${JSON.stringify(error)}`)
    }
    this.startAiPolling()
    this.isRetrying = false
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

  private aiChipLabel(): string {
    if (this.aiStatus === 'success') {
      return '已生成'
    }
    if (this.aiStatus === 'pending') {
      return '生成中'
    }
    return '未生成'
  }

  private aiChipKind(): string {
    if (this.aiStatus === 'success') {
      return 'success'
    }
    if (this.aiStatus === 'pending') {
      return 'warning'
    }
    return 'danger'
  }

  build() {
    Column() {
      AppPageHeader({
        title: '测评详情',
        subtitle: '回看一次状态自查',
        showBack: true
      })

      Scroll() {
        Column() {
          if (this.isLoading) {
            Column() {
              LoadingProgress()
                .width(32)
                .height(32)
                .color(brand().primary)

              Text('正在调取这次记录...')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 12 })
            }
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.app_card'))
            .borderRadius(Dimension.CardRadius)
            .shadow(ShadowStyle.Card)
            .alignItems(HorizontalAlign.Center)
          } else if (this.hasError) {
            Column() {
              Text(this.errorMessage)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .margin({ bottom: 16 })

              AppButton({
                label: '重试',
                kind: 'secondary',
                onPress: () => {
                  this.loadResult(true)
                }
              })
            }
            .width('100%')
            .padding(24)
            .backgroundColor($r('app.color.app_card'))
            .borderRadius(Dimension.CardRadius)
            .shadow(ShadowStyle.Card)
            .alignItems(HorizontalAlign.Center)
          } else {
            this.buildScoreCard()
            this.buildSuggestionCard()
            this.buildAiCard()
          }

          Blank()
            .height(24)
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 2,
          bottom: Dimension.pillSafeArea(this.state.bottomIndicatorVp)
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildScoreCard() {
    Column() {
      Text(this.assessmentTitle)
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(this.formatDateTime(this.createTime))
        .fontSize(FontLevel.Caption)
        .fontColor($r('app.color.text_quaternary'))
        .width('100%')
        .margin({ top: 4 })

      Row() {
        Text(`${this.score}`)
          .fontSize(44)
          .fontWeight(FontWeight.Bold)
          .fontColor(brand().primary)

        Column() {
          Text(` / ${this.maxScore}`)
            .fontSize(FontLevel.Body)
            .fontColor($r('app.color.text_tertiary'))

          Text('状态分，越高越健康')
            .fontSize(FontLevel.Caption)
            .fontColor($r('app.color.text_quaternary'))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: Dimension.SpaceM })

      if (this.level.length > 0) {
        AppChip({
          label: softLevel(this.level),
          kind: softLevelKind(this.level)
        })
          .margin({ top: Dimension.SpaceM })
      }
    }
    .width('100%')
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: Dimension.SpaceM })
  }

  @Builder
  buildSuggestionCard() {
    Column() {
      Text('状态小结')
        .fontSize(FontLevel.SubTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(this.suggestion.length > 0 ? this.suggestion : '本次测评没有留下建议文案')
        .fontSize(FontLevel.Body)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
        .width('100%')
        .margin({ top: Dimension.SpaceS })
    }
    .width('100%')
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: Dimension.SpaceM })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildAiCard() {
    Column() {
      Row() {
        Text('AI 深度解读')
          .fontSize(FontLevel.SubTitle)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        if (this.aiStatus.length > 0) {
          AppChip({
            label: this.aiChipLabel(),
            kind: this.aiChipKind()
          })
        }
      }
      .width('100%')

      if (this.aiStatus === 'success') {
        Text(this.aiSummary.length > 0 ? this.aiSummary : '本次解读内容为空')
          .fontSize(FontLevel.Body)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
          .width('100%')
          .margin({ top: Dimension.SpaceS })

        if (this.aiTrend.length > 0) {
          Text(`趋势：${this.aiTrend}`)
            .fontSize(FontLevel.Aux)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .margin({ top: Dimension.Space2XS })
        }

        ForEach(this.aiSuggestions, (item: AiSuggestionItem, index: number) => {
          Column() {
            Text(item.title ?? '')
              .fontSize(FontLevel.Body)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))

            if (item.detail && item.detail.length > 0) {
              Text(item.detail)
                .fontSize(FontLevel.Aux)
                .fontColor($r('app.color.text_secondary'))
                .lineHeight(FontLevel.bodyLineHeight(FontLevel.Aux))
                .margin({ top: 4 })
            }
          }
          .width('100%')
          .padding(Dimension.CardPaddingInner)
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(Dimension.RadiusM)
          .margin({ top: index === 0 ? Dimension.SpaceS : Dimension.Space2XS })
          .alignItems(HorizontalAlign.Start)
        })
      } else if (this.aiStatus === 'pending') {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(brand().primary)

          Text('正在生成解读…')
            .fontSize(FontLevel.Body)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: Dimension.SpaceS })
      } else {
        // failed / 停滞的 pending / 空：一律给重试出口，不让用户停在死状态
        Text(this.aiError.length > 0 ? this.aiError : '解读还没有生成')
          .fontSize(FontLevel.Body)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ top: Dimension.SpaceS })

        AppButton({
          label: '重新生成解读',
          kind: 'secondary',
          block: true,
          loading: this.isRetrying,
          outerMargin: { top: Dimension.SpaceS },
          onPress: () => {
            this.retryAi()
          }
        })
      }
    }
    .width('100%')
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .alignItems(HorizontalAlign.Start)
  }
}
