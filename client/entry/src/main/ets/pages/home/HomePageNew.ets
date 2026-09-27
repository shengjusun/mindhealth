import { pushRoute, resetRoute } from '../../common/state/AppState'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { brand, Dimension, FontLevel, ShadowStyle } from '../../common/constants/Theme'
import { Logger } from '../../common/utils/Logger'
import { AuthService } from '../../core/auth/AppAuthService'
import { ApiService } from '../../core/api/ApiService'
import { SnapshotRepository } from '../../core/repository/SnapshotRepository'
import { appState } from '../../common/state/AppState'
import { AppButton } from '../../common/components/AppButton'
import { Skeleton } from '../../common/components/Skeleton'

const TAG = 'HomePageNew'

interface HomeQuickAction {
  id: string
  icon: Resource
  title: string
  subtitle: string
  // 要跳转的路由名（route_map.json 里的 name）；为空表示该项只切 Tab 不入栈
  routeName: string
}

interface AssessmentRecordItem {
  id?: number
  userId?: number
  assessmentId?: number
  assessmentTitle?: string
  score?: number
  level?: string
  suggestion?: string
  createTime?: string
}

interface AssessmentListResponse {
  code?: number
  message?: string
  data?: AssessmentRecordItem[]
  timestamp?: number
}

// 首页视图：作为 MainPage 的 Tab 子组件使用（无底部导航，状态常驻）
@ComponentV2
export struct HomeView {
  @Local greetingText: string = '今天也要照顾好自己'
  @Local moodTip: string = '允许自己慢一点，也是一种成长。'
  @Local latestAssessment: AssessmentRecordItem | null = null
  @Local isAssessmentLoading: boolean = false
  // 非空表示当前卡片来自本地快照，需要标注数据时间
  @Local assessmentSnapshotHint: string = ''
  // 无快照且网络失败：骨架屏转错误态（不再伪装成"还没有记录"）
  @Local assessmentLoadError: boolean = false
  // 分数滚动计数的当前显示值（easeOutCubic 600ms）
  @Local displayScore: number = 0
  private scoreTimerId: number = -1

  private authService: AuthService = AuthService.getInstance()
  private apiService: ApiService = ApiService.getInstance()
  private snapshotRepo: SnapshotRepository = SnapshotRepository.getInstance()

