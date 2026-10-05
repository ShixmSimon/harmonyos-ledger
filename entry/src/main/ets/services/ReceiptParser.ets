import { DraftEntry, EntryDirection, EntrySource, LedgerEntry, formatDateOnly, formatDateTime, makeId, parseAmountFen, parseDateTime } from '../model/LedgerModels';
import { OcrLine } from '../model/OcrModels';

interface VisualRow {
  text: string;
  centerY: number;
  height: number;
  left: number;
  right: number;
  lines: OcrLine[];
}

interface AmountToken {
  fen: number;
  direction: EntryDirection | undefined;
  raw: string;
}

interface DateContext {
  year: number;
  month: number;
}

interface ParsedDateTime {
  timestamp: number;
  hasTime: boolean;
}

interface TimeOfDay {
  hour: number;
  minute: number;
}

const ALIPAY_CATEGORY_LABELS: string[] = [
  '餐饮美食', '日用百货', '交通出行', '数码电器', '服饰装扮', '文化休闲', '商业服务', '信用借还',
  '充值缴费', '生活服务', '医疗健康', '运动户外', '教育培训', '美容美发', '酒店旅游', '宠物生活',
  '母婴亲子', '食品酒水', '家居家装', '生活缴费', '公益', '保险', '转账'
];

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
  const typicalHeight = median(sorted.map((line: OcrLine) => line.height));
  const tolerance = Math.max(10, typicalHeight * 0.72);
  const rows: VisualRow[] = [];
  sorted.forEach((line: OcrLine) => {
    const previous = rows.length > 0 ? rows[rows.length - 1] : undefined;
    if (previous !== undefined && Math.abs(previous.centerY - line.centerY) <= tolerance) {
      previous.lines.push(line);
      previous.text += ' ' + line.text.trim();
      previous.centerY = previous.lines.reduce((sum: number, item: OcrLine) => sum + item.centerY, 0) /
        previous.lines.length;
      previous.height = Math.max(previous.height, line.height);
      previous.left = Math.min(previous.left, line.left);
      previous.right = Math.max(previous.right, line.right);
    } else {
      rows.push({
        text: line.text.trim(),
        centerY: line.centerY,
        height: line.height,
        left: line.left,
        right: line.right,
        lines: [line]
      });
    }
  });
  return rows;
}

function parseMonthContext(text: string, baseDate: Date | undefined): DateContext | undefined {
  const normalized = text.replace(/\s/g, '');
  const full = normalized.match(/^(20\d{2})年(\d{1,2})月$/);
  if (full !== null) {
    const year = Number(full[1]);
    const month = Number(full[2]);
    return month >= 1 && month <= 12 ? { year: year, month: month } : undefined;
  }
  const short = normalized.match(/^(\d{1,2})月$/);
  if (short !== null && baseDate !== undefined) {
    const month = Number(short[1]);
    return month >= 1 && month <= 12 ? { year: baseDate.getFullYear(), month: month } : undefined;
  }
  return undefined;
}

function inferYear(month: number, day: number, baseDate: Date | undefined, context: DateContext | undefined): number | undefined {
  if (context !== undefined) {
    return context.year;
  }
  if (baseDate === undefined) {
    return undefined;
  }
  const year = baseDate.getFullYear();
  const candidate = makeDate(year, month, day);
  if (candidate === undefined) {
    return year;
  }
  const baseDay = new Date(year, baseDate.getMonth(), baseDate.getDate(), 0, 0, 0, 0).getTime();
  return candidate > baseDay ? year - 1 : year;
}

function parseTimeOfDay(text: string): TimeOfDay | undefined {
  const normalized = text.replace(/：/g, ':');
  const separated = normalized.match(/(?:^|\D)(\d{1,2}):(\d{2})(?::\d{2})?(?:\D|$)/);
  if (separated !== null) {
    const hour = Number(separated[1]);
    const minute = Number(separated[2]);
    if (hour <= 23 && minute <= 59) {
      return { hour: hour, minute: minute };
    }
  }

  const compact = normalized.replace(/\s/g, '');
  const joinedDateTime = compact.match(/(?:^|\D)(\d{1,2})[-/](\d{1,2})(\d{2}):(\d{2})(?::\d{2})?(?:\D|$)/);
  if (joinedDateTime !== null) {
    const hour = Number(joinedDateTime[3]);
    const minute = Number(joinedDateTime[4]);
    if (hour <= 23 && minute <= 59) {
      return { hour: hour, minute: minute };
    }
  }
  return undefined;
}

