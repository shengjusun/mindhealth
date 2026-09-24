/**
 * 通用头像组件
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
    if (this.hasValidUrl()) {
      Image(this.avatarUrl)
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(this.shape === 'circle' ? this.avatarSize / 2 : 0)
        .border(this.showBorder ? { width: 2, color: $r('app.color.theme_primary') } : undefined)
        .alt(this.defaultAvatar)
        .objectFit(ImageFit.Cover)
    } else {
      Image(this.defaultAvatar)
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(this.shape === 'circle' ? this.avatarSize / 2 : 0)
        .border(this.showBorder ? { width: 2, color: $r('app.color.theme_primary') } : undefined)
        .objectFit(ImageFit.Cover)
    }
  }
}