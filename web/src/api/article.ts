// AI生成
/** 文章（公开接口，无需登录） */
import { get } from './http'
import type { ArticleVO } from './types'

export function listArticles(category?: string): Promise<ArticleVO[]> {
  return get<ArticleVO[]>('/article/list', category ? { category } : undefined)
}

export function getArticle(id: number): Promise<ArticleVO> {
  return get<ArticleVO>(`/article/detail/${id}`)
}
