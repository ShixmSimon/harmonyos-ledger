export type EntryDirection = 'income' | 'expense';

export type ImportSource = 'wechat' | 'alipay' | 'icbc';
export type EntrySource = 'manual' | ImportSource | 'citic';

export interface LedgerEntry {
  id: string;
  happenedAt: number;
  hasTime: boolean;
  amountFen: number;
  direction: EntryDirection;
  source: EntrySource;
  merchant: string;
  category: string;
  note: string;
}

export interface DraftEntry {
  id: string;
  source: EntrySource;
  merchant: string;
  dateText: string;
  hasTime: boolean;
  amountText: string;
  direction: EntryDirection | undefined;
  category: string;
  checked: boolean;
  isRefund: boolean;
  warnings: string[];
}

export function formatDateTime(timestamp: number): string {
  const date = new Date(timestamp);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hour = String(date.getHours()).padStart(2, '0');
  const minute = String(date.getMinutes()).padStart(2, '0');
  return year + '-' + month + '-' + day + ' ' + hour + ':' + minute;
}

export function formatDateOnly(timestamp: number): string {
  return formatDateTime(timestamp).slice(0, 10);
}

export function hasClockTime(value: string): boolean {
  const match = value.trim().match(/(?:^|\D)(\d{1,2}):(\d{2})(?::\d{2})?(?:\D|$)/);
  if (match === null) {
    return false;
  }
  return Number(match[1]) <= 23 && Number(match[2]) <= 59;
}

export function parseDateTime(value: string): number | undefined {
  const match = value.trim().match(/^(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})(?:日)?(?:\s+(\d{1,2}):(\d{1,2}))?$/);
  if (match === null) {
    return undefined;
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = match[4] === undefined ? 0 : Number(match[4]);
  const minute = match[5] === undefined ? 0 : Number(match[5]);
  const date = new Date(year, month - 1, day, hour, minute, 0, 0);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    return undefined;
  }
  return date.getTime();
}

export function parseAmountFen(value: string): number | undefined {
  const raw = value.trim().replace(/[¥￥\s]/g, '');
  if (!/^\d+(?:[.,]\d+)*$/.test(raw)) {
    return undefined;
  }
  const lastSeparator = Math.max(raw.lastIndexOf('.'), raw.lastIndexOf(','));
  const fraction = lastSeparator >= 0 ? raw.slice(lastSeparator + 1) : '';
  const hasDecimal = lastSeparator >= 0 && fraction.length > 0 && fraction.length <= 2;
  const yuanText = (hasDecimal ? raw.slice(0, lastSeparator) : raw).replace(/[.,]/g, '');
  const yuan = Number(yuanText);
  const fen = hasDecimal ? Number((fraction + '00').slice(0, 2)) : 0;
  if (!Number.isFinite(yuan) || !Number.isFinite(fen) || yuan < 0) {
    return undefined;
  }
  return yuan * 100 + fen;
}

export function formatMoney(amountFen: number): string {
  const yuan = Math.floor(amountFen / 100);
  const fen = String(amountFen % 100).padStart(2, '0');
  return '¥' + yuan + '.' + fen;
}

export function makeId(prefix: string): string {
  return prefix + '-' + Date.now().toString(36) + '-' + Math.floor(Math.random() * 1000000).toString(36);
}
