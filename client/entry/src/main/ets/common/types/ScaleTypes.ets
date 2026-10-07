/**
 * 心理量表数据模型
 * 与客户端 rawfile/scales/*.json（安装包内置题库）及本地缓存结构一致；
 * 后端唯一来源是 assessment 表，题目包接口下发的 JSON 同构——三处结构保持统一。
 */

// 单个选项
export interface ScaleOption {
  key: string
  text: string
  score: number
}

// 单道题目
export interface ScaleQuestion {
  id: number
  title: string
  options: ScaleOption[]
}

// 量表清单里的一条记录（只描述量表，不含题目）
export interface ScaleMeta {
  id: number
  name: string
  type: string
  description: string
  questionCount: number
  maxScore: number
  version: number
}

// 量表清单：客户端据此判断哪些量表需要更新
export interface ScaleManifest {
  version: number
  updatedAt: string
  scales: ScaleMeta[]
}

// 单套量表完整内容（含题目）
export interface ScaleDetail {
  id: number
  name: string
  type: string
  version: number
  maxScore: number
  questions: ScaleQuestion[]
}
