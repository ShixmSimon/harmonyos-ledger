@Component
export struct OcrImportView {
  @Prop rawText: string = '';
  @Prop loading: boolean = false;
  @Prop errorMessage: string = '';

  onBack: () => void = () => {};
  onSelectImages: () => void = () => {};
  onRawTextChange: (text: string) => void = (_text: string) => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Button('返回')
          .backgroundColor('#FFFFFF')
          .fontColor('#344563')
          .onClick(() => this.onBack());
        Blank();
        Text('截图 OCR 调试')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#172B4D');
        Blank();
        Button('识别')
          .backgroundColor('#2857C5')
          .fontColor('#FFFFFF')
          .enabled(!this.loading)
          .onClick(() => this.onSelectImages());
      }
      .width('100%');

      Text('选择微信、支付宝或银行账单截图，识别结果仅显示在下方文本框，不会自动入账。')
        .width('100%')
        .fontSize(13)
        .fontColor('#7B8794');

      if (this.loading) {
        Text('正在识别截图…')
          .fontSize(14)
          .fontColor('#2457C5');
      }

      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .width('100%')
          .fontSize(14)
          .fontColor('#B42318');
      }

      Text('OCR 识别内容（可编辑）')
        .width('100%')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#344563');

      TextArea({ text: this.rawText, placeholder: '识别后的文字会显示在这里' })
        .layoutWeight(1)
        .width('100%')
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .onChange((value: string) => this.onRawTextChange(value));
    }
    .width('100%')
    .height('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 24 })
    .backgroundColor('#F6F7F9');
  }
}
