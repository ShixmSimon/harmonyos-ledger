import { common } from '@kit.AbilityKit';
import { OcrRuleEditor } from '../../components/ocr/OcrRuleEditor';
import { createDefaultOcrRules } from '../../services/ocrRules/OcrRuleEngine';
import type { OcrCategoryMapping, OcrPattern, OcrRule, OcrSourceMatcher } from '../../services/ocrRules/OcrRuleModels';
import { loadOcrRules, saveOcrRules } from '../../services/OcrRuleStore';

@Component
export struct OcrRuleSettingsView {
  @State private rules: OcrRule[] = [];
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';
  @State private isSavingRules: boolean = false;
  @State private editingRule: OcrRule | undefined = undefined;
  @State private editingIndex: number = -1;
  onBack: () => void = () => {};

  aboutToAppear(): void {
    void this.reloadRules();
  }

  build() {
    if (this.editingRule !== undefined) {
      OcrRuleEditor({
        rule: this.editingRule,
        isSaving: this.isSavingRules,
        onCancel: () => this.closeEditor(),
        onSave: (rule: OcrRule) => this.saveEditedRule(rule),
        onDelete: this.editingIndex < 0 ? undefined : () => {
          void this.deleteRule(this.editingIndex);
        }
      });
    } else {
      this.rulesPage();
    }
  }

