import { Logger } from '../../common/utils/Logger'
import { pushRoute, resetRoute } from '../../common/state/AppState'
import { AuthService, UserAuthInfo } from '../../core/auth/AppAuthService'
import { ApiService } from '../../core/api/ApiService'
import { AvatarComponent } from '../../common/components/AvatarComponent'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { brand, Dimension, FontLevel, ShadowStyle } from '../../common/constants/Theme'
import { ApiConfig } from '../../common/constants/apiConfig'
import { SnapshotRepository } from '../../core/repository/SnapshotRepository'
import { appState, AppState } from '../../common/state/AppState'
import { AppButton } from '../../common/components/AppButton'

function getAvatarServerOrigin(): string {
  const apiBase: string = ApiConfig.API_BASE_URL
  if (apiBase.endsWith('/api')) {
    return apiBase.substring(0, apiBase.length - 4)
  }
  return apiBase
}

function stripAvatarQuery(url: string): string {
  if (!url || url.trim().length === 0) {
    return ''
  }

  const qIndex: number = url.indexOf('?')
  return qIndex >= 0 ? url.substring(0, qIndex) : url
}

function normalizeAvatarUrlForDisplay(rawAvatar: string): string {
  if (!rawAvatar || rawAvatar.trim().length === 0) {
    return ''
  }

  const cleanAvatar: string = stripAvatarQuery(rawAvatar)
  const serverOrigin: string = getAvatarServerOrigin()

  if (cleanAvatar.startsWith('http://') || cleanAvatar.startsWith('https://')) {
    return cleanAvatar
  }

  if (cleanAvatar.startsWith('/api/')) {
    return serverOrigin + cleanAvatar
  }

  if (cleanAvatar.startsWith('/uploads/')) {
    return serverOrigin + '/api' + cleanAvatar
  }

  const apiUploadIndex: number = cleanAvatar.indexOf('/api/uploads/')
  if (apiUploadIndex >= 0) {
    return serverOrigin + cleanAvatar.substring(apiUploadIndex)
  }

  const uploadIndex: number = cleanAvatar.indexOf('/uploads/')
  if (uploadIndex >= 0) {
    return serverOrigin + '/api' + cleanAvatar.substring(uploadIndex)
  }

  if (cleanAvatar.indexOf('/') < 0) {
    return serverOrigin + '/api/uploads/avatars/' + cleanAvatar
  }

  if (cleanAvatar.startsWith('/')) {
    return serverOrigin + cleanAvatar
  }

  return serverOrigin + '/api/' + cleanAvatar
}

function getInitialAvatarUrl(): string {
  const localUser = AuthService.getInstance().getUserInfo()
  if (!localUser || !localUser.photoUrl || localUser.photoUrl.trim().length === 0) {
    return ''
  }
  return normalizeAvatarUrlForDisplay(localUser.photoUrl)
}

function getInitialUserName(): string {
  const localUser = AuthService.getInstance().getUserInfo()
  if (!localUser || !localUser.displayName || localUser.displayName.trim().length === 0) {
    return '用户'
  }
  return localUser.displayName
}

function getInitialUserPhone(): string {
  const localUser = AuthService.getInstance().getUserInfo()
  if (!localUser || !localUser.phoneNumber) {
    return ''
  }
  return localUser.phoneNumber
}

function getInitialLoginState(): boolean {
  return AuthService.getInstance().isLoggedIn()
}

const TAG = 'MePage'
const USER_INFO_REFRESH_INTERVAL: number = 5 * 60 * 1000

interface MePageStatsCache {
  diaryCount: number
  assessmentCount: number
  isLoaded: boolean
}

// 模块级缓存：replaceUrl 重建页面后仍能保留，避免统计数字从 0 跳到真实值
let mePageStatsCache: MePageStatsCache = {
  diaryCount: 0,
  assessmentCount: 0,
  isLoaded: false
}

// 模块级刷新时间：避免页面重建后每次都强制请求后端
let mePageLastUserInfoRefreshTime: number = 0

interface MenuItem {
  id: string
  icon: Resource
  title: string
  subtitle?: string
  showArrow: boolean
}

interface UserProfileData {
  id?: number
  phone?: string
  nickname?: string
  age?: number
  gender?: string
  avatar?: string
  signature?: string
}

interface PageResultData {
  total?: number
  records?: Object[]
  list?: Object[]
  items?: Object[]
}

