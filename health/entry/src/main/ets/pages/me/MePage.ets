import { Logger } from '../../common/utils/Logger'
import router from '@ohos.router'
import { AuthService, UserAuthInfo } from '../../core/auth/AppAuthService'
import { ApiService } from '../../core/api/ApiService'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AvatarComponent } from '../../common/components/AvatarComponent'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { AppBottomNav } from '../../common/components/AppBottomNav'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { ApiConfig } from '../../common/constants/apiConfig'

/**
 * 获取后端服务根地址
 * 主要用于拼接头像完整访问路径
 */
function getAvatarServerOrigin(): string {
  const apiBase: string = ApiConfig.API_BASE_URL
  if (apiBase.endsWith('/api')) {
    return apiBase.substring(0, apiBase.length - 4)
  }
  return apiBase
}

/**
 * 去掉头像地址后面的查询参数
 * 用于比较两个头像地址是否是同一张图
 */
function stripAvatarQuery(url: string): string {
  if (!url || url.trim().length === 0) {
    return ''
  }

  const qIndex: number = url.indexOf('?')
  return qIndex >= 0 ? url.substring(0, qIndex) : url
}

/**
 * 统一处理头像路径
 * 后端可能返回完整 URL、/api/uploads、/uploads 或文件名
 * 这里统一转换成前端可直接展示的完整地址
 */
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

/**
 * 页面初始化时先从 AuthService 里拿本地头像
 * 这样进入个人中心时不用等后端接口返回，也能先显示本地头像
 */
function getInitialAvatarUrl(): string {
  const localUser = AuthService.getInstance().getUserInfo()
  if (!localUser || !localUser.photoUrl || localUser.photoUrl.trim().length === 0) {
    return ''
  }
  return normalizeAvatarUrlForDisplay(localUser.photoUrl)
}

const TAG = 'MePage'
const DOMAIN = 0xFF00
// 用户信息远程刷新间隔，避免每次切回“我的”都请求后端造成页面跳动
const USER_INFO_REFRESH_INTERVAL: number = 5 * 60 * 1000

// 个人中心菜单项结构
interface MenuItem {
  id: string
  icon: string
  title: string
  subtitle?: string
  showArrow: boolean
}

// 后端返回的用户资料结构
interface UserProfileData {
  id?: number
  phone?: string
  nickname?: string
  age?: number
  gender?: string
  avatar?: string
  signature?: string
}

// 兼容不同分页 / 列表返回结构，用于统计数量
interface PageResultData {
  total?: number
  records?: Object[]
  list?: Object[]
  items?: Object[]
}

@Entry
@Component
struct MePage {
  // 底部导航当前选中 tab
  @State currentTab: string = 'me'

  // 用户资料展示状态
  @State userName: string = '用户'
  @State avatarUrl: string = getInitialAvatarUrl()
  @State userPhone: string = ''
  @State userAge: number = 0
  @State userGender: string = ''

  // 当前页面登录状态
  @State isLoggedIn: boolean = false

  // 个人中心统计数据
  @State diaryCount: number = 0
  @State assessmentCount: number = 0
  @State favoriteCount: number = 0

  // 后端用户 id，加载统计数据时用于判断用户是否有效
  @State backendUserId: number = 0

  // 用户信息加载状态，头像占位和页面刷新时会用到
  @State isUserInfoLoading: boolean = false

  private authService: AuthService = AuthService.getInstance()
  private apiService: ApiService = ApiService.getInstance()

  // 防止 aboutToAppear / onPageShow 同时触发导致重复请求
  private isRefreshingUserInfo: boolean = false

  // 上次从后端刷新用户信息的时间
  private lastUserInfoRefreshTime: number = 0

  // 个人中心菜单配置
  menuItems: MenuItem[] = [
    { id: 'profile', icon: '资', title: '个人资料', subtitle: '完善昵称、头像和基础信息', showArrow: true },
    { id: 'records', icon: '记', title: '我的记录', subtitle: '日记记录、测评结果', showArrow: true },
    { id: 'favorites', icon: '藏', title: '我的收藏', subtitle: '收藏的文章与内容', showArrow: true },
    { id: 'settings', icon: '设', title: '设置', subtitle: '账号、缓存与通用配置', showArrow: true },
    { id: 'help', icon: '助', title: '帮助与反馈', subtitle: '问题反馈与使用帮助', showArrow: true },
    { id: 'about', icon: '关', title: '关于我们', subtitle: '项目介绍与版本信息', showArrow: true }
  ]

  aboutToAppear(): void {
    // 第一次进入个人中心，允许请求后端最新数据
    this.refreshMePage(true)
  }

