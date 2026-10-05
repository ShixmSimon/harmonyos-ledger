import { LedgerStatistics, StatisticsRankItem } from '../../services/LedgerStatistics';
import { formatMoney } from '../../model/LedgerModels';

export type StatisticsRankType = 'category' | 'merchant' | 'source';
export type StatisticsDirection = 'income' | 'expense';

@Component
export struct StatisticsRanking {
  @Prop statistics: LedgerStatistics;
  @Prop rankDirection: StatisticsDirection = 'expense';
  sourceName: (source: string) => string = (source: string) => source;
  onDirectionChange: (direction: StatisticsDirection) => void = (_direction: StatisticsDirection) => {};
  onSelectRank: (type: StatisticsRankType, value: string) => void =
    (_type: StatisticsRankType, _value: string) => {};

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Button('支出分析')
          .layoutWeight(1)
          .backgroundColor(this.rankDirection === 'expense' ? '#2857C5' : '#FFFFFF')
          .fontColor(this.rankDirection === 'expense' ? '#FFFFFF' : '#344563')
          .onClick(() => this.onDirectionChange('expense'));
        Button('收入分析')
          .layoutWeight(1)
          .backgroundColor(this.rankDirection === 'income' ? '#2857C5' : '#FFFFFF')
          .fontColor(this.rankDirection === 'income' ? '#FFFFFF' : '#344563')
          .onClick(() => this.onDirectionChange('income'));
      }
      .width('100%');
      this.rankingCard(this.rankDirection === 'income' ? '收入分类' : '支出分类',
        this.rankDirection === 'income' ? this.statistics.incomeCategories : this.statistics.categories,
        this.totalAmountFen(), 'category');
      this.rankingCard(this.rankDirection === 'income' ? '收入商户' : '支出商户',
        this.rankDirection === 'income' ? this.statistics.incomeMerchants : this.statistics.merchants,
        this.totalAmountFen(), 'merchant');
      this.rankingCard(this.rankDirection === 'income' ? '收入来源' : '支出来源',
        this.rankDirection === 'income' ? this.statistics.incomeSources : this.statistics.sources,
        this.totalAmountFen(), 'source');
    }
    .width('100%');
  }

  @Builder
  private rankingCard(title: string, items: StatisticsRankItem[], total: number, rankType: StatisticsRankType) {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#172B4D');
      if (items.length === 0) {
        Text(this.rankDirection === 'income' ? '暂无收入数据' : '暂无支出数据')
          .fontSize(13)
          .fontColor('#7B8794');
      } else {
        ForEach(items, (item: StatisticsRankItem) => {
          this.rankingItem(item, total, rankType);
        }, (item: StatisticsRankItem) => item.key);
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14);
  }

  @Builder
  private rankingItem(item: StatisticsRankItem, total: number, rankType: StatisticsRankType) {
    Column({ space: 5 }) {
      Row() {
        Column({ space: 2 }) {
          Text(rankType === 'source' ? this.sourceName(item.key) : item.label)
            .fontSize(13)
            .fontColor('#344563');
          Text('查看账目 ›')
            .fontSize(10)
            .fontColor('#2457C5');
          Text(item.count + ' 笔')
            .fontSize(10)
            .fontColor('#7B8794');
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Text(formatMoney(item.amountFen))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#172B4D');
      }
      .width('100%');
      Row() {
        Row()
          .width(this.barWidth(item.amountFen, total))
          .height(6)
          .backgroundColor('#5979D0')
          .borderRadius(3);
      }
      .width('100%')
      .height(6)
      .backgroundColor('#EEF1F4')
      .borderRadius(3);
      Text(total > 0 ? (item.amountFen * 100 / total).toFixed(1) + '%' : '0.0%')
        .fontSize(10)
        .fontColor('#7B8794');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 3, bottom: 5 })
    .onClick(() => this.onSelectRank(rankType, item.key));
  }

  private totalAmountFen(): number {
    return this.rankDirection === 'income' ? this.statistics.incomeFen : this.statistics.expenseFen;
  }

  private barWidth(value: number, maximum: number): string {
    if (value <= 0 || maximum <= 0) {
      return '0%';
    }
    return Math.max(2, value * 100 / maximum).toFixed(1) + '%';
  }
}
