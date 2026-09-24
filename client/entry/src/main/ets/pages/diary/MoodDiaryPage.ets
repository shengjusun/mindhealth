import router from '@ohos.router'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension } from '../../common/constants/Theme'
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'

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

// 传给日记详情页的路由参数
interface DiaryDetailParams {
  id: number
  title: string
  content: string
  emotion: string
  intensity: number
  event: string
  createTime: string
}

// 情绪日记视图：作为 MainPage 的 Tab 子组件使用（无底部导航）
@Component
export struct MoodDiaryView {
  @State isLoading: boolean = true
  @State isRefreshing: boolean = false
  @State hasError: boolean = false
  @State errorMessage: string = '加载失败'
  @State diaryList: DiaryItem[] = []

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    this.loadDiaryList()
  }

  private async loadDiaryList(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.isLoading = true
    }
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

  private getEmotionColor(emotion: string): ResourceColor {
    if (emotion.indexOf('开心') >= 0 || emotion.indexOf('平静') >= 0) {
      return $r('app.color.theme_secondary')
    }
    if (emotion.indexOf('焦虑') >= 0 || emotion.indexOf('难过') >= 0 || emotion.indexOf('生气') >= 0) {
      return $r('app.color.state_warning')
    }
    return $r('app.color.theme_primary')
  }

  private goWriteDiary(): void {
    try {
      router.pushUrl({ url: 'pages/diary/DiaryEditPage' })
    } catch (error) {
      Logger.error(TAG, `跳转写日记页失败: ${JSON.stringify(error)}`)
      ToastUtil.show('写日记页面暂时无法打开')
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
        Refresh({ refreshing: this.isRefreshing }) {
          Scroll() {
            Column() {
              this.buildTopIntroCard()

              if (this.diaryList.length === 0) {
                EmptyComponent({
                  symbol: $r('sys.symbol.book_pages'),
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
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .width('100%')
        .onRefreshing(() => {
          this.loadDiaryList(false).then(() => {
            this.isRefreshing = false
          })
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildTopIntroCard() {
    Column() {
      Text('记录今天的感受')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('记录不是为了评判自己，而是为了更温柔地理解自己。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })

      Button('写日记')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor($r('app.color.text_on_primary'))
        .backgroundColor($r('app.color.theme_primary'))
        .borderRadius(22)
        .margin({ top: 16 })
        .onClick(() => {
          this.goWriteDiary()
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
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
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(10)

        Blank()

        Text(this.getDiaryDateText(item.createTime ? item.createTime : ''))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(item.title ? item.title : '未命名日记')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (item.event && item.event.length > 0) {
        Text(`事件：${item.event}`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .margin({ top: 8 })
      }

      if (item.content && item.content.length > 0) {
        Text(item.content)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 8, bottom: 12 })
      }

      Row() {
        Text(this.getIntensityText(item.intensity))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))

        Blank()

        Text('查看详情')
          .fontSize(14)
          .fontColor($r('app.color.theme_primary'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: index === this.diaryList.length - 1 ? 0 : 12 })
    .onClick(() => {
      // 跳转独立详情页，整条日记通过 params 传过去
      const params: DiaryDetailParams = {
        id: item.id ?? 0,
        title: item.title ?? '',
        content: item.content ?? '',
        emotion: item.emotion ?? '',
        intensity: item.intensity ?? 0,
        event: item.event ?? '',
        createTime: item.createTime ?? ''
      }
      router.pushUrl({
        url: 'pages/diary/DiaryDetailPage',
        params: params
      })
    })
  }

  @Builder
  buildErrorView() {
    Column() {
      ErrorComponent({
        message: this.errorMessage,
        onRetry: () => {
          this.loadDiaryList()
        }
      })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor($r('app.color.app_background'))
  }
}

// 兼容旧路由的独立入口（推荐入口为 pages/MainPage 的 Tab 容器）
@Entry
@Component
struct MoodDiaryPage {
  build() {
    Column() {
      MoodDiaryView()
    }
    .width('100%')
    .height('100%')
  }
}