import { AppPageHeader } from './AppPageHeader'

@ComponentV2
export struct SubPageHeader {
  @Param title: string = ''
  @Param subtitle: string = ''
  @Param rightText: string = ''
  // 右上角动作回调；不传时 AppPageHeader 维持纯展示
  @Param onAction: () => void = () => {}

  build() {
    AppPageHeader({
      title: this.title,
      subtitle: this.subtitle,
      showBack: true,
      actionText: this.rightText,
      onAction: (): void => {
        this.onAction()
      }
    })
  }
}