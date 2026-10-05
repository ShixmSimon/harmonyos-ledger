import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { LedgerRepository } from '../data/LedgerRepository';
import {
  EntryDirection,
  EntrySource,
  LedgerEntry,
  formatDateOnly,
  formatDateTime,
  formatMoney,
  hasClockTime,
  makeId,
  parseAmountFen,
  parseDateTime
} from '../model/LedgerModels';
import { LedgerDayGroup, LedgerHomeView } from './ledger/LedgerHomeView';
import { LedgerEditorView } from './ledger/LedgerEditorView';
import { StatisticsRange, statisticsRange } from '../services/LedgerStatistics';
import { StatisticsView } from './statistics/StatisticsView';


@Entry
@Component
struct Index {
  @State private screen: 'ledger' | 'editor' | 'statistics' = 'ledger';
  @State private entries: LedgerEntry[] = [];
  @State private ready: boolean = false;
  @State private errorMessage: string = '';
  @State private pendingDeleteId: string = '';
  @State private statisticsEditorOpen: boolean = false;
  @State private selectedRankValue: string = '';
  @State private pendingDiscardConfirmation: boolean = false;
  @State private editorDirty: boolean = false;
  @State private editorDateError: string = '';
  @State private editorAmountError: string = '';
  @State private monthCursor: number = Date.now();
  @State private ledgerScrollOffset: number = 0;
  @State private restoreLedgerScrollOnAppear: boolean = false;
  @State private editingId: string = '';
  @State private formMerchant: string = '';
  @State private formDateText: string = '';
  @State private formAmountText: string = '';
  @State private formDirection: EntryDirection = 'expense';
  @State private formCategory: string = '其他';
  @State private formNote: string = '';

  @State private cycleStartDay: number = 15;
  private settingsPreferences: preferences.Preferences | undefined = undefined;
  private repository: LedgerRepository = new LedgerRepository();

  aboutToAppear(): void {
    void this.initialize();
  }

  onBackPress(): boolean {
    if (this.pendingDeleteId.length > 0) {
      this.pendingDeleteId = '';
      return true;
    }
    if (this.pendingDiscardConfirmation) {
      this.pendingDiscardConfirmation = false;
      return true;
    }
    if (this.statisticsEditorOpen || this.screen === 'editor') {
      this.requestLeaveEditor();
      return true;
    }
    if (this.screen === 'statistics') {
      if (this.selectedRankValue.length > 0) {
        this.selectedRankValue = '';
      } else {
        this.screen = 'ledger';
      }
      return true;
    }
    return false;
  }

