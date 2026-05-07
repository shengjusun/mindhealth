import router from '@ohos.router'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { SubPageHeader } from '../../common/components/SubPageHeader'
import { AuthService } from '../../core/auth/AppAuthService'

interface AssessmentDetailData {
  id: number
  title: string
  description: string
  type: string
  duration: string
  questionCount: number
  tips: string[]
}

@Entry
@Component
struct AssessmentDetailPage {
  @State assessmentId: number = 0
  @State detail: AssessmentDetailData = {
    id: 0,
    title: '心理测评',
    description: '帮助你更了解当前的心理状态。',
    type: 'general',
    duration: '约 3~5 分钟',
    questionCount: 10,
    tips: ['请根据最近一周的真实感受作答', '没有绝对正确答案', '本测评仅用于自我了解']
  }

  aboutToAppear(): void {
    try {
      const params = router.getParams() as Record<string, Object>
      const idValue = params['id']
      const titleValue = params['title']
      const descriptionValue = params['description']
      const questionCountValue = params['questionCount']
      const durationValue = params['duration']

      if (typeof idValue === 'string') {
        this.assessmentId = Number(idValue)
      } else if (typeof idValue === 'number') {
        this.assessmentId = idValue
      }

      this.initMockDetail()

      if (typeof titleValue === 'string' && titleValue.length > 0) {
        this.detail.title = titleValue
      }
      if (typeof descriptionValue === 'string' && descriptionValue.length > 0) {
        this.detail.description = descriptionValue
      }
      if (typeof questionCountValue === 'string') {
        const count = Number(questionCountValue)
        if (!isNaN(count) && count > 0) {
          this.detail.questionCount = count
        }
      } else if (typeof questionCountValue === 'number' && questionCountValue > 0) {
        this.detail.questionCount = questionCountValue
      }
      if (typeof durationValue === 'string' && durationValue.length > 0) {
        this.detail.duration = durationValue
      }
    } catch (error) {
      console.error(`AssessmentDetailPage aboutToAppear error: ${JSON.stringify(error)}`)
      this.initMockDetail()
    }
    if (!this.ensureLogin()) {
      return
    }
  }

  private initMockDetail(): void {
    switch (this.assessmentId) {
      case 1:
        this.detail = {
          id: 1,
          title: '情绪状态自评',
          description: '帮助你快速了解最近一周的整体情绪状态，适合日常自查。',
          type: 'emotion',
          duration: '约 3 分钟',
          questionCount: 8,
          tips: ['请回想最近一周的状态', '按第一感觉作答即可', '结果仅供自我参考']
        }
        break
      case 2:
        this.detail = {
          id: 2,
          title: '压力水平测试',
          description: '评估当前学习、工作与生活带来的压力程度，帮助识别压力来源。',
          type: 'stress',
          duration: '约 4 分钟',
          questionCount: 10,
          tips: ['请选择最符合近期情况的选项', '不要过度思考', '完成后可结合日记记录']
        }
        break
      case 3:
        this.detail = {
          id: 3,
          title: '焦虑倾向筛查',
          description: '用于初步评估近期是否存在焦虑倾向与紧张反应。',
          type: 'anxiety',
          duration: '约 4 分钟',
          questionCount: 10,
          tips: ['请根据最近两周的感受回答', '如结果偏高建议进一步关注', '必要时寻求专业帮助']
        }
        break
      case 4:
        this.detail = {
          id: 4,
          title: '抑郁情绪筛查',
          description: '用于初步识别近期是否存在持续低落、兴趣减退等情况。',
          type: 'depression',
          duration: '约 4 分钟',
          questionCount: 10,
          tips: ['请如实填写', '结果不能替代医学诊断', '如长期低落请及时求助']
        }
        break
      case 5:
        this.detail = {
          id: 5,
          title: '睡眠质量评估',
          description: '了解最近的入睡情况、睡眠时长与休息恢复效果。',
          type: 'sleep',
          duration: '约 3 分钟',
          questionCount: 8,
          tips: ['结合最近一周的睡眠情况', '建议在安静状态下作答', '测完后可配合作息调整']
        }
        break
      case 6:
        this.detail = {
          id: 6,
          title: '心理韧性测试',
          description: '评估面对挫折、压力和变化时的恢复能力与适应能力。',
          type: 'resilience',
          duration: '约 5 分钟',
          questionCount: 12,
          tips: ['按真实想法作答', '重点关注面对困难时的反应', '结果可帮助你认识自身优势']
        }
        break
      default:
        this.detail = {
          id: this.assessmentId > 0 ? this.assessmentId : 1,
          title: '心理测评',
          description: '帮助你更了解当前的心理状态。',
          type: 'general',
          duration: '约 3~5 分钟',
          questionCount: 10,
          tips: ['请根据真实感受作答', '没有标准答案', '结果仅供参考']
        }
        break
    }
  }

