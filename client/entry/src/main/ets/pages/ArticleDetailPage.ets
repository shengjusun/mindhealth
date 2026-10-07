import { SubPageHeader } from '../common/components/SubPageHeader'
import { brand, Dimension } from '../common/constants/Theme'
import { LoadingComponent, ErrorComponent } from '../common/components/StateComponents'
import { ApiService } from '../core/api/ApiService'
import { Logger } from '../common/utils/Logger'

const TAG = 'ArticleDetailPage'

interface ArticleItem {
  id?: number
  title?: string
  summary?: string
  content?: string
  category?: string
  author?: string
  createTime?: string
}

@ComponentV2
export struct ArticleDetailPage {
  // 路由入参，由 RouteBuilders 的 ArticleDetailRoute 注入（取代 router.getParams()）
  // V2 中普通属性禁止从外部初始化，必须由父组件传入 —— 用 @Param（只读，组件内不修改）
  @Param routeParam: Record<string, Object> | undefined = undefined

  @Local article: ArticleItem | null = null
  @Local isLoading: boolean = true
  @Local loadFailed: boolean = false

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    // 列表页跳转时会把整篇文章通过 params 带过来，先兜底渲染
    const params = this.routeParam
    if (params) {
      const idValue = params['id']
      const id: number = typeof idValue === 'number' ? idValue : Number(idValue ?? 0)
      this.article = {
        id: id,
        title: params['title'] as string | undefined,
        summary: params['summary'] as string | undefined,
        content: params['content'] as string | undefined,
        category: params['category'] as string | undefined,
        author: params['author'] as string | undefined,
        createTime: params['createTime'] as string | undefined
      }
    }
    this.loadDetail()
  }

  /**
   * 尝试从后端拉取最新详情。
   * 非 200（如「文章不存在」由后端统一返回 400）或请求异常时，静默沿用列表传参的内容，
   * 不打扰阅读；只有本地也没有正文时才置 loadFailed。
   */
  private async loadDetail(): Promise<void> {
    if (!this.article || this.article.id === undefined) {
      this.isLoading = false
      return
    }

    try {
      const res = await this.apiService.getArticleDetail(String(this.article.id))
      if (res.code === 200 && res.data) {
        const remote = res.data as ArticleItem
        // 远端有内容才覆盖，避免空数据顶掉传参内容
        this.article = {
          id: this.article.id,
          title: remote.title ?? this.article.title,
          summary: remote.summary ?? this.article.summary,
          content: remote.content ?? this.article.content,
          category: remote.category ?? this.article.category,
          author: remote.author ?? this.article.author,
          createTime: remote.createTime ?? this.article.createTime
        }
        this.loadFailed = false
      } else if (!this.article.content) {
        this.loadFailed = true
      }
    } catch (error) {
      Logger.warn(TAG, `文章详情接口不可用，使用列表内容展示: ${JSON.stringify(error)}`)
      if (!this.article.content) {
        this.loadFailed = true
      }
    } finally {
      this.isLoading = false
    }
  }

  private getCategory(): string {
    return this.article?.category && this.article.category.length > 0 ? this.article.category : '心理科普'
  }

  private getAuthor(): string {
    return this.article?.author && this.article.author.length > 0 ? this.article.author : '轻心编辑部'
  }

  private getDate(): string {
    const timeText: string = this.article?.createTime ?? ''
    const tIndex: number = timeText.indexOf('T')
    if (tIndex > 0) {
      return timeText.substring(0, tIndex)
    }
    return timeText.length > 0 ? timeText : '最近更新'
  }

  build() {
    Column() {
      SubPageHeader({
        title: '文章详情'
      })

      if (this.isLoading) {
        LoadingComponent({
          message: '正在为你展开这篇文章...',
          loadingSize: 36
        })
          .layoutWeight(1)
      } else if (this.loadFailed || this.article === null) {
        this.buildErrorView()
      } else {
        Scroll() {
          Column() {
            // 头部：分类 + 日期
            Row() {
              Text(this.getCategory())
                .fontSize(12)
                .fontColor(brand().primary)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(brand().tagBlue)
                .borderRadius(10)

              Blank()

              Text(this.getDate())
                .fontSize(12)
                .fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            .margin({ bottom: 14 })

            // 标题
            Text(this.article.title && this.article.title.length > 0 ? this.article.title : '心理文章')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .lineHeight(32)
              .width('100%')
              .margin({ bottom: 8 })

            // 作者
            Text(`文 / ${this.getAuthor()}`)
              .fontSize(13)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
              .margin({ bottom: 18 })

            // 正文（按空行分段，阅读体验更好）
            Column() {
              ForEach(
                this.splitParagraphs(this.article.content),
                (paragraph: string, index: number) => {
                  Text(paragraph)
                    .fontSize(15)
                    .fontColor($r('app.color.text_primary'))
                    .lineHeight(26)
                    .width('100%')
                    .margin({ bottom: 14 })
                },
                (_paragraph: string, index: number) => `p_${index}`
              )
            }
            .width('100%')

            // 结尾小卡
            Column() {
              Text('💙')
                .fontSize(24)
                .margin({ bottom: 8 })
              Text('愿你今天的阅读，成为照顾自己的开始')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(16)
            .backgroundColor(brand().tagBlue)
            .borderRadius(14)
            .margin({ top: 10 })
          }
          .width('100%')
          .padding({
            left: Dimension.SpaceL,
            right: Dimension.SpaceL,
            top: Dimension.SpaceS,
            bottom: Dimension.SpaceXXL
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.TopStart)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildErrorView() {
    Column() {
      ErrorComponent({
        message: '文章内容暂时无法查看',
        onRetry: () => {
          this.isLoading = true
          this.loadFailed = false
          this.loadDetail()
        }
      })
    }
    .layoutWeight(1)
    .width('100%')
  }

  /**
   * 把正文按空行拆成段落数组；没有空行时整体作为一段
   */
  private splitParagraphs(content: string | undefined): string[] {
    const text = content && content.trim().length > 0
      ? content.trim()
      : (this.article?.summary && this.article.summary.length > 0 ? this.article.summary : '当前暂无更多内容')
    const paragraphs = text.split(/\n\s*\n/)
    return paragraphs.filter((p: string) => p.trim().length > 0)
  }
}
