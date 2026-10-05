import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { LedgerEntry, formatDateOnly, formatDateTime, formatMoney } from '../model/LedgerModels';

function csvCell(value: string): string {
  let safeValue = value;
  if (/^[\t\r\n\u0000=+\-@]/.test(safeValue) ||
      /^[\s\uFEFF]*[=+\-@\uFF1D\uFF0B\uFF0D\uFF20]/.test(safeValue)) {
    safeValue = "'" + safeValue;
  }
  return '"' + safeValue.replace(/"/g, '""') + '"';
}

function sourceLabel(source: string): string {
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

export class CsvExporter {
  static async export(context: common.UIAbilityContext, entries: LedgerEntry[]): Promise<boolean> {
    const rows: string[] = ['日期,方向,金额,商户/摘要,分类,来源,备注'];
    entries.forEach((entry: LedgerEntry) => {
      rows.push([
        csvCell(entry.hasTime ? formatDateTime(entry.happenedAt) : formatDateOnly(entry.happenedAt)),
        csvCell(entry.direction === 'income' ? '收入' : '支出'),
        csvCell(formatMoney(entry.amountFen)),
        csvCell(entry.merchant),
        csvCell(entry.category),
        csvCell(sourceLabel(entry.source)),
        csvCell(entry.note)
      ].join(','));
    });
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = ['鸿蒙记账.csv'];
    options.fileSuffixChoices = ['csv'];
    const documentPicker = new picker.DocumentViewPicker(context);
    const uris = await documentPicker.save(options);
    if (uris.length === 0) {
      return false;
    }
    const file = await fileIo.open(
      uris[0],
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    try {
      fileIo.writeSync(file.fd, '\uFEFF' + rows.join('\r\n'));
    } finally {
      fileIo.closeSync(file);
    }
    return true;
  }
}
