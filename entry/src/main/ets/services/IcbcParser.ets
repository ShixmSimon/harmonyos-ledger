import { DraftEntry, EntryDirection, EntrySource, LedgerEntry, formatDateOnly, formatDateTime, makeId, parseAmountFen, parseDateTime } from '../model/LedgerModels';
import { OcrLine } from '../model/OcrModels';

interface VisualRow {
  text: string;
  centerY: number;
  height: number;
  lines: OcrLine[];
}

interface MonthContext {
  year: number;
  month: number;
}

interface ParsedAmount {
  fen: number;
  direction: EntryDirection;
  raw: string;
}

interface TimeOfDay {
  hour: number;
  minute: number;
}

interface AmountRow {
  index: number;
  value: ParsedAmount;
}

interface TimeRow {
  index: number;
  value: TimeOfDay;
}

interface MerchantDetails {
  merchant: string;
  category: string;
}

function median(values: number[]): number {
  if (values.length === 0) {
    return 20;
  }
  const sorted = values.slice().sort((left: number, right: number) => left - right);
  return sorted[Math.floor(sorted.length / 2)];
}

function buildRows(lines: OcrLine[]): VisualRow[] {
  const sorted = lines.filter((line: OcrLine) => line.text.trim().length > 0)
    .slice()
    .sort((left: OcrLine, right: OcrLine) => left.centerY - right.centerY);
  const tolerance = Math.max(10, median(sorted.map((line: OcrLine) => line.height)) * 0.72);
  const rows: VisualRow[] = [];
  sorted.forEach((line: OcrLine) => {
    const previous = rows.length > 0 ? rows[rows.length - 1] : undefined;
    if (previous !== undefined && Math.abs(previous.centerY - line.centerY) <= tolerance) {
      previous.lines.push(line);
      previous.text += ' ' + line.text.trim();
      previous.centerY = previous.lines.reduce((sum: number, item: OcrLine) => sum + item.centerY, 0) /
        previous.lines.length;
      previous.height = Math.max(previous.height, line.height);
    } else {
      rows.push({
        text: line.text.trim(),
        centerY: line.centerY,
        height: line.height,
        lines: [line]
      });
    }
  });
  return rows;
}

function parseMonth(text: string, imageDate: Date | undefined): MonthContext | undefined {
  const normalized = text.replace(/\s/g, '');
  const explicit = normalized.match(/(20\d{2})年(\d{1,2})月/);
  if (explicit !== null) {
    const year = Number(explicit[1]);
    const month = Number(explicit[2]);
    return month >= 1 && month <= 12 ? { year: year, month: month } : undefined;
  }
  const short = normalized.match(/(^|\D)(\d{1,2})月($|\D)/);
  if (short !== null && imageDate !== undefined) {
    const month = Number(short[2]);
    return month >= 1 && month <= 12 ? { year: imageDate.getFullYear(), month: month } : undefined;
  }
  return undefined;
}

function makeDate(year: number, month: number, day: number): number | undefined {
  const date = new Date(year, month - 1, day, 0, 0, 0, 0);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    return undefined;
  }
  return date.getTime();
}

function resolveWeekday(text: string, month: MonthContext | undefined, imageDate: Date | undefined): number | undefined {
  const match = text.replace(/\s/g, '').match(/周([一二三四五六日天])/);
  if (match === null || imageDate === undefined) {
    return undefined;
  }
  const weekdayMap: Record<string, number> = {
    '日': 0,
    '天': 0,
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6
  };
  const expected = weekdayMap[match[1]];
  for (let daysAgo = 0; daysAgo < 7; daysAgo++) {
    const candidate = new Date(imageDate.getFullYear(), imageDate.getMonth(), imageDate.getDate() - daysAgo, 0);
    if (candidate.getDay() === expected &&
      (month === undefined || (candidate.getFullYear() === month.year && candidate.getMonth() + 1 === month.month))) {
      return candidate.getTime();
    }
  }
  return undefined;
}

function parseDateMarker(text: string, month: MonthContext | undefined, imageDate: Date | undefined): number | undefined {
  const normalized = text.replace(/\s/g, '');
  const full = normalized.match(/(20\d{2})[-/.年](\d{1,2})[-/.月](\d{1,2})日?/);
  if (full !== null) {
    return makeDate(Number(full[1]), Number(full[2]), Number(full[3]));
  }
  if (month !== undefined) {
    const monthDay = normalized.match(/(\d{1,2})月(\d{1,2})日/);
    if (monthDay !== null) {
      return makeDate(month.year, Number(monthDay[1]), Number(monthDay[2]));
    }
    if (/^\d{1,2}$/.test(normalized)) {
      return makeDate(month.year, month.month, Number(normalized));
    }
  }
  return resolveWeekday(normalized, month, imageDate);
}

