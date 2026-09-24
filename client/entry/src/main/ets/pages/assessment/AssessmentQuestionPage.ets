import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { Dimension } from '../../common/constants/Theme'
import { SubPageHeader } from '../../common/components/SubPageHeader'
import { LoadingComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { AuthService } from '../../core/auth/AppAuthService'

const TAG = 'AssessmentQuestionPage'

interface QuestionOption {
  key: string
  text: string
  score: number
}

interface AssessmentQuestion {
  id: number
  title: string
  options: QuestionOption[]
}

interface AssessmentDetailData {
  id?: number
  name?: string
  description?: string
  type?: string
  questions?: string
}

interface AssessmentSubmitResult {
  id?: number
  userId?: number
  assessmentId?: number
  assessmentTitle?: string
  score?: number
  level?: string
  suggestion?: string
  createTime?: string
}

interface AssessmentSubmitRequest {
  assessmentId: number
  score: number
}

@Entry
@Component
struct AssessmentQuestionPage {
  @State assessmentId: number = 0
  @State assessmentTitle: string = '心理测评'
  @State currentIndex: number = 0
  @State selectedAnswers: number[] = []
  @State questions: AssessmentQuestion[] = []
  @State isLoadingQuestions: boolean = true
  @State showResult: boolean = false
  @State resultData: AssessmentSubmitResult | null = null
  @State isSubmitting: boolean = false

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
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
   * 从后端拉取量表题库（GET /api/assessment/{id} 的 questions JSON）
   * 拉取失败或格式无效时，回退使用内置通用题库，保证答题流程始终可用
   */
  private async loadQuestions(): Promise<void> {
    this.isLoadingQuestions = true

    try {
      const res = await this.apiService.getAssessmentResult(String(this.assessmentId))
      if (res.code === 200 && res.data) {
        const detail = res.data as AssessmentDetailData
        if (detail.questions && detail.questions.length > 0) {
          const parsed = this.parseQuestions(detail.questions)
          if (parsed.length > 0) {
            this.applyQuestions(parsed)
            this.isLoadingQuestions = false
            return
          }
        }
      }
      // 后端没有题库（未执行迁移脚本）时使用内置题库
      this.applyQuestions(this.buildDefaultQuestions())
    } catch (error) {
      Logger.warn(TAG, `拉取题库失败，使用内置题库: ${JSON.stringify(error)}`)
      this.applyQuestions(this.buildDefaultQuestions())
    } finally {
      this.isLoadingQuestions = false
    }
  }

  /**
   * 解析后端题库 JSON，并做结构校验（题目至少 1 题、每题至少 2 个选项）
   */
  private parseQuestions(jsonText: string): AssessmentQuestion[] {
    try {
      const raw = JSON.parse(jsonText) as AssessmentQuestion[]
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
    } catch (error) {
      Logger.warn(TAG, `题库 JSON 解析失败: ${JSON.stringify(error)}`)
      return []
    }
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

  /**
   * 内置通用题库（后端题库不可用时的兜底）
   */
  private buildDefaultQuestions(): AssessmentQuestion[] {
    return [
      {
        id: 1,
        title: '最近一周，你是否经常感到情绪低落或烦躁？',
        options: [
          { key: 'A', text: '几乎没有', score: 0 },
          { key: 'B', text: '偶尔有', score: 1 },
          { key: 'C', text: '经常有', score: 2 },
          { key: 'D', text: '几乎每天都有', score: 3 }
        ]
      },
      {
        id: 2,
        title: '最近一周，你是否容易因为小事紧张或担心？',
        options: [
          { key: 'A', text: '完全不会', score: 0 },
          { key: 'B', text: '偶尔会', score: 1 },
          { key: 'C', text: '经常会', score: 2 },
          { key: 'D', text: '非常明显', score: 3 }
        ]
      },
      {
        id: 3,
        title: '最近一周，你的睡眠情况如何？',
        options: [
          { key: 'A', text: '很好', score: 0 },
          { key: 'B', text: '偶尔睡不好', score: 1 },
          { key: 'C', text: '经常睡不好', score: 2 },
          { key: 'D', text: '严重影响休息', score: 3 }
        ]
      },
      {
        id: 4,
        title: '最近一周，你做事时是否难以集中注意力？',
        options: [
          { key: 'A', text: '没有影响', score: 0 },
          { key: 'B', text: '轻微影响', score: 1 },
          { key: 'C', text: '明显影响', score: 2 },
          { key: 'D', text: '非常严重', score: 3 }
        ]
      },
      {
        id: 5,
        title: '最近一周，你是否愿意主动与他人交流？',
        options: [
          { key: 'A', text: '很愿意', score: 0 },
          { key: 'B', text: '还可以', score: 1 },
          { key: 'C', text: '不太愿意', score: 2 },
          { key: 'D', text: '完全不想', score: 3 }
        ]
      }
    ]
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
    let i: number = 0

    while (i < this.questions.length) {
      const answerIndex = this.selectedAnswers[i]
      if (answerIndex >= 0) {
        totalScore += this.questions[i].options[answerIndex].score
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
        score: totalScore
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
        this.showResult = true
      } else {
        ToastUtil.show('测评提交成功，但结果解析失败')
      }
    } catch (error) {
      Logger.error(TAG, `提交测评失败: ${JSON.stringify(error)}`)
      ToastUtil.show('提交失败，请稍后重试')
    } finally {
      this.isSubmitting = false
    }
  }

  build() {
    Column() {
      SubPageHeader({
        title: this.assessmentTitle,
        subtitle: this.showResult ? '测评结果' : '正在答题',
        rightText: this.showResult ? '完成' : this.getProgressText()
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
      if (this.isLoadingQuestions || this.questions.length === 0) {
        LoadingComponent({
          message: '正在准备题目...',
          loadingSize: 36
        })
          .layoutWeight(1)
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
          .backgroundColor($r('app.color.theme_primary'))
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
        .fontColor($r('app.color.theme_primary'))
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
          .fontColor(this.selectedAnswers[this.currentIndex] === index ? $r('app.color.text_on_primary') : $r('app.color.theme_primary'))
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(14)
      .backgroundColor(this.selectedAnswers[this.currentIndex] === index ? $r('app.color.theme_primary') : $r('app.color.tag_blue'))
      .margin({ right: 12 })

      Text(option.text)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .lineHeight(22)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.selectedAnswers[this.currentIndex] === index ? $r('app.color.tag_blue') : $r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 12 })
    .onClick(() => {
      this.selectOption(index)
    })
  }

  @Builder
  buildBottomAction() {
    Row() {
      Button('上一题')
        .width('46%')
        .height(Dimension.ButtonHeight)
        .fontSize(15)
        .fontColor($r('app.color.theme_primary'))
        .backgroundColor($r('app.color.tag_blue'))
        .borderRadius(24)
        .enabled(this.currentIndex > 0 && !this.isSubmitting)
        .opacity(this.currentIndex > 0 ? 1 : 0.5)
        .onClick(() => {
          this.goPrev()
        })

      Blank()
        .width('8%')

      Button(this.isSubmitting ? '提交中...' : (this.currentIndex === this.questions.length - 1 ? '提交测评' : '下一题'))
        .width('46%')
        .height(Dimension.ButtonHeight)
        .fontSize(15)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.theme_primary'))
        .borderRadius(24)
        .enabled(!this.isSubmitting)
        .onClick(() => {
          if (!this.isSubmitting) {
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

  /**
   * 动态计算满分：当前题库每题最高分之和（默认题库为 5 题 × 3 分 = 15）
   */
  private getMaxScore(): number {
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
              .color($r('app.color.theme_primary'))
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
        .margin({ bottom: 16 })

        Column() {
          this.buildResultRow('结果等级', this.resultData?.level ? this.resultData!.level! : '未知')
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.app_card'))
        .borderRadius(16)
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
        .margin({ bottom: 20 })

        Button('返回上一页')
          .width('100%')
          .height(Dimension.ButtonHeight)
          .fontSize(16)
          .fontColor($r('app.color.text_on_primary'))
          .backgroundColor($r('app.color.theme_primary'))
          .borderRadius(24)
          .onClick(() => {
            router.back()
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

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}