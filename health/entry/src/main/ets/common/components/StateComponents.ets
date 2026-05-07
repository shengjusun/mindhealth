/**
 * 加载状态组件
 */
@Component
export struct LoadingComponent {
  @Prop message: string = '加载中...'
  @Prop loadingSize: number = 40

  build() {
    Column() {
      LoadingProgress()
        .width(this.loadingSize)
        .height(this.loadingSize)
        .color('#4A9EFF')

      Text(this.message)
        .fontSize(14)
        .fontColor('#6B7280')
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF8F0')
  }
}

/**
 * 空状态组件
 */
@Component
export struct EmptyComponent {
  @Prop icon: string = '📭'
  @Prop message: string = '暂无数据'
  @Prop buttonText: string = ''

  build() {
    Column() {
      Text(this.icon)
        .fontSize(64)
        .margin({ bottom: 16 })

      Text(this.message)
        .fontSize(16)
        .fontColor('#6B7280')
        .margin({ bottom: 16 })

      if (this.buttonText) {
        Button(this.buttonText)
          .height(40)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .backgroundColor('#4A9EFF')
          .borderRadius(20)
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF8F0')
  }
}

/**
 * 错误状态组件
 */
@Component
export struct ErrorComponent {
  @Prop message: string = '加载失败'
  @Prop buttonText: string = '重试'

  build() {
    Column() {
      Text('❌')
        .fontSize(64)
        .margin({ bottom: 16 })

      Text(this.message)
        .fontSize(16)
        .fontColor('#6B7280')
        .margin({ bottom: 16 })

      Button(this.buttonText)
        .height(40)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#4A9EFF')
        .borderRadius(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF8F0')
  }
}

/**
 * 网络错误组件
 */
@Component
export struct NetworkErrorComponent {
  build() {
    Column() {
      Text('📡')
        .fontSize(64)
        .margin({ bottom: 16 })

      Text('网络连接失败')
        .fontSize(16)
        .fontColor('#1F2937')
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      Text('请检查网络设置后重试')
        .fontSize(14)
        .fontColor('#6B7280')
        .margin({ bottom: 16 })

      Button('重试')
        .height(40)
        .width(120)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#4A9EFF')
        .borderRadius(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#FFF8F0')
  }
}