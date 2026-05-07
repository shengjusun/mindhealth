import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { SubPageHeader } from '../../common/components/SubPageHeader'
import { Logger } from '../../common/utils/Logger'
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

    this.initQuestions()

  }

  private initQuestions(): void {
    this.questions = [
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

    this.selectedAnswers = []
    let i: number = 0
    while (i < this.questions.length) {
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
  }

  private goPrev(): void {
    if (this.currentIndex > 0) {
      this.currentIndex--
    }
  }

  private goNext(): void {
    if (this.selectedAnswers[this.currentIndex] < 0) {
      AlertDialog.show({
        title: '提示',
        message: '请先选择一个选项',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
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
      AlertDialog.show({
        title: '提示',
        message: '测评ID无效，无法提交',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
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
        AlertDialog.show({
          title: '提示',
          message: '测评提交成功，但结果解析失败',
          primaryButton: {
            value: '知道了',
            action: () => {}
          }
        })
      }
    } catch (error) {
      Logger.error(TAG, `提交测评失败: ${JSON.stringify(error)}`)
      AlertDialog.show({
        title: '提示',
        message: '提交失败，请稍后重试',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
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
    .backgroundColor(LightTheme.Background)
  }

  @Builder
  buildQuestionView() {
    Column() {
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
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  buildProgressBar() {
    Column() {
      Row() {
        Text('答题进度')
          .fontSize(13)
          .fontColor(LightTheme.TextSecondary)

        Blank()

        Text(this.getProgressText())
          .fontSize(13)
          .fontColor(LightTheme.TextSecondary)
      }
      .width('100%')
      .margin({ bottom: 8 })

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(8)
          .backgroundColor(LightTheme.SurfaceSoft)
          .borderRadius(4)

        Row()
          .width(`${((this.currentIndex + 1) / this.questions.length) * 100}%`)
          .height(8)
          .backgroundColor(LightTheme.Primary)
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
        .fontColor(LightTheme.Primary)
        .margin({ bottom: 10 })
        .width('100%')

      Text(this.getCurrentQuestion().title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .lineHeight(30)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(LightTheme.Card)
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
          .fontColor(this.selectedAnswers[this.currentIndex] === index ? LightTheme.TextWhite : LightTheme.Primary)
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(14)
      .backgroundColor(this.selectedAnswers[this.currentIndex] === index ? LightTheme.Primary : LightTheme.TagBlue)
      .margin({ right: 12 })

      Text(option.text)
        .fontSize(15)
        .fontColor(LightTheme.TextPrimary)
        .layoutWeight(1)
        .lineHeight(22)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.selectedAnswers[this.currentIndex] === index ? '#EAF4FF' : LightTheme.Card)
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
        .fontColor(LightTheme.Primary)
        .backgroundColor(LightTheme.TagBlue)
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
        .fontColor(LightTheme.TextWhite)
        .backgroundColor(LightTheme.Primary)
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
    .backgroundColor(LightTheme.Background)
  }

  @Builder
  buildResultView() {
    Scroll() {
      Column() {
        Column() {
          Text('测评完成')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightTheme.TextPrimary)

          Text(this.resultData?.assessmentTitle ? this.resultData!.assessmentTitle! : this.assessmentTitle)
            .fontSize(15)
            .fontColor(LightTheme.TextSecondary)
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(24)
        .backgroundColor(LightTheme.Card)
        .borderRadius(18)
        .margin({ bottom: 16 })

        Column() {
          this.buildResultRow('总分', `${this.resultData?.score ?? 0}`)
          this.buildResultRow('结果等级', this.resultData?.level ? this.resultData!.level! : '未知')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(LightTheme.Card)
        .borderRadius(16)
        .margin({ bottom: 16 })

        Column() {
          Text('建议')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightTheme.TextPrimary)
            .width('100%')
            .margin({ bottom: 12 })

          Text(this.resultData?.suggestion ? this.resultData!.suggestion! : '暂无建议')
            .fontSize(14)
            .fontColor(LightTheme.TextSecondary)
            .lineHeight(24)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(LightTheme.Card)
        .borderRadius(16)
        .margin({ bottom: 20 })

        Button('返回上一页')
          .width('100%')
          .height(Dimension.ButtonHeight)
          .fontSize(16)
          .fontColor(LightTheme.TextWhite)
          .backgroundColor(LightTheme.Primary)
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
        .fontColor(LightTheme.TextSecondary)

      Blank()

      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
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