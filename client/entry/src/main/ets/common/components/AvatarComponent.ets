import { brand } from '../constants/Theme'

/**
 * 通用头像组件
 *
 * 圆形实现用「容器裁切」：圆角与 clip 挂在外层 Stack 上，Image 只负责填充。
 * （对该平板上仍渲染为方图的现象已记录，详见 ui-redesign-notes.md——用户决定暂不追。）
 */
@ComponentV2
export struct AvatarComponent {
  @Param avatarUrl: string = ''
  @Param avatarSize: number = 48
  @Param shape: 'circle' | 'square' = 'circle'
  @Param showBorder: boolean = false

  private defaultAvatar: Resource = $r('app.media.ic_avatar_default')

  private hasValidUrl(): boolean {
    return this.avatarUrl !== undefined &&
      this.avatarUrl !== null &&
      this.avatarUrl.trim().length > 0
  }

  build() {
    Stack() {
      if (this.hasValidUrl()) {
        Image(this.avatarUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .alt(this.defaultAvatar)
      } else {
        Image(this.defaultAvatar)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .borderRadius(this.shape === 'circle' ? this.avatarSize / 2 : 0)
    .clip(true)
    .border(this.showBorder ? { width: 2, color: brand().primary } : undefined)
  }
}
