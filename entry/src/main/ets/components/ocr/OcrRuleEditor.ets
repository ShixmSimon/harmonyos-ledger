import type { ImportSource } from '../../model/LedgerModels';
import type {
  OcrCategoryMapping,
  OcrLayoutStrategy,
  OcrPattern,
  OcrRule,
  OcrSourceMatcher
} from '../../services/ocrRules/OcrRuleModels';
import { validateOcrRule } from '../../services/ocrRules/OcrRuleEngine';

@Component
struct OcrRuleTextField {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop placeholder: string = '';
  onChange: (value: string) => void = (_value: string) => {};

  build() {
    Column({ space: 5 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor('#52606D');
      TextInput({ text: this.value, placeholder: this.placeholder.length > 0 ? this.placeholder : this.label })
        .fontSize(14)
        .backgroundColor('#F6F7F9')
        .borderRadius(8)
        .onChange((value: string) => this.onChange(value));
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }
}

@Component
struct OcrRuleTextArea {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop placeholder: string = '';
  onChange: (value: string) => void = (_value: string) => {};

  build() {
    Column({ space: 5 }) {
      Text(this.label)
        .fontSize(12)
        .fontColor('#52606D');
      TextArea({ text: this.value, placeholder: this.placeholder })
        .height(96)
        .fontSize(13)
        .backgroundColor('#F6F7F9')
        .borderRadius(8)
        .onChange((value: string) => this.onChange(value));
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start);
  }
}

@Component
export struct OcrRuleEditor {
  @Prop rule: OcrRule = {
    id: '',
    name: '',
    enabled: true,
    source: 'wechat',
    layoutStrategy: 'receipt-list',
    sourceMatchers: [],
    minimumScore: 4,
    scoreMargin: 2,
    amountPattern: { pattern: '', groupIndex: 1 },
    datePattern: { pattern: '', groupIndex: 1 },
    dateFormat: 'auto',
    incomeKeywords: [],
    expenseKeywords: [],
    failurePatterns: [],
    refundPatterns: [],
    summaryPatterns: [],
    defaultCategory: '其他',
    categoryMappings: []
  };
  @State private draft: OcrRule = {
    id: '',
    name: '',
    enabled: true,
    source: 'wechat',
    layoutStrategy: 'receipt-list',
    sourceMatchers: [],
    minimumScore: 4,
    scoreMargin: 2,
    amountPattern: { pattern: '', groupIndex: 1 },
    datePattern: { pattern: '', groupIndex: 1 },
    dateFormat: 'auto',
    incomeKeywords: [],
    expenseKeywords: [],
    failurePatterns: [],
    refundPatterns: [],
    summaryPatterns: [],
    defaultCategory: '其他',
    categoryMappings: []
  };
  @State private sourceMatcherText: string = '';
  @State private incomeKeywordText: string = '';
  @State private expenseKeywordText: string = '';
  @State private failurePatternText: string = '';
  @State private refundPatternText: string = '';
  @State private summaryPatternText: string = '';
  @State private categoryMappingText: string = '';
  @State private validationMessage: string = '';
  @State private isSubmitting: boolean = false;
  @Prop isSaving: boolean = false;
  onCancel: () => void = () => {};
  onSave: (rule: OcrRule) => Promise<string | undefined> = (_rule: OcrRule) => Promise.resolve(undefined);
  onDelete: (() => void) | undefined = undefined;

  aboutToAppear(): void {
    this.draft = this.copyRule(this.rule);
    this.syncTextFields();
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Button('返回')
            .backgroundColor('#FFFFFF')
            .fontColor('#344563')
            .onClick(() => this.onCancel());
          Blank();
          Text(this.onDelete === undefined ? '新增 OCR 规则' : '编辑 OCR 规则')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#172B4D');
          Blank();
          Blank().width(48);
        }
        .width('100%');

        Text('规则按列表顺序尝试。正则引用捕获组时从 1 开始；日期格式支持 yyyy、MM、dd、HH、mm、M、d，或使用 auto。')
          .fontSize(12)
          .fontColor('#52606D')
          .width('100%');

        Column({ space: 12 }) {
          OcrRuleTextField({
            label: '规则名称', value: this.draft.name,
            onChange: (value: string) => this.updateRule((rule: OcrRule) => rule.name = value)
          });
          Text('账单来源')
            .fontSize(12)
            .fontColor('#52606D');
          Row({ space: 6 }) {
            this.sourceButton('微信', 'wechat');
            this.sourceButton('支付宝', 'alipay');
            this.sourceButton('工商银行', 'icbc');
          }
          .width('100%');
          Text('布局策略')
            .fontSize(12)
            .fontColor('#52606D');
          Row({ space: 6 }) {
            this.layoutButton('账单列表', 'receipt-list');
            this.layoutButton('银行明细', 'icbc-statement');
          }
          .width('100%');
          Row({ space: 8 }) {
            OcrRuleTextField({
              label: '最低来源分', value: String(this.draft.minimumScore),
              onChange: (value: string) => this.updateRule((rule: OcrRule) => rule.minimumScore = Number(value))
            });
            OcrRuleTextField({
              label: '与次高来源的最低分差', value: String(this.draft.scoreMargin),
              onChange: (value: string) => this.updateRule((rule: OcrRule) => rule.scoreMargin = Number(value))
            });
          }
          .width('100%');
          OcrRuleTextArea({
            label: '来源表达式（每行“权重 => 正则”）', value: this.sourceMatcherText,
            placeholder: '例如：6 => 微信支付|微信账单|微信钱包',
            onChange: (value: string) => {
              this.sourceMatcherText = value;
              this.updateRule((rule: OcrRule) => rule.sourceMatchers = this.parseSourceMatchers(value));
            }
          });
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(14);

        Column({ space: 12 }) {
          Text('字段表达式')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#172B4D');
          this.patternFields('amountPattern', '金额表达式', this.draft.amountPattern, true);
          this.patternFields('datePattern', '日期表达式', this.draft.datePattern, true);
          OcrRuleTextField({
            label: '日期格式', value: this.draft.dateFormat,
            placeholder: 'auto 或 yyyy年MM月dd日 HH时mm分',
            onChange: (value: string) => this.updateRule((rule: OcrRule) => rule.dateFormat = value)
          });
          this.patternFields('timePattern', '时间表达式（可选）', this.draft.timePattern, false);
          this.patternFields('directionPattern', '方向表达式（可选）', this.draft.directionPattern, false);
          this.patternFields('merchantPattern', '商户表达式（可选）', this.draft.merchantPattern, false);
          this.patternFields('categoryPattern', '分类表达式（可选）', this.draft.categoryPattern, false);
          OcrRuleTextArea({
            label: '收入关键词（每行或用顿号分隔）', value: this.incomeKeywordText,
            onChange: (value: string) => {
              this.incomeKeywordText = value;
              this.updateRule((rule: OcrRule) => rule.incomeKeywords = this.parseKeywords(value));
            }
          });
          OcrRuleTextArea({
            label: '支出关键词（每行或用顿号分隔）', value: this.expenseKeywordText,
            onChange: (value: string) => {
              this.expenseKeywordText = value;
              this.updateRule((rule: OcrRule) => rule.expenseKeywords = this.parseKeywords(value));
            }
          });
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(14);

        Column({ space: 12 }) {
          Text('分类与过滤')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#172B4D');
          OcrRuleTextField({
            label: '默认分类', value: this.draft.defaultCategory,
            onChange: (value: string) => this.updateRule((rule: OcrRule) => rule.defaultCategory = value)
          });
          OcrRuleTextArea({
            label: '分类映射（每行“正则 => 分类”）', value: this.categoryMappingText,
            placeholder: '例如：^餐饮美食 => 餐饮美食',
            onChange: (value: string) => {
              this.categoryMappingText = value;
              this.updateRule((rule: OcrRule) => rule.categoryMappings = this.parseCategoryMappings(value));
            }
          });
          OcrRuleTextArea({
            label: '失败/取消过滤正则（每行一条）', value: this.failurePatternText,
            onChange: (value: string) => {
              this.failurePatternText = value;
              this.updateRule((rule: OcrRule) => rule.failurePatterns = this.parseExpressions(value));
            }
          });
          OcrRuleTextArea({
            label: '退款识别正则（每行一条）', value: this.refundPatternText,
            onChange: (value: string) => {
              this.refundPatternText = value;
              this.updateRule((rule: OcrRule) => rule.refundPatterns = this.parseExpressions(value));
            }
          });
          OcrRuleTextArea({
            label: '汇总内容过滤正则（每行一条）', value: this.summaryPatternText,
            onChange: (value: string) => {
              this.summaryPatternText = value;
              this.updateRule((rule: OcrRule) => rule.summaryPatterns = this.parseExpressions(value));
            }
          });
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(14);

        if (this.validationMessage.length > 0) {
          Text(this.validationMessage)
            .fontSize(13)
            .fontColor('#B42318')
            .width('100%');
        }
        Button('保存规则')
          .width('100%')
          .backgroundColor('#2857C5')
          .fontColor('#FFFFFF')
          .enabled(!this.isSaving && !this.isSubmitting)
          .onClick(() => {
            void this.submitRule();
          });
        if (this.onDelete !== undefined) {
          Button('删除规则')
            .width('100%')
            .backgroundColor('#FCE8E6')
            .fontColor('#B42318')
            .enabled(!this.isSaving && !this.isSubmitting)
            .onClick(() => this.onDelete?.());
        }
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start)
      .enabled(!this.isSaving && !this.isSubmitting);
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private sourceButton(label: string, source: ImportSource) {
    Button(label)
      .layoutWeight(1)
      .backgroundColor(this.draft.source === source ? '#E9F1FF' : '#F1F3F5')
      .fontColor(this.draft.source === source ? '#2457C5' : '#344563')
      .onClick(() => this.updateRule((rule: OcrRule) => rule.source = source));
  }

  @Builder
  private layoutButton(label: string, strategy: OcrLayoutStrategy) {
    Button(label)
      .layoutWeight(1)
      .backgroundColor(this.draft.layoutStrategy === strategy ? '#E9F1FF' : '#F1F3F5')
      .fontColor(this.draft.layoutStrategy === strategy ? '#2457C5' : '#344563')
      .onClick(() => this.updateRule((rule: OcrRule) => rule.layoutStrategy = strategy));
  }

  @Builder
  private patternFields(field: 'amountPattern' | 'datePattern' | 'timePattern' | 'directionPattern' |
    'merchantPattern' | 'categoryPattern', label: string, pattern: OcrPattern | undefined, required: boolean) {
    Column({ space: 8 }) {
      OcrRuleTextField({
        label: label,
        value: pattern?.pattern ?? '',
        placeholder: required ? '正则表达式，捕获组内填写要提取的文字' : '留空表示不使用该字段表达式',
        onChange: (value: string) => this.updatePattern(field, value, pattern?.groupIndex ?? 1)
      });
      Row({ space: 8 }) {
        Text('捕获组编号')
          .width('58%')
          .fontSize(12)
          .fontColor('#52606D');
        TextInput({ text: pattern === undefined ? '' : String(pattern.groupIndex), placeholder: '1' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor('#F6F7F9')
          .borderRadius(8)
          .enabled(required || pattern !== undefined)
          .onChange((value: string) => this.updatePattern(field, pattern?.pattern ?? '', Number(value)));
      }
      .width('100%');
    }
    .width('100%');
  }

  private updatePattern(field: 'amountPattern' | 'datePattern' | 'timePattern' | 'directionPattern' |
    'merchantPattern' | 'categoryPattern', pattern: string, groupIndex: number): void {
    this.updateRule((rule: OcrRule) => {
      let value: OcrPattern | undefined = undefined;
      if (pattern.trim().length > 0) {
        const nextPattern: OcrPattern = { pattern: pattern, groupIndex: groupIndex };
        value = nextPattern;
      }
      if (field === 'amountPattern') {
        rule.amountPattern = value ?? { pattern: '', groupIndex: groupIndex };
      } else if (field === 'datePattern') {
        rule.datePattern = value ?? { pattern: '', groupIndex: groupIndex };
      } else if (field === 'timePattern') {
        rule.timePattern = value;
      } else if (field === 'directionPattern') {
        rule.directionPattern = value;
      } else if (field === 'merchantPattern') {
        rule.merchantPattern = value;
      } else {
        rule.categoryPattern = value;
      }
    });
  }

  private parseSourceMatchers(value: string): OcrSourceMatcher[] {
    return value.split('\n').map((row: string) => row.trim()).filter((row: string) => row.length > 0)
      .map((row: string): OcrSourceMatcher => {
        const separator = row.indexOf('=>');
        let matcher: OcrSourceMatcher;
        if (separator < 0) {
          matcher = { pattern: row, weight: Number.NaN };
        } else {
          matcher = { weight: Number(row.slice(0, separator).trim()), pattern: row.slice(separator + 2).trim() };
        }
        return matcher;
      });
  }

  private parseCategoryMappings(value: string): OcrCategoryMapping[] {
    return value.split('\n').map((row: string) => row.trim()).filter((row: string) => row.length > 0)
      .map((row: string): OcrCategoryMapping => {
        const separator = row.indexOf('=>');
        let mapping: OcrCategoryMapping;
        if (separator < 0) {
          mapping = { pattern: row, category: '' };
        } else {
          mapping = { pattern: row.slice(0, separator).trim(), category: row.slice(separator + 2).trim() };
        }
        return mapping;
      });
  }

  private parseExpressions(value: string): string[] {
    return value.split('\n').map((pattern: string) => pattern.trim()).filter((pattern: string) => pattern.length > 0);
  }

  private parseKeywords(value: string): string[] {
    return value.split(/[\n、，,]/).map((keyword: string) => keyword.trim()).filter((keyword: string) => keyword.length > 0);
  }

  private syncTextFields(): void {
    this.sourceMatcherText = this.draft.sourceMatchers
      .map((matcher) => matcher.weight + ' => ' + matcher.pattern).join('\n');
    this.incomeKeywordText = this.draft.incomeKeywords.join('、');
    this.expenseKeywordText = this.draft.expenseKeywords.join('、');
    this.failurePatternText = this.draft.failurePatterns.join('\n');
    this.refundPatternText = this.draft.refundPatterns.join('\n');
    this.summaryPatternText = this.draft.summaryPatterns.join('\n');
    this.categoryMappingText = this.draft.categoryMappings
      .map((mapping) => mapping.pattern + ' => ' + mapping.category).join('\n');
  }

  private updateRule(update: (rule: OcrRule) => void): void {
    const next = this.copyRule(this.draft);
    update(next);
    this.draft = next;
    this.validationMessage = '';
  }

  private copyRule(rule: OcrRule): OcrRule {
    const copyPattern = (pattern: OcrPattern | undefined): OcrPattern | undefined => {
      if (pattern === undefined) {
        return undefined;
      }
      const copy: OcrPattern = { pattern: pattern.pattern, groupIndex: pattern.groupIndex };
      return copy;
    };
    const copyMatcher = (matcher: OcrSourceMatcher): OcrSourceMatcher => {
      const copy: OcrSourceMatcher = { pattern: matcher.pattern, weight: matcher.weight };
      return copy;
    };
    const copyMapping = (mapping: OcrCategoryMapping): OcrCategoryMapping => {
      const copy: OcrCategoryMapping = { pattern: mapping.pattern, category: mapping.category };
      return copy;
    };
    return {
      id: rule.id,
      name: rule.name,
      enabled: rule.enabled,
      source: rule.source,
      layoutStrategy: rule.layoutStrategy,
      sourceMatchers: rule.sourceMatchers.map((matcher: OcrSourceMatcher) => copyMatcher(matcher)),
      minimumScore: rule.minimumScore,
      scoreMargin: rule.scoreMargin,
      amountPattern: copyPattern(rule.amountPattern) as OcrPattern,
      datePattern: copyPattern(rule.datePattern) as OcrPattern,
      timePattern: copyPattern(rule.timePattern),
      directionPattern: copyPattern(rule.directionPattern),
      merchantPattern: copyPattern(rule.merchantPattern),
      categoryPattern: copyPattern(rule.categoryPattern),
      dateFormat: rule.dateFormat,
      incomeKeywords: rule.incomeKeywords.slice(),
      expenseKeywords: rule.expenseKeywords.slice(),
      failurePatterns: rule.failurePatterns.slice(),
      refundPatterns: rule.refundPatterns.slice(),
      summaryPatterns: rule.summaryPatterns.slice(),
      defaultCategory: rule.defaultCategory,
      categoryMappings: rule.categoryMappings.map((mapping: OcrCategoryMapping) => copyMapping(mapping))
    };
  }

  private async submitRule(): Promise<void> {
    if (this.isSaving || this.isSubmitting) {
      return;
    }
    const issue = validateOcrRule(this.draft);
    if (issue !== undefined) {
      this.validationMessage = issue.field + '：' + issue.message;
      return;
    }
    this.isSubmitting = true;
    try {
      this.validationMessage = await this.onSave(this.copyRule(this.draft)) ?? '';
    } catch (error) {
      const failure = error as Error;
      this.validationMessage = failure.message;
    } finally {
      this.isSubmitting = false;
    }
  }
}
