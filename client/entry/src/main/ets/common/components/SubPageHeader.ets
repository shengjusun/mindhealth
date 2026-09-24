import { AppPageHeader } from './AppPageHeader'

@ComponentV2
export struct SubPageHeader {
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param rightText: string = ''

  build() {
    AppPageHeader({
      title: this.title,
      subtitle: this.subtitle,
      showBack: true,
      actionText: this.rightText
    })
  }
}