function parsedDate(year: number, month: number, day: number, time: TimeOfDay | undefined): ParsedDateTime | undefined {
  const timestamp = makeDate(year, month, day, time === undefined ? 0 : time.hour,
    time === undefined ? 0 : time.minute);
  return timestamp === undefined ? undefined : { timestamp: timestamp, hasTime: time !== undefined };
}

function parseDateHeader(text: string, baseDate: Date | undefined, context?: DateContext): ParsedDateTime | undefined {
  const time = parseTimeOfDay(text);
  const hour = time === undefined ? 0 : time.hour;
  const minute = time === undefined ? 0 : time.minute;
  const normalized = text.replace(/\s/g, '').replace(/：/g, ':');
  const dateOnly = normalized.replace(/\d{1,2}:\d{2}(?::\d{2})?/g, '');
  const full = dateOnly.match(/(20\d{2})[-/.年](\d{1,2})[-/.月](\d{1,2})日?/);
  if (full !== null) {
    return parsedDate(Number(full[1]), Number(full[2]), Number(full[3]), time);
  }
  const short = dateOnly.match(/(\d{1,2})月(\d{1,2})日/);
  if (short !== null) {
    const month = Number(short[1]);
    const day = Number(short[2]);
    const year = inferYear(month, day, baseDate, context);
    if (year !== undefined) {
      return parsedDate(year, month, day, time);
    }
  }
  const numericShort = dateOnly.match(/(\d{1,2})[-/](\d{1,2})/);
  if (numericShort !== null) {
    const month = Number(numericShort[1]);
    const day = Number(numericShort[2]);
    const year = inferYear(month, day, baseDate, context);
    if (year !== undefined) {
      return parsedDate(year, month, day, time);
    }
  }
  if (normalized.indexOf('今天') >= 0 && baseDate !== undefined) {
    return {
      timestamp: new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate(), hour, minute).getTime(),
      hasTime: time !== undefined
    };
  }
  if (normalized.indexOf('昨天') >= 0 && baseDate !== undefined) {
    return {
      timestamp: new Date(baseDate.getFullYear(), baseDate.getMonth(), baseDate.getDate() - 1, hour, minute).getTime(),
      hasTime: time !== undefined
    };
  }
  return undefined;
}

function makeDate(year: number, month: number, day: number, hour: number = 0, minute: number = 0): number | undefined {
  const date = new Date(year, month - 1, day, hour, minute, 0, 0);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) {
    return undefined;
  }
  return date.getTime();
}

function extractAmount(text: string): AmountToken | undefined {
  const searchable = text
    .replace(/20\d{2}[-/.年]\d{1,2}[-/.月]\d{1,2}日?/g, ' ')
    .replace(/\d{1,2}月\d{1,2}日/g, ' ')
    .replace(/\d{1,2}:\d{2}/g, ' ')
    .replace(/\d{1,2}[-/]\d{1,2}/g, ' ');
  let raw = '';
  let numeric = '';
  let sign = '';
  const explicit = searchable.match(/(?:[+-]\s*[¥￥]?\s*\d+(?:[,.]\d{3})*(?:[,.]\d{1,2})?|[¥￥]\s*[+-]?\s*\d+(?:[,.]\d{3})*(?:[,.]\d{1,2})?)/);
  if (explicit !== null) {
    raw = explicit[0].trim();
    const numberMatch = raw.match(/\d+(?:[,.]\d{3})*(?:[,.]\d{1,2})?/);
    if (numberMatch === null) {
      return undefined;
    }
    numeric = numberMatch[0];
    sign = raw.indexOf('-') >= 0 ? '-' : (raw.indexOf('+') >= 0 ? '+' : '');
  } else {
    const decimalPattern = /\d+(?:[,.]\d{3})*[,.]\d{1,2}/g;
    let decimalMatch = decimalPattern.exec(searchable);
    while (decimalMatch !== null) {
      raw = decimalMatch[0];
      numeric = decimalMatch[0];
      decimalMatch = decimalPattern.exec(searchable);
    }
  }
  const fen = parseAmountFen(numeric);
  if (fen === undefined || fen <= 0) {
    return undefined;
  }
  let direction: EntryDirection | undefined = undefined;
  if (sign === '-') {
    direction = 'expense';
  } else if (sign === '+') {
    direction = 'income';
  } else if (/(收入|收款|入账)/.test(text)) {
    direction = 'income';
  } else if (/(支出|付款|消费)/.test(text)) {
    direction = 'expense';
  }
  return {
    fen: fen,
    direction: direction,
    raw: raw
  };
}

