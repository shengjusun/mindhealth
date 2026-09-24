import { Logger } from '../../common/utils/Logger'
import { appState, AppState, popRoute, resetRoute } from '../../common/state/AppState'
import { AvatarService } from '../../core/services/AvatarService'
import { AuthService, UserAuthInfo } from '../../core/auth/AppAuthService'
import { AvatarComponent } from '../../common/components/AvatarComponent'
import { ApiService } from '../../core/api/ApiService'
import { Dimension } from '../../common/constants/Theme'
import { ApiConfig } from '../../common/constants/apiConfig'

const TAG = 'ProfileEditPage'

// 后端返回的用户资料结构
interface UserProfileData {
  id?: number
  nickname?: string
  phone?: string
  avatar?: string
  age?: number
  gender?: string
  signature?: string
}

// 修改用户资料时传给后端的请求体
interface UpdateUserRequest {
  nickname: string
  gender: string
  signature: string
  avatar?: string
  phone?: string
  age?: number
}

@ComponentV2
export struct ProfileEditPage {
  // 表单当前输入状态
  @Local userName: string = ''
  @Local userGender: string = ''
  @Local userAge: string = ''
  @Local userPhone: string = ''
  @Local userSignature: string = ''
  @Local avatarUrl: string = ''

  // 保存按钮 loading 状态，防止重复点击
  @Local isSaving: boolean = false

  // 手机号是否处于可编辑状态
  @Local isPhoneEditable: boolean = false

  // 原始表单数据，用来判断用户是否修改过资料
  @Local originalUserName: string = ''
  @Local originalUserGender: string = ''
  @Local originalUserAge: string = ''
  @Local originalUserPhone: string = ''
  @Local originalUserSignature: string = ''
  @Local originalAvatarUrl: string = ''

  // 用于 @Monitor 监听路由层转发过来的返回手势
  @Local state: AppState = appState()

  // 页面上展示的性别选项
  genders: string[] = ['男', '女', '其他']

