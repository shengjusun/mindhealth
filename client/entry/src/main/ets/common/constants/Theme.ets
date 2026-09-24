/**
 * 全局主题
 * @description 心理健康 App 统一视觉规范
 *
 * 颜色已全部迁移到资源系统（resources/base/element/color.json + dark/element/color.json），
 * 页面统一用 $r('app.color.xxx') 引用，深浅色模式自动切换。
 * 本文件只保留尺寸与阴影常量。
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