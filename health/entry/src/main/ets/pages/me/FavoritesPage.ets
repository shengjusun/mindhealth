import router from '@ohos.router'
import { LightTheme, Dimension } from '../../common/constants/Theme'
import { AuthService } from '../../core/auth/AppAuthService'

@Entry
@Component
struct FavoritesPage {
  private authService: AuthService = AuthService.getInstance()

  private goBack(): void {
    try {
      router.back()
    } catch (error) {
      console.error(`FavoritesPage back error: ${JSON.stringify(error)}`)
    }
  }

  private goArticles(): void {
    try {
      router.pushUrl({ url: 'pages/article/ArticlesPage' })
    } catch (error) {
      console.error(`FavoritesPage goArticles error: ${JSON.stringify(error)}`)
      AlertDialog.show({
        title: '提示',
        message: '文章页暂时无法打开',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
    }
  }

  private goAssessments(): void {
    try {
      router.pushUrl({ url: 'pages/assessment/AssessmentsPage' })
    } catch (error) {
      console.error(`FavoritesPage goAssessments error: ${JSON.stringify(error)}`)
      AlertDialog.show({
        title: '提示',
        message: '测评页暂时无法打开',
        primaryButton: {
          value: '知道了',
          action: () => {}
        }
      })
    }
  }
  aboutToAppear(): void {
    if (!this.ensureLogin) {
      return
    }
  }

  build() {
    Column() {
      this.buildHeader()

      Scroll() {
        Column() {
          this.buildTopCard()

          this.buildActionCard(
            '收藏文章',
            '后续这里展示你收藏的心理文章、科普内容和成长话题。',
            '去看文章',
            () => {
              this.goArticles()
            }
          )

          this.buildActionCard(
            '收藏测评',
            '后续这里展示你标记保存过的测评内容，方便再次查看和体验。',
            '去看测评',
            () => {
              this.goAssessments()
            }
          )

          this.buildNoteCard(
            '当前说明',
            '收藏功能页面先搭好骨架。下一步只需要在文章页或测评页补“收藏/取消收藏”逻辑，这里就能接真数据。'
          )

          Blank()
            .height(24)
        }
        .width('100%')
        .padding({
          left: Dimension.SpaceL,
          right: Dimension.SpaceL,
          top: 8,
          bottom: Dimension.SpaceXXL
        })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildHeader() {
    Row() {
      Row() {
        Text('←')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2937')
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .onClick(() => {
        this.goBack()
      })

      Column() {
        Text('我的收藏')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Text('收藏的内容与入口')
          .fontSize(11)
          .fontColor('#8B95A7')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Blank()
        .width(40)
    }
    .width('100%')
    .padding({
      left: Dimension.SpaceL,
      right: Dimension.SpaceL,
      top: 14,
      bottom: 10
    })
    .backgroundColor('#F6F8FB')
  }

  @Builder
  buildTopCard() {
    Column() {
      Text('把值得反复查看的内容留住')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')

      Text('收藏页更适合作为长期阅读与复盘的入口。后面接上真实收藏逻辑后，会很适合项目展示。')
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildActionCard(title: string, desc: string, buttonText: string, action: () => void) {
    Column() {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')

      Text(desc)
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
        .margin({ top: 10 })

      Button(buttonText)
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontColor(LightTheme.Primary)
        .backgroundColor('#EAF4FF')
        .borderRadius(22)
        .margin({ top: 16 })
        .onClick(() => {
          action()
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildNoteCard(title: string, content: string) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .width('100%')
        .margin({ bottom: 10 })

      Text(content)
        .fontSize(14)
        .fontColor('#6B7280')
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  private ensureLogin(): boolean {
    if (this.authService.isLoggedIn()) {
      return true
    }

    router.replaceUrl({ url: 'pages/auth/LoginPage' })
    return false
  }
}