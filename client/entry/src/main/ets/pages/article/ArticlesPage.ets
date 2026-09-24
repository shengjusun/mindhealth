import router from '@ohos.router'
import { AppPageHeader } from '../../common/components/AppPageHeader'
import { Dimension } from '../../common/constants/Theme'
import { LoadingComponent, EmptyComponent, ErrorComponent } from '../../common/components/StateComponents'
import { ApiService } from '../../core/api/ApiService'
import { Logger } from '../../common/utils/Logger'
import { ToastUtil } from '../../common/utils/ToastUtil'
import { AuthService } from '../../core/auth/AppAuthService'

const TAG = 'ArticlesPage'

interface ArticleItem {
  id?: number
  title?: string
  summary?: string
  content?: string
  category?: string
  cover?: string
  author?: string
  createTime?: string
  updateTime?: string
}

// 传给文章详情页的路由参数
interface ArticleDetailParams {
  id: number
  title: string
  summary: string
  content: string
  category: string
  author: string
  createTime: string
}

@Entry
@Component
struct ArticlesPage {
  @State isLoading: boolean = true
  @State isRefreshing: boolean = false
  @State hasError: boolean = false
  @State errorMessage: string = '加载失败'
  @State articleList: ArticleItem[] = []

  private apiService: ApiService = ApiService.getInstance()

  aboutToAppear(): void {
    this.loadArticles()
    if (!this.ensureLogin()) {
      return
    }
  }

  private async loadArticles(showLoading: boolean = true): Promise<void> {
    if (showLoading) {
      this.isLoading = true
    }
    this.hasError = false

    try {
      const res = await this.apiService.getArticleList()
      if (res.code === 200 && res.data) {
        this.articleList = res.data as ArticleItem[]
      } else {
        this.hasError = true
        this.errorMessage = res.message ? res.message : '加载文章失败'
      }
    } catch (error) {
      Logger.error(TAG, `加载文章失败: ${JSON.stringify(error)}`)
      this.hasError = true
      this.errorMessage = '网络异常，请稍后重试'
    } finally {
      this.isLoading = false
    }
  }

  private getArticleSummary(item: ArticleItem): string {
    if (item.summary && item.summary.length > 0) {
      return item.summary
    }
    if (item.content && item.content.length > 0) {
      return item.content
    }
    return '这是一篇与你当下状态相关的温柔科普内容。'
  }

  private getArticleCategory(item: ArticleItem): string {
    if (item.category && item.category.length > 0) {
      return item.category
    }
    return '心理科普'
  }

  private getArticleDate(item: ArticleItem): string {
    const timeText: string = item.createTime ? item.createTime : ''
    if (!timeText || timeText.length === 0) {
      return '最近更新'
    }

    const tIndex: number = timeText.indexOf('T')
    if (tIndex > 0) {
      return timeText.substring(0, tIndex)
    }
    return timeText
  }

  build() {
    Column() {
      AppPageHeader({
        title: '心理科普',
        showBack: true
      })

      if (this.isLoading) {
        LoadingComponent({
          message: '正在整理温柔内容...',
          loadingSize: 36
        })
          .layoutWeight(1)
      } else if (this.hasError) {
        this.buildErrorView()
      } else {
        Refresh({ refreshing: this.isRefreshing }) {
          Scroll() {
            Column() {
              this.buildIntroCard()

              if (this.articleList.length === 0) {
                EmptyComponent({
                  symbol: $r('sys.symbol.book'),
                  icon: '📚',
                  message: '暂时还没有可阅读内容'
                })
                  .height(320)
              } else {
                this.buildArticleList()
              }
            }
            .width('100%')
            .padding({
              left: Dimension.SpaceL,
              right: Dimension.SpaceL,
              top: Dimension.SpaceS,
              bottom: Dimension.SpaceXXL
            })
          }
          .width('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .width('100%')
        .onRefreshing(() => {
          this.loadArticles(false).then(() => {
            this.isRefreshing = false
          })
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background'))
  }

  @Builder
  buildIntroCard() {
    Column() {
      Text('📚')
        .fontSize(32)
        .margin({ bottom: 10 })

      Text('给情绪一点理解，也给自己一点空间')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('读一点温和的心理知识，不是为了变得完美，而是为了更懂自己。')
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildArticleList() {
    Column() {
      ForEach(this.articleList, (item: ArticleItem, index: number) => {
        this.buildArticleCard(item, index)
      })
    }
    .width('100%')
  }

  @Builder
  buildArticleCard(item: ArticleItem, index: number) {
    Column() {
      Row() {
        Text(this.getArticleCategory(item))
          .fontSize(12)
          .fontColor($r('app.color.theme_primary'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.tag_blue'))
          .borderRadius(10)

        Blank()

        Text(this.getArticleDate(item))
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 12 })

      Text(item.title ? item.title : '心理文章')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(this.getArticleSummary(item))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8, bottom: 14 })

      Row() {
        Text(item.author && item.author.length > 0 ? item.author : '轻心编辑部')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))

        Blank()

        Text('阅读全文')
          .fontSize(14)
          .fontColor($r('app.color.theme_primary'))
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.app_card'))
    .borderRadius(16)
    .margin({ bottom: index === this.articleList.length - 1 ? 0 : 12 })
    .onClick(() => {
      if (item.id !== undefined) {
        // 整篇文章通过 params 带过去：后端详情接口不可用时详情页直接用它兜底渲染
        const params: ArticleDetailParams = {
          id: item.id,
          title: item.title ?? '',
          summary: item.summary ?? '',
          content: item.content ?? '',
          category: item.category ?? '',
          author: item.author ?? '',
          createTime: item.createTime ?? ''
        }
        router.pushUrl({
          url: 'pages/ArticleDetailPage',
          params: params
        })
      } else {
        ToastUtil.show('当前文章缺少编号，暂无法查看详情')
      }
    })
  }
  @Builder
  buildErrorView() {
    Column() {
      ErrorComponent({
        message: this.errorMessage,
        onRetry: () => {
          this.loadArticles()
        }
      })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor($r('app.color.app_background'))
  }
  private authService: AuthService = AuthService.getInstance()

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}