  private authService: AuthService = AuthService.getInstance()
  private avatarService: AvatarService = AvatarService.getInstance()
  private apiService: ApiService = ApiService.getInstance()

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column() {
          this.buildAvatarSection()
          this.buildBasicInfo()
          this.buildSignature()
          this.buildSaveButton()
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
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  aboutToAppear(): void {
    if (!this.ensureLogin()) {
      return
    }

    // 先用 AuthService 本地用户信息快速回显，避免页面先空白再跳动
    this.applyLocalUserInfoToForm()

    // 再请求后端最新资料
    // 普通加载不强制给头像加时间戳，避免头像每次进入都重新加载
    this.loadUserInfo(false)
  }
  /**
   * 先从 AuthService 读取本地用户信息，快速回显表单
   * 这样进入编辑资料页时不会先显示空表单再跳动
   */
  private applyLocalUserInfoToForm(): void {
    const localUser = this.authService.getUserInfo()

    if (!localUser) {
      return
    }

    this.userName = localUser.displayName || ''
    this.userPhone = localUser.phoneNumber || ''

    const localAvatarUrl: string = this.normalizeAvatarUrl(localUser.photoUrl || '')
    if (localAvatarUrl) {
      this.avatarUrl = localAvatarUrl
    }

    // 本地用户信息里通常没有年龄、性别、签名
    // 这些仍然等后端 getUserInfo 返回后补齐

    // 先记录当前表单状态，避免进入页面后立刻被判断为“已修改”
    this.syncOriginalForm()
  }

  /**
   * V2 组件不支持 onBackPress —— 编译器不报错，但运行时不会触发，属于静默失效。
   * 改由 NavDestination.onBackPressed 递增 AppState.backPressedTick，这里监听后执行确认逻辑。
   */
  @Monitor('state.backPressedTick')
  onBackPressed(): void {
    this.handleBack()
  }

  // 表单任一字段变化时，把「是否脏」同步到全局，供路由层的 onBackPressed 判断是否拦截
  @Monitor('userName', 'userGender', 'userAge', 'userPhone', 'userSignature', 'avatarUrl')
  onFormChange(): void {
    appState().hasUnsavedChanges = this.hasFormChanged()
  }

  aboutToDisappear(): void {
    // 脏标记是全局共享的，离开页面必须清掉，否则会污染其他页面的返回拦截
    appState().hasUnsavedChanges = false
  }

  // 安全返回上一页
  private safeBack(): void {
    try {
      popRoute()
    } catch (error) {
      Logger.error(TAG, `返回失败: ${JSON.stringify(error)}`)
    }
  }

  // 获取后端服务根地址，用来拼接头像完整访问路径
  private getServerOrigin(): string {
    const apiBase: string = ApiConfig.API_BASE_URL
    if (apiBase.endsWith('/api')) {
      return apiBase.substring(0, apiBase.length - 4)
    }
    return apiBase
  }

  /**
   * 把后端返回的头像路径转换成页面能直接展示的完整 URL
   * 后端可能返回完整 URL、/api/uploads、/uploads 或文件名
   */
  private normalizeAvatarUrl(rawAvatar: string): string {
    if (!rawAvatar || rawAvatar.trim().length === 0) {
      return ''
    }

    const serverOrigin: string = this.getServerOrigin()

    if (rawAvatar.startsWith('http://') || rawAvatar.startsWith('https://')) {
      return rawAvatar
    }

    if (rawAvatar.startsWith('/api/')) {
      return serverOrigin + rawAvatar
    }

    if (rawAvatar.startsWith('/uploads/')) {
      return serverOrigin + '/api' + rawAvatar
    }

    const apiUploadIndex: number = rawAvatar.indexOf('/api/uploads/')
    if (apiUploadIndex >= 0) {
      return serverOrigin + rawAvatar.substring(apiUploadIndex)
    }

    const uploadIndex: number = rawAvatar.indexOf('/uploads/')
    if (uploadIndex >= 0) {
      return serverOrigin + '/api' + rawAvatar.substring(uploadIndex)
    }

    if (rawAvatar.indexOf('/') < 0) {
      return serverOrigin + '/api/uploads/avatars/' + rawAvatar
    }

    if (rawAvatar.startsWith('/')) {
      return serverOrigin + rawAvatar
    }

    return serverOrigin + '/api/' + rawAvatar
  }

  /**
   * 给头像 URL 加时间戳
   * 作用：避免浏览器 / 系统缓存导致头像上传成功后页面还显示旧头像
   */
  private addAvatarTimestamp(url: string): string {
    if (!url || url.trim().length === 0) {
      return ''
    }

    const qIndex: number = url.indexOf('?')
    const cleanUrl: string = qIndex >= 0 ? url.substring(0, qIndex) : url
    return cleanUrl + '?t=' + Date.now()
  }

  /**
   * 保存资料时，把页面展示用的完整头像 URL 转成后端需要保存的路径
   * 比如完整 URL 转回 /api/uploads/avatars/xxx.jpg
   */
  private toBackendAvatarPath(url: string): string {
    if (!url || url.trim().length === 0) {
      return ''
    }

    const qIndex: number = url.indexOf('?')
    const cleanUrl: string = qIndex >= 0 ? url.substring(0, qIndex) : url
    const serverOrigin: string = this.getServerOrigin()
    const apiBase: string = ApiConfig .API_BASE_URL

    if (cleanUrl.startsWith(serverOrigin + '/api/')) {
      return cleanUrl.substring(serverOrigin.length)
    }

    if (cleanUrl.startsWith(apiBase + '/')) {
      const rest: string = cleanUrl.substring(apiBase.length)
      if (rest.startsWith('/')) {
        return '/api' + rest
      }
    }

    if (cleanUrl.startsWith('/api/')) {
      return cleanUrl
    }

    if (cleanUrl.startsWith('/uploads/')) {
      return '/api' + cleanUrl
    }

    return cleanUrl
  }

  // 后端性别值转成页面展示值
  private normalizeGenderForDisplay(rawGender: string): string {
    const value: string = rawGender.trim().toLowerCase()

    if (value === 'male' || value === 'm' || value === '1' || value === '男') {
      return '男'
    }

    if (value === 'female' || value === 'f' || value === '2' || value === '女') {
      return '女'
    }

    if (value === 'other' || value === 'others' || value === '3' || value === '其他') {
      return '其他'
    }

    return rawGender
  }

  // 页面展示的中文性别转成后端需要的英文值
  private toBackendGenderValue(displayGender: string): string {
    if (displayGender === '男') {
      return 'male'
    }
    if (displayGender === '女') {
      return 'female'
    }
    if (displayGender === '其他') {
      return 'other'
    }
    return displayGender
  }

  // 判断当前表单是否有修改
  private hasFormChanged(): boolean {
    return this.userName !== this.originalUserName ||
      this.userGender !== this.originalUserGender ||
      this.userAge !== this.originalUserAge ||
      this.userPhone !== this.originalUserPhone ||
      this.userSignature !== this.originalUserSignature ||
      this.avatarUrl !== this.originalAvatarUrl
  }

  // 记录当前表单为原始状态，用于后续判断是否修改过
  private syncOriginalForm(): void {
    this.originalUserName = this.userName
    this.originalUserGender = this.userGender
    this.originalUserAge = this.userAge
    this.originalUserPhone = this.userPhone
    this.originalUserSignature = this.userSignature
    this.originalAvatarUrl = this.avatarUrl

    // 必须主动清脏标记：@Monitor 监听的是表单字段，用后端数据填充表单时会触发
    // onFormChange，而此刻原值还是旧的、会被误判成「已修改」；
    // 同步原值又不改变表单字段，不会再触发一次监听来纠正。
    appState().hasUnsavedChanges = false
  }

  /**
   * 返回前处理
   * 如果表单没修改，直接返回
   * 如果表单修改过，提示用户保存或不保存
   */
  private handleBack(): void {
    if (!this.hasFormChanged()) {
      this.safeBack()
      return
    }

    AlertDialog.show({
      title: '提示',
      message: '当前信息已修改，是否保存后再返回？',
      primaryButton: {
        value: '保存',
        action: () => {
          this.saveProfile(true)
        }
      },
      secondaryButton: {
        value: '不保存',
        action: () => {
          this.safeBack()
        }
      }
    })
  }

  /**
   * 加载用户资料
   * 页面进入后调用，用于表单回显
   * 同时会把后端最新资料同步回 AuthService
   */
  /**
   * 加载用户资料
   *
   * forceAvatarRefresh:
   * true  表示刚上传头像成功，需要给头像 URL 加时间戳，强制刷新图片缓存
   * false 表示普通加载，不加时间戳，避免每次进入页面头像都跳动
   */
  async loadUserInfo(forceAvatarRefresh: boolean = false): Promise<void> {
    try {
      const oldUser = this.authService.getUserInfo()

      if (!oldUser || !oldUser.isLoggedIn) {
        resetRoute('LoginPage')
        return
      }

      // 请求后端当前用户信息
      // ApiService 会自动携带 token
      const res = await this.apiService.getUserInfo()

      if (res.code === 200 && res.data) {
        const user: UserProfileData = res.data as UserProfileData

        const backendAvatarPath: string = user.avatar ? String(user.avatar) : ''
        const normalizedAvatarUrl: string = this.normalizeAvatarUrl(backendAvatarPath)

        // 普通加载不加时间戳，避免每次进入编辑页头像都重新加载
        // 只有刚上传头像成功后，才 forceAvatarRefresh 加时间戳防缓存
        const displayAvatar: string = forceAvatarRefresh
          ? this.addAvatarTimestamp(normalizedAvatarUrl)
          : normalizedAvatarUrl

        // 如果用户已经开始编辑表单，就不要用后端返回覆盖用户正在输入的内容
        // 避免请求回来后把用户刚输入的内容冲掉
        const canOverwriteForm: boolean = !this.hasFormChanged()

        if (canOverwriteForm) {
          this.userName = user.nickname ? user.nickname : ''
          this.userPhone = user.phone ? user.phone : ''
          this.userAge = user.age !== undefined ? String(user.age) : ''
          this.userGender = this.normalizeGenderForDisplay(user.gender ? String(user.gender) : '')
          this.userSignature = user.signature ? user.signature : ''
          this.avatarUrl = displayAvatar

          // 当前表单加载完成后，记录一份原始值
          this.syncOriginalForm()
        }

        // 同步 AuthService 本地用户信息
        // 这样返回 MePage 或下次启动时能拿到最新资料
        const newUserInfo: UserAuthInfo = {
          uid: oldUser.uid,
          displayName: user.nickname ? user.nickname : oldUser.displayName,
          photoUrl: backendAvatarPath || oldUser.photoUrl || '',
          email: oldUser.email,
          phoneNumber: user.phone ? user.phone : oldUser.phoneNumber,
          accessToken: oldUser.accessToken,
          refreshToken: oldUser.refreshToken,
          isLoggedIn: oldUser.isLoggedIn
        }

        await this.authService.updateUserInfo(newUserInfo)

        Logger.info(TAG, `加载用户信息成功: avatar=${this.avatarUrl}`)
      } else {
        Logger.error(TAG, `加载用户信息失败: code=${res.code}, msg=${res.message}`)
      }
    } catch (error) {
      Logger.error(TAG, `加载用户信息失败: ${JSON.stringify(error)}`)
      AlertDialog.show({
        title: '提示',
        message: '加载用户信息失败，请稍后重试',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
    }
  }

  /**
   * 更换头像
   * 先选择本地图片，再上传到后端
   * 上传成功后重新 loadUserInfo，保证页面和本地登录态同步最新头像
   */
  async onChangeAvatar(): Promise<void> {
    try {
      const userInfo = this.authService.getUserInfo()

      // 未登录不能更换头像
      if (!userInfo || !userInfo.isLoggedIn) {
        AlertDialog.show({
          title: '提示',
          message: '请先登录后再更换头像',
          primaryButton: {
            value: '知道了',
            action: () => {}
          }
        })
        return
      }

      // 选择本地头像图片
      const uri = await this.avatarService.selectAvatar()
      if (!uri) {
        return
      }

      // 上传头像到后端
      const result = await this.avatarService.uploadAvatar(uri)

      if (result.success) {
        // 上传成功后重新从后端拉取用户信息
        // 这样可以拿到后端保存后的头像路径
        await this.loadUserInfo()

        AlertDialog.show({
          title: '成功',
          message: '头像上传成功',
          primaryButton: {
            value: '好的',
            action: () => {}
          }
        })
      } else {
        AlertDialog.show({
          title: '失败',
          message: result.errorMessage || '头像上传失败，请稍后重试',
          primaryButton: {
            value: '知道了',
            action: () => {}
          }
        })
      }
    } catch (error) {
      Logger.error(TAG, `更换头像失败: ${JSON.stringify(error)}`)
      AlertDialog.show({
        title: '错误',
        message: '操作失败，请稍后重试',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
    }
  }

  // 顶部标题栏和返回按钮
  @Builder
  buildHeader() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .borderRadius(Dimension.CardRadius)
      .backgroundColor($r('app.color.app_card'))
      .onClick(() => {
        this.handleBack()
      })

      Column() {
        Text('编辑资料')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Text('完善个人信息')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
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
    .backgroundColor($r('app.color.app_background'))
  }

  // 头像区域：展示头像和更换头像入口
  @Builder
  buildAvatarSection() {
    Column() {
      AvatarComponent({
        avatarUrl: this.avatarUrl,
        avatarSize: 88,
        shape: 'circle'
      })
        .margin({ bottom: 10 })

      Text('更换头像')
        .fontSize(Dimension.FontM)
        .fontColor($r('app.color.theme_primary'))
        .fontWeight(FontWeight.Medium)
        .onClick(() => {
          this.onChangeAvatar()
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  // 基本信息表单：昵称、性别、年龄、手机号
  @Builder
  buildBasicInfo() {
    Column() {
      Text('基本信息')
        .fontSize(Dimension.FontL)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 16 })

      Row() {
        Text('昵称')
          .fontSize(Dimension.FontM)
          .fontColor($r('app.color.text_secondary'))
          .width(60)

        TextInput({ placeholder: '请输入昵称', text: this.userName })
          .layoutWeight(1)
          .height(Dimension.InputHeight)
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(10)
          .onChange((value: string) => {
            this.userName = value
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      Row() {
        Text('性别')
          .fontSize(Dimension.FontM)
          .fontColor($r('app.color.text_secondary'))
          .width(60)

        Row() {
          ForEach(this.genders, (gender: string) => {
            Button(gender)
              .height(32)
              .fontSize(14)
              .fontColor(this.userGender === gender ? $r('app.color.text_on_primary') : $r('app.color.text_secondary'))
              .backgroundColor(this.userGender === gender ? $r('app.color.theme_primary') : $r('app.color.surface_soft'))
              .borderRadius(16)
              .margin({ right: 8 })
              .onClick(() => {
                this.userGender = gender
              })
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 16 })

      Row() {
        Text('年龄')
          .fontSize(Dimension.FontM)
          .fontColor($r('app.color.text_secondary'))
          .width(60)

        TextInput({ placeholder: '请输入年龄', text: this.userAge })
          .layoutWeight(1)
          .height(Dimension.InputHeight)
          .type(InputType.Number)
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(10)
          .onChange((value: string) => {
            this.userAge = value
          })
      }
      .width('100%')
      .margin({ bottom: 16 })

      Row() {
        Text('手机号')
          .fontSize(Dimension.FontM)
          .fontColor($r('app.color.text_secondary'))
          .width(60)

        if (this.isPhoneEditable) {
          TextInput({ placeholder: '请输入手机号', text: this.userPhone })
            .layoutWeight(1)
            .height(Dimension.InputHeight)
            .type(InputType.PhoneNumber)
            .backgroundColor($r('app.color.surface_soft'))
            .borderRadius(10)
            .onChange((value: string) => {
              this.userPhone = value
            })
        } else {
          Text(this.userPhone)
            .fontSize(Dimension.FontM)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }

        Text(this.isPhoneEditable ? '完成' : '更换')
          .fontSize(Dimension.FontM)
          .fontColor($r('app.color.theme_primary'))
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })
          .onClick(() => {
            this.isPhoneEditable = !this.isPhoneEditable
          })
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.surface_soft'))
      .borderRadius(10)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  // 个性签名输入区域
  @Builder
  buildSignature() {
    Column() {
      Text('个性签名')
        .fontSize(Dimension.FontL)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 12 })

      TextArea({ placeholder: '写点什么介绍一下自己吧...', text: this.userSignature })
        .width('100%')
        .height(100)
        .fontSize(Dimension.FontM)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor($r('app.color.surface_soft'))
        .borderRadius(10)
        .maxLength(50)
        .onChange((value: string) => {
          this.userSignature = value
        })

      Text(`${this.userSignature.length}/50`)
        .fontSize(Dimension.FontS)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
        .textAlign(TextAlign.End)
        .margin({ top: 4 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
  }

  // 保存按钮，通过 isSaving 控制文案和是否可点击
  @Builder
  buildSaveButton() {
    Button(this.isSaving ? '保存中...' : '保存修改')
      .width('100%')
      .height(Dimension.ButtonHeight)
      .fontSize(16)
      .fontColor($r('app.color.text_on_primary'))
      .backgroundColor(this.isSaving ? $r('app.color.text_tertiary') : $r('app.color.theme_primary'))
      .borderRadius(24)
      .enabled(!this.isSaving)
      .onClick(() => {
        if (!this.isSaving) {
          this.saveProfile(true)
        }
      })
  }

  /**
   * 保存个人资料
   * needBack 为 true 时，保存成功后返回上一页
   */
  async saveProfile(needBack: boolean): Promise<void> {
    // 昵称不能为空
    if (this.userName.trim() === '') {
      AlertDialog.show({
        title: '提示',
        message: '昵称不能为空',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
      return
    }

    // 年龄可以不填，但填写后必须是数字
    let ageNum: number = 0
    const hasAge: boolean = this.userAge.trim() !== ''

    if (hasAge) {
      ageNum = Number(this.userAge)
      if (isNaN(ageNum)) {
        AlertDialog.show({
          title: '提示',
          message: '年龄格式不正确',
          primaryButton: {
            value: '知道了',
            action: () => {}
          }
        })
        return
      }
    }

    // 进入保存中状态，禁用按钮防止重复提交
    this.isSaving = true

    try {
      // 组装更新资料请求体
      const payload: UpdateUserRequest = {
        nickname: this.userName.trim(),
        gender: this.toBackendGenderValue(this.userGender),
        signature: this.userSignature.trim(),
        avatar: this.toBackendAvatarPath(this.avatarUrl)
      }

      if (this.userPhone.trim() !== '') {
        payload.phone = this.userPhone.trim()
      }

      if (hasAge) {
        payload.age = ageNum
      }

      // 请求后端更新用户资料
      const res = await this.apiService.updateUserInfo(payload)

      if (res.code === 200) {
        // 保存成功后重新加载用户信息
        // 这样可以拿到后端最终保存的数据，并同步 AuthService
        await this.loadUserInfo()

        // 保存后关闭手机号编辑状态
        this.isPhoneEditable = false

        if (needBack) {
          this.safeBack()
          return
        }

        AlertDialog.show({
          title: '保存成功',
          message: '个人信息已更新',
          primaryButton: {
            value: '好的',
            action: () => {}
          }
        })
      } else {
        AlertDialog.show({
          title: '保存失败',
          message: res.message ? res.message : '更新失败，请稍后重试',
          primaryButton: {
            value: '知道了',
            action: () => {}
          }
        })
      }
    } catch (error) {
      Logger.error(TAG, `保存个人信息失败: ${JSON.stringify(error)}`)
      AlertDialog.show({
        title: '保存失败',
        message: '网络异常或服务器错误，请稍后重试',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
    } finally {
      // 无论保存成功还是失败，都结束保存状态
      this.isSaving = false
    }
  }

  // 判断是否已登录，未登录就跳回登录页
  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    resetRoute('LoginPage')
    return false
  }
}