/**
 * AppButton —— 全 App 统一按钮（ui-redesign-preview.html「按钮 3 类 + 图标型例外」）
 *
 * primary    主按钮：高48 / full 圆角 / 15fp Medium / 主色底 / 白字
 * secondary  次按钮：高48 / full 圆角 / 15fp Medium / 主色浅底 / 主色字
 * text       文字按钮：热区高44（视觉 32）/ 14fp Medium / 主色字
 * icon       图标型主按钮：44×44 圆形主色底（树洞发送键等唯一例外）
 * danger     危险操作（删除/退出登录）：主按钮形态，state_error 底色
 * loading    加载中：置灰且不可点（原「保存中...」交互的样式由调用方切换 label）
 *
 * 说明：尺寸/边距全部走内部参数（block/layoutWeight/fixedWidth/margin），
 * 不依赖调用方对自定义组件链式设置通用属性。
 */
import { brand, Dimension, FontLevel, Motion } from '../constants/Theme'

@ComponentV2
export struct AppButton {
  @Param kind: string = 'primary'
  @Param label: string = ''
  @Param block: boolean = false
  @Param weight: number = 0
  @Param fixedWidth: number = 0
  @Param widthPercent: string = ''
  @Param outerMargin: Margin = { top: 0, bottom: 0, left: 0, right: 0 }
  @Param active: boolean = true
  @Param loading: boolean = false
  @Param danger: boolean = false
  @Event onPress: () => void = () => {}
  // 按压态：onTouch 驱动，弹簧曲线让松手有物理回弹
  @Local pressed: boolean = false

  private bgColor(): ResourceColor {
    if (this.kind === 'text') {
      return Color.Transparent
    }
    if (this.loading) {
      return $r('app.color.text_tertiary')
    }
    if (this.kind === 'secondary') {
      return brand().primaryWeak
    }
    if (this.danger) {
      return $r('app.color.state_error')
    }
    return brand().primary
  }

  private labelColor(): ResourceColor {
    if (this.kind === 'secondary' || this.kind === 'text') {
      return brand().primary
    }
    return $r('app.color.text_on_primary')
  }

  build() {
    Button(this.label)
      .height(this.kind === 'primary' || this.kind === 'secondary' ? Dimension.ButtonHeight : 44)
      .width(this.kind === 'icon' ? 44 : (this.block ? '100%' : (this.fixedWidth > 0 ? this.fixedWidth : (this.widthPercent.length > 0 ? this.widthPercent : 'auto'))))
      .padding({
        left: this.kind === 'text' ? 8 : (this.kind === 'icon' ? 0 : 24),
        right: this.kind === 'text' ? 8 : (this.kind === 'icon' ? 0 : 24)
      })
      .fontSize(this.kind === 'text' ? FontLevel.Body : (this.kind === 'icon' ? 14 : FontLevel.Button))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.labelColor())
      .backgroundColor(this.bgColor())
      .borderRadius(this.kind === 'icon' ? Dimension.RadiusS : Dimension.RadiusFull)
      .layoutWeight(this.weight)
      .margin(this.outerMargin)
      .opacity(this.active ? (this.pressed ? 0.85 : 1) : 0.5)
      .scale({ x: this.pressed ? 0.97 : 1, y: this.pressed ? 0.97 : 1 })
      .animation({ curve: Motion.springEmphasized })
      .enabled(this.active)
      .onTouch((event: TouchEvent) => {
        // Move 事件会伴随按压持续触发，只能按事件类型分支置位
        if (event.type === TouchType.Down) {
          this.pressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressed = false
        }
      })
      .onClick(() => {
        if (this.active && !this.loading) {
          this.onPress()
        }
      })
  }
}