// 「我的」视图：作为 MainPage 的 Tab 子组件使用（状态常驻）
// MainPage / 兼容壳递增 appState().meRefreshTick 时，会强制刷新用户信息
@ComponentV2
export struct MeView {
  // 全局共享状态：不再通过父组件 @Prop 传值，改为监听全局刷新信号
  @Local state: AppState = appState()

  @Local userName: string = getInitialUserName()
  @Local avatarUrl: string = getInitialAvatarUrl()
  @Local userPhone: string = getInitialUserPhone()
  @Local userAge: number = 0
  @Local userGender: string = ''

  @Local isLoggedIn: boolean = getInitialLoginState()

  @Local diaryCount: number = mePageStatsCache.diaryCount
  @Local assessmentCount: number = mePageStatsCache.assessmentCount
  @Local isStatsLoaded: boolean = mePageStatsCache.isLoaded

  @Local backendUserId: number = 0
  @Local isUserInfoLoading: boolean = false
  // 非空表示当前统计数字来自本地快照，需要在界面上标注数据时间
  @Local statsSnapshotHint: string = ''

  private authService: AuthService = AuthService.getInstance()
  private apiService: ApiService = ApiService.getInstance()
  private snapshotRepo: SnapshotRepository = SnapshotRepository.getInstance()

  private isRefreshingUserInfo: boolean = false
  private isStatisticsRefreshing: boolean = false

  menuItems: MenuItem[] = [
    { id: 'records', icon: $r('sys.symbol.doc_text'), title: '我的记录', subtitle: '心情日记与状态足迹', showArrow: true },
    { id: 'help', icon: $r('sys.symbol.ellipsis_bubble'), title: '帮助与反馈', subtitle: '问题反馈与使用帮助', showArrow: true }
  ]

  aboutToAppear(): void {
    this.refreshMePage(false)
  }

  // MainPage / 兼容壳递增 appState().meRefreshTick 通知本视图刷新
  @Monitor('state.meRefreshTick')
  onRefreshTickChange(): void {
    this.refreshMePage(true)
  }

  private refreshMePage(forceRemoteRefresh: boolean = false): void {
    this.isLoggedIn = this.authService.isLoggedIn()

    if (!this.isLoggedIn) {
      this.resetUserState()
      return
    }

    this.applyLocalUserInfo()
    this.applySnapshotData()

    const now: number = Date.now()
    const needRemoteRefresh: boolean =
      forceRemoteRefresh ||
        mePageLastUserInfoRefreshTime <= 0 ||
        now - mePageLastUserInfoRefreshTime > USER_INFO_REFRESH_INTERVAL

    if (!needRemoteRefresh) {
      return
    }

    this.isUserInfoLoading = this.avatarUrl.length === 0
    this.loadUserInfo()
  }

  /**
   * 断网降级：先用本地快照把用户资料和统计数字填上，界面不留空。
   * 头像不在这里回填——离线时 URL 拼得出来但图片必然下载失败，保留上一次成功加载的即可。
   */
  private async applySnapshotData(): Promise<void> {
    try {
      const profile: Object | null = await this.snapshotRepo.getUserProfile()
      if (profile) {
        const user = profile as UserProfileData
        this.userName = user.nickname ? user.nickname : this.userName
        this.userPhone = user.phone ? user.phone : this.userPhone
        this.userAge = user.age ? user.age : 0
        this.userGender = user.gender !== undefined && user.gender !== null ? String(user.gender) : ''
        this.backendUserId = user.id ? Number(user.id) : 0
      }

      const diaryCount: number | null = await this.snapshotRepo.getDiaryCount()
      const assessmentCount: number | null = await this.snapshotRepo.getAssessmentCount()

      if (diaryCount !== null || assessmentCount !== null) {
        this.diaryCount = diaryCount !== null ? diaryCount : this.diaryCount
        this.assessmentCount = assessmentCount !== null ? assessmentCount : this.assessmentCount
        this.isStatsLoaded = true

        const ts: number = await this.snapshotRepo.getDiaryTimestamp()
        this.statsSnapshotHint = SnapshotRepository.formatAgoText(ts)
        Logger.info(TAG, `统计数字命中本地快照 ${this.statsSnapshotHint}`)
      }
    } catch (error) {
      Logger.error(TAG, `读取本地快照失败: ${JSON.stringify(error)}`)
    }
  }

