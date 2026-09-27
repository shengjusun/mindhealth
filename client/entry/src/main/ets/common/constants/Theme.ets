/**
 * 全局主题
 * @description 心理健康 App 统一视觉规范
 *
 * 颜色已全部迁移到资源系统（resources/base/element/color.json + dark/element/color.json），
 * 页面统一用 $r('app.color.xxx') 引用，深浅色模式自动切换。
 * 本文件只保留尺寸、字体层级与阴影常量。
 */

import { curves } from '@kit.ArkUI'
import ICurve from '@ohos.curves'
import { appState } from '../state/AppState'

export interface ShadowConfig {
  radius: number
  color: string
  offsetX: number
  offsetY: number
}

export class Dimension {
  // 圆角（对齐 ui-redesign-preview.html 的 radius 阶梯：6/8/12/16/20/full）
  static readonly RadiusXS: number = 6      // --radius-xs：chip、气泡"说话方向"角
  static readonly RadiusS: number = 8       // --radius-sm：输入框
  static readonly RadiusM: number = 12      // --radius-md：卡内灰块
  static readonly RadiusL: number = 16      // --radius-lg：标准卡片
  static readonly RadiusXL: number = 20     // --radius-xl：hero 引导大卡
  static readonly RadiusFull: number = 999  // --radius-full：按钮/胶囊/分段控件

  // 统一卡片圆角：hero 20 ＞ 标准卡 16 ＞ 卡内灰块 12，内层不得大于外层
  static readonly CardRadius: number = 16      // 标准卡片（--radius-lg）
  static readonly HeroCardRadius: number = 20  // hero 引导大卡（--radius-xl）
  static readonly CardRadiusInner: number = 12 // 卡片内嵌的小块 / 列表项（--radius-md）
  static readonly SheetRadius: number = 24     // 半屏弹层（比卡片更圆）

  // 间距（对齐 ui-redesign-preview.html 的 space 阶梯：2/4/8/12/16/20/24/32/48）
  static readonly Space2XS: number = 2
  static readonly SpaceXS: number = 4
  static readonly SpaceS: number = 8
  static readonly SpaceM: number = 12
  static readonly SpaceL: number = 16
  static readonly SpaceXL: number = 20
  static readonly SpaceXXL: number = 24
  static readonly SpaceHuge: number = 32
  static readonly Space4XL: number = 48

  // 字号
  static readonly FontXS: number = 10
  static readonly FontS: number = 12
  static readonly FontM: number = 14
  static readonly FontL: number = 16
  static readonly FontXL: number = 18
  static readonly FontXXL: number = 22
  static readonly FontTitle: number = 26

  // 高度
  static readonly HeaderHeight: number = 56 // 页面标题栏（HTML navbar 56vp）
  static readonly BottomNavHeight: number = 54
  static readonly ButtonHeight: number = 48
  static readonly InputHeight: number = 44

  // 卡片内边距（对齐 HTML：standard/mini 16，hero 20，卡内灰块 12）
  static readonly CardPadding: number = 16
  static readonly CardPaddingHero: number = 20
  static readonly CardPaddingInner: number = 12

  // 悬浮胶囊 Tab 栏（MainPage 底部浮动栏，现为官方 HdsTabs 浮动样式）
  static readonly PillHeight: number = 54 // 扁一点
  static readonly PillMarginBottom: number = 10 // 紧贴底部手势条上方，少遮内容
  // 栏与内容之间的呼吸间距（不含系统手势条）
  static readonly PillSafeAreaBase: number = 22

  /**
   * 胶囊栏自身距屏幕底部的距离 = 设计边距 + 系统手势条高度。
   *
   * 手势条高度各机型不同（常见 0~32vp），写死会让栏压住手势条或离屏边过远。
   * 真实高度由 EntryAbility 从窗口避让区读出，经 AppState.bottomIndicatorVp 传进来。
   */
  static pillMarginBottom(indicatorVp: number): number {
    return Dimension.PillMarginBottom + indicatorVp
  }

  /**
   * 内容底部应预留的高度 = 栏高 + 栏下边距 + 呼吸间距 + 手势条高度。
   *
   * 悬浮栏浮在内容之上，不预留会导致最后一条被栏挡住；同时也正是靠这段空白
   * 让内容从栏下方穿过，毛玻璃才有东西可模糊。
   */
  static pillSafeArea(indicatorVp: number): number {
    return Dimension.PillHeight + Dimension.PillMarginBottom + Dimension.PillSafeAreaBase + indicatorVp
  }
}

