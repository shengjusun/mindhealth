/**
 * 通用头像组件
 */

@Component
export struct AvatarComponent {
  @Prop avatarUrl: string = ''
  @Prop avatarSize: number = 48
  @Prop shape: 'circle' | 'square' = 'circle'
  @Prop showBorder: boolean = false

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
        .border(this.showBorder ? { width: 2, color: '#7FA9C9' } : undefined)
        .alt(this.defaultAvatar)
        .objectFit(ImageFit.Cover)
    } else {
      Image(this.defaultAvatar)
        .width(this.avatarSize)
        .height(this.avatarSize)
        .borderRadius(this.shape === 'circle' ? this.avatarSize / 2 : 0)
        .border(this.showBorder ? { width: 2, color: '#7FA9C9' } : undefined)
        .objectFit(ImageFit.Cover)
    }
  }
}