  private applyLocalUserInfo(): void {
    const localUser = this.authService.getUserInfo()

    if (!localUser) {
      return
    }

    this.userName = localUser.displayName || '用户'
    this.userPhone = localUser.phoneNumber || ''

    const localAvatarUrl: string = this.normalizeAvatarUrl(localUser.photoUrl || '')
    if (localAvatarUrl && !this.isSameAvatar(localAvatarUrl)) {
      this.avatarUrl = localAvatarUrl
    }
  }

  private resetUserState(): void {
    this.isUserInfoLoading = false
    this.isRefreshingUserInfo = false
    this.isStatisticsRefreshing = false
    this.isStatsLoaded = false

    this.diaryCount = 0
    this.assessmentCount = 0
    this.backendUserId = 0
    this.userName = '用户'
    this.userPhone = ''
    this.userAge = 0
    this.userGender = ''
    this.avatarUrl = ''

    mePageStatsCache = {
      diaryCount: 0,
      assessmentCount: 0,
      isLoaded: false
    }

    mePageLastUserInfoRefreshTime = 0
  }

  private normalizeAvatarUrl(rawAvatar: string): string {
    return normalizeAvatarUrlForDisplay(rawAvatar)
  }

  private isSameAvatar(nextUrl: string): boolean {
    return stripAvatarQuery(this.avatarUrl) === stripAvatarQuery(nextUrl)
  }

  private parseCount(data: Object): number {
    if (Array.isArray(data)) {
      return (data as Object[]).length
    }

    const pageData = data as PageResultData

    if (pageData.total !== undefined && pageData.total !== null) {
      return Number(pageData.total)
    }

    if (pageData.records && Array.isArray(pageData.records)) {
      return pageData.records.length
    }

    if (pageData.list && Array.isArray(pageData.list)) {
      return pageData.list.length
    }

    if (pageData.items && Array.isArray(pageData.items)) {
      return pageData.items.length
    }

    return 0
  }

  async loadUserInfo(): Promise<void> {
    if (this.isRefreshingUserInfo) {
      return
    }

    this.isRefreshingUserInfo = true

    try {
      this.isLoggedIn = this.authService.isLoggedIn()

      if (!this.isLoggedIn) {
        this.resetUserState()
        return
      }

      const localUser = this.authService.getUserInfo()
      this.applyLocalUserInfo()

      const res = await this.apiService.getUserInfo()

      if (res.code === 200 && res.data) {
        const user: UserProfileData = res.data as UserProfileData

        const latestName: string = user.nickname ? user.nickname : '用户'
        const latestPhone: string = user.phone ? user.phone : ''
        const backendAvatarPath: string = user.avatar ? String(user.avatar) : ''
        const backendAvatarUrl: string = this.normalizeAvatarUrl(backendAvatarPath)

        this.userName = latestName
        this.userPhone = latestPhone
        this.userAge = user.age ? user.age : 0
        this.userGender = user.gender !== undefined && user.gender !== null ? String(user.gender) : ''
        this.backendUserId = user.id ? Number(user.id) : 0

        Logger.info(TAG, `当前后端用户ID: ${this.backendUserId}`)

        if (backendAvatarUrl && !this.isSameAvatar(backendAvatarUrl)) {
          this.avatarUrl = backendAvatarUrl
        }

        if (localUser) {
          const newUserInfo: UserAuthInfo = {
            uid: localUser.uid,
            displayName: latestName,
            photoUrl: backendAvatarPath || localUser.photoUrl || '',
            email: localUser.email,
            phoneNumber: latestPhone,
            accessToken: localUser.accessToken,
            refreshToken: localUser.refreshToken,
            isLoggedIn: localUser.isLoggedIn
          }
          await this.authService.updateUserInfo(newUserInfo)
        }

        await this.snapshotRepo.saveUserProfile(user as Object)

        this.loadStatistics()
        Logger.info(TAG, `后端用户信息已更新: ${this.userName}`)
      } else {
        Logger.error(TAG, `加载用户信息失败: code=${res.code}`)
      }
    } catch (error) {
      Logger.error(TAG, `加载用户信息失败: ${JSON.stringify(error)}`)
    } finally {
      this.isUserInfoLoading = false
      this.isRefreshingUserInfo = false
      mePageLastUserInfoRefreshTime = Date.now()
    }
  }