  build() {
    Stack() {
      if (!this.ready) {
        this.loadingView();
      } else if (this.screen === 'editor') {
        LedgerEditorView({
          editingId: this.editingId,
          merchant: this.formMerchant,
          dateText: this.formDateText,
          amountText: this.formAmountText,
          entryDirection: this.formDirection,
          category: this.formCategory,
          note: this.formNote,
          dateError: this.editorDateError,
          amountError: this.editorAmountError,
          onBack: () => this.requestLeaveEditor(),
          onSave: () => {
            void this.saveEditor();
          },
          onChooseDate: () => this.chooseEditorDate(),
          onFieldChange: (field: string, value: string) => this.setFormValue(field, value),
          onDirectionChange: (direction: EntryDirection) => {
            this.editorDirty = this.editorDirty || this.formDirection !== direction;
            this.formDirection = direction;
          }
        });
      } else if (this.screen === 'statistics') {
        StatisticsView({
          entries: this.entries,
          cycleStartDay: this.cycleStartDay,
          selectedRankValue: $selectedRankValue,
          onBack: () => {
            this.selectedRankValue = '';
            this.screen = 'ledger';
          },
          onEditEntry: (entry: LedgerEntry) => this.openEditor(entry, true),
          onDeleteRequest: (entry: LedgerEntry) => {
            this.pendingDeleteId = entry.id;
          }
        });
      } else {
        LedgerHomeView({
          monthEntries: this.monthEntries(),
          dayGroups: this.monthEntryGroupsByDay(),
          incomeTotalFen: this.monthTotal('income'),
          expenseTotalFen: this.monthTotal('expense'),
          monthLabel: this.monthLabel(),
          cycleStartDay: this.cycleStartDay,
          scrollOffset: this.ledgerScrollOffset,
          restoreScrollOnAppear: this.restoreLedgerScrollOnAppear,
          onSaveScroll: (offset: number) => {
            this.ledgerScrollOffset = Math.max(0, offset);
            this.restoreLedgerScrollOnAppear = true;
          },
          onRestoreScrollComplete: () => {
            this.restoreLedgerScrollOnAppear = false;
          },
          onPreviousMonth: () => this.moveMonth(-1),
          onNextMonth: () => this.moveMonth(1),
          onOpenStatistics: () => {
            this.selectedRankValue = '';
            this.screen = 'statistics';
          },
          onCycleStartDayChange: (day: number) => {
            void this.changeCycleStartDay(day);
          },
          onAddEntry: () => this.openEditor(),
          onEditEntry: (entry: LedgerEntry) => this.openEditor(entry),
          onDeleteRequest: (entry: LedgerEntry) => {
            this.pendingDeleteId = entry.id;
          },
          sourceLabel: (source: EntrySource) => this.sourceLabel(source)
        });
      }
      if (this.statisticsEditorOpen) {
        this.statisticsEditorOverlay();
      }
      if (this.pendingDeleteId.length > 0) {
        this.deleteConfirmationView();
      } else if (this.pendingDiscardConfirmation) {
        this.discardConfirmationView();
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7F9');
  }

  @Builder
  private loadingView() {
    Column({ space: 12 }) {
      Text(this.errorMessage.length > 0 ? this.errorMessage : '正在打开本地账本…')
        .fontSize(16)
        .fontColor('#52606D');
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private statisticsEditorOverlay() {
    Column() {
      LedgerEditorView({
        editingId: this.editingId,
        merchant: this.formMerchant,
        dateText: this.formDateText,
        amountText: this.formAmountText,
        entryDirection: this.formDirection,
        category: this.formCategory,
        note: this.formNote,
        dateError: this.editorDateError,
        amountError: this.editorAmountError,
        onBack: () => this.requestLeaveEditor(),
        onSave: () => {
          void this.saveEditor();
        },
        onChooseDate: () => this.chooseEditorDate(),
        onFieldChange: (field: string, value: string) => this.setFormValue(field, value),
        onDirectionChange: (direction: EntryDirection) => {
          this.editorDirty = this.editorDirty || this.formDirection !== direction;
          this.formDirection = direction;
        }
      });
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F7F9')
    .zIndex(1);
  }

  @Builder
  private deleteConfirmationView() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.pendingDeleteId = '';
        });
      Column({ space: 10 }) {
        Text('确定删除这条账目吗？')
          .fontSize(14)
          .fontColor('#344563');
        Text(this.pendingDeleteSummary())
          .width('100%')
          .fontSize(13)
          .fontColor('#7B8794');
        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor('#F1F3F5')
            .fontColor('#344563')
            .onClick(() => {
              this.pendingDeleteId = '';
            });
          Button('确认删除')
            .layoutWeight(1)
            .backgroundColor('#B42318')
            .fontColor('#FFFFFF')
            .onClick(() => {
              void this.confirmDelete();
            });
        }
      }
      .width('90%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .onClick(() => {});
    }
    .width('100%')
    .height('100%')
    .zIndex(1);
  }

  @Builder
  private discardConfirmationView() {
    Column() {
      Column({ space: 10 }) {
        Text('有内容尚未保存，确定放弃并离开吗？')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#344563');
        Row({ space: 10 }) {
          Button('继续编辑')
            .layoutWeight(1)
            .backgroundColor('#F1F3F5')
            .fontColor('#344563')
            .onClick(() => {
              this.pendingDiscardConfirmation = false;
            });
          Button('放弃并离开')
            .layoutWeight(1)
            .backgroundColor('#B42318')
            .fontColor('#FFFFFF')
            .onClick(() => this.discardEditor());
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(16);
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24 })
    .backgroundColor('#66000000')
    .zIndex(1);
  }

  private async initialize(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.Context;
      await this.repository.open(context);
      await this.loadCycleStartDay(context);
      await this.reloadEntries();
      this.ready = true;
    } catch (error) {
      const businessError = error as BusinessError;
      this.errorMessage = '本地账本打开失败：' + businessError.message;
    }
  }

  private async reloadEntries(): Promise<void> {
    this.entries = await this.repository.listEntries();
  }

  private async loadCycleStartDay(context: common.Context): Promise<void> {
    try {
      this.settingsPreferences = await preferences.getPreferences(context, 'ledger_settings');
      const savedDay = this.settingsPreferences.getSync('cycleStartDay', 15);
      if (typeof savedDay === 'number' && savedDay >= 1 && savedDay <= 31) {
        this.cycleStartDay = savedDay;
      }
    } catch (error) {
      this.cycleStartDay = 15;
    }
  }

  private async changeCycleStartDay(day: number): Promise<void> {
    this.cycleStartDay = day;
    try {
      if (this.settingsPreferences === undefined) {
        const context = this.getUIContext().getHostContext() as common.Context;
        this.settingsPreferences = await preferences.getPreferences(context, 'ledger_settings');
      }
      await this.settingsPreferences.put('cycleStartDay', day);
      await this.settingsPreferences.flush();
      this.showToast('周期起始日已设为每月 ' + day + ' 号');
    } catch (error) {
      const businessError = error as BusinessError;
      this.showToast('保存周期起始日失败：' + businessError.message);
    }
  }

  private monthRange(): StatisticsRange {
    return statisticsRange('month', this.monthCursor, 0, 0, this.cycleStartDay);
  }

  private monthEntries(): LedgerEntry[] {
    const range = this.monthRange();
    return this.entries.filter((entry: LedgerEntry) =>
      entry.happenedAt >= range.start && entry.happenedAt < range.endExclusive);
  }

  private monthEntryGroupsByDay(): LedgerDayGroup[] {
    const groups: LedgerDayGroup[] = [];
    this.monthEntries().forEach((entry: LedgerEntry) => {
      const dateKey = formatDateOnly(entry.happenedAt);
      let group = groups.find((item: LedgerDayGroup) => item.dateKey === dateKey);
      if (group === undefined) {
        group = { dateKey: dateKey, entries: [], expenseTotalFen: 0, incomeTotalFen: 0 };
        groups.push(group);
      }
      group.entries.push(entry);
      if (entry.direction === 'expense') {
        group.expenseTotalFen += entry.amountFen;
      } else {
        group.incomeTotalFen += entry.amountFen;
      }
    });
    return groups;
  }

  private monthTotal(direction: EntryDirection): number {
    let total = 0;
    this.monthEntries().forEach((entry: LedgerEntry) => {
      if (entry.direction === direction) {
        total += entry.amountFen;
      }
    });
    return total;
  }

  private monthLabel(): string {
    const range = this.monthRange();
    const start = new Date(range.start);
    const end = new Date(range.endExclusive - 24 * 60 * 60 * 1000);
    const endYear = start.getFullYear() === end.getFullYear() ? '' : end.getFullYear() + '年';
    return start.getFullYear() + '年' + (start.getMonth() + 1) + '月' + start.getDate() +
      '日—' + endYear + (end.getMonth() + 1) + '月' + end.getDate() + '日';
  }

  private moveMonth(offset: number): void {
    const date = new Date(this.monthCursor);
    this.monthCursor = new Date(date.getFullYear(), date.getMonth() + offset, 1).getTime();
  }

  private sourceLabel(source: EntrySource): string {
    if (source === 'wechat') {
      return '微信支付';
    }
    if (source === 'alipay') {
      return '支付宝';
    }
    if (source === 'icbc') {
      return '工商银行';
    }
    if (source === 'citic') {
      return '中信银行';
    }
    return '手动';
  }

  private openEditor(entry?: LedgerEntry, fromStatistics: boolean = false): void {
    this.errorMessage = '';
    this.editorDirty = false;
    this.editorDateError = '';
    this.editorAmountError = '';
    if (entry === undefined) {
      this.editingId = '';
      this.formMerchant = '';
      this.formDateText = formatDateTime(Date.now());
      this.formAmountText = '';
      this.formDirection = 'expense';
      this.formCategory = '其他';
      this.formNote = '';
    } else {
      this.editingId = entry.id;
      this.formMerchant = entry.merchant;
      this.formDateText = entry.hasTime ? formatDateTime(entry.happenedAt) : formatDateOnly(entry.happenedAt);
      this.formAmountText = (entry.amountFen / 100).toFixed(2);
      this.formDirection = entry.direction;
      this.formCategory = entry.category;
      this.formNote = entry.note;
    }
    if (fromStatistics) {
      this.statisticsEditorOpen = true;
    } else {
      this.statisticsEditorOpen = false;
      this.screen = 'editor';
    }
  }

  private setFormValue(field: string, value: string): void {
    if (field === 'merchant') {
      this.editorDirty = this.editorDirty || this.formMerchant !== value;
      this.formMerchant = value;
    } else if (field === 'date') {
      this.editorDirty = this.editorDirty || this.formDateText !== value;
      this.formDateText = value;
      this.editorDateError = '';
    } else if (field === 'amount') {
      this.editorDirty = this.editorDirty || this.formAmountText !== value;
      this.formAmountText = value;
      this.editorAmountError = '';
    } else if (field === 'category') {
      this.editorDirty = this.editorDirty || this.formCategory !== value;
      this.formCategory = value;
    } else {
      this.editorDirty = this.editorDirty || this.formNote !== value;
      this.formNote = value;
    }
  }

  private chooseEditorDate(): void {
    const current = parseDateTime(this.formDateText) ?? Date.now();
    const uiContext = this.getUIContext();
    uiContext.showDatePickerDialog({
      selected: new Date(current),
      onDateAccept: (date: Date) => {
        const selected = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
        const time = this.formDateText.trim().match(/(?:^|\s)(\d{1,2}):(\d{2})$/);
        const dateText = formatDateOnly(selected);
        const value = time === null ? dateText : dateText + ' ' +
          String(Number(time[1])).padStart(2, '0') + ':' + time[2];
        uiContext.runScopedTask(() => {
          this.setFormValue('date', value);
        });
      }
    });
  }

  private async saveEditor(): Promise<void> {
    const date = parseDateTime(this.formDateText);
    const amountFen = parseAmountFen(this.formAmountText);
    this.editorDateError = date === undefined ? '请填写有效日期，例如 2026-10-04 18:30。' : '';
    this.editorAmountError = amountFen === undefined || amountFen <= 0 ? '金额需为大于 0 的有效数字。' : '';
    if (this.editorDateError.length > 0 || this.editorAmountError.length > 0 ||
      date === undefined || amountFen === undefined || amountFen <= 0) {
      return;
    }
    const existing = this.findEntry(this.editingId);
    const entry: LedgerEntry = {
      id: this.editingId.length > 0 ? this.editingId : makeId('entry'),
      happenedAt: date,
      hasTime: hasClockTime(this.formDateText),
      amountFen: amountFen,
      direction: this.formDirection,
      source: existing === undefined ? 'manual' : existing.source,
      merchant: this.formMerchant.trim(),
      category: this.formCategory.trim().length > 0 ? this.formCategory.trim() : '其他',
      note: this.formNote.trim()
    };
    try {
      if (this.editingId.length > 0) {
        await this.repository.updateEntry(entry);
      } else {
        await this.repository.addEntry(entry);
      }
      await this.reloadEntries();
      const editingFromStatistics = this.statisticsEditorOpen;
      if (!editingFromStatistics) {
        this.monthCursor = date;
      }
      this.editorDirty = false;
      if (editingFromStatistics) {
        this.statisticsEditorOpen = false;
      } else {
        this.screen = 'ledger';
      }
      this.showToast('账目已保存');
    } catch (error) {
      const businessError = error as BusinessError;
      this.showToast('保存失败：' + businessError.message);
    }
  }

  private findEntry(id: string): LedgerEntry | undefined {
    return this.entries.find((entry: LedgerEntry) => entry.id === id);
  }

  private pendingDeleteSummary(): string {
    const entry = this.findEntry(this.pendingDeleteId);
    if (entry === undefined) {
      return '该账目已不存在';
    }
    const dateText = entry.hasTime ? formatDateTime(entry.happenedAt) : formatDateOnly(entry.happenedAt);
    const merchant = entry.merchant.length > 0 ? entry.merchant : '未填写摘要';
    return merchant + ' · ' + formatMoney(entry.amountFen) + '\n' + dateText;
  }

  private async confirmDelete(): Promise<void> {
    try {
      const deletedId = this.pendingDeleteId;
      await this.repository.deleteEntry(deletedId);
      this.entries = await this.repository.listEntries();
      this.pendingDeleteId = '';
      this.showToast('账目已删除');
    } catch (error) {
      const businessError = error as BusinessError;
      this.showToast('删除失败：' + businessError.message);
    }
  }

  private requestLeaveEditor(): void {
    if (this.editorDirty) {
      this.pendingDiscardConfirmation = true;
      return;
    }
    this.discardEditor();
  }

  private discardEditor(): void {
    const editingFromStatistics = this.statisticsEditorOpen;
    this.pendingDiscardConfirmation = false;
    this.editorDirty = false;
    this.editorDateError = '';
    this.editorAmountError = '';
    if (editingFromStatistics) {
      this.statisticsEditorOpen = false;
    } else {
      this.screen = 'ledger';
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message });
  }
}
