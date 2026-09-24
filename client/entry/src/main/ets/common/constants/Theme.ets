/**
 * 全局主题
 * @description 心理健康 App 统一视觉规范
 *
 * 颜色已全部迁移到资源系统（resources/base/element/color.json + dark/element/color.json），
 * 页面统一用 $r('app.color.xxx') 引用，深浅色模式自动切换。
 * 本文件只保留尺寸、字体层级与阴影常量。
 */

export interface ShadowConfig {
  radius: number
  color: string
  offsetX: number
  offsetY: number
}

export class Dimension {
  // 圆角
  static readonly RadiusXS: number = 6
  static readonly RadiusS: number = 10
  static readonly RadiusM: number = 14
  static readonly RadiusL: number = 18
  static readonly RadiusXL: number = 24

  // 统一卡片圆角：全 App 卡片一律落在这个区间，不再各处写死数字
  static readonly CardRadius: number = 20 // 标准大卡片
  static readonly CardRadiusInner: number = 16 // 卡片内嵌的小块 / 列表项
  static readonly SheetRadius: number = 24 // 半屏弹层（比卡片更圆）

  // 间距
  static readonly SpaceXS: number = 4
  static readonly SpaceS: number = 8
  static readonly SpaceM: number = 12
  static readonly SpaceL: number = 16
  static readonly SpaceXL: number = 20
  static readonly SpaceXXL: number = 24
  static readonly SpaceHuge: number = 32

  // 字号
  static readonly FontXS: number = 10
  static readonly FontS: number = 12
  static readonly FontM: number = 14
  static readonly FontL: number = 16
  static readonly FontXL: number = 18
  static readonly FontXXL: number = 22
  static readonly FontTitle: number = 26

  // 高度
  static readonly HeaderHeight: number = 52
  static readonly BottomNavHeight: number = 54
  static readonly ButtonHeight: number = 48
  static readonly InputHeight: number = 44

  // 卡片
  static readonly CardPadding: number = 16

  // 悬浮胶囊 Tab 栏（MainPage 底部浮动栏）
  static readonly PillHeight: number = 58
  static readonly PillMarginBottom: number = 16
  // 悬浮栏浮在内容之上，滚动内容必须预留这么高的空白，
  // 否则最后一条被栏挡住、且毛玻璃没有内容可模糊
  static readonly PillSafeArea: number = 96
}

/**
 * 字体层级
 * 统一「标题更重更大、正文更浅、行高 1.6」的排版规范。
 * 正文色请用 $r('app.color.text_secondary')（#6E7B87，比 #666 更浅），
 * 不要再用 text_primary（#2F3A45 太重，用作正文会压过标题层级）。
 */
export class FontLevel {
  static readonly PageTitle: number = 26 // 页面大标题
  static readonly SectionTitle: number = 18 // 区块标题
  static readonly CardTitle: number = 16 // 卡片标题
  static readonly Body: number = 14 // 正文
  static readonly Caption: number = 12 // 辅助说明 / 时间戳

  // 行高倍数：正文 1.6，标题可以略紧
  static readonly BodyLineHeightRatio: number = 1.6
  static readonly TitleLineHeightRatio: number = 1.35

  /** 正文行高：14 → 22 */
  static bodyLineHeight(fontSize: number): number {
    return Math.round(fontSize * FontLevel.BodyLineHeightRatio)
  }

  /** 标题行高，比正文紧一点，避免大标题显得散 */
  static titleLineHeight(fontSize: number): number {
    return Math.round(fontSize * FontLevel.TitleLineHeightRatio)
  }
}

/**
 * 阴影：一律用主色系（#7FA9C9 一族）的半透明色，不用黑灰，
 * 这样阴影在米色背景上呈现淡蓝调，观感柔和。
 *
 * 注意：这里的 color 是写死的 rgba 字符串，不随深浅色模式切换。
 * 深色模式下阴影本来就几乎不可见，影响可接受；若后续要严格适配，
 * 需要把阴影色也迁到资源系统。
 */
export class ShadowStyle {
  static readonly Light: ShadowConfig = {
    radius: 12,
    color: 'rgba(74, 126, 168, 0.08)',
    offsetX: 0,
    offsetY: 2
  }

  static readonly Medium: ShadowConfig = {
    radius: 18,
    color: 'rgba(74, 126, 168, 0.12)',
    offsetX: 0,
    offsetY: 6
  }

  /** 卡片：柔和、扩散大，只做「浮起一点」的暗示 */
  static readonly Card: ShadowConfig = {
    radius: 20,
    color: 'rgba(74, 126, 168, 0.10)',
    offsetX: 0,
    offsetY: 8
  }

  /** 悬浮胶囊栏：需要有明显的漂浮感，比卡片重 */
  static readonly Pill: ShadowConfig = {
    radius: 28,
    color: 'rgba(74, 126, 168, 0.24)',
    offsetX: 0,
    offsetY: 10
  }

  /** 主按钮：小范围、偏实，提升点击欲望 */
  static readonly Button: ShadowConfig = {
    radius: 14,
    color: 'rgba(74, 126, 168, 0.30)',
    offsetX: 0,
    offsetY: 6
  }
}

/**
 * 主按钮配方
 *
 * 渐变没法做成常量：它需要 ResourceColor，而 $r('app.color.xxx') 只能在组件
 * 上下文里解析，放在普通 class 中不生效。所以这里只记录配方，在调用点照抄：
 *
 *   .linearGradient({
 *     angle: 135,
 *     colors: [[$r('app.color.theme_primary'), 0], [$r('app.color.primary_pressed'), 1]]
 *   })
 *   .shadow(ShadowStyle.Button)
 *
 * 选 theme_primary → primary_pressed 的原因：这两个色在浅色（#7FA9C9→#6B96B7）
 * 和深色（#8FB8D6→#7CA6C4）模式下都是「同色系由浅到深」，一套写法两边都成立。
 * 别用白色做渐变起点——深色模式下会变成惨白。
 */
export class ButtonStyle {
  static readonly Height: number = Dimension.ButtonHeight
  static readonly Radius: number = Dimension.CardRadiusInner
}
