import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { AppBottomNav } from '../../common/components/AppBottomNav'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { LoadingComponent, EmptyComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'

const TAG = 'MoodDiaryPage'

interface DiaryItem {
  id?: number
  userId?: number
  title?: string
  content?: string
  emotion?: string
  intensity?: number
  event?: string
  createTime?: string
  updateTime?: string
}

@Entry
@Component
struct MoodDiaryPage {
  @State currentTab: string = 'diary'
  @State isLoading: boolean = true
  @State hasError: boolean = false
  @State errorMessage: string = '加载失败'
  @State diaryList: DiaryItem[] = []

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    this.loadDiaryList()
  }

  private async loadDiaryList(): Promise<void> {
    this.isLoading = true
    this.hasError = false
    try {
      const res = await this.apiService.getDiaryList()
      if (res.code === 200 && res.data) {
        if (Array.isArray(res.data)) {
          this.diaryList = res.data as DiaryItem[]
        } else {
          this.diaryList = []
        }
      } else {
        this.hasError = true
        this.errorMessage = res.message ? res.message : '加载日记失败'
        this.diaryList = []
      }
    } catch (error) {
      Logger.error(TAG, `加载日记失败:${JSON.stringify(error)}`)
      this.hasError = true
      this.errorMessage = '网络异常， 请稍后重试'
      this.diaryList = []
    } finally {
      this.isLoading = false
    }
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

  private getIntensityText(intensity?: number): string {
    if (intensity === undefined) {
      return '情绪强度未知'
    }
    return `情绪强度 ${intensity}/10`
  }

  private getEmotionColor(emotion: string): string {
    if (emotion.indexOf('开心') >= 0 || emotion.indexOf('平静') >= 0) {
      return LightTheme.Secondary
    }
    if (emotion.indexOf('焦虑') >= 0 || emotion.indexOf('难过') >= 0 || emotion.indexOf('生气') >= 0) {
      return LightTheme.Warning
    }
    return LightTheme.Primary
  }

  private goWriteDiary(): void {
    try {
      router.pushUrl({ url: 'pages/diary/DiaryEditPage' })
    } catch (error) {
      Logger.error(TAG, `跳转写日记页失败: ${JSON.stringify(error)}`)
      AlertDialog.show({
        title: '提示',
        message: '写日记页面暂时无法打开',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
    }
  }

  build() {
    Column() {
      AppPageHeader({
        title: '情绪日记'
      })

      if (this.isLoading) {
        LoadingComponent({
          message: '正在加载日记...',
          loadingSize: 36
        })
          .layoutWeight(1)
      } else if (this.hasError) {
        this.buildErrorView()
      } else {
        Scroll() {
          Column() {
            this.buildTopIntroCard()

            if (this.diaryList.length === 0) {
              EmptyComponent({
                icon: '📔',
                message: '还没有日记，写下今天的第一条感受吧'
              })
                .height(320)
            } else {
              this.buildDiaryList()
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
  buildTopIntroCard() {
    Column() {
      Text('记录今天的感受')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')

      Text('记录不是为了评判自己，而是为了更温柔地理解自己。')
        .fontSize(14)
        .fontColor(LightTheme.TextSecondary)
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })

      Button('写日记')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor('#FFFFFF')
        .backgroundColor(LightTheme.Primary)
        .borderRadius(22)
        .margin({ top: 16 })
        .onClick(() => {
          this.goWriteDiary()
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildDiaryList() {
    Column() {
      ForEach(this.diaryList, (item: DiaryItem, index: number) => {
        this.buildDiaryCard(item, index)
      })
    }
    .width('100%')
  }

  @Builder
  buildDiaryCard(item: DiaryItem, index: number) {
    Column() {
      Row() {
        Text(item.emotion ? item.emotion : '情绪记录')
          .fontSize(12)
          .fontColor(this.getEmotionColor(item.emotion ? item.emotion : ''))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(LightTheme.SurfaceSoft)
          .borderRadius(10)

        Blank()

        Text(this.getDiaryDateText(item.createTime ? item.createTime : ''))
          .fontSize(12)
          .fontColor(LightTheme.TextTertiary)
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(item.title ? item.title : '未命名日记')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(LightTheme.TextPrimary)
        .width('100%')

      if (item.event && item.event.length > 0) {
        Text(`事件：${item.event}`)
          .fontSize(13)
          .fontColor(LightTheme.TextSecondary)
          .width('100%')
          .margin({ top: 8 })
      }

      if (item.content && item.content.length > 0) {
        Text(item.content)
          .fontSize(14)
          .fontColor(LightTheme.TextSecondary)
          .lineHeight(22)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 8, bottom: 12 })
      }

      Row() {
        Text(this.getIntensityText(item.intensity))
          .fontSize(12)
          .fontColor(LightTheme.TextTertiary)

        Blank()

        Text('查看详情')
          .fontSize(14)
          .fontColor(LightTheme.Primary)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(LightTheme.Card)
    .borderRadius(16)
    .margin({ bottom: index === this.diaryList.length - 1 ? 0 : 12 })
    .onClick(() => {
      AlertDialog.show({
        title: '日记详情',
        message: item.content && item.content.length > 0 ? item.content : '暂无更多内容',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
    })
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
          this.loadDiaryList()
        })
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF8F0')
  }
}