  onPageShow(): void {
    // 从其他页面返回时，优先同步本地信息，不强制请求后端
    // 这样可以避免每次切回“我的”都刷新导致页面跳动
    this.refreshMePage(false)
  }

  /**
   * 个人中心统一刷新入口
   * 先判断登录态，再决定是否加载本地信息和后端信息
   */
  /**
   * 个人中心统一刷新入口
   *
   * 逻辑：
   * 1. 未登录：清空状态，展示登录引导，不请求后端
   * 2. 已登录：先用 AuthService 本地信息快速展示
   * 3. 首次进入 / 超过刷新间隔 / 强制刷新时，再请求后端最新资料
   */
  private refreshMePage(forceRemoteRefresh: boolean = false): void {
    this.isLoggedIn = this.authService.isLoggedIn()

    if (!this.isLoggedIn) {
      this.resetUserState()
      return
    }

    // 每次进入页面都先同步本地用户信息
    // 这样从编辑资料页返回时，头像 / 昵称可以立即刷新
    this.applyLocalUserInfo()

    const now: number = Date.now()
    const needRemoteRefresh: boolean =
      forceRemoteRefresh ||
        this.lastUserInfoRefreshTime <= 0 ||
        now - this.lastUserInfoRefreshTime > USER_INFO_REFRESH_INTERVAL

    if (!needRemoteRefresh) {
      return
    }

    // 如果已有头像和昵称，就不明显展示头像 loading，避免页面视觉跳动
    this.isUserInfoLoading = this.avatarUrl.length === 0

    this.loadUserInfo()
  }

  /**
   * 从 AuthService 读取本地用户信息，快速刷新页面展示
   */
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

  /**
   * 未登录时清空个人中心状态
   */
  private resetUserState(): void {
    this.isUserInfoLoading = false
    this.isRefreshingUserInfo = false
    this.diaryCount = 0
    this.assessmentCount = 0
    this.favoriteCount = 0
    this.backendUserId = 0
    this.userName = '用户'
    this.userPhone = ''
    this.userAge = 0
    this.userGender = ''
    this.avatarUrl = ''
  }

  // 头像路径统一处理
  private normalizeAvatarUrl(rawAvatar: string): string {
    return normalizeAvatarUrlForDisplay(rawAvatar)
  }

  // 比较头像是否相同，比较前先去掉 query 参数
  private isSameAvatar(nextUrl: string): boolean {
    return stripAvatarQuery(this.avatarUrl) === stripAvatarQuery(nextUrl)
  }

  // 兼容不同接口返回结构，统一解析数量
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

  /**
   * 加载用户信息
   * 已登录后请求后端最新资料
   * 成功后更新页面 @State，并同步回 AuthService 和 Preferences
   */
  async loadUserInfo(): Promise<void> {
    if (this.isRefreshingUserInfo) {
      return
    }

    this.isRefreshingUserInfo = true

    try {
      this.isLoggedIn = this.authService.isLoggedIn()

      // 未登录就不请求后端用户信息
      if (!this.isLoggedIn) {
        this.resetUserState()
        return
      }

      // 请求前先展示本地信息，提升页面响应速度
      const localUser = this.authService.getUserInfo()
      this.applyLocalUserInfo()

      // 请求后端最新用户信息
      // ApiService 会在请求头里携带 token
      const res = await this.apiService.getUserInfo()

      if (res.code === 200 && res.data) {
        const user: UserProfileData = res.data as UserProfileData

        const latestName: string = user.nickname ? user.nickname : '用户'
        const latestPhone: string = user.phone ? user.phone : ''
        const backendAvatarPath: string = user.avatar ? String(user.avatar) : ''
        const backendAvatarUrl: string = this.normalizeAvatarUrl(backendAvatarPath)

        // 更新页面展示状态
        this.userName = latestName
        this.userPhone = latestPhone
        this.userAge = user.age ? user.age : 0
        this.userGender = user.gender !== undefined && user.gender !== null ? String(user.gender) : ''
        this.backendUserId = user.id ? Number(user.id) : 0

        Logger.info(TAG, `当前后端用户ID: ${this.backendUserId}, phone=${this.userPhone}`)

        // 如果后端头像和当前头像不同，就刷新头像
        if (backendAvatarUrl && !this.isSameAvatar(backendAvatarUrl)) {
          this.avatarUrl = backendAvatarUrl
        }

        // 把后端最新资料同步回 AuthService
        // 这样其他页面和下次启动也能拿到最新用户信息
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

        // 用户信息加载成功后，再加载日记数和测评数
        this.loadStatistics()

        Logger.info(TAG, `后端用户信息: ${this.userName}, phone: ${this.userPhone}, avatar: ${this.avatarUrl}`)
      } else {
        Logger.error(TAG, `加载用户信息失败: code=${res.code}`)
      }
    } catch (error) {
      Logger.error(TAG, `加载用户信息失败: ${JSON.stringify(error)}`)
    } finally {
      // 无论成功失败，都结束用户信息加载状态
      this.isUserInfoLoading = false
      this.isRefreshingUserInfo = false

      // 记录本次远程刷新时间，避免频繁切换 Tab 时重复请求后端
      this.lastUserInfoRefreshTime = Date.now()
    }
  }