function parseSignedAmount(text: string): ParsedAmount | undefined {
  if (/余额|人民币余额|当页汇总|收\s*[¥￥]|支\s*[¥￥]/.test(text)) {
    return undefined;
  }
  const match = text.match(/[+-]\s*[¥￥]?\s*\d+(?:[,.]\d{3})*(?:[,.]\d{1,2})?/);
  if (match === null) {
    return undefined;
  }
  const raw = match[0].trim();
  const numeric = raw.replace(/[+\-¥￥\s]/g, '');
  const fen = parseAmountFen(numeric);
  if (fen === undefined || fen <= 0) {
    return undefined;
  }
  return {
    fen: fen,
    direction: raw.indexOf('-') >= 0 ? 'expense' : 'income',
    raw: raw
  };
}

function parseTime(text: string): TimeOfDay | undefined {
  const match = text.match(/(?:^|\D)(\d{1,2}):(\d{2})(?::\d{2})?(?:\D|$)/);
  if (match === null) {
    return undefined;
  }
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) {
    return undefined;
  }
  return { hour: hour, minute: minute };
}

function withTime(date: number, time: TimeOfDay | undefined): number {
  const source = new Date(date);
  if (time === undefined) {
    return date;
  }
  return new Date(source.getFullYear(), source.getMonth(), source.getDate(), time.hour, time.minute).getTime();
}

function isBalanceRow(text: string): boolean {
  return /余额\s*[:：]/.test(text);
}

function isFailedBlock(rows: VisualRow[]): boolean {
  return /(交易失败|交易关闭|已撤销|已取消|失败)/.test(rows.map((row: VisualRow) => row.text).join(' '));
}

function isRefundBlock(rows: VisualRow[]): boolean {
  return /(退款|退回|已退)/.test(rows.map((row: VisualRow) => row.text).join(' '));
}

function isNoiseMerchant(text: string): boolean {
  return text.length === 0 ||
    /余额|人民币余额|借记卡|信用卡|尾号|当页汇总|^(周[一二三四五六日天]|\d{1,2})$/.test(text) ||
    /^(消费|转账|收入|支出|ATM取款)$/.test(text) ||
    /^[-—–]+$/.test(text) ||
    parseMonth(text, undefined) !== undefined ||
    parseSignedAmount(text) !== undefined ||
    parseTime(text) !== undefined;
}

function merchantAndCategory(rows: VisualRow[]): MerchantDetails {
  let category = '其他';
  const parts: string[] = [];
  rows.forEach((row: VisualRow) => {
    const original = row.text.trim();
    const text = original
      .replace(/[+-]\s*[¥￥]?\s*\d+(?:[,.]\d{3})*(?:[,.]\d{1,2})?/g, '')
      .replace(/\d{1,2}:\d{2}(?::\d{2})?/g, '')
      .trim();
    if (/ATM取款/.test(original)) {
      category = '取现';
    } else if (/贷款本息/.test(original)) {
      category = '贷款';
    } else if (/消费/.test(original) && category === '其他') {
      category = '消费';
    }
    if (!isNoiseMerchant(text) && !parts.includes(text)) {
      parts.push(text);
    }
  });
  let merchant = parts.length > 0 ? parts[parts.length - 1] : '';
  if (parts.length >= 2 && /贷款本息/.test(parts[0])) {
    merchant = parts[0] + ' ' + parts[parts.length - 1];
  }
  if (merchant.length === 0 && rows.some((row: VisualRow) => /ATM取款/.test(row.text))) {
    merchant = 'ATM取款';
  }
  return { merchant: merchant, category: category };
}

function sameDay(first: number, second: number): boolean {
  const left = new Date(first);
  const right = new Date(second);
  return left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() && left.getDate() === right.getDate();
}