/**
 * 字体层级
 * 统一「标题更重更大、正文更浅、行高 1.6」的排版规范。
 * 正文色请用 $r('app.color.text_secondary')（#6E7B87，比 #666 更浅），
 * 不要再用 text_primary（#2F3A45 太重，用作正文会压过标题层级）。
 */
export class FontLevel {
  static readonly PageTitle: number = 24   // 页面主标题（hero-title 24/Bold）
  static readonly SectionTitle: number = 17 // 区块标题（17/Medium）
  static readonly CardTitle: number = 17   // 卡片标题（17/Medium）
  static readonly Body: number = 14        // 正文
  static readonly Caption: number = 12     // 时间戳 / 极灰辅助
  static readonly Aux: number = 13         // 辅助说明（13fp）
  static readonly SubTitle: number = 15    // 列表条目标题（15fp Medium）
  static readonly Button: number = 15      // 主/次按钮（15fp Medium）
  static readonly Stat: number = 28        // 统计数字（28fp Bold）

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
 * 动效令牌：时长与曲线全部收口在这里（与色/圆角令牌同构，设计变更一处生效）。
 * - 交互密集处（按压/切换）用弹簧：可中断、可续接、天然跟手
 * - 展示编排处（转场/主题过渡）用强调贝塞尔：节奏可控
 * - 规划中的全局「减弱动效」：所有时长乘 motionScale（无障碍）
 */
export class Motion {
  static readonly Fast: number = 120      // 按压反馈、chip 进出
  static readonly Normal: number = 240    // 卡片、气泡、默认转场
  static readonly Slow: number = 350      // 主题切换、大元素过渡
  /** 强调弹簧：回弹明显（按压、选中态） */
  static readonly springEmphasized: ICurve = curves.springMotion(0.25, 0.8)
  /** 标准弹簧：位移滑动（Tab 滑块、气泡进场） */
  static readonly springStandard: ICurve = curves.springMotion(0.35, 0.9)
  /** 强调贝塞尔：先快后缓的"降速"节奏（主题过渡、页面进场）。cubicBezier 返回曲线字符串 */
  static readonly emphasized: string = curves.cubicBezier(0.2, 0.0, 0.0, 1.0)
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
 * 主按钮配方（已被 AppButton 组件取代）
 *
 * HTML 设计稿的主按钮是**实色**（无渐变、无阴影），按下态靠 primaryPressed 底色 + 缩放反馈。
 * 全 App 按钮一律使用 common/components/AppButton.ets：
 *   AppButton({ label: '保存', kind: 'primary', onPress: () => {...} })
 * 渐变写法仅作历史参考，不要再往调用点抄：
 *   .linearGradient({ angle: 135, colors: [[brand().primary, 0], [brand().primaryPressed, 1]] })
 *   .shadow(ShadowStyle.Button)
 */
export class ButtonStyle {
  static readonly Height: number = Dimension.ButtonHeight
  static readonly Radius: number = Dimension.RadiusFull
  static readonly TextHeight: number = 32
  static readonly TextHitHeight: number = 44
  static readonly IconSide: number = 44
}

// ================================================================== 可换主题的品牌色

/**
 * 品牌色板：用户可切换的那部分颜色。
 *
 * 为什么只搬这 5 个色而不是全部 26 个：中性色（背景、文字、分割线）继续留在
 * 资源系统里，才能白嫖系统深浅色自动切换。品牌色一旦换成这里的常量，
 * 深浅两套就必须我们自己各备一份 —— 但换来的是运行时可换主题。
 *
 * 这是「混合方案」的核心取舍：品牌色可控，中性色交给系统。
 */
export interface BrandPalette {
  /** 主色：按钮、强调、图标高亮（HTML --primary） */
  primary: string
  /** 主色按下态：渐变终点（HTML --primary-deep） */
  primaryPressed: string
  /** 主色浅底 alpha：标签、选中态底色（HTML --primary-weak） */
  primaryWeak: string
  /** 主色浅底 alpha 加深：次按钮按下态（HTML --primary-weak2） */
  primaryWeak2: string
  /** 主色描边 alpha：分段控件、描边芯片（HTML --primary-border） */
  primaryBorder: string
  /** 主色浅底实色：主题预览圆点等需要实色底的场景 */
  tagBlue: string
  /** 导航栏选中色 */
  navActive: string
  /** 辅助色：次要强调 */
  secondary: string
}

export interface ThemeDef {
  id: string
  name: string
  desc: string
  light: BrandPalette
  dark: BrandPalette
}

/**
 * 三套主题，均为低饱和柔和色系 —— 心理健康类产品不宜用高饱和撞色。
 * 每套各备浅/深两份：深色模式下主色要提亮一档，否则压在深背景上看不清。
 */
export const THEMES: ThemeDef[] = [
  {
    id: 'misty',
    name: '晨雾蓝',
    desc: '清透安静，适合清晨与睡前',
    light: {
      primary: '#6E93B8',
      primaryPressed: '#5A7FA6',
      primaryWeak: 'rgba(110, 147, 184, 0.10)',
      primaryWeak2: 'rgba(110, 147, 184, 0.18)',
      primaryBorder: 'rgba(110, 147, 184, 0.32)',
      tagBlue: '#EAF3F8',
      navActive: '#4A7EA8',
      secondary: '#9BBE9B'
    },
    dark: {
      primary: '#85A9CB',
      primaryPressed: '#6E93B8',
      primaryWeak: 'rgba(133, 169, 203, 0.20)',
      primaryWeak2: 'rgba(133, 169, 203, 0.30)',
      primaryBorder: 'rgba(133, 169, 203, 0.42)',
      tagBlue: '#26333D',
      navActive: '#B6D8EE',
      secondary: '#93B893'
    }
  },
  {
    id: 'forest',
    name: '森林绿',
    desc: '自然松弛，像走进一片林地',
    light: {
      primary: '#6F9B7A',
      primaryPressed: '#5C8770',
      primaryWeak: 'rgba(111, 155, 122, 0.10)',
      primaryWeak2: 'rgba(111, 155, 122, 0.18)',
      primaryBorder: 'rgba(111, 155, 122, 0.32)',
      tagBlue: '#ECF4ED',
      navActive: '#55866A',
      secondary: '#A8C4A0'
    },
    dark: {
      primary: '#87B091',
      primaryPressed: '#6F9B7A',
      primaryWeak: 'rgba(135, 176, 145, 0.20)',
      primaryWeak2: 'rgba(135, 176, 145, 0.30)',
      primaryBorder: 'rgba(135, 176, 145, 0.42)',
      tagBlue: '#253329',
      navActive: '#B4DBBE',
      secondary: '#93B893'
    }
  },
  {
    id: 'sunset',
    name: '暖阳橙',
    desc: '温暖治愈，阴天也有一点光',
    light: {
      primary: '#C98B6E',
      primaryPressed: '#B4785C',
      primaryWeak: 'rgba(201, 139, 110, 0.10)',
      primaryWeak2: 'rgba(201, 139, 110, 0.18)',
      primaryBorder: 'rgba(201, 139, 110, 0.32)',
      tagBlue: '#FAF0E5',
      navActive: '#C07E4E',
      secondary: '#D9B48C'
    },
    dark: {
      primary: '#D9A288',
      primaryPressed: '#C98B6E',
      primaryWeak: 'rgba(217, 162, 136, 0.20)',
      primaryWeak2: 'rgba(217, 162, 136, 0.30)',
      primaryBorder: 'rgba(217, 162, 136, 0.42)',
      tagBlue: '#352E24',
      navActive: '#EDC9A6',
      secondary: '#DBB379'
    }
  }
]

/**
 * 取当前生效的品牌色板。
 *
 * 读的是 AppState 的 @Trace 字段，所以切换主题时所有引用处会自动重渲染。
 * 页面侧一律用 brand().primary 取代 $r('app.color.theme_primary')。
 */
export function brand(): BrandPalette {
  const id: string = appState().themeId
  let def: ThemeDef = THEMES[0]
  for (const item of THEMES) {
    if (item.id === id) {
      def = item
      break
    }
  }
  return appState().isDark ? def.dark : def.light
}

/** 按 id 取主题定义，切换器与持久化都用它 */
export function themeDef(id: string): ThemeDef {
  for (const item of THEMES) {
    if (item.id === id) {
      return item
    }
  }
  return THEMES[0]
}
