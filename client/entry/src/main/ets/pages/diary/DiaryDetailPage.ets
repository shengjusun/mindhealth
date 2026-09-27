import { appState, AppState, popRoute, pushRouteWithParam } from '../../common/state/AppState'
import { SubPageHeader } from '../../common/components/SubPageHeader'
import { brand, Dimension, FontLevel, ShadowStyle, Motion } from '../../common/constants/Theme'
import { AppButton } from '../../common/components/AppButton'
import { AppChip } from '../../common/components/AppChip'
import { softIntensity, emotionChipKind } from '../../common/utils/AssessmentTone'
import { ApiService } from '../../core/api/ApiService'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'

const TAG = 'DiaryDetailPage'

interface DiaryItem {
  id?: number
  title?: string
  content?: string
  emotion?: string
  intensity?: number
  event?: string
  createTime?: string
}

// 传给日记编辑页的路由参数
interface DiaryEditParams {
  diaryId: number
  title: string
  content: string
  emotion: string
  intensity: number
  event: string
}

@ComponentV2
export struct DiaryDetailPage {
  // 路由入参，由 RouteBuilders 的 DiaryDetailRoute 注入（取代 router.getParams()）
  // V2 中普通属性禁止从外部初始化，必须由父组件传入 —— 用 @Param（只读，组件内不修改）
  @Param routeParam: Record<string, Object> | undefined = undefined

  @Local diary: DiaryItem | null = null
  @Local isDeleting: boolean = false

