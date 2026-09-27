/**
 * AppChip —— 统一标签（ui-redesign-preview.html：高24 / radius-xs 6 / 12fp Medium）
 * primary  主色浅底主色字（默认）
 * success / warning / danger  语义色浅底语义色字（深色下底色 alpha 加实，见 HTML）
 * plain    灰底灰字
 */
import { brand, Dimension, FontLevel } from '../constants/Theme'
import { appState } from '../state/AppState'

@ComponentV2
export struct AppChip {
  @Param label: string = ''
  @Param kind: string = 'primary'

  private bgColor(): ResourceColor {
    const dark: boolean = appState().isDark
    if (this.kind === 'success') {
      return dark ? 'rgba(140, 199, 158, 0.20)' : 'rgba(111, 169, 127, 0.12)'
    }
    if (this.kind === 'warning') {
      return dark ? 'rgba(232, 174, 110, 0.22)' : 'rgba(216, 154, 92, 0.14)'
    }
    if (this.kind === 'danger') {
      return dark ? 'rgba(224, 136, 116, 0.20)' : 'rgba(201, 112, 95, 0.13)'
    }
    if (this.kind === 'plain') {
      return $r('app.color.surface_soft')
    }
    return brand().primaryWeak
  }

  private labelColor(): ResourceColor {
    if (this.kind === 'success') {
      return $r('app.color.state_success')
    }
    if (this.kind === 'warning') {
      return $r('app.color.state_warning')
    }
    if (this.kind === 'danger') {
      return $r('app.color.state_error')
    }
    if (this.kind === 'plain') {
      return $r('app.color.text_tertiary')
    }
    return brand().primary
  }

  build() {
    Text(this.label)
      .height(24)
      .padding({ left: Dimension.SpaceS, right: Dimension.SpaceS })
      .borderRadius(Dimension.RadiusXS)
      .fontSize(FontLevel.Caption)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.labelColor())
      .backgroundColor(this.bgColor())
  }
}