  // 兼容数组、data、records、list、items 等不同列表结构
  private unwrapArrayData(response: Object): Object[] {
    if (Array.isArray(response)) {
      return response as Object[]
    }

    const wrapped = response as Record<string, Object>

    if (wrapped['data'] && Array.isArray(wrapped['data'])) {
      return wrapped['data'] as Object[]
    }

    if (wrapped['records'] && Array.isArray(wrapped['records'])) {
      return wrapped['records'] as Object[]
    }

    if (wrapped['list'] && Array.isArray(wrapped['list'])) {
      return wrapped['list'] as Object[]
    }

    if (wrapped['items'] && Array.isArray(wrapped['items'])) {
      return wrapped['items'] as Object[]
    }

    return []
  }

  /**
   * 加载个人中心统计数据
   * 包括日记数量、测评记录数量、收藏数量
   */
  loadStatistics(): void {
    // 未登录或没有有效后端用户 id，就不加载统计
    if (!this.isLoggedIn || this.backendUserId <= 0) {
      this.diaryCount = 0
      this.assessmentCount = 0
      this.favoriteCount = 0
      return
    }

    // 加载日记数量
    this.apiService.getDiaryList().then((res) => {
      if (res.code === 200 && res.data) {
        this.diaryCount = this.parseCount(res.data as Object)
      } else {
        this.diaryCount = 0
      }
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, `加载日记统计失败: ${error.message}`)
      this.diaryCount = 0
    })

    // 加载测评记录数量
    this.apiService.getAssessmentResults().then((res) => {
      if (Array.isArray(res)) {
        this.assessmentCount = res.length
      } else if (res.code === 200 && res.data && Array.isArray(res.data)) {
        this.assessmentCount = res.data.length
      } else {
        this.assessmentCount = 0
      }
    }).catch((error: Error) => {
      hilog.error(DOMAIN, TAG, `加载测评记录统计失败: ${error.message}`)
      this.assessmentCount = 0
    })