  async loadStatistics(): Promise<void> {
    if (this.isStatisticsRefreshing) {
      return
    }

    if (!this.isLoggedIn || this.backendUserId <= 0) {
      this.diaryCount = 0
      this.assessmentCount = 0
      this.isStatsLoaded = false

      mePageStatsCache = {
        diaryCount: 0,
        assessmentCount: 0,
        isLoaded: false
      }
      return
    }

    this.isStatisticsRefreshing = true

    let nextDiaryCount: number = this.diaryCount
    let nextAssessmentCount: number = this.assessmentCount

    try {
      try {
        const diaryRes = await this.apiService.getDiaryList()
        if (diaryRes.code === 200 && diaryRes.data) {
          nextDiaryCount = this.parseCount(diaryRes.data as Object)
          // 直接是数组时顺便存一份列表快照，供日记页离线展示
          if (Array.isArray(diaryRes.data)) {
            await this.snapshotRepo.saveDiaryList(diaryRes.data as Object[])
          }
        }
      } catch (error) {
        Logger.error(TAG, `加载日记统计失败: ${JSON.stringify(error)}`)
      }

      try {
        const assessmentRes = await this.apiService.getAssessmentResults()

        if (Array.isArray(assessmentRes)) {
          const list: Object[] = assessmentRes as Object[]
          nextAssessmentCount = list.length
          await this.snapshotRepo.saveAssessmentResults(list)
        } else if (assessmentRes.code === 200 && assessmentRes.data && Array.isArray(assessmentRes.data)) {
          nextAssessmentCount = assessmentRes.data.length
          await this.snapshotRepo.saveAssessmentResults(assessmentRes.data as Object[])
        }
      } catch (error) {
        Logger.error(TAG, `加载测评记录统计失败: ${JSON.stringify(error)}`)
      }

      // 总数单独落盘：日记列表快照会被截断到 20 条，不能拿长度当总数
      await this.snapshotRepo.saveCounts(nextDiaryCount, nextAssessmentCount)

      this.diaryCount = nextDiaryCount
      this.assessmentCount = nextAssessmentCount
      this.isStatsLoaded = true
      this.statsSnapshotHint = ''

      mePageStatsCache = {
        diaryCount: nextDiaryCount,
        assessmentCount: nextAssessmentCount,
        isLoaded: true
      }
    } finally {
      this.isStatisticsRefreshing = false
    }
  }

  private getGenderText(): string {
    const value: string = this.userGender.trim().toLowerCase()

    if (value === 'male' || value === 'm' || value === 'man' || value === '1' || value === '男') {
      return '男'
    }

    if (value === 'female' || value === 'f' || value === 'woman' || value === '2' || value === '女') {
      return '女'
    }

    // 第三项语义为「隐藏」（历史值 other，现行值 hidden），显示为隐藏而非未填写
    if (value === 'other' || value === 'others' || value === '3' || value === '其他'
      || value === 'hidden' || value === '隐藏') {
      return '隐藏'
    }

    return '未填写'
  }

