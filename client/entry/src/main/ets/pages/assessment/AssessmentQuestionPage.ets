import { appState, AppState, popRoute, resetRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { brand, Dimension, ShadowStyle, Motion } from '../../common/constants/Theme'
import { SubPageHeader } from '../../common/components/SubPageHeader'
import { LoadingComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { AuthService } from '../../core/auth/AppAuthService'
import { ScaleRepository } from '../../core/repository/ScaleRepository'
import { ScaleDetail, ScaleOption, ScaleQuestion } from '../../common/types/ScaleTypes'
import { AppButton } from '../../common/components/AppButton'
import { softLevel } from '../../common/utils/AssessmentTone'

const TAG = 'AssessmentQuestionPage'

// 题目结构统一复用 common/types/ScaleTypes，页面里不再维护第二份容易漂移的副本
type QuestionOption = ScaleOption
type AssessmentQuestion = ScaleQuestion

// 单题作答。服务端据此重算分数并生成逐题分析，
// 所以必须上报「选了哪个选项」，不能只传一个总分。
interface AssessmentAnswer {
  questionId: number
  optionKey: string
}

interface AssessmentSubmitResult {
  id?: number
  userId?: number
  assessmentId?: number
  assessmentTitle?: string
  score?: number
  maxScore?: number
  level?: string
  suggestion?: string
  /** AI 解读状态：none / pending / success / failed */
  aiStatus?: string
  /** AI 解读结果（结构化 JSON 字符串） */
  aiAnalysis?: string
  aiError?: string
  createTime?: string
}

interface AssessmentSubmitRequest {
  assessmentId: number
  /** 保留总分仅为兼容；服务端以 answers 为准 */
  score: number
  answers: AssessmentAnswer[]
}

interface AssessmentAiDimension {
  name?: string
  level?: string
  comment?: string
}

interface AssessmentAiSuggestion {
  title?: string
  detail?: string
}

// 与服务端 AssessmentAiService 约定的输出结构
interface AssessmentAiAnalysis {
  summary?: string
  trend?: string
  riskLevel?: string
  needProfessionalHelp?: boolean
  dimensions?: AssessmentAiDimension[]
  suggestions?: AssessmentAiSuggestion[]
}

@ComponentV2
export struct AssessmentQuestionPage {
  // 路由入参，由 RouteBuilders 的 AssessmentQuestionRoute 注入（取代 router.getParams()）
  // V2 中普通属性禁止从外部初始化，必须由父组件传入 —— 用 @Param（只读，组件内不修改）
  @Param routeParam: Record<string, Object> | undefined = undefined

  /**
   * @Monitor('state.backPressedTick') 的取值目标。
   * 存在的意义不是读它的值，而是让 @Monitor 的路径能解析到 AppState 实例。
   * 此前缺这个字段，返回拦截的确认弹窗从未触发过；而路由层已经递增 tick 并 return true
   * 把返回吞掉，表现出来就是「按返回没反应」。
   */
  @Local state: AppState = appState()

  @Local assessmentId: number = 0
  @Local assessmentTitle: string = '心理测评'
  @Local currentIndex: number = 0
  @Local selectedAnswers: number[] = []
  @Local questions: AssessmentQuestion[] = []
  @Local isLoadingQuestions: boolean = true
  @Local loadError: string = ''
  @Local diagInfo: string = ''
  @Local scaleMaxScore: number = 0
  @Local showResult: boolean = false
  @Local resultData: AssessmentSubmitResult | null = null
  @Local isSubmitting: boolean = false

  // ===== AI 深度解读 =====
  // 提交后服务端异步生成，这里轮询等到结果。失败不阻塞测评展示，只是少一块内容。
  @Local resultId: number = 0
  @Local aiStatus: string = 'none'
  @Local aiAnalysis: AssessmentAiAnalysis | null = null
  @Local aiError: string = ''
  private aiPollCount: number = 0
  /** 轮询定时器句柄。必须留存，否则页面销毁后无法清除，回调仍会打到已销毁的组件上 */
  private aiPollTimerId: number = -1
  private static readonly AI_POLL_INTERVAL_MS: number = 2000
  private static readonly AI_POLL_MAX_TIMES: number = 15

  private apiService: ApiService = ApiService.getInstance()
  private scaleRepo: ScaleRepository = ScaleRepository.getInstance()

  aboutToAppear(): void {
    const params: Record<string, Object> = this.routeParam ?? {} as Record<string, Object>
    const idValue = params['id']
    const titleValue = params['title']

    if (typeof idValue === 'string') {
      this.assessmentId = Number(idValue)
    } else if (typeof idValue === 'number') {
      this.assessmentId = idValue
    }

    if (typeof titleValue === 'string' && titleValue.length > 0) {
      this.assessmentTitle = titleValue
    }
    if (!this.ensureLogin()) {
      return
    }

    // 题目从后端量表详情拉取，失败时回退内置通用题库
    this.loadQuestions()
  }

  /**
   * 加载量表题目：本地优先（内存 → Preferences 缓存 → rawfile 内置题库），
   * 本地都没有时才走网络，断网时依然能用内置题库答题。
   */
  private async loadQuestions(): Promise<void> {
    this.isLoadingQuestions = true
    this.loadError = ''
    this.diagInfo = ''

    if (this.assessmentId <= 0) {
      this.loadError = '测评ID无效，无法加载题目'
      this.diagInfo = `id=${this.assessmentId}`
      this.isLoadingQuestions = false
      return
    }

    try {
      const detail: ScaleDetail | null = await this.scaleRepo.getScale(this.assessmentId)
      if (!detail) {
        this.loadError = '暂无可用题目，请检查网络后重试'
        this.diagInfo = await this.scaleRepo.getDiagnostics(this.assessmentId)
        this.applyQuestions([])
        return
      }

      // 题库自带名称优先，避免路由参数与题库不一致
      if (typeof detail.name === 'string' && detail.name.length > 0) {
        this.assessmentTitle = detail.name
      }
      if (typeof detail.maxScore === 'number' && detail.maxScore > 0) {
        this.scaleMaxScore = detail.maxScore
      }

      const valid: AssessmentQuestion[] = this.sanitizeQuestions(detail.questions)
      if (valid.length > 0) {
        this.applyQuestions(valid)
        return
      }

      this.loadError = '题库内容异常，请更新应用后重试'
      this.diagInfo = await this.scaleRepo.getDiagnostics(this.assessmentId)
      this.applyQuestions([])
    } catch (error) {
      Logger.warn(TAG, `加载量表 ${this.assessmentId} 失败: ${JSON.stringify(error)}`)
      this.loadError = '题目加载失败，请检查网络后重试'
      this.diagInfo = await this.scaleRepo.getDiagnostics(this.assessmentId)
      this.applyQuestions([])
    } finally {
      this.isLoadingQuestions = false
    }
  }

  /**
   * 结构校验：至少 1 题、每题至少 2 个选项，过滤掉脏数据
   */
  private sanitizeQuestions(raw: ScaleQuestion[]): AssessmentQuestion[] {
    if (!Array.isArray(raw) || raw.length === 0) {
      return []
    }
    const valid: AssessmentQuestion[] = []
    for (let i = 0; i < raw.length; i++) {
      const q = raw[i]
      if (q && typeof q.title === 'string' && Array.isArray(q.options) && q.options.length >= 2) {
        valid.push({
          id: typeof q.id === 'number' ? q.id : i + 1,
          title: q.title,
          options: q.options.filter((o: QuestionOption) =>
            typeof o.text === 'string' && typeof o.score === 'number')
        })
      }
    }
    return valid
  }

  private applyQuestions(list: AssessmentQuestion[]): void {
    this.questions = list
    this.currentIndex = 0
    this.selectedAnswers = []
    let i: number = 0
    while (i < list.length) {
      this.selectedAnswers.push(-1)
      i++
    }
  }

  private getProgressText(): string {
    return `${this.currentIndex + 1} / ${this.questions.length}`
  }

  private getCurrentQuestion(): AssessmentQuestion {
    return this.questions[this.currentIndex]
  }

  private selectOption(optionIndex: number): void {
    this.selectedAnswers[this.currentIndex] = optionIndex
    this.selectedAnswers = [...this.selectedAnswers]
    // 已答任意一题且未出结果：视为有未提交内容（驱动路由层返回拦截，审计 C-5-1）
    appState().hasUnsavedChanges = !this.showResult && this.hasAnswerProgress()
  }

  private hasAnswerProgress(): boolean {
    return this.selectedAnswers.some((v: number): boolean => v >= 0)
  }

  aboutToDisappear(): void {
    appState().hasUnsavedChanges = false
    this.clearAiPollTimer()
  }

  /**
   * 清掉尚未触发的轮询定时器。
   * 此前 setTimeout 的句柄没有留存，页面 pop 之后回调仍会执行：对着已销毁的组件写 @Local，
   * 而且 retryAi 会再起一条链，造成多条轮询并发打后台。
   */
  private clearAiPollTimer(): void {
    if (this.aiPollTimerId !== -1) {
      clearTimeout(this.aiPollTimerId)
      this.aiPollTimerId = -1
    }
  }

  @Monitor('state.backPressedTick')
  onBackIntercepted(): void {
    if (this.showResult || !this.hasAnswerProgress()) {
      return
    }
    AlertDialog.show({
      title: '放弃本次答题？',
      message: '返回后已答内容将不会保留',
      primaryButton: {
        value: '继续答题',
        action: () => {}
      },
      secondaryButton: {
        value: '放弃',
        action: () => {
          appState().hasUnsavedChanges = false
          popRoute()
        }
      }
    })
  }

  private goPrev(): void {
    if (this.currentIndex > 0) {
      this.currentIndex--
    }
  }

  private goNext(): void {
    if (this.selectedAnswers[this.currentIndex] < 0) {
      ToastUtil.show('请先选择一个选项')
      return
    }

    if (this.currentIndex < this.questions.length - 1) {
      this.currentIndex++
    } else {
      this.submitAssessment()
    }
  }

  private unwrapSubmitResult(response: Object): AssessmentSubmitResult | null {
    const wrapped = response as Record<string, Object>

    if (wrapped['data']) {
      return wrapped['data'] as AssessmentSubmitResult
    }

    const raw = response as AssessmentSubmitResult
    if (raw.assessmentId !== undefined || raw.assessmentTitle !== undefined || raw.level !== undefined) {
      return raw
    }

    return null
  }

  private async submitAssessment(): Promise<void> {
    let totalScore: number = 0
    const answers: AssessmentAnswer[] = []
    let i: number = 0

    while (i < this.questions.length) {
      const answerIndex = this.selectedAnswers[i]
      if (answerIndex >= 0) {
        const option: QuestionOption = this.questions[i].options[answerIndex]
        totalScore += option.score
        // 上报逐题作答：服务端据此重算分数并生成「逐题 + 维度」的 AI 解读。
        // 只传总分的话，服务端永远只能按固定阈值挑一句模板话。
        const answer: AssessmentAnswer = {
          questionId: this.questions[i].id,
          optionKey: option.key
        }
        answers.push(answer)
      }
      i++
    }

    if (this.assessmentId <= 0) {
      ToastUtil.show('测评ID无效，无法提交')
      return
    }

    this.isSubmitting = true

    try {
      const payload: AssessmentSubmitRequest = {
        assessmentId: this.assessmentId,
        score: totalScore,
        answers: answers
      }

      const response = await this.apiService.submitAssessment(payload)

      const result: AssessmentSubmitResult | null = this.unwrapSubmitResult(response as Object)

      if (result) {
        if (!result.assessmentTitle || result.assessmentTitle.length === 0) {
          result.assessmentTitle = this.assessmentTitle
        }
        if (result.score === undefined) {
          result.score = totalScore
        }
        this.resultData = result
        this.resultId = result.id ?? 0
        this.aiStatus = result.aiStatus ? result.aiStatus : 'none'
        this.aiError = result.aiError ? result.aiError : ''
        // 结果视图进场：缩放+淡入（emphasized 节奏），配合 buildResultView 的 .transition
        this.getUIContext().animateTo({ duration: Motion.Normal, curve: Motion.emphasized }, () => {
          this.showResult = true
        })
        // 规则基线结果已经拿到，AI 解读在服务端异步生成，这里开始轮询
        if (this.resultId > 0 && this.aiStatus === 'pending') {
          this.startAiPolling()
        }
        // 出结果后返回不再拦截
        appState().hasUnsavedChanges = false
      } else {
        ToastUtil.show('保存的时候出了点小差错，这次结果没存上')
      }
    } catch (error) {
      Logger.error(TAG, `提交测评失败: ${JSON.stringify(error)}`)
      ToastUtil.show('提交失败，请稍后重试')
    } finally {
      this.isSubmitting = false
    }
  }

  // ------------------------------------------------------------------ AI 深度解读

  /** 服务端异步生成，客户端每 2 秒查一次，最多查 15 次 */
  private startAiPolling(): void {
    // 先清掉可能残留的定时器：重复点「重新生成」时，避免起出多条并行的轮询链
    this.clearAiPollTimer()
    this.aiPollCount = 0
    this.fetchAiResult()
  }

  private async fetchAiResult(): Promise<void> {
    if (this.resultId <= 0) {
      return
    }
    try {
      const res = await this.apiService.getAssessmentResult(this.resultId)
      if (res.code !== 200) {
        // 不能静默 return：轮询链会就此断掉，aiStatus 一直停在 pending，
        // 界面永远显示「正在生成…」，而重试入口只在 failed 状态出现 —— 用户没有出口。
        // 后端所有业务错误都按「HTTP 200 + 业务码」返回，所以这个分支是常态而非异常。
        this.aiStatus = 'failed'
        this.aiError = res.message ? res.message : '查询解读结果失败，可点击重试'
        return
      }

      const data: AssessmentSubmitResult = res.data as AssessmentSubmitResult
      const status: string = data.aiStatus ? data.aiStatus : 'none'

      if (status === 'success') {
        const parsed: AssessmentAiAnalysis | null = this.parseAiAnalysis(data.aiAnalysis)
        if (parsed) {
          this.aiStatus = 'success'
          this.aiAnalysis = parsed
        } else {
          this.aiStatus = 'failed'
          this.aiError = 'AI 解读内容异常，可点击重试'
        }
        return
      }

      if (status === 'failed') {
        this.aiStatus = 'failed'
        this.aiError = data.aiError ? data.aiError : 'AI 解读生成失败，可点击重试'
        return
      }

      this.scheduleNextAiPoll()
    } catch (error) {
      Logger.warn(TAG, `查询 AI 解读失败: ${JSON.stringify(error)}`)
      this.scheduleNextAiPoll()
    }
  }

  private scheduleNextAiPoll(): void {
    if (this.aiPollCount >= AssessmentQuestionPage.AI_POLL_MAX_TIMES) {
      // 轮询到上限：不报错打断用户，只说"还在生成"，用户下次进来能看到
      this.aiStatus = 'failed'
      this.aiError = 'AI 解读还在生成中，稍后重新进入即可查看'
      return
    }
    this.aiPollCount++
    this.aiPollTimerId = setTimeout(() => {
      this.fetchAiResult()
    }, AssessmentQuestionPage.AI_POLL_INTERVAL_MS)
  }

  private parseAiAnalysis(raw: string | undefined): AssessmentAiAnalysis | null {
    if (!raw || raw.length === 0) {
      return null
    }
    try {
      return JSON.parse(raw) as AssessmentAiAnalysis
    } catch (error) {
      Logger.warn(TAG, `解析 AI 解读失败: ${JSON.stringify(error)}`)
      return null
    }
  }

  /** 首次生成失败或超时后，用户可手动重试 */
  private async retryAi(): Promise<void> {
    if (this.resultId <= 0) {
      return
    }
    this.aiStatus = 'pending'
    this.aiError = ''
    try {
      await this.apiService.retriggerAssessmentAi(this.resultId)
    } catch (error) {
      Logger.warn(TAG, `重试 AI 解读失败: ${JSON.stringify(error)}`)
    }
    this.startAiPolling()
  }

  build() {
    Column() {
      SubPageHeader({
        title: this.assessmentTitle,
        subtitle: this.showResult ? '测评结果' : '正在答题',
        rightText: this.showResult ? '完成' : this.getProgressText(),
        onAction: (): void => {
          // 结果页「完成」：回自查列表（此前是无人回调的死按钮）
          popRoute()
        }
      })

      if (this.showResult) {
        this.buildResultView()
      } else {
        this.buildQuestionView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildQuestionView() {
    Column() {
      if (this.isLoadingQuestions) {
        LoadingComponent({
          message: '正在准备题目...',
          loadingSize: 36
        })
          .layoutWeight(1)
      } else if (this.questions.length === 0) {
        this.buildEmptyView()
      } else {
        this.buildProgressBar()

        Scroll() {
          Column() {
            this.buildQuestionCard()
            this.buildOptionList()
          }
          .width('100%')
          .padding({
            left: Dimension.SpaceL,
            right: Dimension.SpaceL,
            top: Dimension.SpaceS,
            bottom: Dimension.SpaceXL
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)

        this.buildBottomAction()
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildEmptyView() {
    Column() {
      Text(this.loadError.length > 0 ? this.loadError : '暂无题目')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .margin({ bottom: 16 })

      if (this.diagInfo.length > 0) {
        Text(this.diagInfo)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .textAlign(TextAlign.Center)
          .margin({ bottom: 16 })
      }

      AppButton({
        label: '重新加载',
        kind: 'primary',
        widthPercent: '60%',
        onPress: () => {
          this.loadQuestions()
        }
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: Dimension.SpaceL, right: Dimension.SpaceL })
  }

  @Builder
  buildProgressBar() {
    Column() {
      Row() {
        Text('答题进度')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))

        Blank()

        Text(this.getProgressText())
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .margin({ bottom: 8 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(4)

        Row()
          .width(`${((this.currentIndex + 1) / this.questions.length) * 100}%`)
          .height(8)
          .backgroundColor(brand().primary)
          .borderRadius(4)
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 8,
      bottom: 6
    })
  }

  @Builder
  buildQuestionCard() {
    Column() {
      Text(`第 ${this.currentIndex + 1} 题`)
        .fontSize(13)
        .fontColor(brand().primary)
        .margin({ bottom: 10 })
        .width('100%')

      Text(this.getCurrentQuestion().title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .lineHeight(30)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(18)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildOptionList() {
    Column() {
      ForEach(this.getCurrentQuestion().options, (option: QuestionOption, index: number) => {
        this.buildOptionItem(option, index)
      })
    }
    .width('100%')
  }

  @Builder
  buildOptionItem(option: QuestionOption, index: number) {
    Row() {
      Row() {
        Text(option.key)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.selectedAnswers[this.currentIndex] === index ? $r('app.color.text_on_primary') : brand().primary)
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(14)
      .backgroundColor(this.selectedAnswers[this.currentIndex] === index ? brand().primary : brand().tagBlue)
      .margin({ right: 12 })

      Text(option.text)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .lineHeight(22)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.selectedAnswers[this.currentIndex] === index ? brand().tagBlue : $r('app.color.app_card'))
    .borderRadius(16)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 12 })
    .onClick(() => {
      this.selectOption(index)
    })
  }

  @Builder
  buildBottomAction() {
    Row() {
      AppButton({
        label: '上一题',
        kind: 'secondary',
        widthPercent: '46%',
        active: this.currentIndex > 0 && !this.isSubmitting,
        onPress: () => {
          this.goPrev()
        }
      })

      Blank()
        .width('8%')

      AppButton({
        label: this.isSubmitting ? '提交中...' : (this.currentIndex === this.questions.length - 1 ? '提交测评' : '下一题'),
        kind: 'primary',
        widthPercent: '46%',
        loading: this.isSubmitting,
        active: !this.isSubmitting,
        onPress: () => {
          this.goNext()
        }
      })
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 12,
      bottom: 18
    })
    .backgroundColor($r('app.color.app_background'))
  }

  // ------------------------------------------------------------------ AI 卡片

  private aiSummary(): string {
    return this.aiAnalysis && this.aiAnalysis.summary ? this.aiAnalysis.summary : ''
  }

  private aiTrend(): string {
    return this.aiAnalysis && this.aiAnalysis.trend ? this.aiAnalysis.trend : ''
  }

  private aiDimensions(): AssessmentAiDimension[] {
    return this.aiAnalysis && this.aiAnalysis.dimensions ? this.aiAnalysis.dimensions : []
  }

  private aiSuggestions(): AssessmentAiSuggestion[] {
    return this.aiAnalysis && this.aiAnalysis.suggestions ? this.aiAnalysis.suggestions : []
  }

  @Builder
  buildAiCard() {
    Column() {
      Row() {
        Text('AI 深度解读')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)

        if (this.aiStatus === 'success') {
          Text('仅供参考')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.aiStatus === 'success' && this.aiAnalysis) {
        this.buildAiBody()
      } else if (this.aiStatus === 'failed') {
        Text(this.aiError.length > 0 ? this.aiError : 'AI 解读暂时不可用')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .lineHeight(22)
          .width('100%')

        Text('点击重新生成')
          .fontSize(13)
          .fontColor(brand().primary)
          .margin({ top: 10 })
          .onClick(() => {
            this.retryAi()
          })
      } else {
        Text('正在结合你的逐题作答、历史得分和近期记录生成解读，大约需要几秒…')
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .lineHeight(22)
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildAiBody() {
    Column() {
      if (this.aiSummary().length > 0) {
        Text(this.aiSummary())
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(23)
          .width('100%')
          .margin({ bottom: 14 })
      }

      ForEach(this.aiDimensions(), (item: AssessmentAiDimension, index: number) => {
        this.buildAiDimension(item, index)
      }, (item: AssessmentAiDimension, index: number) => `ai-dim-${index}`)

      if (this.aiTrend().length > 0) {
        Row() {
          Text('变化趋势')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .width(64)
            .flexShrink(0)

          Text(this.aiTrend())
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(21)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ top: 8 })
      }

      ForEach(this.aiSuggestions(), (item: AssessmentAiSuggestion, index: number) => {
        this.buildAiSuggestion(item, index)
      }, (item: AssessmentAiSuggestion, index: number) => `ai-sug-${index}`)

      if (this.aiAnalysis && this.aiAnalysis.needProfessionalHelp === true) {
        Text('AI 生成的内容不能替代专业诊断。如持续困扰，建议尽快联系专业心理支持。')
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .lineHeight(18)
          .width('100%')
          .margin({ top: 12 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildAiDimension(item: AssessmentAiDimension, index: number) {
    Row() {
      Text(item.name && item.name.length > 0 ? item.name : '关注点')
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .width(84)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(item.level && item.level.length > 0 ? item.level : '—')
        .fontSize(11)
        .fontColor(brand().primary)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .borderRadius(6)
        .backgroundColor(brand().tagBlue)

      Text(item.comment && item.comment.length > 0 ? item.comment : '')
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(19)
        .layoutWeight(1)
        .margin({ left: 8 })
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .margin({ bottom: 10 })
  }

  @Builder
  buildAiSuggestion(item: AssessmentAiSuggestion, index: number) {
    Column() {
      Text(item.title && item.title.length > 0 ? item.title : `建议 ${index + 1}`)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(item.detail && item.detail.length > 0 ? item.detail : '')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(21)
        .width('100%')
        .margin({ top: 4 })
    }
    .width('100%')
    .padding({ top: 12 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 满分：优先取题库自带的 maxScore（口径与后端一致），
   * 缺失时再按「每题最高分之和」动态计算
   */
  private getMaxScore(): number {
    // 服务端返回的满分最权威（现在后端会按题库重算并回传 maxScore）
    if (this.resultData && this.resultData.maxScore && this.resultData.maxScore > 0) {
      return this.resultData.maxScore
    }
    if (this.scaleMaxScore > 0) {
      return this.scaleMaxScore
    }
    let max: number = 0
    let i: number = 0
    while (i < this.questions.length) {
      const options = this.questions[i].options
      let qMax = 0
      let j = 0
      while (j < options.length) {
        if (options[j].score > qMax) {
          qMax = options[j].score
        }
        j++
      }
      max += qMax
      i++
    }
    return max > 0 ? max : 15
  }

  @Builder
  buildResultView() {
    Scroll() {
      Column() {
        // 顶部卡：环形分数 + 标题
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            Progress({
              value: this.resultData?.score ?? 0,
              total: this.getMaxScore(),
              type: ProgressType.Ring
            })
              .width(104)
              .height(104)
              .color(brand().primary)
              .style({ strokeWidth: 9 })

            Column() {
              Text(`${this.resultData?.score ?? 0}`)
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))

              Text(`满分 ${this.getMaxScore()}`)
                .fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Center)
          }
          .margin({ bottom: 16 })

          Text('测评完成')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text(this.resultData?.assessmentTitle ? this.resultData!.assessmentTitle! : this.assessmentTitle)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor($r('app.color.app_card'))
        .borderRadius(18)
        .shadow(ShadowStyle.Card)
        .margin({ bottom: 16 })

        Column() {
          this.buildResultRow('此刻的状态', softLevel(this.resultData?.level ? this.resultData!.level! : '未知'))
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.app_card'))
        .borderRadius(16)
        .shadow(ShadowStyle.Card)
        .margin({ bottom: 16 })

        Column() {
          Text('建议')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .margin({ bottom: 12 })

          Text(this.resultData?.suggestion ? this.resultData!.suggestion! : '暂无建议')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(24)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.app_card'))
        .borderRadius(16)
        .shadow(ShadowStyle.Card)
        .margin({ bottom: 16 })

        // AI 深度解读：结合逐题作答 + 历史得分 + 近期日记情绪生成。
        // 服务端异步产出，这里按 aiStatus 分别展示加载 / 结果 / 失败可重试
        this.buildAiCard()

        AppButton({
          label: '返回上一页',
          kind: 'primary',
          block: true,
          onPress: () => {
            popRoute()
          }
        })
      }
      .width('100%')
      .padding({
        left: Dimension.SpaceL,
        right: Dimension.SpaceL,
        top: Dimension.SpaceS,
        bottom: Dimension.SpaceXL
      })
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    // 结果视图：缩放+淡入弹簧进场（提交成功的 animateTo 触发）
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.96, y: 0.96 })),
      TransitionEffect.OPACITY
    ).animation({ curve: Motion.springEmphasized, duration: Motion.Normal }))
  }

  @Builder
  buildResultRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))

      Blank()

      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
    }
    .width('100%')
    .margin({ bottom: 12 })
  }
  private authService: AuthService = AuthService.getInstance()

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    resetRoute('LoginPage')
    return false
  }
}
