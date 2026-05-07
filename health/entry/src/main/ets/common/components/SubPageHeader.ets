import { AppPageHeader } from './AppPageHeader'

@Component
export struct SubPageHeader {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop rightText: string = ''

  build() {
    AppPageHeader({
      title: this.title,
      subtitle: this.subtitle,
      showBack: true,
      actionText: this.rightText
    })
  }
}