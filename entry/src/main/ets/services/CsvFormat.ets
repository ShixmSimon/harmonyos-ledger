import { EntrySource } from '../model/LedgerModels';

export const CSV_HEADER: string[] = ['日期', '方向', '金额', '商户/摘要', '分类', '来源', '备注'];

export function csvSourceLabel(source: EntrySource): string {
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

export function parseCsvSourceLabel(label: string): EntrySource | undefined {
  if (label === '微信支付') {
    return 'wechat';
  }
  if (label === '支付宝') {
    return 'alipay';
  }
  if (label === '工商银行') {
    return 'icbc';
  }
  if (label === '中信银行') {
    return 'citic';
  }
  if (label === '手动') {
    return 'manual';
  }
  return undefined;
}

function needsSpreadsheetProtection(value: string): boolean {
  return /^[\t\r\n\u0000=+\-@]/.test(value) ||
    /^[\s\uFEFF]*[=+\-@\uFF1D\uFF0B\uFF0D\uFF20]/.test(value);
}

export function encodeCsvCell(value: string): string {
  const safeValue = needsSpreadsheetProtection(value) ? "'" + value : value;
  return '"' + safeValue.replace(/"/g, '""') + '"';
}

export function decodeCsvCell(value: string): string {
  const hasProtectionPrefix = value.startsWith("'") && needsSpreadsheetProtection(value.slice(1));
  return hasProtectionPrefix ? value.slice(1) : value;
}
