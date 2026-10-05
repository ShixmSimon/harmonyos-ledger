import { CycleStartDaySelector } from './CycleStartDaySelector';

@Component
export struct SettingsView {
  @Prop cycleStartDay: number = 15;

  onBack: () => void = () => {};
  onCycleStartDayChange: (day: number) => void = (_day: number) => {};
  onOpenNotificationSettings: () => void = () => {};

  build() {
    Column() {
      Row() {
        Button('返回')
          .backgroundColor('#FFFFFF')
          .fontColor('#344563')
          .onClick(() => this.onBack());
        Blank();
        Text('设置')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor('#172B4D');
        Blank();
        Blank().width(48);
      }
      .width('100%')
      .padding(18);

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 8 }) {
            Text('数据与隐私')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#172B4D');
            Text('账目和 OCR 截图只在本机处理，不会上传。卸载应用可能会删除本机数据。')
              .fontSize(13)
              .fontColor('#52606D');
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(14);

          Column({ space: 8 }) {
            Text('记账周期')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#172B4D');
            Text('周期从每月所选日期开始，至下月前一天结束。')
              .fontSize(13)
              .fontColor('#52606D');
            CycleStartDaySelector({
              startDay: this.cycleStartDay,
              onChange: (day: number) => this.onCycleStartDayChange(day)
            });
            Text('年统计仍按自然年。')
              .fontSize(12)
              .fontColor('#7B8794');
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(14);

          Column({ space: 8 }) {
            Text('通知与设备')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#172B4D');
            Text('授权通知读取后，可从支持银行的通知中自动记录收支。')
              .fontSize(13)
              .fontColor('#52606D');
            Button('打开通知与设备设置')
              .width('100%')
              .backgroundColor('#E9F1FF')
              .fontColor('#2457C5')
              .onClick(() => this.onOpenNotificationSettings());
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(14);
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18, bottom: 24 });
      }
      .layoutWeight(1)
      .width('100%');
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7F9');
  }
}
