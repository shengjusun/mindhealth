/**
 * Skeleton —— 骨架屏占位（灰底块 + 循环流光）
 * 用于卡片级加载占位：传宽高与圆角即可，流光自动往复循环。
 * 深浅色自适应：底块走资源色 surface_soft，流光是半透明白，深色下同样可见。
 */
import { Dimension } from '../constants/Theme'

@ComponentV2
export struct Skeleton {
  // 命名避开基类通用属性 width/height（@Param 不能遮蔽它们）
  @Param blockWidth: Length = '100%'
  @Param blockHeight: Length = 16
  @Param radius: number = Dimension.RadiusS
  // aboutToAppear 置 true 后 translate 开始动画，iterations -1 持续往复
  @Local started: boolean = false

  aboutToAppear(): void {
    this.started = true
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Row()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.surface_soft'))

      Row()
        .width('40%')
        .height('100%')
        .linearGradient({
          angle: 90,
          colors: [
            ['rgba(255, 255, 255, 0)', 0],
            ['rgba(255, 255, 255, 0.55)', 0.5],
            ['rgba(255, 255, 255, 0)', 1]
          ]
        })
        .translate({ x: this.started ? '260%' : '-160%' })
        .animation({ duration: 1400, iterations: -1, curve: Curve.Linear })
    }
    .clip(true)
    .width(this.blockWidth)
    .height(this.blockHeight)
    .borderRadius(this.radius)
  }
}