  build() {
    Column() {
      // 设置是低频全局入口：按成熟 App 惯例收进右上角齿轮，不再占内容区菜单位
      AppPageHeader({
        title: '我的',
        subtitle: '把状态看见，也把自己照顾好',
        actionIcon: $r('sys.symbol.gearshape'),
        onAction: () => {
          pushRoute('SettingsPage')
        }
      })

      Scroll() {
        Column() {
          if (this.isLoggedIn) {
            this.buildUserCard()
            this.buildStatsCard()
            this.buildQuickActionCard()
            this.buildMenuList()
          } else {
            this.buildLoginPrompt()
          }
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 6,
          // 底部留出悬浮胶囊栏的高度，避免最后一张卡片被栏挡住
          bottom: Dimension.pillSafeArea(this.state.bottomIndicatorVp)
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildLoginPrompt() {
    Column() {
      Column() {
        Text('欢迎回来')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('登录后查看个人资料和记录')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 10 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 28 })

      AppButton({
        label: '去登录',
        kind: 'primary',
        widthPercent: '76%',
        onPress: () => {
          this.handleLogin()
        }
      })
    }
    .width('100%')
    .padding({ top: 64, bottom: 64 })
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
  }

  @Builder
  buildAvatarView() {
    if (this.avatarUrl || !this.isUserInfoLoading) {
      AvatarComponent({
        avatarUrl: this.avatarUrl,
        avatarSize: 60,
        shape: 'circle'
      })
    } else {
      Stack() {}
      .width(60)
      .height(60)
      .borderRadius(30)
      .backgroundColor($r('app.color.surface_soft'))
    }
  }

  @Builder
  buildUserCard() {
    Column() {
      Row() {
        this.buildAvatarView()

        Column() {
          Text(this.userName)
            .fontSize(FontLevel.PageTitle)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Text(`年龄：${this.userAge > 0 ? this.userAge.toString() : '未填写'}   性别：${this.getGenderText()}`)
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
        .layoutWeight(1)

        // HTML 设计稿：个人卡右上角「编辑资料」为文字按钮
        AppButton({
          label: '编辑资料',
          kind: 'text',
          onPress: () => {
            pushRoute('ProfileEditPage')
          }
        })
      }
      .width('100%')

      Text('把状态看见，也把自己照顾好')
        .fontSize(FontLevel.Aux)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .padding({ top: Dimension.SpaceL })
        .margin({ top: Dimension.SpaceL })
        .border({ width: { top: 1 }, color: $r('app.color.app_divider') })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildStatsCard() {
    Column() {
      Row() {
      Column() {
        Text(this.isStatsLoaded ? `${this.diaryCount}` : '—')
          .fontSize(FontLevel.Stat)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('日记')
          .fontSize(FontLevel.Caption)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: Dimension.Space2XS })
      }
      .layoutWeight(1)
      .onClick(() => {
        // 切到日记 Tab（保留 Tab 状态），不再整页替换
        appState().mainTabIndex = 2
      })

      // HTML 设计稿：两列统计之间 1vp 竖分隔线
      Divider()
        .vertical(true)
        .height(32)
        .color($r('app.color.app_divider'))

      Column() {
        Text(this.isStatsLoaded ? `${this.assessmentCount}` : '—')
          .fontSize(FontLevel.Stat)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('状态足迹')
          .fontSize(FontLevel.Caption)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: Dimension.Space2XS })
      }
      .layoutWeight(1)
      .onClick(() => {
        pushRoute('MyRecordsPage')
      })
      }

      if (this.statsSnapshotHint.length > 0) {
        Text(this.statsSnapshotHint)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildQuickActionCard() {
    Row() {
      AppButton({
        label: '写日记',
        kind: 'primary',
        weight: 1,
        onPress: () => {
          pushRoute('DiaryEditPage')
        }
      })

      Blank()
        .width(12)

      // 产品温度：与 Tab 术语统一（自查），次按钮形态
      AppButton({
        label: '做个小自查',
        kind: 'secondary',
        weight: 1,
        onPress: () => {
          // 切到自查 Tab（保留 Tab 状态），不再整页替换
          appState().mainTabIndex = 3
        }
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  @Builder
  buildMenuList() {
    Column() {
      ForEach(this.menuItems, (item: MenuItem, index: number) => {
        Row() {
          Row() {
            // HTML 设计稿：菜单图标底统一为主色浅底（40×40 / radius-lg）
            SymbolGlyph(item.icon)
              .fontSize(18)
              .fontColor([brand().primary])
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(brand().primaryWeak)
          .borderRadius(Dimension.RadiusL)

          Column() {
            Text(item.title)
              .fontSize(FontLevel.SubTitle)
              .fontColor($r('app.color.text_primary'))
              .fontWeight(FontWeight.Medium)

            if (item.subtitle) {
              Text(item.subtitle)
                .fontSize(FontLevel.Aux)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: Dimension.Space2XS })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)

          if (item.showArrow) {
            Text('›')
              .fontSize(20)
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          this.handleMenuClick(item.id)
        })

        if (index < this.menuItems.length - 1) {
          Divider()
            .width('100%')
            .height(1)
            .color($r('app.color.app_divider'))
            .margin({ left: 62 })
        }
      })
    }
    .width('100%')
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.CardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: 16 })
  }

  async handleLogin(): Promise<void> {
    try {
      pushRoute('LoginPage')
    } catch (error) {
      Logger.error(TAG, `跳转失败: ${error}`)
    }
  }

  handleMenuClick(id: string): void {
    if (id === 'records') {
      pushRoute('MyRecordsPage')
      return
    }

    if (id === 'help') {
      pushRoute('HelpFeedbackPage')
      return
    }
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    resetRoute('LoginPage')
    return false
  }
}

