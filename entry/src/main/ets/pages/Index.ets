@Entry
@Component
struct Index {
  build() {
    Row() {
      Column({ space: 12 }) {
        Text('账本正在初始化')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
        Text('后续会逐步加入记账、统计和截图识别。')
          .fontSize(14)
          .fontColor('#6B7280')
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