function isSummaryRow(text: string): boolean {
  return /(收支统计|月账单|总支出|总收入|本月支出|本月收入|合计|净收入|余额|可用金额)/.test(text) ||
    /(收入.*支出|支出.*收入)/.test(text) ||
    /^\s*(收入|支出)\s*[¥￥]?\s*\d+(?:[,.]\d{3})*(?:[,.]\d{1,2})?\s*$/.test(text);
}

function isSummaryValueRow(rows: VisualRow[], rowIndex: number): boolean {
  if (!/^\s*[¥￥]?\s*\d+(?:[,.]\d{3})*(?:[,.]\d{1,2})?\s*$/.test(rows[rowIndex].text)) {
    return false;
  }
  const nearbyLabels = rows.slice(Math.max(0, rowIndex - 2), rowIndex)
    .map((row: VisualRow) => row.text)
    .join(' ');
  return /(收入|支出)/.test(nearbyLabels);
}

function transactionDate(
  rows: VisualRow[],
  rowIndex: number,
  baseDate: Date | undefined,
  dateContext: DateContext | undefined
): ParsedDateTime | undefined {
  const inlineDate = parseDateHeader(rows[rowIndex].text, baseDate, dateContext);
  if (inlineDate !== undefined) {
    return inlineDate;
  }
  let nearbyDate: ParsedDateTime | undefined = undefined;
  for (let index = rowIndex + 1; index < rows.length; index++) {
    const candidate = rows[index];
    const candidateDate = parseDateHeader(candidate.text, baseDate, dateContext);
    if (candidateDate !== undefined) {
      if (candidateDate.hasTime) {
        return candidateDate;
      }
      nearbyDate = candidateDate;
    }
    if (!isSummaryRow(candidate.text) && extractAmount(candidate.text) !== undefined) {
      break;
    }
  }
  if (nearbyDate !== undefined) {
    return nearbyDate;
  }
  return undefined;
}

function isFailedRow(text: string): boolean {
  return /(已关闭|已取消|支付失败|交易失败|已撤销|交易关闭)/.test(text);
}

function isRefundRow(text: string): boolean {
  return /(退款|退回|已退)/.test(text);
}

function alipayCategoryForTransaction(
  rows: VisualRow[],
  rowIndex: number,
  baseDate: Date | undefined,
  dateContext: DateContext | undefined
): string | undefined {
  for (let index = rowIndex + 1; index < rows.length; index++) {
    const candidate = rows[index];
    if (!isSummaryRow(candidate.text) && !isSummaryValueRow(rows, index) &&
      extractAmount(candidate.text) !== undefined) {
      break;
    }
    const candidateDate = parseDateHeader(candidate.text, baseDate, dateContext);
    if (candidateDate !== undefined && candidateDate.hasTime) {
      break;
    }
    const normalized = candidate.text.replace(/\s/g, '');
    for (const category of ALIPAY_CATEGORY_LABELS) {
      if (normalized === category || normalized.indexOf(category) === 0) {
        return category;
      }
    }
  }
  return undefined;
}

function cleanMerchant(text: string, amount: AmountToken): string {
  return text.replace(amount.raw, '').trim();
}

function dateText(date: ParsedDateTime | undefined): string {
  if (date === undefined) {
    return '';
  }
  return date.hasTime ? formatDateTime(date.timestamp) : formatDateOnly(date.timestamp);
}

function sameLocalDay(first: number, second: number): boolean {
  const left = new Date(first);
  const right = new Date(second);
  return left.getFullYear() === right.getFullYear() &&
    left.getMonth() === right.getMonth() &&
    left.getDate() === right.getDate();
}

