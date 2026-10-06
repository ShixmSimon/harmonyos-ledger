import { common } from '@kit.AbilityKit';
import { NotificationRuleEditor } from '../../components/notifications/NotificationRuleEditor';
import { NotificationCategoryMapping, NotificationRule } from '../../services/notificationRules/NotificationRuleModels';
import { loadNotificationRules, saveNotificationRules } from '../../services/NotificationRuleStore';

@Component
export struct NotificationRuleSettingsView {
  @State private rules: NotificationRule[] = [];
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';
  @State private isSavingRules: boolean = false;
  @State private editingRule: NotificationRule | undefined = undefined;
  @State private editingIndex: number = -1;
  onBack: () => void = () => {};

  aboutToAppear(): void {
    void this.reloadRules();
  }

  build() {
    if (this.editingRule !== undefined) {
      NotificationRuleEditor({
        rule: this.editingRule,
        isSaving: this.isSavingRules,
        onCancel: () => this.closeEditor(),
        onSave: (rule: NotificationRule) => this.saveEditedRule(rule),
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
            .onClick(() => {
              this.onBack();
            });
          Blank();
          Text('通知识别规则')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#172B4D');
          Blank();
          Blank().width(48);
        }
        .width('100%');

        Text('按列表顺序匹配通知。默认规则包含工商银行、中信银行、支付宝和微信支付；删除或清空后不会自动恢复。')
          .fontSize(13)
          .fontColor('#52606D')
          .width('100%');

        if (!this.isLoading && this.errorMessage.length === 0) {
          Button('新增规则')
            .width('100%')
            .backgroundColor('#2857C5')
            .fontColor('#FFFFFF')
            .enabled(!this.isSavingRules)
            .onClick(() => {
              this.openNewRule();
            });
        }

        if (this.isLoading) {
          Text('正在读取规则…')
            .fontSize(13)
            .fontColor('#52606D');
        } else if (this.rules.length === 0 && this.errorMessage.length === 0) {
          Text('当前没有识别规则。新增规则后，匹配的通知才会自动入账。')
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
        ForEach(this.rules, (rule: NotificationRule, index: number) => {
          this.ruleCard(index);
        }, (_rule: NotificationRule, index: number) => 'rule-' + index);
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
      Text('来源：' + this.rules[index].sourceKeywords.join('、'))
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

  private async reloadRules(): Promise<void> {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      this.rules = await loadNotificationRules(context);
    } catch (error) {
      const failure = error as Error;
      this.errorMessage = '读取通知规则失败：' + failure.message;
    } finally {
      this.isLoading = false;
    }
  }

  private openNewRule(): void {
    this.editingIndex = -1;
    this.editingRule = {
      id: 'rule-' + Date.now().toString(36),
      name: '',
      enabled: true,
      sourceKeywords: [],
      bodyPattern: '',
      amountGroup: 1,
      directionGroup: 2,
      incomeText: '收入',
      expenseText: '支出',
      dateFormat: '',
      dateStrategy: 'delivery-time',
      defaultMerchant: '',
      defaultCategory: '其他',
      categoryMappings: [],
      merchantPrefixToStrip: '',
      noteTemplate: ''
    };
  }

  private openRule(index: number): void {
    this.editingIndex = index;
    this.editingRule = this.copyRule(this.rules[index]);
  }

  private closeEditor(): void {
    this.editingRule = undefined;
    this.editingIndex = -1;
  }

  private async saveEditedRule(rule: NotificationRule): Promise<string | undefined> {
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
    const nextRules = this.rules.filter((_rule: NotificationRule, currentIndex: number) => currentIndex !== index);
    const saveError = await this.persistRules(nextRules);
    if (saveError === undefined && this.editingRule !== undefined) {
      this.closeEditor();
    }
  }

  private async persistRules(rules: NotificationRule[]): Promise<string | undefined> {
    if (this.isSavingRules) {
      return '正在保存规则，请稍候';
    }
    this.isSavingRules = true;
    this.errorMessage = '';
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      await saveNotificationRules(context, rules);
      this.rules = rules;
      return undefined;
    } catch (error) {
      const failure = error as Error;
      const message = '保存通知规则失败：' + failure.message;
      this.errorMessage = message;
      return message;
    } finally {
      this.isSavingRules = false;
    }
  }

  private copyRule(rule: NotificationRule): NotificationRule {
    const categoryMappings: NotificationCategoryMapping[] = [];
    rule.categoryMappings.forEach((mapping: NotificationCategoryMapping) => {
      const copiedMapping: NotificationCategoryMapping = {
        text: mapping.text,
        matchMode: mapping.matchMode,
        category: mapping.category
      };
      categoryMappings.push(copiedMapping);
    });
    return {
      id: rule.id,
      name: rule.name,
      enabled: rule.enabled,
      sourceKeywords: rule.sourceKeywords.slice(),
      bodyPattern: rule.bodyPattern,
      amountGroup: rule.amountGroup,
      directionGroup: rule.directionGroup,
      incomeText: rule.incomeText,
      expenseText: rule.expenseText,
      dateGroup: rule.dateGroup,
      dateFormat: rule.dateFormat,
      dateStrategy: rule.dateStrategy,
      merchantGroup: rule.merchantGroup,
      categoryGroup: rule.categoryGroup,
      defaultMerchant: rule.defaultMerchant,
      defaultCategory: rule.defaultCategory,
      categoryMappings: categoryMappings,
      merchantPrefixToStrip: rule.merchantPrefixToStrip,
      noteTemplate: rule.noteTemplate,
      entrySource: rule.entrySource
    };
  }
}
