import { EntryDirection } from '../../model/LedgerModels';

@Component
export struct LedgerEditorView {
  @Prop editingId: string = '';
  @Prop merchant: string = '';
  @Prop dateText: string = '';
  @Prop amountText: string = '';
  @Prop entryDirection: EntryDirection = 'expense';
  @Prop category: string = '其他';
  @Prop note: string = '';
  @Prop dateError: string = '';
  @Prop amountError: string = '';

  private scroller: Scroller = new Scroller();
  @State private viewportHeight: number = 0;

  onBack: () => void = () => {};
  onSave: () => void = () => {};
  onChooseDate: () => void = () => {};
  onFieldChange: (field: string, value: string) => void = (_field: string, _value: string) => {};
  onDirectionChange: (direction: EntryDirection) => void = (_direction: EntryDirection) => {};

  build() {
    Column() {
      Row() {
        Button('返回')
          .backgroundColor('#FFFFFF')
          .fontColor('#344563')
          .onClick(() => this.onBack());
        Blank();
        Text(this.editingId.length > 0 ? '编辑账目' : '手动记账')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#172B4D');
        Blank();
        Button('保存')
          .backgroundColor('#2857C5')
          .fontColor('#FFFFFF')
          .onClick(() => this.onSave());
      }
      .width('100%')
      .padding(18);
      Scroll(this.scroller) {
        Column({ space: 14 }) {
          this.inputField('商户或摘要', this.merchant, 'merchant');
          this.inputField('日期时间（YYYY-MM-DD HH:mm）', this.dateText, 'date', this.dateError);
          Button('选择日期')
            .width('100%')
            .backgroundColor('#E9F1FF')
            .fontColor('#2457C5')
            .onClick(() => this.onChooseDate());
          this.inputField('金额（元）', this.amountText, 'amount', this.amountError);
          Text('方向')
            .fontSize(14)
            .fontColor('#52606D');
          Row({ space: 10 }) {
            Button('支出')
              .layoutWeight(1)
              .backgroundColor(this.entryDirection === 'expense' ? '#2857C5' : '#FFFFFF')
              .fontColor(this.entryDirection === 'expense' ? '#FFFFFF' : '#344563')
              .onClick(() => this.onDirectionChange('expense'));
            Button('收入')
              .layoutWeight(1)
              .backgroundColor(this.entryDirection === 'income' ? '#16845B' : '#FFFFFF')
              .fontColor(this.entryDirection === 'income' ? '#FFFFFF' : '#344563')
              .onClick(() => this.onDirectionChange('income'));
          }
          .width('100%');
          this.inputField('分类', this.category, 'category');
          this.inputField('备注（可选）', this.note, 'note');
          Text('截图识别的内容仍需你核对。')
            .fontSize(12)
            .fontColor('#7B8794');
        }
        .width('100%')
        .constraintSize({ minHeight: this.viewportHeight })
        .justifyContent(FlexAlign.Start)
        .padding({ left: 18, right: 18, top: 4, bottom: 24 });
      }
      .layoutWeight(1)
      .onAreaChange((oldArea, newArea) => {
        if (typeof newArea.height === 'number' && newArea.height > 0 &&
          this.viewportHeight !== newArea.height) {
          this.viewportHeight = newArea.height;
        }
      })
      .onAppear(() => {
        this.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false });
      });
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private inputField(label: string, value: string, field: string, error: string = '') {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(14)
        .fontColor('#52606D');
      TextInput({ text: value, placeholder: label })
        .fontSize(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(10)
        .type(field === 'amount' ? InputType.NUMBER_DECIMAL : InputType.Normal)
        .onChange((changed: string) => {
          this.onFieldChange(field, changed);
        });
      if (error.length > 0) {
        Text(error)
          .fontSize(12)
          .fontColor('#B42318');
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }
}
