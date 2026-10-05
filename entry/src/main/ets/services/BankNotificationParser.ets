import { notificationExtensionSubscription } from '@kit.NotificationKit';
import { EntryDirection, EntrySource, LedgerEntry, parseAmountFen } from '../model/LedgerModels';

interface BankNotificationSource {
  source: EntrySource;
  bankName: string;
}

function notificationSource(info: notificationExtensionSubscription.NotificationInfo): BankNotificationSource | undefined {
  const appName = (info.appName ?? '').toLowerCase();
  const bundleName = info.bundleName.toLowerCase();
  const sourceText = appName + ' ' + bundleName;
  if (sourceText.includes('工商银行') || sourceText.includes('icbc')) {
    return { source: 'icbc', bankName: '工商银行' };
  }
  if (sourceText.includes('中信银行') || sourceText.includes('citic')) {
    return { source: 'citic', bankName: '中信银行' };
  }
  return undefined;
}

function normalizeMinute(timestamp: number): number {
  const date = new Date(timestamp);
  date.setSeconds(0, 0);
  return date.getTime();
}

function makeEntry(
  source: BankNotificationSource,
  happenedAt: number,
  directionText: string,
  amountText: string,
  merchant: string,
  category: string,
  note: string
): LedgerEntry | undefined {
  const amountFen = parseAmountFen(amountText);
  if (amountFen === undefined || amountFen <= 0) {
    return undefined;
  }
  const direction: EntryDirection = directionText === '收入' ? 'income' : 'expense';
  const normalizedTime = normalizeMinute(happenedAt);
  const normalizedMerchant = merchant.length > 0 ? merchant : source.bankName + '账户';
  return {
    id: 'notice-' + source.source + '-' + normalizedTime + '-' + amountFen + '-' + direction + '-' + normalizedMerchant,
    happenedAt: normalizedTime,
    hasTime: true,
    amountFen: amountFen,
    direction: direction,
    source: source.source,
    merchant: normalizedMerchant,
    category: category,
    note: note
  };
}

function parseIcbcNotification(
  source: BankNotificationSource,
  body: string,
  receivedAt: number
): LedgerEntry | undefined {
  const match = body.match(/尾号\s*(\d{4})\s*卡\s*(\d{1,2})月(\d{1,2})日\s*(\d{1,2}):(\d{2})\s*(支出|收入)\s*[（(]\s*([^）)]*?)\s*[）)]\s*(\d+(?:[.,]\d{1,2})?)\s*元/);
  if (match === null) {
    return undefined;
  }
  const receivedDate = new Date(receivedAt);
  let year = receivedDate.getFullYear();
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  let happenedAt = new Date(year, month - 1, day, hour, minute, 0, 0);
  if (happenedAt.getMonth() !== month - 1 || happenedAt.getDate() !== day ||
    happenedAt.getHours() !== hour || happenedAt.getMinutes() !== minute) {
    return undefined;
  }
  const halfYearMs = 183 * 24 * 60 * 60 * 1000;
  if (happenedAt.getTime() - receivedAt > halfYearMs) {
    year--;
  } else if (receivedAt - happenedAt.getTime() > halfYearMs) {
    year++;
  }
  happenedAt = new Date(year, month - 1, day, hour, minute, 0, 0);
  const transactionDetail = match[7].trim();
  let category = '其他';
  let merchant = transactionDetail;
  if (transactionDetail.startsWith('消费')) {
    category = '消费';
    merchant = transactionDetail.slice('消费'.length).trim();
  } else if (transactionDetail.includes('ATM取款')) {
    category = '取现';
  } else if (transactionDetail.includes('贷款本息')) {
    category = '贷款';
  }
  return makeEntry(source, happenedAt.getTime(), match[6], match[8], merchant, category,
    '尾号' + match[1] + '卡 · 动账通知');
}

function parseCiticNotification(
  info: notificationExtensionSubscription.NotificationInfo,
  source: BankNotificationSource,
  body: string,
  receivedAt: number
): LedgerEntry | undefined {
  const match = body.match(/尾号\s*(\d{3,6})\s*的账户\s*(支出|收入)\s*[¥￥]?\s*(\d+(?:[.,]\d{1,2})?)\s*元/);
  if (match === null) {
    return undefined;
  }
  const deliveredAt = typeof info.deliveryTime === 'number' && info.deliveryTime > 0 ? info.deliveryTime : receivedAt;
  return makeEntry(source, deliveredAt, match[2], match[3], '', '其他',
    '尾号' + match[1] + '账户 · 通知未提供商户');
}

export function parseBankNotificationEntry(
  info: notificationExtensionSubscription.NotificationInfo,
  receivedAt: number
): LedgerEntry | undefined {
  const source = notificationSource(info);
  if (source === undefined) {
    return undefined;
  }
  const body = info.content?.text ?? '';
  if (/(交易失败|扣款失败|交易取消|已撤销)/.test(body)) {
    return undefined;
  }
  if (source.source === 'icbc') {
    return parseIcbcNotification(source, body, receivedAt);
  }
  return parseCiticNotification(info, source, body, receivedAt);
}