function isDuplicate(
  date: number,
  amount: ParsedAmount,
  merchant: string,
  existing: LedgerEntry[],
  priorDrafts: DraftEntry[],
  drafts: DraftEntry[]
): boolean {
  const normalized = merchant.replace(/\s/g, '').toLowerCase();
  for (const entry of existing) {
    if (entry.source === 'icbc' && entry.amountFen === amount.fen && sameDay(entry.happenedAt, date) &&
      entry.merchant.replace(/\s/g, '').toLowerCase() === normalized) {
      return true;
    }
  }
  for (const draft of priorDrafts.concat(drafts)) {
    const draftDate = parseDateTime(draft.dateText);
    if (draft.source === 'icbc' && parseAmountFen(draft.amountText) === amount.fen &&
      draftDate !== undefined && sameDay(draftDate, date) &&
      draft.merchant.replace(/\s/g, '').toLowerCase() === normalized) {
      return true;
    }
  }
  return false;
}

function parseBlock(
  rows: VisualRow[],
  date: number | undefined,
  existing: LedgerEntry[],
  priorDrafts: DraftEntry[],
  result: DraftEntry[]
): void {
  if (rows.length === 0 || isFailedBlock(rows)) {
    return;
  }
  const amounts: AmountRow[] = [];
  rows.forEach((row: VisualRow, index: number) => {
    const amount = parseSignedAmount(row.text);
    if (amount !== undefined) {
      amounts.push({ index: index, value: amount });
    }
  });
  for (const candidate of amounts) {
    const amount = candidate.value;
    const times: TimeRow[] = [];
    rows.forEach((row: VisualRow, index: number) => {
      const time = parseTime(row.text);
      if (time !== undefined) {
        times.push({ index: index, value: time });
      }
    });
    let transactionTime: TimeOfDay | undefined = undefined;
    if (times.length > 0) {
      times.sort((left, right) => Math.abs(left.index - candidate.index) - Math.abs(right.index - candidate.index));
      transactionTime = times[0].value;
    }

    let happenedAt = date;
    if (happenedAt !== undefined) {
      happenedAt = withTime(happenedAt, transactionTime);
    }
    if (happenedAt === undefined) {
      continue;
    }

    const details = merchantAndCategory(rows);
    const refund = isRefundBlock(rows);
    const warnings: string[] = [];
    let direction: EntryDirection | undefined = amount.direction;
    if (refund) {
      direction = undefined;
      warnings.push('识别到退款，请确认收入或支出方向');
    }
    if (details.merchant.length === 0) {
      warnings.push('未识别到商户或摘要');
    }
    if (isDuplicate(happenedAt, amount, details.merchant, existing, priorDrafts, result)) {
      warnings.push('与已有账目相似，可能是重复记录');
    }
    result.push({
      id: makeId('draft'),
      source: 'icbc',
      merchant: details.merchant,
      dateText: transactionTime === undefined ? formatDateOnly(happenedAt) : formatDateTime(happenedAt),
      hasTime: transactionTime !== undefined,
      amountText: (amount.fen / 100).toFixed(2),
      direction: direction,
      category: refund ? '退款' : details.category,
      checked: true,
      isRefund: refund,
      warnings: warnings
    });
  }
}

export class IcbcParser {
  static parse(
    lines: OcrLine[],
    existing: LedgerEntry[],
    priorDrafts: DraftEntry[] = [],
    captureTime?: number
  ): DraftEntry[] {
    const rows = buildRows(lines);
    const imageDate = captureTime === undefined ? undefined : new Date(captureTime);
    let month: MonthContext | undefined = undefined;
    let currentDate: number | undefined = undefined;
    let blockDate: number | undefined = undefined;
    let blockRows: VisualRow[] = [];
    const result: DraftEntry[] = [];

    rows.forEach((row: VisualRow) => {
      const newMonth = parseMonth(row.text, imageDate);
      if (newMonth !== undefined) {
        parseBlock(blockRows, blockDate, existing, priorDrafts, result);
        blockRows = [];
        month = newMonth;
        currentDate = undefined;
        blockDate = undefined;
        return;
      }

      const marker = parseDateMarker(row.text, month, imageDate);
      if (marker !== undefined) {
        currentDate = marker;
        blockDate = marker;
      }
      blockRows.push(row);

      if (isBalanceRow(row.text)) {
        parseBlock(blockRows, blockDate === undefined ? currentDate : blockDate,
          existing, priorDrafts, result);
        blockRows = [];
        blockDate = currentDate;
      }
    });
    parseBlock(blockRows, blockDate === undefined ? currentDate : blockDate, existing, priorDrafts, result);
    return result;
  }
}