  private goBack(): void {
    try {
      router.back()
    } catch (error) {
      console.error(`AssessmentDetailPage back error: ${JSON.stringify(error)}`)
    }
  }

  private startAnswer(): void {
    if (this.detail.id <= 0) {
      AlertDialog.show({
        title: '提示',
        message: '当前测评数据异常，暂时无法开始答题',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
      return
    }

    router.pushUrl(
      {
        url: 'pages/assessment/AssessmentQuestionPage',
        params: {
          id: this.detail.id,
          assessmentId: this.detail.id,
          title: this.detail.title,
          type: this.detail.type,
          questionCount: this.detail.questionCount,
          duration: this.detail.duration
        }
      },
      (err) => {
        if (err && err.code) {
          console.error(`AssessmentDetailPage push error: ${JSON.stringify(err)}`)
          AlertDialog.show({
            title: '跳转失败',
            message: `题目页没有成功打开，请检查 pages/AssessmentQuestionPage 路由注册。错误码：${err.code}`,
            primaryButton: {
              value: '知道了',
              action: () => {}
            }
          })
        }
      }
    )
  }
  private getTypeText(type: string): string {
    switch (type) {
      case 'emotion':
        return '情绪状态'
      case 'stress':
        return '压力水平'
      case 'anxiety':
        return '焦虑倾向'
      case 'depression':
        return '抑郁情绪'
      case 'sleep':
        return '睡眠质量'
      case 'resilience':
        return '心理韧性'
      default:
        return '综合测评'
    }
  }

  build() {
    Column() {
      SubPageHeader({
        title: '心理测评',
        subtitle: '了解此刻的自己'
      })

      Scroll() {
        Column() {
          this.buildHeroCard()
          this.buildInfoCard()
          this.buildTipsCard()

          Blank()
            .height(90)
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 8,
          bottom: 12
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      this.buildBottomAction()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Text('←')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .onClick(() => {
        this.goBack()
      })

      Column() {
        Text('心理测评')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Text('了解此刻的自己')
          .fontSize(11)
          .fontColor('#8B95A7')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Blank()
        .width(40)
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 14,
      bottom: 10
    })
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildHeroCard() {
    Column() {

      Text(this.detail.title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ top: 10 })

      Text(this.detail.description)
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildInfoCard() {
    Column() {
      Text('测评信息')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 16 })

      this.buildInfoRow('测评类型', this.getTypeText(this.detail.type))
      this.buildInfoRow('预计时长', this.detail.duration)
      this.buildInfoRow('题目数量', `${this.detail.questionCount} 题`)
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  @Builder
  buildInfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#6B7280')

      Blank()

      Text(value)
        .fontSize(14)
        .fontColor('#1F2937')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  buildTipsCard() {
    Column() {
      Text('作答提示')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 16 })

      ForEach(this.detail.tips, (tip: string) => {
        Row() {
          Row() {
            Text('•')
              .fontSize(14)
              .fontColor('#FFFFFF')
          }
          .width(20)
          .height(20)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(LightTheme.Primary)
          .borderRadius(10)
          .margin({ right: 10 })

          Text(tip)
            .fontSize(14)
            .fontColor('#6B7280')
            .lineHeight(22)
            .layoutWeight(1)
        }
        .width('100%')
        .margin({ bottom: 12 })
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
  }

  @Builder
  buildBottomAction() {
    Column() {
      Button('开始答题')
        .width('100%')
        .height(52)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(LightTheme.Primary)
        .borderRadius(26)
        .onClick(() => {
          this.startAnswer()
        })
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 12,
      bottom: 18
    })
    .backgroundColor('#F6F8FB')
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