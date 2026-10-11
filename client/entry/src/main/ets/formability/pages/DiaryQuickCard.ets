/**
 * 服务卡片：快捷入口（2×4 中规格）。
 *
 * 四个入口 —— 写日记 / 树洞 / 自查 / 我的，点击后通过 postCardAction(router)
 * 拉起主应用，并在 params 里带一个 cardTarget 字符串；
 * EntryAbility 读到它后映射成主 Tab 索引（见 ContinueState.cardTargetToTab），
 * 复用接续功能同一条「落到指定 Tab」的通道，不另写跳转逻辑。
 *
 * 卡片 UI 约束：布局保持最简单的 Column/Row/Text，配色全部走系统资源
 * （sys.color.*），浅色/深色模式下都不需要自己处理适配。
 */
@Entry
@Component
struct DiaryQuickCard {
  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        this.quickEntry('写日记', 'diary')
        this.quickEntry('树洞', 'treehole')
      }
      .layoutWeight(1)

      Row({ space: 8 }) {
        this.quickEntry('自查', 'assess')
        this.quickEntry('我的', 'me')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding(10)
  }

  @Builder
  quickEntry(label: string, target: string) {
    Column() {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
    }
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(14)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { cardTarget: target }
      })
    })
  }
}