  @Builder
  private rulesPage() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Button('返回')
            .backgroundColor('#FFFFFF')
            .fontColor('#344563')
            .onClick(() => this.onBack());
          Blank();
          Text('OCR 识别规则')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#172B4D');
          Blank();
          Blank().width(48);
        }
        .width('100%');

        Text('规则只用于生成待复核草稿。自动识别按来源分数判断；同一来源的多个规则按列表顺序尝试。')
          .fontSize(13)
          .fontColor('#52606D')
          .width('100%');

        if (!this.isLoading && this.errorMessage.length === 0) {
          Button('新增规则')
            .width('100%')
            .backgroundColor('#2857C5')
            .fontColor('#FFFFFF')
            .enabled(!this.isSavingRules)
            .onClick(() => this.openNewRule());
        }

        if (this.isLoading) {
          Text('正在读取规则…')
            .fontSize(13)
            .fontColor('#52606D');
        } else if (this.rules.length === 0 && this.errorMessage.length === 0) {
          Text('当前没有 OCR 规则。自动识别将把截图留在来源确认流程中。')
            .fontSize(13)
            .fontColor('#52606D');
        }
        if (this.errorMessage.length > 0) {
          Column({ space: 8 }) {
            Text(this.errorMessage)
              .fontSize(13)
              .fontColor('#B42318');
            Button('重新读取')
              .backgroundColor('#F1F3F5')
              .fontColor('#344563')
              .enabled(!this.isSavingRules)
              .onClick(() => {
                void this.reloadRules();
              });
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start);
        }
        ForEach(this.rules, (_rule: OcrRule, index: number) => {
          this.ruleCard(index);
        }, (_rule: OcrRule, index: number) => 'ocr-rule-' + index);
      }
      .width('100%')
      .padding(18)
      .alignItems(HorizontalAlign.Start);
    }
    .width('100%')
    .height('100%');
  }

  @Builder
  private ruleCard(index: number) {
    Column({ space: 9 }) {
      Row() {
        Column({ space: 4 }) {
          Text((index + 1) + '. ' + this.rules[index].name)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#172B4D');
          Text(this.rules[index].enabled ? '已启用' : '已停用')
            .fontSize(12)
            .fontColor(this.rules[index].enabled ? '#16845B' : '#7B8794');
        }
        .alignItems(HorizontalAlign.Start);
        Blank();
        Button(this.rules[index].enabled ? '停用' : '启用')
          .backgroundColor(this.rules[index].enabled ? '#F1F3F5' : '#E9F1FF')
          .fontColor(this.rules[index].enabled ? '#344563' : '#2457C5')
          .enabled(!this.isSavingRules)
          .onClick(() => {
            void this.setRuleEnabled(index, !this.rules[index].enabled);
          });
      }
      .width('100%');
      Text('来源：' + this.sourceName(this.rules[index].source) + ' · ' +
        (this.rules[index].layoutStrategy === 'receipt-list' ? '账单列表' : '银行明细'))
        .fontSize(12)
        .fontColor('#52606D')
        .width('100%');
      Text('来源表达式 ' + this.rules[index].sourceMatchers.length + ' 条 · 最低分 ' +
        this.rules[index].minimumScore + ' · 分差 ' + this.rules[index].scoreMargin)
        .fontSize(12)
        .fontColor('#52606D')
        .width('100%');
      Row({ space: 8 }) {
        Button('编辑')
          .layoutWeight(1)
          .backgroundColor('#E9F1FF')
          .fontColor('#2457C5')
          .enabled(!this.isSavingRules)
          .onClick(() => this.openRule(index));
        Button('上移')
          .layoutWeight(1)
          .backgroundColor('#F1F3F5')
          .fontColor('#344563')
          .enabled(!this.isSavingRules && index > 0)
          .onClick(() => {
            void this.moveRule(index, -1);
          });
        Button('下移')
          .layoutWeight(1)
          .backgroundColor('#F1F3F5')
          .fontColor('#344563')
          .enabled(!this.isSavingRules && index < this.rules.length - 1)
          .onClick(() => {
            void this.moveRule(index, 1);
          });
        Button('删除')
          .layoutWeight(1)
          .backgroundColor('#FCE8E6')
          .fontColor('#B42318')
          .enabled(!this.isSavingRules)
          .onClick(() => {
            void this.deleteRule(index);
          });
      }
      .width('100%');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(14);
  }

  private sourceName(source: string): string {
    if (source === 'wechat') {
      return '微信';
    }
    if (source === 'alipay') {
      return '支付宝';
    }
    return '工商银行';
  }

  private async reloadRules(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      this.rules = await loadOcrRules(context);
    } catch (error) {
      const failure = error as Error;
      this.errorMessage = '读取 OCR 识别规则失败：' + failure.message;
    } finally {
      this.isLoading = false;
    }
  }

  private openNewRule(): void {
    const rule = this.copyRule(createDefaultOcrRules()[0]);
    rule.id = 'ocr-rule-' + Date.now().toString(36);
    rule.name = '新 OCR 规则';
    this.editingIndex = -1;
    this.editingRule = rule;
  }

  private openRule(index: number): void {
    this.editingIndex = index;
    this.editingRule = this.copyRule(this.rules[index]);
  }

  private closeEditor(): void {
    this.editingRule = undefined;
    this.editingIndex = -1;
  }

  private async saveEditedRule(rule: OcrRule): Promise<string | undefined> {
    const nextRules = this.rules.slice();
    if (this.editingIndex < 0) {
      nextRules.push(rule);
    } else {
      nextRules[this.editingIndex] = rule;
    }
    const saveError = await this.persistRules(nextRules);
    if (saveError !== undefined) {
      return saveError;
    }
    this.closeEditor();
    return undefined;
  }

  private async setRuleEnabled(index: number, enabled: boolean): Promise<void> {
    const nextRules = this.rules.slice();
    const changed = this.copyRule(nextRules[index]);
    changed.enabled = enabled;
    nextRules[index] = changed;
    await this.persistRules(nextRules);
  }

  private async moveRule(index: number, offset: number): Promise<void> {
    const target = index + offset;
    if (target < 0 || target >= this.rules.length) {
      return;
    }
    const nextRules = this.rules.slice();
    const moving = nextRules[index];
    nextRules[index] = nextRules[target];
    nextRules[target] = moving;
    await this.persistRules(nextRules);
  }

  private async deleteRule(index: number): Promise<void> {
    const nextRules = this.rules.filter((_rule: OcrRule, currentIndex: number) => currentIndex !== index);
    const saveError = await this.persistRules(nextRules);
    if (saveError === undefined && this.editingRule !== undefined) {
      this.closeEditor();
    }
  }

  private async persistRules(rules: OcrRule[]): Promise<string | undefined> {
    if (this.isSavingRules) {
      return '正在保存规则，请稍候';
    }
    this.isSavingRules = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      await saveOcrRules(context, rules);
      this.rules = rules;
      return undefined;
    } catch (error) {
      const failure = error as Error;
      const message = '保存 OCR 识别规则失败：' + failure.message;
      this.errorMessage = message;
      return message;
    } finally {
      this.isSavingRules = false;
    }
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
}