function likelyDuplicate(
  source: EntrySource,
  date: number | undefined,
  amountFen: number,
  merchant: string,
  existing: LedgerEntry[],
  drafts: DraftEntry[]
): boolean {
  if (date === undefined) {
    return false;
  }
  const normalizedMerchant = merchant.replace(/\s/g, '').toLowerCase();
  for (const entry of existing) {
    if (entry.source === source && entry.amountFen === amountFen &&
      sameLocalDay(entry.happenedAt, date) &&
      entry.merchant.replace(/\s/g, '').toLowerCase() === normalizedMerchant) {
      return true;
    }
  }
  for (const draft of drafts) {
    const draftDate = parseDateTime(draft.dateText);
    const draftAmount = parseAmountFen(draft.amountText);
    if (draft.source === source && draftAmount === amountFen &&
      draftDate !== undefined && sameLocalDay(draftDate, date) &&
      draft.merchant.replace(/\s/g, '').toLowerCase() === normalizedMerchant) {
      return true;
    }
  }
  return false;
}

export class ReceiptParser {
  static parse(
    lines: OcrLine[],
    source: EntrySource,
    existing: LedgerEntry[],
    priorDrafts: DraftEntry[] = [],
    captureTime?: number
  ): DraftEntry[] {
    const rows = buildRows(lines);
    const result: DraftEntry[] = [];
    const baseDate = captureTime === undefined ? undefined : new Date(captureTime);
    let dateContext: DateContext | undefined = undefined;
    const typicalHeight = median(rows.map((row: VisualRow) => row.height));

    for (let index = 0; index < rows.length; index++) {
      const row = rows[index];
      const monthContext = parseMonthContext(row.text, baseDate);
      if (monthContext !== undefined) {
        dateContext = monthContext;
        continue;
      }
      const headerDate = parseDateHeader(row.text, baseDate, dateContext);
      const rowAmount = extractAmount(row.text);
      if (headerDate !== undefined && rowAmount === undefined) {
        continue;
      }
      if (isSummaryRow(row.text) || isSummaryValueRow(rows, index)) {
        continue;
      }
      const amount = rowAmount;
      if (amount === undefined) {
        continue;
      }

      const contextParts: string[] = [row.text];
      const nearby: VisualRow[] = [];
      for (let neighborIndex = Math.max(0, index - 1);
        neighborIndex <= Math.min(rows.length - 1, index + 1);
        neighborIndex++) {
        if (neighborIndex === index) {
          continue;
        }
        const neighbor = rows[neighborIndex];
        if (Math.abs(neighbor.centerY - row.centerY) <= typicalHeight * 2.4) {
          contextParts.push(neighbor.text);
          nearby.push(neighbor);
        }
      }
      const context = contextParts.join(' ');
      if (isFailedRow(context)) {
        continue;
      }
      const happenedAt = transactionDate(rows, index, baseDate, dateContext);
      if (happenedAt === undefined) {
        continue;
      }

      let merchant = cleanMerchant(row.text, amount);
      if (merchant.length === 0) {
        nearby.sort((left: VisualRow, right: VisualRow) =>
          Math.abs(left.centerY - row.centerY) - Math.abs(right.centerY - row.centerY));
        for (const candidate of nearby) {
          if (parseDateHeader(candidate.text, baseDate, dateContext) === undefined &&
            extractAmount(candidate.text) === undefined &&
            !isSummaryRow(candidate.text) && !isFailedRow(candidate.text)) {
            merchant = candidate.text.replace(/\d{1,2}:\d{2}/g, '').trim();
            break;
          }
        }
      }

      const refund = isRefundRow(context);
      let direction = amount.direction;
      const warnings: string[] = [];
      if (refund) {
        direction = undefined;
        warnings.push('识别到退款，请确认收入或支出方向');
      }
      if (direction === undefined && !refund) {
        warnings.push('金额方向不明确，请选择收入或支出');
      }
      if (merchant.length === 0) {
        warnings.push('未识别到商户或摘要');
      }
      if (likelyDuplicate(source, happenedAt.timestamp, amount.fen, merchant, existing, priorDrafts.concat(result))) {
        warnings.push('与已有账目相似，可能是重复记录');
      }

      let category = '其他';
      if (refund) {
        category = '退款';
      } else if (source === 'alipay') {
        const recognizedCategory = alipayCategoryForTransaction(rows, index, baseDate, dateContext);
        if (recognizedCategory !== undefined) {
          category = recognizedCategory;
        }
      }

      result.push({
        id: makeId('draft'),
        source: source,
        merchant: merchant,
        dateText: dateText(happenedAt),
        hasTime: happenedAt.hasTime,
        amountText: (amount.fen / 100).toFixed(2),
        direction: direction,
        category: category,
        checked: true,
        isRefund: refund,
        warnings: warnings
      });
    }
    return result;
  }
}
