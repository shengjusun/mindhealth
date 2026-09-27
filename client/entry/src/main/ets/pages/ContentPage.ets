import { AppPageHeader } from '../common/components/AppPageHeader'
import { FontLevel, Dimension } from '../common/constants/Theme'

/**
 * ContentPage —— 通用内容详情页（批次 6）
 *
 * 取代「隐私说明 / 关于」这类内容型 AlertDialog：说明型内容用页面承载，
 * 可滚动、可复查、未来加用户协议/开源许可直接扩 resolveBody 的分支。
 * 操作确认类交互仍用弹窗（删除确认、退出确认等）。
 *
 * 入参（route param）：{ title: string, type: 'privacy' | 'about' }
 */

const PRIVACY_TEXT: string = '本项目仅用于学习与演示。用户资料、情绪日记与测评结果仅存储于你自己的账号下，' +
'仅在 App 内展示与同步所必需的范围内使用，不用于任何商业目的，也不会与第三方共享。' +
'如需彻底删除数据，可在「我的 → 设置」中退出登录后联系开发者处理。'

const ABOUT_TEXT: string = '轻心是一个基于 HarmonyOS NEXT + Spring Boot 3 + MySQL 的心理健康辅导项目，' +
'围绕「情绪记录 → 心理测评 → AI 陪伴」构建完整的业务闭环。' +
'情绪日记与心理测评帮助你看见自己的状态，AI 陪伴在你需要倾听时随时在场。'

@ComponentV2
export struct ContentPage {
  @Param routeParam: Record<string, Object> | undefined = undefined

  @Local title: string = '详情'
  @Local body: string = ''

  aboutToAppear(): void {
    const params: Record<string, Object> = this.routeParam ?? {}
    const titleValue: Object | undefined = params['title']
    const typeValue: Object | undefined = params['type']

    if (typeof titleValue === 'string' && titleValue.length > 0) {
      this.title = titleValue
    }
    if (typeof typeValue === 'string') {
      this.body = this.resolveBody(typeValue)
    }
  }

  private resolveBody(type: string): string {
    if (type === 'about') {
      return ABOUT_TEXT
    }
    return PRIVACY_TEXT
  }

  build() {
    Column() {
      AppPageHeader({
        title: this.title,
        showBack: true
      })

      Scroll() {
        Text(this.body)
          .fontSize(FontLevel.Body)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(FontLevel.bodyLineHeight(FontLevel.Body))
          .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)
      .padding({
        left: Dimension.SpaceL,
        right: Dimension.SpaceL,
        top: Dimension.SpaceM,
        bottom: Dimension.SpaceXXL
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }
}
