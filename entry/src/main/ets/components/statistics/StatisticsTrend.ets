import { LedgerStatistics, StatisticsTrendItem } from '../../services/LedgerStatistics';
import { formatMoney } from '../../model/LedgerModels';

@Component
export struct StatisticsTrend {
  @Prop statistics: LedgerStatistics;
  @Prop maximumAmountFen: number = 0;
  @Prop selectedSummary: string = '';
  onSelectTrend: (key: string) => void = (_key: string) => {};

  build() {
    Column({ space: 10 }) {
      Text('收支趋势')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#172B4D');
      Row({ space: 12 }) {
        Text('收入')
          .fontSize(11)
          .fontColor('#16845B');
        Text('支出')
          .fontSize(11)
          .fontColor('#B54747');
      }
      if (this.statistics.entryCount === 0) {
        Text('暂无趋势数据')
          .fontSize(13)
          .fontColor('#7B8794');
      } else {
        Row() {
          ForEach(this.statistics.trend, (item: StatisticsTrendItem) => {
            this.trendItem(item, this.statistics.trend.length);
          }, (item: StatisticsTrendItem) => item.key);
        }
        .width('100%')
        .height(112)
        .alignItems(VerticalAlign.Bottom);
        if (this.selectedSummary.length > 0) {
          Text(this.selectedSummary)
            .fontSize(12)
            .fontColor('#52606D');
        }
        Row()
          .width('100%')
          .height(1)
          .backgroundColor('#DDE3E8');
        if (this.statistics.trend.length <= 12) {
          Row() {
            ForEach(this.statistics.trend, (item: StatisticsTrendItem) => {
              Text(item.label)
                .layoutWeight(1)
                .fontSize(9)
                .fontColor('#7B8794')
                .textAlign(TextAlign.Center);
            }, (item: StatisticsTrendItem) => item.key);
          }
          .width('100%');
        } else {
          Row() {
            Text(this.statistics.trend[0].label)
              .layoutWeight(1)
              .fontSize(9)
              .fontColor('#7B8794');
            Text(this.statistics.trend[Math.floor(this.statistics.trend.length / 2)].label)
              .layoutWeight(1)
              .fontSize(9)
              .fontColor('#7B8794')
              .textAlign(TextAlign.Center);
            Text(this.statistics.trend[this.statistics.trend.length - 1].label)
              .layoutWeight(1)
              .fontSize(9)
              .fontColor('#7B8794')
              .textAlign(TextAlign.End);
          }
          .width('100%');
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14);
  }

  @Builder
  private trendItem(item: StatisticsTrendItem, count: number) {
    Column() {
      Blank().layoutWeight(1);
      Row({ space: count > 20 ? 1 : 3 }) {
        Column()
          .width(this.columnWidth(count))
          .height(this.columnHeight(item.incomeFen))
          .backgroundColor('#16845B')
          .borderRadius(2);
        Column()
          .width(this.columnWidth(count))
          .height(this.columnHeight(item.expenseFen))
          .backgroundColor('#B54747')
          .borderRadius(2);
      }
      .alignItems(VerticalAlign.Bottom);
    }
    .layoutWeight(1)
    .height(112)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => this.onSelectTrend(item.key));
  }

  private columnWidth(count: number): number {
    return count > 20 ? 3 : count > 12 ? 6 : 10;
  }

  private columnHeight(value: number): number {
    if (value <= 0 || this.maximumAmountFen <= 0) {
      return 0;
    }
    return Math.max(2, value * 96 / this.maximumAmountFen);
  }
}
