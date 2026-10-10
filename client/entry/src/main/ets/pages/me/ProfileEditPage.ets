import { Logger } from '../../common/utils/Logger'
import { appState, AppState, popRoute, resetRoute } from '../../common/state/AppState'
import { AvatarService } from '../../core/services/AvatarService'
import { AuthService, UserAuthInfo } from '../../core/auth/AppAuthService'
import { AvatarComponent } from '../../common/components/AvatarComponent'
import { AppButton } from '../../common/components/AppButton'
import { ApiService } from '../../core/api/ApiService'
import { brand, ShadowStyle, Dimension, FontLevel } from '../../common/constants/Theme'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { ApiConfig } from '../../common/constants/apiConfig'
import { ErrorText } from '../../common/utils/ErrorText'

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

  // 页面上展示的性别选项：第三项为「隐藏」（保密式设计，存储值 hidden）
  genders: string[] = ['男', '女', '隐藏']

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
          bottom: Dimension.SpaceXXL + this.state.bottomIndicatorVp
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

    if (value === 'other' || value === 'others' || value === '3' || value === '其他'
      || value === 'hidden' || value === '隐藏') {
      return '隐藏'
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
    if (displayGender === '隐藏') {
      return 'hidden'
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

        // 头像只可能来自「上传」，页面没有让用户手改 URL 的入口，因此它和表单脏状态无关：
        // 必须始终按后端最新值回显。否则「先改昵称/签名，再换头像」时会被下面的守卫挡掉，
        // 出现「提示上传成功、页面却还是旧头像」的假成功。
        // 注意顺序：先应用头像，再在可覆盖时 syncOriginalForm，保证原始值抓到的是新头像。
        this.avatarUrl = displayAvatar

        if (canOverwriteForm) {
          this.userName = user.nickname ? user.nickname : ''
          this.userPhone = user.phone ? user.phone : ''
          this.userAge = user.age !== undefined ? String(user.age) : ''
          this.userGender = this.normalizeGenderForDisplay(user.gender ? String(user.gender) : '')
          this.userSignature = user.signature ? user.signature : ''

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
      ToastUtil.show(ErrorText.network())
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
        ToastUtil.show('请先登录后再更换头像')
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
        // 传 true 强制给头像 URL 加时间戳：即使后端文件名未变，也能破系统图片缓存（双保险）
        await this.loadUserInfo(true)

        ToastUtil.show('头像上传成功')
      } else {
        ToastUtil.show(result.errorMessage || '头像上传失败，请稍后重试')
      }
    } catch (error) {
      Logger.error(TAG, `更换头像失败: ${JSON.stringify(error)}`)
      ToastUtil.show(ErrorText.action())
    }
  }

  // 顶部标题栏（HTML navbar：56vp 内容高 + 返回 + 居中标题；顶部避让动态化 D7）
  @Builder
  buildHeader() {
    Row() {
      Row() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.handleBack()
      })

      Text('编辑资料')
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank()
        .width(40)
    }
    .width('100%')
    .height(this.state.topAvoidVp > 0 ? this.state.topAvoidVp + Dimension.HeaderHeight : 70)
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: this.state.topAvoidVp > 0 ? this.state.topAvoidVp : 14,
      bottom: 8
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
        .fontColor(brand().primary)
        .fontWeight(FontWeight.Medium)
        .onClick(() => {
          this.onChangeAvatar()
        })
    }
    .width('100%')
    .padding(Dimension.CardPaddingHero)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(Dimension.HeroCardRadius)
    .shadow(ShadowStyle.Card)
    .margin({ bottom: Dimension.SpaceXXL })
  }

  // 基本信息表单：分区标题在卡片外（HTML form-group-title），行高 56、行间细分隔线、值列统一左对齐
  @Builder
  buildBasicInfo() {
    Column() {
      Text('基本信息')
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: Dimension.SpaceM })

      Column() {
        Row() {
          Text('昵称')
            .fontSize(FontLevel.Aux)
            .fontColor($r('app.color.text_tertiary'))
            .width(80)

          TextInput({ placeholder: '请输入昵称', text: this.userName })
            .layoutWeight(1)
            .height(36)
            .fontSize(FontLevel.Body)
            .maxLength(50)
            .backgroundColor($r('app.color.surface_soft'))
            .borderRadius(Dimension.RadiusS)
            .onChange((value: string) => {
              this.userName = value
            })
        }
        .height(56)
        .width('100%')

        Divider()
          .color($r('app.color.app_divider'))

        Row() {
          Text('性别')
            .fontSize(FontLevel.Aux)
            .fontColor($r('app.color.text_tertiary'))
            .width(80)

          // HTML 分段控件：外层 36 圆角胶囊 bg-subtle，三段等宽 72
          Row({ space: Dimension.Space2XS }) {
            ForEach(this.genders, (gender: string) => {
              Text(gender)
                .width(72)
                .height(32)
                .borderRadius(Dimension.RadiusFull)
                .fontSize(FontLevel.Body)
                .fontColor(this.userGender === gender ? $r('app.color.text_on_primary') : $r('app.color.text_tertiary'))
                .fontWeight(this.userGender === gender ? FontWeight.Medium : FontWeight.Normal)
                .backgroundColor(this.userGender === gender ? brand().primary : Color.Transparent)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.userGender = gender
                })
            })
          }
          .height(36)
          .padding(Dimension.Space2XS)
          .borderRadius(Dimension.RadiusFull)
          .backgroundColor($r('app.color.surface_soft'))
          .alignItems(VerticalAlign.Center)
          .layoutWeight(1)
        }
        .height(56)
        .width('100%')

        Divider()
          .color($r('app.color.app_divider'))

        Row() {
          Text('年龄')
            .fontSize(FontLevel.Aux)
            .fontColor($r('app.color.text_tertiary'))
            .width(80)

          TextInput({ placeholder: '请输入年龄', text: this.userAge })
            .layoutWeight(1)
            .height(36)
            .fontSize(FontLevel.Body)
            .type(InputType.Number)
            .maxLength(3)
            .backgroundColor($r('app.color.surface_soft'))
            .borderRadius(Dimension.RadiusS)
            .onChange((value: string) => {
              this.userAge = value
            })
        }
        .height(56)
        .width('100%')

        Divider()
          .color($r('app.color.app_divider'))

        Row() {
          Text('手机号')
            .fontSize(FontLevel.Aux)
            .fontColor($r('app.color.text_tertiary'))
            .width(80)

          if (this.isPhoneEditable) {
            TextInput({ placeholder: '请输入手机号', text: this.userPhone })
              .layoutWeight(1)
              .height(36)
              .fontSize(FontLevel.Body)
              .type(InputType.PhoneNumber)
              .backgroundColor($r('app.color.surface_soft'))
              .borderRadius(Dimension.RadiusS)
              .onChange((value: string) => {
                this.userPhone = value
              })
          } else {
            // HTML form-value.plain：手机号行不用输入框背景
            Text(this.userPhone.length > 0 ? this.userPhone : '未绑定')
              .fontSize(FontLevel.Body)
              .fontColor($r('app.color.text_primary'))
              .layoutWeight(1)
          }

          Text(this.isPhoneEditable ? '完成' : '更换')
            .fontSize(FontLevel.Body)
            .fontColor(brand().primary)
            .fontWeight(FontWeight.Medium)
            .margin({ left: Dimension.SpaceM })
            .onClick(() => {
              this.isPhoneEditable = !this.isPhoneEditable
            })
        }
        .height(56)
        .width('100%')
      }
      .width('100%')
      .padding({
        left: Dimension.SpaceL,
        right: Dimension.SpaceL,
        top: Dimension.Space2XS,
        bottom: Dimension.Space2XS
      })
      .backgroundColor($r('app.color.app_card'))
      .borderRadius(Dimension.CardRadius)
      .shadow(ShadowStyle.Card)
    }
    .width('100%')
    .margin({ bottom: Dimension.SpaceXXL })
  }

  // 个性签名输入区域：分区标题在卡片外（HTML form-group-title）
  @Builder
  buildSignature() {
    Column() {
      Text('个性签名')
        .fontSize(FontLevel.SectionTitle)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: Dimension.SpaceM })

      Column() {
        TextArea({ placeholder: '写点什么介绍一下自己吧...', text: this.userSignature })
          .width('100%')
          .height(100)
          .fontSize(FontLevel.Body)
          .fontColor($r('app.color.text_primary'))
          .backgroundColor($r('app.color.surface_soft'))
          .borderRadius(Dimension.RadiusM)
          .maxLength(50)
          .onChange((value: string) => {
            this.userSignature = value
          })

        Text(`${this.userSignature.length}/50`)
          .fontSize(FontLevel.Caption)
          .fontColor($r('app.color.text_quaternary'))
          .width('100%')
          .textAlign(TextAlign.End)
          .margin({ top: Dimension.Space2XS })
      }
      .width('100%')
      .padding(Dimension.CardPadding)
      .backgroundColor($r('app.color.app_card'))
      .borderRadius(Dimension.CardRadius)
      .shadow(ShadowStyle.Card)
      .margin({ bottom: Dimension.SpaceXXL })
    }
    .width('100%')
  }

  // 保存按钮，通过 isSaving 控制文案和是否可点击
  @Builder
  buildSaveButton() {
    AppButton({
      label: this.isSaving ? '保存中...' : '保存修改',
      kind: 'primary',
      block: true,
      loading: this.isSaving,
      active: !this.isSaving,
      onPress: () => {
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
      if (isNaN(ageNum) || ageNum < 0 || ageNum > 150) {
        AlertDialog.show({
          title: '提示',
          message: '年龄需为 0~150 之间的数字',
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
        const submittedPhone: string = this.userPhone.trim()
        await this.loadUserInfo()

        // D6：后端白名单不收手机号（静默丢弃），提交值与回读值不一致必须明确提示
        if (submittedPhone.length > 0 && this.userPhone.trim() !== submittedPhone) {
          ToastUtil.show('手机号修改暂未生效：当前版本不支持在线改绑')
        }

        // 保存后关闭手机号编辑状态
        this.isPhoneEditable = false

        if (needBack) {
          this.safeBack()
          return
        }

        ToastUtil.show('个人信息已更新')
      } else {
        ToastUtil.show(res.message ? res.message : '更新失败，请稍后重试')
      }
    } catch (error) {
      Logger.error(TAG, `保存个人信息失败: ${JSON.stringify(error)}`)
      ToastUtil.show(ErrorText.network())
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
