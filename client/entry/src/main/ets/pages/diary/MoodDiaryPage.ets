import { pushRoute, pushRouteWithParam, resetRoute } from '../../common/state/AppState'
import { ApiService } from '../../core/api/ApiService'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { brand, Dimension, FontLevel, ShadowStyle } from '../../common/constants/Theme'
import { appState, AppState } from '../../common/state/AppState'
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../../common/components/StateComponents'
import { AppButton } from '../../common/components/AppButton'
import { AppChip } from '../../common/components/AppChip'
import { softIntensity, emotionChipKind } from '../../common/utils/AssessmentTone'
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

  /**
   * @Monitor('state.meRefreshTick') 的取值目标。
   * 存在的意义不是读它的值，而是让 @Monitor 的路径能解析到 AppState 实例。
   */
  @Local state: AppState = appState()

  private apiService: ApiService = ApiService.getInstance()
  private snapshotRepo: SnapshotRepository = SnapshotRepository.getInstance()

  aboutToAppear(): void {
    this.loadDiaryList()
  }

  /**
   * 从二级页（写日记 / 日记详情）返回 MainPage 时，MainPage 的 onShown 会递增
   * appState().meRefreshTick。本视图是 MainPage 的常驻 Tab 子组件，aboutToAppear
   * 只在首次挂载时触发一次，不接这个信号的话新增/编辑/删除后列表一直是旧数据。
   */
  @Monitor('state.meRefreshTick')
  onRefreshTickChange(): void {
    // 传 false：后台静默刷新，不闪整页 loading
    this.loadDiaryList(false)
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
    // 有快照：立即展示快照数据（SWR）；无快照：保持 loading 直到网络返回，
    // 避免空列表的假空态闪现（审计 C-1-5）
    if (hasSnapshot) {
      this.isLoading = false
    }

    if (showLoading) {
      // 进入页面时的自动加载：静默刷新不 await，网络回来再覆盖列表
      this.refreshFromServer(hasSnapshot)
    } else {
      // 下拉刷新是用户主动触发的，必须等他等到结果，转圈停下来才有意义
      await this.refreshFromServer(hasSnapshot)
    }
  }

  /**
   * 拉网络并覆盖列表。
   * 失败时：本地有快照就保留快照，本地也没有才转成错误态（避免假空态）。
   */
  private async refreshFromServer(hasSnapshot: boolean): Promise<void> {
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
        this.errorMessage = '网络好像不太顺畅，稍后再试试'
        this.diaryList = []
      }
    } finally {
      // 无快照场景下 loading 一直亮到网络返回（有快照时已在上面提前清掉）
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
    return softIntensity(intensity ?? 0)
  }

  /** D5 语义色映射收编到 AssessmentTone（详情/记录卡共用） */
  private getEmotionChipKind(emotion: string): string {
    return emotionChipKind(emotion)
  }

  private goWriteDiary(): void {
    try {
      pushRoute('DiaryEditPage')
    } catch (error) {
      Logger.error(TAG, `跳转写日记页失败: ${JSON.stringify(error)}`)
      ToastUtil.show('页面没打开成功，再试一次吧')
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
        .align(Alignment.TopStart)
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
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('记录不是为了评判自己，而是为了更温柔地理解自己。')
        .fontSize(FontLevel.Body)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
        .width('100%')
        .margin({ top: Dimension.SpaceS })

      // HTML 设计稿：日记引导卡的「写日记」为次按钮
      AppButton({
        label: '写日记',
        kind: 'secondary',
        block: true,
        outerMargin: { top: Dimension.SpaceL },
        onPress: () => {
          this.goWriteDiary()
        }
      })
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
        // 情绪语义色标签（D5 映射）
        AppChip({
          label: item.emotion ? item.emotion : '情绪记录',
          kind: this.getEmotionChipKind(item.emotion ? item.emotion : '')
        })

        Blank()

        Text(this.getDiaryDateText(item.createTime ? item.createTime : ''))
          .fontSize(FontLevel.Caption)
          .fontColor($r('app.color.text_quaternary'))
      }
      .width('100%')
      .margin({ bottom: Dimension.SpaceS })

      Text(item.title ? item.title : '未命名日记')
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (item.event && item.event.length > 0) {
        // HTML：「事件：」标签 13fp t4 弱化，内容 13fp t3
        Text() {
          Span('事件：')
            .fontColor($r('app.color.text_quaternary'))
          Span(item.event)
            .fontColor($r('app.color.text_tertiary'))
        }
        .fontSize(FontLevel.Aux)
        .lineHeight(20)
        .width('100%')
        .margin({ top: Dimension.SpaceM })
      }

      if (item.content && item.content.length > 0) {
        Text(item.content)
          .fontSize(FontLevel.Body)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: Dimension.SpaceS, bottom: Dimension.SpaceM })
      }

      Row() {
        // 情绪温度：描述语 + 小刻度条（替代 X/10 的体检感）
        Column() {
          Text(this.getIntensityText(item.intensity))
            .fontSize(FontLevel.Caption)
            .fontColor($r('app.color.text_quaternary'))

          Row() {
            Row()
              .width(Dimension.Space4XL * 2 * (item.intensity ?? 0) / 10)
              .height(3)
              .backgroundColor(brand().primary)
              .opacity(0.45)
          }
          .width(Dimension.Space4XL * 2)
          .height(3)
          .borderRadius(2)
          .backgroundColor($r('app.color.surface_soft'))
          .margin({ top: Dimension.Space2XS })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('查看详情')
          .fontSize(FontLevel.Body)
          .fontColor(brand().primary)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .padding({ top: Dimension.SpaceM })
      .margin({ top: Dimension.SpaceS })
      .border({ width: { top: 1 }, color: $r('app.color.app_divider') })
    }
    .width('100%')
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: index === this.diaryList.length - 1 ? 0 : Dimension.SpaceXXL })
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

