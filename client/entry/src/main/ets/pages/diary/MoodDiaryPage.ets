import { pushRoute, pushRouteWithParam, resetRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension, ShadowStyle } from '../../common/constants/Theme'
import { appState } from '../../common/state/AppState'
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../../common/components/StateComponents'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { SnapshotRepository } from '../../core/repository/SnapshotRepository'

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
@ComponentV2
export struct MoodDiaryView {
  @Local isLoading: boolean = true
  @Local isRefreshing: boolean = false
  @Local hasError: boolean = false
  @Local errorMessage: string = '加载失败'
  @Local diaryList: DiaryItem[] = []
  // 非空表示当前列表来自本地快照，需要在界面上标注数据时间，避免用户以为是最新
  @Local snapshotHint: string = ''

  private apiService: ApiService = ApiService.getInstance()
  private snapshotRepo: SnapshotRepository = SnapshotRepository.getInstance()

  aboutToAppear(): void {
    this.loadDiaryList()
  }

  /**
   * 离线优先（SWR）：
   * 1. 先读本地快照并立刻渲染，不等网络；
   * 2. 再静默刷新，成功则覆盖并更新快照，失败一律吞掉并保留快照；
   * 3. 只有「本地与网络都没有数据」时才展示错误页。
   */
  private async loadDiaryList(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.isLoading = true
    }
    this.hasError = false

    const cached: Object[] | null = await this.snapshotRepo.getDiaryList()
    const hasSnapshot: boolean = cached !== null
    if (hasSnapshot) {
      this.diaryList = cached as DiaryItem[]
      const ts: number = await this.snapshotRepo.getDiaryTimestamp()
      this.snapshotHint = SnapshotRepository.formatAgoText(ts)
      Logger.info(TAG, `日记命中本地快照，共 ${this.diaryList.length} 条 ${this.snapshotHint}`)
    }
    this.isLoading = false

    try {
      const res = await this.apiService.getDiaryList()
      if (res.code === 200 && res.data && Array.isArray(res.data)) {
        this.diaryList = res.data as DiaryItem[]
        this.snapshotHint = ''
        await this.snapshotRepo.saveDiaryList(res.data as Object[])
      } else if (!hasSnapshot) {
        this.hasError = true
        this.errorMessage = res.message ? res.message : '加载日记失败'
        this.diaryList = []
      }
    } catch (error) {
      Logger.error(TAG, `刷新日记失败:${JSON.stringify(error)}`)
      if (!hasSnapshot) {
        this.hasError = true
        this.errorMessage = '网络异常， 请稍后重试'
        this.diaryList = []
      }
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
      pushRoute('DiaryEditPage')
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

              if (this.snapshotHint.length > 0) {
                Text(this.snapshotHint)
                  .fontSize(12)
                  .fontColor($r('app.color.text_tertiary'))
                  .width('100%')
                  .textAlign(TextAlign.Start)
                  .margin({ bottom: 8 })
              }

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
              // 底部留出悬浮胶囊栏的高度，否则最后一篇日记被栏挡住
              bottom: Dimension.pillSafeArea(appState().bottomIndicatorVp)
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
        // 主按钮：同色系轻微渐变 + 柔和主色阴影，提升点击欲望
        .linearGradient({
          angle: 135,
          colors: [[$r('app.color.theme_primary'), 0], [$r('app.color.primary_pressed'), 1]]
        })
        .borderRadius(Dimension.CardRadiusInner)
        .shadow(ShadowStyle.Button)
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
      pushRouteWithParam('DiaryDetailPage', params)
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

