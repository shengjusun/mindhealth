import { Logger } from '../common/utils/Logger';
import { ApiConfig } from '../common/constants/AppConstants';

const TAG = 'IndexPage';

@Entry
@Component
struct Index {
  @State message: string = '轻心AI';
  @State subtitle: string = '鸿蒙原生客户端';
  @State appInfo: string = 'v1.0.0';

  aboutToAppear() {
    Logger.info(TAG, '应用启动');
    Logger.info(TAG, `API地址: ${ApiConfig.BASE_URL}`);
  }

  build() {
    Column() {
      Column() {
        
        Text(this.message)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
        
        Text(this.subtitle)
          .fontSize(16)
          .fontColor('#666666')
          .margin({ top: 8 })
        
        Text(this.appInfo)
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .width('100%')
      .height('60%')
      .justifyContent(FlexAlign.Center)

      // 功能列表
      Column() {
        this.FeatureItem('💬', 'TraeAI陪伴', '智能对话,情感支持')
        this.FeatureItem('📝', '情绪日记', '记录心情,分析趋势')
        this.FeatureItem('📊', '心理测评', '专业量表,科学评估')
        this.FeatureItem('📚', '心理科普', '知识学习,自我成长')
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      // 底部信息
      Column() {
        Text('非医疗性质AI心理陪伴工具')
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 20 })
        
        Text('© 2024 轻心AI平台')
          .fontSize(12)
          .fontColor('#CCCCCC')
          .margin({ top: 8 })
      }
      .width('100%')
      .height('20%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  FeatureItem(icon: string, title: string, desc: string) {
    Row() {
      Text(icon)
        .fontSize(24)
        .width(40)
      
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        
        Text(desc)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .height(60)
    .padding({ left: 16, right: 16 })
    .backgroundColor(Color.White)
    .borderRadius(8)
    .margin({ bottom: 8 })
    .shadow({ radius: 2, color: '#E0E0E0', offsetX: 0, offsetY: 1 })
  }
}