    // 收藏功能目前只保留入口，统计接口后续再接
    this.favoriteCount = 0
  }

  // 把后端可能返回的性别值转换成页面展示文案
  private getGenderText(): string {
    const value: string = this.userGender.trim().toLowerCase()

    if (value === 'male' || value === 'm' || value === 'man' || value === '1' || value === '男') {
      return '男'
    }

    if (value === 'female' || value === 'f' || value === 'woman' || value === '2' || value === '女') {
      return '女'
    }

    return '未填写'
  }

  // 根据菜单 id 返回图标背景色
  private getMenuBadgeBg(id: string): string {
    switch (id) {
      case 'profile':
        return LightTheme.TagBlue
      case 'records':
        return LightTheme.TagGreen
      case 'favorites':
        return '#F7EDEF'
      case 'settings':
        return LightTheme.SurfaceSoft
      case 'help':
        return LightTheme.TagOrange
      case 'about':
        return '#F1EEF8'
      default:
        return LightTheme.SurfaceSoft
    }
  }

  // 根据菜单 id 返回图标文字色
  private getMenuBadgeColor(id: string): string {
    switch (id) {
      case 'profile':
        return LightTheme.Primary
      case 'records':
        return LightTheme.Secondary
      case 'favorites':
        return '#C88493'
      case 'settings':
        return LightTheme.TextSecondary
      case 'help':
        return LightTheme.Warning
      case 'about':
        return '#8D83B8'
      default:
        return LightTheme.TextSecondary
    }
  }

  build() {
    Column() {
      AppPageHeader({
        title: '我的',
        subtitle: '把状态看见，也把自己照顾好'
      })

      Scroll() {
        Column() {
          // 已登录：展示用户资料、统计、菜单和退出登录
          if (this.isLoggedIn) {
            this.buildUserCard()
            this.buildStatsCard()
            this.buildQuickActionCard()
            this.buildMenuList()
            this.buildLogoutButton()
          } else {
            // 未登录：展示登录引导
            this.buildLoginPrompt()
          }
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 6,
          bottom: Dimension.SpaceXXL
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      AppBottomNav({
        currentTab: this.currentTab
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(LightTheme.Background)
  }

  // 未登录时展示的登录引导卡片
  @Builder
  buildLoginPrompt() {
    Column() {
      Column() {
        Text('欢迎回来')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightTheme.TextPrimary)

        Text('登录后查看个人资料、记录和收藏')
          .fontSize(14)
          .fontColor(LightTheme.TextSecondary)
          .margin({ top: 10 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ bottom: 28 })

      Button('去登录')
        .width('76%')
        .height(Dimension.ButtonHeight)
        .fontSize(16)
        .fontColor(LightTheme.TextWhite)
        .backgroundColor(LightTheme.Primary)
        .borderRadius(24)
        .onClick(() => {
          this.handleLogin()
        })
    }
    .width('100%')
    .padding({ top: 64, bottom: 64 })
    .backgroundColor(LightTheme.Card)
    .borderRadius(20)
  }

  // 头像展示，加载时用占位圆形
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
      .backgroundColor(LightTheme.SurfaceSoft)
    }
  }

  // 用户资料卡片：头像、昵称、手机号、年龄、性别、编辑入口
  @Builder
  buildUserCard() {
    Column() {
      Row() {
        this.buildAvatarView()

        Column() {
          Text(this.userName)
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor(LightTheme.TextPrimary)

          if (this.userPhone) {
            Text(this.userPhone)
              .fontSize(13)
              .fontColor(LightTheme.TextSecondary)
              .margin({ top: 6 })
          }

          Text(`年龄：${this.userAge > 0 ? this.userAge.toString() : '未填写'}   性别：${this.getGenderText()}`)
            .fontSize(12)
            .fontColor(LightTheme.TextTertiary)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
        .layoutWeight(1)

        Button('编辑资料')
          .height(34)
          .fontSize(13)
          .fontColor(LightTheme.Primary)
          .backgroundColor(LightTheme.TagBlue)
          .borderRadius(17)
          .onClick(() => {
            router.pushUrl({ url: 'pages/me/ProfileEditPage' })
          })
      }
      .width('100%')

      Text('把状态看见，也把自己照顾好')
        .fontSize(13)
        .fontColor(LightTheme.TextSecondary)
        .width('100%')
        .margin({ top: 16 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(LightTheme.Card)
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  // 统计卡片：日记数量、测评记录数量、收藏数量
  @Builder
  buildStatsCard() {
    Row() {
      Column() {
        Text(`${this.diaryCount}`)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightTheme.Primary)

        Text('日记')
          .fontSize(12)
          .fontColor(LightTheme.TextTertiary)
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .onClick(() => {
        // 日记页是一级 Tab 页面，和“我的”平级，用 replaceUrl
        router.replaceUrl({ url: 'pages/diary/MoodDiaryPage' })
      })

      Column() {
        Text(`${this.assessmentCount}`)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(LightTheme.Secondary)

        Text('测评记录')
          .fontSize(12)
          .fontColor(LightTheme.TextTertiary)
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .onClick(() => {
        router.pushUrl({ url: 'pages/me/MyRecordsPage' })
      })

      Column() {
        Text(`${this.favoriteCount}`)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#C88493')

        Text('收藏')
          .fontSize(12)
          .fontColor(LightTheme.TextTertiary)
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .onClick(() => {
        AlertDialog.show({
          title: '我的收藏',
          message: '收藏功能下一步继续开发，先把入口保留出来。',
          primaryButton: { value: '知道了', action: () => {} }
        })
      })
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .backgroundColor(LightTheme.Card)
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  // 单个统计项 Builder，目前保留，后续可以复用优化 buildStatsCard
  @Builder
  buildStatItem(value: string, label: string, color: string, url: string) {
    Column() {
      Text(value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)

      Text(label)
        .fontSize(12)
        .fontColor(LightTheme.TextTertiary)
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .onClick(() => {
      router.pushUrl({ url: url })
    })
  }

  // 收藏统计项，目前入口保留，具体收藏功能后续完善
  @Builder
  buildFavoriteStat() {
    Column() {
      Text(this.favoriteCount.toString())
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#C88493')

      Text('收藏')
        .fontSize(12)
        .fontColor(LightTheme.TextTertiary)
        .margin({ top: 6 })
    }
    .layoutWeight(1)
    .onClick(() => {
      AlertDialog.show({
        title: '我的收藏',
        message: '收藏功能下一步继续开发，先把入口保留出来。',
        primaryButton: { value: '知道了', action: () => {} }
      })
    })
  }

  // 快捷操作：写日记、做测评
  @Builder
  buildQuickActionCard() {
    Row() {
      Button('写日记')
        .layoutWeight(1)
        .height(46)
        .fontSize(15)
        .fontColor(LightTheme.TextWhite)
        .backgroundColor(LightTheme.Primary)
        .borderRadius(23)
        .onClick(() => {
          // 写日记是二级业务页面，需要支持返回个人中心
          router.pushUrl({ url: 'pages/diary/DiaryEditPage' })
        })

      Blank()
        .width(12)

      Button('做测评')
        .layoutWeight(1)
        .height(46)
        .fontSize(15)
        .fontColor(LightTheme.Primary)
        .backgroundColor(LightTheme.SurfaceSoft)
        .borderRadius(23)
        .onClick(() => {
          // 状态自查列表页是一级 Tab 页面，和“我的”平级，用 replaceUrl
          router.replaceUrl({ url: 'pages/assessment/AssessmentsPage' })
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(LightTheme.Card)
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  // 菜单列表，通过 menuItems 数组循环渲染
  @Builder
  buildMenuList() {
    Column() {
      ForEach(this.menuItems, (item: MenuItem, index: number) => {
        Row() {
          Row() {
            Text(item.icon)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getMenuBadgeColor(item.id))
          }
          .width(34)
          .height(34)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.getMenuBadgeBg(item.id))
          .borderRadius(17)

          Column() {
            Text(item.title)
              .fontSize(16)
              .fontColor(LightTheme.TextPrimary)
              .fontWeight(FontWeight.Medium)

            if (item.subtitle) {
              Text(item.subtitle)
                .fontSize(12)
                .fontColor(LightTheme.TextTertiary)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          .layoutWeight(1)

          if (item.showArrow) {
            Text('›')
              .fontSize(20)
              .fontColor(LightTheme.TextTertiary)
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
            .color(LightTheme.Divider)
            .margin({ left: 62 })
        }
      })
    }
    .width('100%')
    .backgroundColor(LightTheme.Card)
    .borderRadius(20)
    .margin({ bottom: 16 })
  }

  // 退出登录按钮
  @Builder
  buildLogoutButton() {
    Button('退出登录')
      .width('100%')
      .height(Dimension.ButtonHeight)
      .fontSize(16)
      .fontColor(LightTheme.Danger)
      .backgroundColor(LightTheme.Card)
      .borderRadius(18)
      .onClick(() => {
        this.handleLogout()
      })
  }

  // 未登录时点击“去登录”
  async handleLogin(): Promise<void> {
    try {
      router.pushUrl({ url: 'pages/auth/LoginPage' })
    } catch (error) {
      hilog.error(DOMAIN, TAG, `跳转失败: ${error}`)
    }
  }

  // 菜单点击分发
  handleMenuClick(id: string): void {
    if (id === 'profile') {
      router.pushUrl({ url: 'pages/me/ProfileEditPage' })
      return
    }

    if (id === 'records') {
      router.pushUrl({ url: 'pages/me/MyRecordsPage' })
      return
    }

    if (id === 'favorites') {
      router.pushUrl({ url: 'pages/me/FavoritesPage' })
      return
    }

    if (id === 'settings') {
      router.pushUrl({ url: 'pages/me/SettingsPage' })
      return
    }

    if (id === 'help') {
      router.pushUrl({ url: 'pages/me/HelpFeedbackPage' })
      return
    }

    AlertDialog.show({
      title: '关于我们',
      message: '这是一个情绪记录、状态自查与 AI 陪伴的 HarmonyOS NEXT 全栈项目。',
      primaryButton: { value: '知道了', action: () => {} }
    })
  }

  /**
   * 退出登录
   * 清理 AuthService 登录态、页面状态和路由栈
   */
  handleLogout(): void {
    AlertDialog.show({
      title: '退出登录',
      message: '确定要退出登录吗？',
      primaryButton: {
        value: '确定',
        action: async () => {
          try {
            // 调用认证服务退出登录
            // 内部会清空 userInfo、ApiService token 和 Preferences
            await this.authService.logout()

            // 清空当前页面展示状态
            this.resetUserState()

            try {
              // 清空路由栈，避免退出后返回到已登录页面
              router.clear()
            } catch (clearError) {
              hilog.error(DOMAIN, TAG, `清空路由栈失败: ${JSON.stringify(clearError)}`)
            }

            // 跳转登录页
            router.replaceUrl({ url: 'pages/auth/LoginPage' })
          } catch (error) {
            hilog.error(DOMAIN, TAG, `退出登录失败: ${error}`)
          }
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  // 当前页面保留的登录校验方法，后续如果需要也可以复用
  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}