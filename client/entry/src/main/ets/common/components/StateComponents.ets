/**
 * 通用状态组件：加载 / 空状态 / 错误 / 网络错误
 * 统一使用主题资源配色（浅/深色自适应），错误类组件支持 onRetry 回调
 */
import { brand } from '../constants/Theme'
import { AppButton } from './AppButton'

@ComponentV2
export struct LoadingComponent {
  @Param message: string = '加载中...'
  @Param loadingSize: number = 40

  build() {
    Column() {
      LoadingProgress()
        .width(this.loadingSize)
        .height(this.loadingSize)
        .color(brand().primary)

      Text(this.message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.app_background'))
  }
}

@ComponentV2
export struct EmptyComponent {
  @Param icon: string = '📭'
  // 优先使用系统符号图标；未传时回退 emoji
  @Param symbol: Resource | null = null
  @Param message: string = '暂无数据'
  @Param buttonText: string = ''
  @Event onRetry: () => void = () => {}

  build() {
    Column() {
      if (this.symbol !== null) {
        SymbolGlyph(this.symbol)
          .fontSize(52)
          .fontColor([$r('app.color.text_tertiary')])
          .margin({ bottom: 16 })
      } else {
        Text(this.icon)
          .fontSize(64)
          .margin({ bottom: 16 })
      }

      Text(this.message)
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 16 })

      if (this.buttonText.length > 0) {
        AppButton({
          label: this.buttonText,
          kind: 'primary',
          onPress: () => {
            this.onRetry()
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.app_background'))
  }
}

@ComponentV2
export struct ErrorComponent {
  @Param message: string = '加载失败'
  @Param buttonText: string = '重试'
  @Event onRetry: () => void = () => {}

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
        .fontSize(44)
        .fontColor([$r('app.color.state_warning')])
        .margin({ bottom: 16 })

      Text(this.message)
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 16 })

      AppButton({
        label: this.buttonText,
        kind: 'primary',
        onPress: () => {
          this.onRetry()
        }
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.app_background'))
  }
}

@ComponentV2
export struct NetworkErrorComponent {
  @Event onRetry: () => void = () => {}

  build() {
    Column() {
      SymbolGlyph($r('sys.symbol.globe_badge_message'))
        .fontSize(44)
        .fontColor([$r('app.color.text_tertiary')])
        .margin({ bottom: 16 })

      Text('网络连接失败')
        .fontSize(16)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      Text('请检查网络设置后重试')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ bottom: 16 })

      AppButton({
        label: '重试',
        kind: 'primary',
        fixedWidth: 120,
        onPress: () => {
          this.onRetry()
        }
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.app_background'))
  }
}
