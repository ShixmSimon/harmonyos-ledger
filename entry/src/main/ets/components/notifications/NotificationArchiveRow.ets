import { NotificationArchiveEntry } from '../../model/NotificationArchiveModels';
import { formatDateTime } from '../../model/LedgerModels';

@Component
export struct NotificationArchiveRow {
  @Prop entry: NotificationArchiveEntry;
  onSelect: () => void = () => {};

  build() {
    Column({ space: 5 }) {
      Row() {
        Text(this.entry.appName.length > 0 ? this.entry.appName : this.entry.bundleName)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2457C5')
          .maxLines(1);
        Blank();
        Text(formatDateTime(this.entry.eventTime))
          .fontSize(11)
          .fontColor('#7B8794');
      }
      .width('100%');
      Text(this.entry.title.length > 0 ? this.entry.title : '（无标题）')
        .fontSize(15)
        .fontColor('#172B4D')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
      Text(this.entry.body.length > 0 ? this.entry.body : '（无正文）')
        .fontSize(13)
        .fontColor('#52606D')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis });
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => this.onSelect());
  }
}