/**
 * 全局主题
 * @description 心理健康 App 统一视觉规范
 */

export interface ShadowConfig {
  radius: number
  color: string
  offsetX: number
  offsetY: number
}

export class LightTheme {
  // 主色：柔和、治愈
  static readonly Primary: string = '#7FA9C9'
  static readonly PrimaryLight: string = '#EAF3F8'
  static readonly PrimaryPressed: string = '#6B96B7'

  static readonly Secondary: string = '#9BBE9B'
  static readonly SecondaryLight: string = '#EEF6EE'

  // 背景
  static readonly Background: string = '#F8F4EC'
  static readonly Surface: string = '#FFFDF9'
  static readonly SurfaceSoft: string = '#FDF8F1'
  static readonly Card: string = '#FFFDF9'

  // 文字
  static readonly TextPrimary: string = '#2F3A45'
  static readonly TextSecondary: string = '#6E7B87'
  static readonly TextTertiary: string = '#9AA5AE'
  static readonly TextWhite: string = '#FFFFFF'

  // 功能色
  static readonly Success: string = '#73B77E'
  static readonly Warning: string = '#D7A86E'
  static readonly Error: string = '#D97C7C'
  static readonly Danger: string = '#D97C7C'

  // 边框 / 分割线
  static readonly Border: string = '#ECE4D8'
  static readonly Divider: string = '#E9E3D8'

  // 导航
  static readonly NavBackground: string = 'rgba(255, 253, 249, 0.96)'
  static readonly NavInactive: string = '#93A0AA'
  static readonly NavActive: string = '#7FA9C9'

  // 标签背景
  static readonly TagBlue: string = '#EAF3F8'
  static readonly TagGreen: string = '#EEF6EE'
  static readonly TagOrange: string = '#FAF1E6'
}

export class Dimension {
  // 圆角
  static readonly RadiusXS: number = 6
  static readonly RadiusS: number = 10
  static readonly RadiusM: number = 14
  static readonly RadiusL: number = 18
  static readonly RadiusXL: number = 24

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
}

export class ShadowStyle {
  static readonly Light: ShadowConfig = {
    radius: 10,
    color: 'rgba(90, 106, 120, 0.08)',
    offsetX: 0,
    offsetY: 2
  }

  static readonly Medium: ShadowConfig = {
    radius: 14,
    color: 'rgba(90, 106, 120, 0.10)',
    offsetX: 0,
    offsetY: 4
  }
}