  // 前三个是底部 Tab，点一下直接切 Tab，不入栈；只有文章页是真正的入栈跳转
  private quickActions: HomeQuickAction[] = [
    {
      id: 'chat',
      icon: $r('sys.symbol.message'),
      title: '轻心树洞',
      subtitle: '把今天的想法慢慢说出来',
      routeName: ''
    },
    {
      id: 'diary',
      icon: $r('sys.symbol.book_pages'),
      title: '心情日记',
      subtitle: '记录今天的心情与生活片段',
      routeName: ''
    },
    {
      id: 'assessment',
      icon: $r('sys.symbol.checkmark_clipboard'),
      title: '状态自查',
      subtitle: '简单记录今天的生活状态',
      routeName: ''
    },
    {
      id: 'article',
      icon: $r('sys.symbol.doc_text'),
      title: '生活小贴士',
      subtitle: '看看适合今天的温柔提醒',
      routeName: 'ArticlesPage'
    }
  ]

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }

    this.loadLatestAssessment()
  }

  aboutToDisappear(): void {
    // Tab 视图常驻基本不销毁，清理仅为完整性
    if (this.scoreTimerId >= 0) {
      clearInterval(this.scoreTimerId)
      this.scoreTimerId = -1
    }
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    AlertDialog.show({
      title: '请先登录',
      message: '当前页面需要登录后才能访问',
      primaryButton: {
        value: '去登录',
        action: () => {
          resetRoute('LoginPage')
        }
      }
    })

    return false
  }

  /**
   * 离线优先（SWR）：先渲染本地快照，再静默刷新；网络失败保留快照，不报错。
   */
  private async loadLatestAssessment(): Promise<void> {
    this.isAssessmentLoading = true
    this.assessmentLoadError = false

    const cached: Object[] | null = await this.snapshotRepo.getAssessmentResults()
    if (cached !== null && cached.length > 0) {
      this.latestAssessment = cached[0] as AssessmentRecordItem
      const ts: number = await this.snapshotRepo.getAssessmentTimestamp()
      this.assessmentSnapshotHint = SnapshotRepository.formatAgoText(ts)
      Logger.info(TAG, `最近状态记录命中本地快照 ${this.assessmentSnapshotHint}`)
      this.updateScoreTarget()
      // 有快照：立即展示快照数据（SWR），不阻塞在网络上
      this.isAssessmentLoading = false
    }

    // 静默刷新不 await：本地快照已经渲染出来了，网络失败也不该让调用方等；
    // 无快照时骨架屏保持到网络返回，失败转错误态（审计 C-1-5 / C-1-6）
    this.refreshInBackground().then(() => {
      this.isAssessmentLoading = false
    })
  }

  /** 后台静默刷新最近一次状态记录 */
  private async refreshInBackground(): Promise<void> {
    try {
      const rawResult = await this.apiService.getAssessmentResults() as Object
      const list: AssessmentRecordItem[] | null = this.extractAssessmentList(rawResult)

      if (list) {
        this.latestAssessment = list.length > 0 ? list[0] : null
        this.assessmentSnapshotHint = ''
        this.updateScoreTarget()
        await this.snapshotRepo.saveAssessmentResults(list as Object[])
      } else if (!this.latestAssessment) {
        this.assessmentLoadError = true
      }
    } catch (error) {
      Logger.error(TAG, `刷新最近状态记录失败: ${JSON.stringify(error)}`)
      if (!this.latestAssessment) {
        this.assessmentLoadError = true
      }
    }
  }

  /** 分数滚动计数：easeOutCubic 600ms（24 步 × 25ms），结束自动清理 */
  private startScoreCountUp(target: number): void {
    if (this.scoreTimerId >= 0) {
      clearInterval(this.scoreTimerId)
    }
    let step: number = 0
    const steps: number = 24
    this.scoreTimerId = setInterval(() => {
      step++
      const t: number = Math.min(step / steps, 1)
      this.displayScore = Math.round(target * (1 - Math.pow(1 - t, 3)))
      if (t >= 1) {
        clearInterval(this.scoreTimerId)
        this.scoreTimerId = -1
      }
    }, 25)
  }

  /** 以 latestAssessment.score 为目标触发滚动 */
  private updateScoreTarget(): void {
    const score: number | null | undefined = this.latestAssessment ? this.latestAssessment.score : undefined
    if (score === undefined || score === null) {
      this.displayScore = 0
      return
    }
    this.startScoreCountUp(score)
  }

  /**
   * 后端可能直接返回数组，也可能返回 { code, data } 包装，这里统一成数组
   */
  private extractAssessmentList(rawResult: Object): AssessmentRecordItem[] | null {
    if (Array.isArray(rawResult)) {
      return rawResult as AssessmentRecordItem[]
    }

    const wrapped = rawResult as AssessmentListResponse
    if (wrapped.code === 200 && wrapped.data && Array.isArray(wrapped.data)) {
      return wrapped.data
    }
    return null
  }

  private safePush(routeName: string): void {
    try {
      pushRoute(routeName)
    } catch (error) {
      Logger.error(TAG, `跳转失败: ${JSON.stringify(error)}`)
    }
  }

  /**
   * 快捷入口点击：一级 Tab 功能直接切 Tab（保留各页状态），其余跳二级页
   */
  private openQuickAction(item: HomeQuickAction): void {
    if (item.id === 'chat') {
      appState().mainTabIndex = 1
      return
    }
    if (item.id === 'diary') {
      appState().mainTabIndex = 2
      return
    }
    if (item.id === 'assessment') {
      appState().mainTabIndex = 3
      return
    }
    pushRoute(item.routeName)
  }

  private formatTime(text: string): string {
    if (!text || text.length === 0) {
      return '刚刚完成'
    }

    const tIndex: number = text.indexOf('T')
    if (tIndex > 0) {
      return text.substring(0, 16).replace('T', ' ')
    }

    if (text.length >= 16) {
      return text.substring(0, 16)
    }

    return text
  }

  private getLevelBg(level: string): ResourceColor {
    if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
      return $r('app.color.tag_green')
    }

    if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0) {
      return $r('app.color.tag_orange')
    }

    if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
      return $r('app.color.tag_orange')
    }

    return brand().tagBlue
  }

  private getLevelColor(level: string): ResourceColor {
    if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
      return brand().secondary
    }

    if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0) {
      return $r('app.color.state_warning')
    }

    if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
      return $r('app.color.state_error')
    }

    return brand().primary
  }

  private getDisplayLevel(level: string): string {
    if (!level || level.length === 0) {
      return '已记录'
    }

    if (level.indexOf('良好') >= 0 || level.indexOf('稳定') >= 0) {
      return '状态稳定'
    }

    if (level.indexOf('轻度') >= 0 || level.indexOf('起伏') >= 0) {
      return '有点起伏'
    }

    if (level.indexOf('中度') >= 0 || level.indexOf('较高') >= 0 || level.indexOf('明显') >= 0) {
      return '需要放慢'
    }

    return level
  }

  private getDisplayTitle(title: string): string {
    if (!title || title.length === 0) {
      return '状态自查'
    }

    if (title.indexOf('焦虑') >= 0 || title.indexOf('紧张') >= 0) {
      return '紧张感记录'
    }

    if (title.indexOf('抑郁') >= 0 || title.indexOf('低落') >= 0) {
      return '低落感记录'
    }

    if (title.indexOf('压力') >= 0) {
      return '压力感受记录'
    }

    if (title.indexOf('睡眠') >= 0) {
      return '睡眠状态记录'
    }

    if (title.indexOf('韧性') >= 0) {
      return '状态恢复力记录'
    }

    if (title.indexOf('心理') >= 0 || title.indexOf('测评') >= 0 || title.indexOf('筛查') >= 0) {
      return '状态自查'
    }

    return title
  }

  private getSuggestionText(text: string): string {
    if (!text || text.length === 0) {
      return '继续留意自己的生活节奏，慢慢调整就好。'
    }

    return text
      .replace('心理', '状态')
      .replace('测评', '记录')
      .replace('治疗', '调整')
      .replace('诊断', '判断')
      .replace('焦虑', '紧张感')
      .replace('抑郁', '低落感')
  }

  private getScoreText(): string {
    if (!this.latestAssessment) {
      return '--'
    }

    if (this.latestAssessment.score === undefined || this.latestAssessment.score === null) {
      return '--'
    }

    return String(this.latestAssessment.score)
  }

  /** 实际渲染值：数据就位后走滚动计数，无数据回退 '--' */
  private getScoreDisplay(): string {
    if (!this.latestAssessment || this.latestAssessment.score === undefined || this.latestAssessment.score === null) {
      return this.getScoreText()
    }
    return String(this.displayScore)
  }

  build() {
    Column() {
      AppPageHeader({
        title: '轻心',
        subtitle: '记录心情，也记录生活'
      })

      Scroll() {
        Column() {
          this.buildHeroCard()
          this.buildLatestAssessmentCard()
          this.buildQuickActionSection()
          this.buildDailySuggestionCard()
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 6,
          // 底部留出悬浮胶囊栏的高度，否则最后一张卡片被栏挡住
          bottom: Dimension.pillSafeArea(appState().bottomIndicatorVp)
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

  // ===== 以下为构建器 =====

  @Builder
  buildHeroCard() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text('今日心情')
              .fontSize(12)
              .fontColor(brand().primary)
              .padding({
                left: 10,
                right: 10,
                top: 5,
                bottom: 5
              })
              .backgroundColor(brand().tagBlue)
              .borderRadius(12)
          }
          .margin({ bottom: 14 })

          Text(this.greetingText)
            .fontSize(FontLevel.PageTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .lineHeight(FontLevel.titleLineHeight(FontLevel.PageTitle))

          Text('慢下来，先和自己待一会儿。')
            .fontSize(FontLevel.Body)
            .fontColor($r('app.color.text_secondary'))
            // 行高 1.6：14 → 22
            .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
            .margin({ top: 8 })

          Row() {
            Text('今日小提醒')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_secondary'))

            Blank()

            Text('轻呼吸')
              .fontSize(12)
              .fontColor(brand().primary)
              .padding({
                left: 10,
                right: 10,
                top: 4,
                bottom: 4
              })
              .backgroundColor(brand().tagBlue)
              .borderRadius(12)
          }
          .width('100%')
          .margin({
            top: 18,
            bottom: 10
          })

          Text(this.moodTip)
            .fontSize(FontLevel.Body)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
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
  buildLatestAssessmentCard() {
    Column() {
      if (this.isAssessmentLoading) {
        // 骨架屏：镜像状态卡的排版（标题条 + 灰块建议区 + 右下按钮位）
        Column({ space: Dimension.SpaceM }) {
          Skeleton({ blockWidth: '40%', blockHeight: 18 })
          Skeleton({ blockWidth: '100%', blockHeight: 64, radius: Dimension.RadiusM })
          Row() {
            Skeleton({ blockWidth: 128, blockHeight: 48, radius: Dimension.RadiusFull })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
        }
        .width('100%')
      } else if (this.assessmentLoadError && !this.latestAssessment) {
        // 错误态：明确告知 + 重试（不再把网络失败伪装成"还没有记录"，审计 C-1-6）
        Column({ space: Dimension.SpaceM }) {
          Text('状态记录加载失败')
            .fontSize(FontLevel.SubTitle)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))

          Text('网络似乎不太顺畅，稍后再试试。')
            .fontSize(FontLevel.Aux)
            .fontColor($r('app.color.text_tertiary'))

          AppButton({
            label: '重试',
            kind: 'secondary',
            onPress: () => {
              this.loadLatestAssessment()
            }
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      } else if (this.latestAssessment) {
        // 信息层级（HTML）：量表名 15fp t2 居左，分数 28fp Bold text-1 居右
        Row() {
          Text(this.getDisplayTitle(this.latestAssessment.assessmentTitle ? this.latestAssessment.assessmentTitle : ''))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))
            .layoutWeight(1)

          Row() {
            Text(this.getScoreDisplay())
              .fontSize(FontLevel.Stat)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))

            Text('分')
              .fontSize(FontLevel.Caption)
              .fontColor($r('app.color.text_quaternary'))
              .margin({ left: Dimension.Space2XS })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        // 建议文案：卡内灰块（HTML inner-block：bg-subtle / radius 12 / padding 12）
        Text(this.getSuggestionText(this.latestAssessment.suggestion ? this.latestAssessment.suggestion : ''))
          .fontSize(FontLevel.Body)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
          .width('100%')
          .padding(Dimension.CardPaddingInner)
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(Dimension.RadiusM)
          .margin({ top: Dimension.SpaceM })

        // 底部：等级 chip 居左，完成时间与快照标注 12fp 极灰居右
        Row() {
          Text(this.getDisplayLevel(this.latestAssessment.level ? this.latestAssessment.level : ''))
            .fontSize(FontLevel.Caption)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getLevelColor(this.latestAssessment.level ? this.latestAssessment.level : ''))
            .padding({
              left: Dimension.SpaceS,
              right: Dimension.SpaceS,
              top: 3,
              bottom: 3
            })
            .backgroundColor(this.getLevelBg(this.latestAssessment.level ? this.latestAssessment.level : ''))
            .borderRadius(Dimension.RadiusXS)

          Blank()

          Column() {
            Text(this.formatTime(this.latestAssessment.createTime ? this.latestAssessment.createTime : ''))
              .fontSize(FontLevel.Caption)
              .fontColor($r('app.color.text_quaternary'))

            if (this.assessmentSnapshotHint.length > 0) {
              Text(this.assessmentSnapshotHint)
                .fontSize(FontLevel.Caption)
                .fontColor($r('app.color.text_quaternary'))
                .margin({ top: Dimension.Space2XS })
            }
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .margin({ top: Dimension.SpaceM })

        Row() {
          AppButton({
            label: '查看记录',
            kind: 'text',
            weight: 1,
            onPress: () => {
              this.safePush('MyRecordsPage')
            }
          })

          Blank()
            .width(12)

          AppButton({
            label: '再记一次',
            kind: 'primary',
            fixedWidth: 128,
            onPress: () => {
              appState().mainTabIndex = 3
            }
          })
        }
        .width('100%')
        .margin({ top: 16 })
      } else {
        Text('你还没有状态记录，先做一次简单自查，首页就会展示你的最近状态。')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
          .width('100%')

        AppButton({
          label: '去了解自己',
          kind: 'primary',
          block: true,
          outerMargin: { top: 16 },
          onPress: () => {
            appState().mainTabIndex = 3
          }
        })
      }
    }
    .width('100%')
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: Dimension.SpaceXXL })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildQuickActionSection() {
    Column() {
      Row() {
        Text('常用功能')
          .fontSize(FontLevel.SectionTitle)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .margin({ bottom: Dimension.SpaceM })

      Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch }) {
        this.buildQuickActionCard(this.quickActions[0], true)
        this.buildQuickActionCard(this.quickActions[1], false)
      }
      .width('100%')
      .margin({ bottom: Dimension.SpaceM })

      Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Stretch }) {
        this.buildQuickActionCard(this.quickActions[2], true)
        this.buildQuickActionCard(this.quickActions[3], false)
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 18 })
  }

  @Builder
  buildQuickActionCard(item: HomeQuickAction, withRightMargin: boolean) {
    // HTML mini-card：图标 40 主色浅底 / 标题 17fp Medium / 描述 13fp t3 两行截断 / 等高 min 148
    Column() {
      Row() {
        Row() {
          SymbolGlyph(item.icon)
            .fontSize(20)
            .fontColor([brand().primary])
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(brand().primaryWeak)
        .borderRadius(Dimension.RadiusL)

        Blank()

        Text('›')
          .fontSize(18)
          .fontColor($r('app.color.text_quaternary'))
      }
      .width('100%')
      .margin({ bottom: Dimension.SpaceL })

      Text(item.title)
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(item.subtitle)
        .fontSize(FontLevel.Aux)
        .fontColor($r('app.color.text_tertiary'))
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: Dimension.SpaceS })
    }
    .width('48%')
    .constraintSize({ minHeight: 148 })
    .padding(Dimension.CardPadding)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ right: withRightMargin ? '4%' : 0 })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openQuickAction(item)
    })
  }

  @Builder
  buildDailySuggestionCard() {
    Column() {
      Text('今日小提醒')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      Column() {
        this.buildSuggestionItem('休息', '如果今天有些累，试着早点休息。', true)
        this.buildSuggestionItem('记录', '把一个让你在意的念头写下来。', true)
        this.buildSuggestionItem('鼓励', '给自己一句不带评判的鼓励。', false)
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.app_card'))
      .borderRadius(18)
      .shadow(ShadowStyle.Card)
    }
    .width('100%')
  }

  @Builder
  buildSuggestionItem(tag: string, text: string, showDivider: boolean) {
    Column() {
      Row() {
        Text(tag)
          .fontSize(12)
          .fontColor(brand().primary)
          .padding({
            left: 10,
            right: 10,
            top: 4,
            bottom: 4
          })
          .backgroundColor(brand().tagBlue)
          .borderRadius(10)
          .margin({ right: 10 })

        Text(text)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
          .lineHeight(22)
      }
      .width('100%')
      .padding({
        top: 8,
        bottom: 8
      })

      if (showDivider) {
        Divider()
          .width('100%')
          .height(1)
          .color($r('app.color.app_divider'))
          .margin({
            top: 2,
            bottom: 2
          })
      }
    }
    .width('100%')
  }
}