  // 用于 @Monitor 监听底部 Tab/导航返回的刷新信号
  @Local state: AppState = appState()

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    const params = this.routeParam
    if (params) {
      const idValue = params['id']
      this.diary = {
        id: typeof idValue === 'number' ? idValue : Number(idValue ?? 0),
        title: params['title'] as string | undefined,
        content: params['content'] as string | undefined,
        emotion: params['emotion'] as string | undefined,
        intensity: params['intensity'] as number | undefined,
        event: params['event'] as string | undefined,
        createTime: params['createTime'] as string | undefined
      }
    }
  }

  /**
   * V2 组件不支持 onPageShow（编译器不报错，但运行时不会触发，属于静默失效）。
   *
   * 改为：NavDestination.onShown 递增 AppState.diaryDetailRefreshTick，
   * 这里用 @Monitor 监听该计数，在从编辑页保存返回时重新拉取最新内容。
   * 接口失败时静默保留现有展示，不影响阅读。
   */
  @Monitor('state.diaryDetailRefreshTick')
  onShownRefresh(): void {
    this.refreshFromServer()
  }

  private async refreshFromServer(): Promise<void> {
    if (!this.diary || this.diary.id === undefined || this.diary.id === 0) {
      return
    }
    try {
      const res = await this.apiService.getDiaryDetail(String(this.diary.id))
      if (res.code === 200 && res.data) {
        const remote = res.data as DiaryItem
        this.diary = {
          id: this.diary.id,
          title: remote.title ?? this.diary.title,
          content: remote.content ?? this.diary.content,
          emotion: remote.emotion ?? this.diary.emotion,
          intensity: remote.intensity ?? this.diary.intensity,
          event: remote.event ?? this.diary.event,
          createTime: remote.createTime ?? this.diary.createTime
        }
      }
    } catch (error) {
      Logger.warn(TAG, `刷新日记详情失败: ${JSON.stringify(error)}`)
    }
  }

  private getDate(): string {
    const timeText: string = this.diary?.createTime ?? ''
    const tIndex: number = timeText.indexOf('T')
    if (tIndex > 0) {
      return timeText.substring(0, tIndex)
    }
    return timeText.length > 0 ? timeText : '今天'
  }

  private getIntensityText(): string {
    return softIntensity(this.diary ? this.diary.intensity ?? 0 : 0)
  }

  private goEdit(): void {
    if (!this.diary || this.diary.id === undefined) {
      ToastUtil.show('日记信息不完整，无法编辑')
      return
    }
    const params: DiaryEditParams = {
      diaryId: this.diary.id,
      title: this.diary.title ?? '',
      content: this.diary.content ?? '',
      emotion: this.diary.emotion ?? '',
      intensity: this.diary.intensity ?? 5,
      event: this.diary.event ?? ''
    }
    pushRouteWithParam('DiaryEditPage', params)
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: '删除这篇日记',
      message: '删除后无法恢复。确定要放下这段记录吗？',
      primaryButton: {
        value: '再想想',
        action: () => {
        }
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.state_error'),
        action: () => {
          this.deleteDiary()
        }
      }
    })
  }

  private async deleteDiary(): Promise<void> {
    if (!this.diary || this.diary.id === undefined || this.isDeleting) {
      return
    }

    this.isDeleting = true
    try {
      const res = await this.apiService.deleteDiary(String(this.diary.id))
      if (res.code === 200) {
        ToastUtil.show('日记已删除')
        popRoute()
      } else {
        ToastUtil.show(res.message ? res.message : '删除失败，请稍后重试')
      }
    } catch (error) {
      Logger.error(TAG, `删除日记失败: ${JSON.stringify(error)}`)
      ToastUtil.show('网络好像不太顺畅，稍后再试试')
    } finally {
      this.isDeleting = false
    }
  }

  build() {
    Column() {
      SubPageHeader({
        title: '日记详情'
      })

      if (this.diary === null) {
        this.buildEmptyView()
      } else {
        Scroll() {
          Column() {
            // 头部：情绪语义 chip + 日期（t4 极灰）
            Row() {
              AppChip({
                label: this.diary.emotion && this.diary.emotion.length > 0 ? this.diary.emotion : '情绪记录',
                kind: emotionChipKind(this.diary.emotion ?? '')
              })

              Blank()

              Text(this.getDate())
                .fontSize(FontLevel.Caption)
                .fontColor($r('app.color.text_quaternary'))
            }
            .width('100%')

            // 标题
            Text(this.diary.title && this.diary.title.length > 0 ? this.diary.title : '未命名日记')
              .fontSize(FontLevel.PageTitle)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .lineHeight(FontLevel.titleLineHeight(FontLevel.PageTitle))
              .width('100%')
              .margin({ top: Dimension.SpaceM })

            // 情绪温度：描述语 + 刻度条（与日记列表同款视觉语言）
            Column() {
              Text(this.getIntensityText())
                .fontSize(FontLevel.Aux)
                .fontColor($r('app.color.text_tertiary'))

              Row() {
                Row()
                  .width(Dimension.Space4XL * 2 * (this.diary.intensity ?? 0) / 10)
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
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: Dimension.SpaceM })

            // 触发事件
            if (this.diary.event && this.diary.event.length > 0) {
              Column() {
                Text('触发事件')
                  .fontSize(FontLevel.Caption)
                  .fontColor($r('app.color.text_quaternary'))
                  .margin({ bottom: Dimension.Space2XS })
                Text(this.diary.event)
                  .fontSize(FontLevel.Body)
                  .fontColor($r('app.color.text_secondary'))
                  .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(Dimension.CardPaddingInner)
              .backgroundColor($r('app.color.surface_soft'))
              .borderRadius(Dimension.RadiusM)
              .margin({ top: Dimension.SpaceM })
            }

            // 正文
            Text(this.diary.content && this.diary.content.length > 0
              ? this.diary.content
              : '这一天没有写下更多内容。')
              .fontSize(15)
              .fontColor($r('app.color.text_primary'))
              .lineHeight(26)
              .width('100%')
              .margin({ top: Dimension.SpaceL })
          }
          .width('100%')
          .padding({
            left: Dimension.SpaceL,
            right: Dimension.SpaceL,
            top: Dimension.SpaceS,
            bottom: Dimension.SpaceHuge
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)

        // 底部操作栏：删除 / 编辑（底部加手势条动态避让）
        Row() {
          AppButton({
            label: this.isDeleting ? '删除中...' : '删除',
            kind: 'primary',
            danger: true,
            weight: 1,
            active: !this.isDeleting,
            outerMargin: { right: 12 },
            onPress: () => {
              this.confirmDelete()
            }
          })

          AppButton({
            label: '编辑',
            kind: 'primary',
            weight: 1,
            onPress: () => {
              this.goEdit()
            }
          })
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 12,
          bottom: Dimension.SpaceL + this.state.bottomIndicatorVp
        })
        .backgroundColor($r('app.color.nav_background'))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
    // 内容进场：上浮 + 淡入弹簧（一镜到底 geometryTransition 的轻量替代，真机联调后再评估升级）
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 24 })),
      TransitionEffect.OPACITY
    ).animation({ curve: Motion.springStandard, duration: Motion.Normal }))
  }

  @Builder
  buildEmptyView() {
    Column() {
      SymbolGlyph($r('sys.symbol.book_pages'))
        .fontSize(48)
        .fontColor([$r('app.color.text_tertiary')])
        .margin({ bottom: 16 })
      Text('日记信息加载失败，请返回重试')
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))
    }
    .layoutWeight(1)
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}
