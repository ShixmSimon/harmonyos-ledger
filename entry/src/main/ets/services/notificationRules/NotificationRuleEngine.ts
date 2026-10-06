import { parseAmountFen } from './AmountParser.ts';
import type {
  NotificationCategoryMapping,
  NotificationDateStrategy,
  NotificationInput,
  NotificationRule,
  NotificationRuleLoadResult,
  ParsedNotificationEntry,
  RuleValidationIssue
} from './NotificationRuleModels.ts';

const HALF_YEAR_MS = 183 * 24 * 60 * 60 * 1000;
const BLOCKED_BODY_PATTERN = /(交易失败|扣款失败|交易取消|已撤销)/;
const BUILT_IN_SOURCE_NAMES = ['manual', 'wechat', 'alipay', 'icbc', 'citic', '手动', '微信支付', '支付宝', '工商银行', '中信银行'];
const AMOUNT_PATTERN = String.raw`(?:\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:[.,]\d{1,2})?)`;
const ALIPAY_INCOME_TEXT = '收钱到账|收款到账|收款成功|转账到账|收到转账|转账收入|余额宝到账|转入|收入|入账';
const ALIPAY_EXPENSE_TEXT = '支付成功|付款成功|扣款成功|转账付款|消费|支出|转出';
const WECHAT_INCOME_TEXT = '收款到账|收款成功|收钱到账|转账到账|收到一笔转账|收到转账|零钱入账|红包到账|收到红包|收入';
const WECHAT_EXPENSE_TEXT = '支付凭证|支付成功|付款成功|扣款成功|转账付款|消费|支出|转出';
const LEGACY_ICBC_BODY_PATTERN = String.raw`尾号\s*(\d{4})\s*卡\s*(\d{1,2}月\d{1,2}日\s*\d{1,2}:\d{2})\s*(支出|收入)\s*[（(]\s*([^）)]*?)\s*[）)]\s*(\d+(?:[.,]\d{1,2})?)\s*元`;
const LEGACY_CITIC_BODY_PATTERN = String.raw`尾号\s*(\d{3,6})\s*的账户\s*(支出|收入)\s*[¥￥]?\s*(\d+(?:[.,]\d{1,2})?)\s*元`;

function splitDirectionTexts(value: string): string[] {
  return value.split(/[|、,，]/).map((text: string) => text.trim()).filter((text: string) => text.length > 0);
}

function buildPaymentNotificationPattern(incomeText: string, expenseText: string): string {
  const directionTerms = splitDirectionTexts(incomeText).concat(splitDirectionTexts(expenseText));
  directionTerms.sort((left: string, right: string) => right.length - left.length);
  const directionPattern = directionTerms.map((text: string) => escapeRegExp(text)).join('|');
  const amountWithCurrencyOrUnit = String.raw`(?:[¥￥]\s*${AMOUNT_PATTERN}|${AMOUNT_PATTERN}\s*元)`;
  const directionAmountPair = String.raw`(?=[\s\S]{0,100}?(?:${directionPattern})[\s\S]{0,100}?(?:${amountWithCurrencyOrUnit})|[\s\S]{0,100}?(?:${amountWithCurrencyOrUnit})[\s\S]{0,100}?(?:${directionPattern}))`;
  return String.raw`^(?![\s\S]*(?:退款|退回|退还|失败|撤销|取消))${directionAmountPair}(?=[\s\S]*?(${directionPattern}))[\s\S]*?(${amountWithCurrencyOrUnit})`;
}

export function createDefaultNotificationRules(): NotificationRule[] {
  return [
    {
      id: 'icbc',
      name: '工商银行',
      enabled: true,
      sourceKeywords: ['工商银行', 'icbc'],
      bodyPattern: String.raw`尾号\s*(\d{4})\s*卡\s*(\d{1,2}月\d{1,2}日\s*\d{1,2}:\d{2})\s*(支出|收入)\s*[（(]\s*([^）)]*?)\s*[）)]\s*(${AMOUNT_PATTERN})\s*元`,
      amountGroup: 5,
      directionGroup: 3,
      incomeText: '收入',
      expenseText: '支出',
      dateGroup: 2,
      dateFormat: 'M月d日 HH:mm',
      dateStrategy: 'infer-year',
      merchantGroup: 4,
      categoryGroup: 4,
      defaultMerchant: '工商银行账户',
      defaultCategory: '其他',
      categoryMappings: [
        { text: '消费', matchMode: 'startsWith', category: '消费' },
        { text: 'ATM取款', matchMode: 'includes', category: '取现' },
        { text: '贷款本息', matchMode: 'includes', category: '贷款' }
      ],
      merchantPrefixToStrip: '消费',
      noteTemplate: '尾号{{1}}卡 · 动账通知',
      entrySource: 'icbc'
    },
    {
      id: 'citic',
      name: '中信银行',
      enabled: true,
      sourceKeywords: ['中信银行', 'citic'],
      bodyPattern: String.raw`尾号\s*(\d{3,6})\s*的账户\s*(支出|收入)\s*[¥￥]?\s*(${AMOUNT_PATTERN})\s*元`,
      amountGroup: 3,
      directionGroup: 2,
      incomeText: '收入',
      expenseText: '支出',
      dateFormat: '',
      dateStrategy: 'delivery-time',
      defaultMerchant: '中信银行账户',
      defaultCategory: '其他',
      categoryMappings: [],
      merchantPrefixToStrip: '',
      noteTemplate: '尾号{{1}}账户 · 通知未提供商户',
      entrySource: 'citic'
    },
    {
      id: 'alipay',
      name: '支付宝',
      enabled: true,
      sourceKeywords: ['支付宝', 'alipay'],
      incomeText: ALIPAY_INCOME_TEXT,
      expenseText: ALIPAY_EXPENSE_TEXT,
      bodyPattern: buildPaymentNotificationPattern(ALIPAY_INCOME_TEXT, ALIPAY_EXPENSE_TEXT),
      amountGroup: 2,
      directionGroup: 1,
      dateFormat: '',
      dateStrategy: 'delivery-time',
      defaultMerchant: '支付宝',
      defaultCategory: '其他',
      categoryMappings: [],
      merchantPrefixToStrip: '',
      noteTemplate: '支付宝交易通知',
      entrySource: 'alipay'
    },
    {
      id: 'wechat',
      name: '微信支付',
      enabled: true,
      sourceKeywords: ['微信支付', '微信', 'com.tencent.mm'],
      incomeText: WECHAT_INCOME_TEXT,
      expenseText: WECHAT_EXPENSE_TEXT,
      bodyPattern: buildPaymentNotificationPattern(WECHAT_INCOME_TEXT, WECHAT_EXPENSE_TEXT),
      amountGroup: 2,
      directionGroup: 1,
      dateFormat: '',
      dateStrategy: 'delivery-time',
      defaultMerchant: '微信支付',
      defaultCategory: '其他',
      categoryMappings: [],
      merchantPrefixToStrip: '',
      noteTemplate: '微信支付交易通知',
      entrySource: 'wechat'
    }
  ];
}

function migrateLegacyDefaultAmountPatterns(rules: NotificationRule[]): boolean {
  const defaults = createDefaultNotificationRules();
  let migrated = false;
  for (const rule of rules) {
    if (rule.id === 'icbc' && rule.entrySource === 'icbc' && rule.bodyPattern === LEGACY_ICBC_BODY_PATTERN) {
      rule.bodyPattern = defaults[0].bodyPattern;
      migrated = true;
    } else if (rule.id === 'citic' && rule.entrySource === 'citic' && rule.bodyPattern === LEGACY_CITIC_BODY_PATTERN) {
      rule.bodyPattern = defaults[1].bodyPattern;
      migrated = true;
    }
  }
  return migrated;
}

function countCaptureGroups(pattern: string): number {
  let count = 0;
  let escaped = false;
  let inCharacterClass = false;
  for (let index = 0; index < pattern.length; index++) {
    const character = pattern[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (character === '\\') {
      escaped = true;
      continue;
    }
    if (inCharacterClass) {
      if (character === ']') {
        inCharacterClass = false;
      }
      continue;
    }
    if (character === '[') {
      inCharacterClass = true;
      continue;
    }
    if (character !== '(') {
      continue;
    }
    if (pattern[index + 1] !== '?') {
      count++;
    } else if (pattern[index + 2] === '<' && pattern[index + 3] !== '=' && pattern[index + 3] !== '!') {
      count++;
    }
  }
  return count;
}

function isPositiveGroup(group: number | undefined): group is number {
  return typeof group === 'number' && Number.isInteger(group) && group > 0;
}

function validateGroupReference(
  field: string,
  group: number | undefined,
  captureCount: number,
  required: boolean
): RuleValidationIssue | undefined {
  if (group === undefined && !required) {
    return undefined;
  }
  if (!isPositiveGroup(group)) {
    return { field, message: '捕获组编号必须是正整数' };
  }
  if (group > captureCount) {
    return { field, message: '正文正则没有这个捕获组' };
  }
  return undefined;
}

export function validateNotificationRule(rule: NotificationRule): RuleValidationIssue | undefined {
  if (rule === null || typeof rule !== 'object') {
    return { field: 'rule', message: '规则内容无效' };
  }
  if (typeof rule.id !== 'string' || rule.id.trim().length === 0) {
    return { field: 'id', message: '规则标识无效' };
  }
  if (typeof rule.enabled !== 'boolean') {
    return { field: 'enabled', message: '规则启用状态无效' };
  }
  if (typeof rule.name !== 'string' || rule.name.trim().length === 0) {
    return { field: 'name', message: '请输入规则名称' };
  }
  if ((typeof rule.entrySource !== 'string' || rule.entrySource.length === 0) &&
    BUILT_IN_SOURCE_NAMES.includes(rule.name.trim().toLowerCase())) {
    return { field: 'name', message: '自定义规则名称不能使用内置来源名称' };
  }
  if (!Array.isArray(rule.sourceKeywords) || rule.sourceKeywords.length === 0 ||
    rule.sourceKeywords.some((keyword: string) => typeof keyword !== 'string' || keyword.trim().length === 0)) {
    return { field: 'sourceKeywords', message: '至少填写一个非空来源关键词' };
  }
  if (typeof rule.bodyPattern !== 'string' || rule.bodyPattern.length === 0) {
    return { field: 'bodyPattern', message: '请输入正文正则' };
  }
  let captureCount = 0;
  try {
    new RegExp(rule.bodyPattern);
    captureCount = countCaptureGroups(rule.bodyPattern);
  } catch (_error) {
    return { field: 'bodyPattern', message: '正文正则格式无效' };
  }
  const amountIssue = validateGroupReference('amountGroup', rule.amountGroup, captureCount, true);
  if (amountIssue !== undefined) {
    return amountIssue;
  }
  const directionIssue = validateGroupReference('directionGroup', rule.directionGroup, captureCount, true);
  if (directionIssue !== undefined) {
    return directionIssue;
  }
  if (typeof rule.incomeText !== 'string' || splitDirectionTexts(rule.incomeText).length === 0 ||
    typeof rule.expenseText !== 'string' || splitDirectionTexts(rule.expenseText).length === 0) {
    return { field: 'directionText', message: '收入和支出对应的通知文字不能为空' };
  }
  if (typeof rule.dateFormat !== 'string') {
    return { field: 'dateFormat', message: '日期格式无效' };
  }
  if (typeof rule.defaultMerchant !== 'string') {
    return { field: 'defaultMerchant', message: '默认商户无效' };
  }
  if (typeof rule.defaultCategory !== 'string' || rule.defaultCategory.trim().length === 0) {
    return { field: 'defaultCategory', message: '请输入默认分类' };
  }
  if (typeof rule.merchantPrefixToStrip !== 'string') {
    return { field: 'merchantPrefixToStrip', message: '商户前缀无效' };
  }
  if (typeof rule.entrySource !== 'undefined' && typeof rule.entrySource !== 'string') {
    return { field: 'entrySource', message: '来源标识无效' };
  }
  const strategy: NotificationDateStrategy = rule.dateStrategy;
  if (strategy !== 'format' && strategy !== 'infer-year' && strategy !== 'delivery-time') {
    return { field: 'dateStrategy', message: '日期策略无效' };
  }
  if (strategy !== 'delivery-time') {
    const dateIssue = validateGroupReference('dateGroup', rule.dateGroup, captureCount, true);
    if (dateIssue !== undefined) {
      return dateIssue;
    }
    if (typeof rule.dateFormat !== 'string' || rule.dateFormat.length === 0) {
      return { field: 'dateFormat', message: '请填写日期格式' };
    }
    if (!rule.dateFormat.includes('HH') || !rule.dateFormat.includes('mm')) {
      return { field: 'dateFormat', message: '日期格式必须包含 HH 和 mm；仅有日期时请选择投递时间策略' };
    }
  } else if (rule.dateGroup !== undefined) {
    const dateIssue = validateGroupReference('dateGroup', rule.dateGroup, captureCount, false);
    if (dateIssue !== undefined) {
      return dateIssue;
    }
  }
  const merchantIssue = validateGroupReference('merchantGroup', rule.merchantGroup, captureCount, false);
  if (merchantIssue !== undefined) {
    return merchantIssue;
  }
  const categoryIssue = validateGroupReference('categoryGroup', rule.categoryGroup, captureCount, false);
  if (categoryIssue !== undefined) {
    return categoryIssue;
  }
  if (typeof rule.noteTemplate !== 'string') {
    return { field: 'noteTemplate', message: '备注模板无效' };
  }
  const noteGroupPattern = /{{(\d+)}}/g;
  let noteGroup: RegExpExecArray | null = noteGroupPattern.exec(rule.noteTemplate);
  while (noteGroup !== null) {
    const group = Number(noteGroup[1]);
    if (!isPositiveGroup(group) || group > captureCount) {
      return { field: 'noteTemplate', message: '备注引用了不存在的捕获组' };
    }
    noteGroup = noteGroupPattern.exec(rule.noteTemplate);
  }
  if (!Array.isArray(rule.categoryMappings)) {
    return { field: 'categoryMappings', message: '分类映射无效' };
  }
  for (const mapping of rule.categoryMappings) {
    if (mapping === null || typeof mapping !== 'object' ||
      typeof mapping.text !== 'string' || mapping.text.trim().length === 0 ||
      typeof mapping.category !== 'string' || mapping.category.trim().length === 0 ||
      (mapping.matchMode !== 'startsWith' && mapping.matchMode !== 'includes')) {
      return { field: 'categoryMappings', message: '分类映射内容无效' };
    }
  }
  return undefined;
}

export function decodeNotificationRuleStore(value: string | undefined): NotificationRuleLoadResult {
  if (value === undefined) {
    return { rules: createDefaultNotificationRules(), persistDefaults: true };
  }
  let stored: unknown;
  try {
    stored = JSON.parse(value);
  } catch (_error) {
    throw new Error('通知规则数据格式无效');
  }
  if (stored === null || typeof stored !== 'object' ||
    (stored as { version?: unknown }).version !== 1 ||
    !Array.isArray((stored as { rules?: unknown }).rules)) {
    throw new Error('通知规则数据版本或内容无效');
  }
  const store = stored as { rules: NotificationRule[]; defaultRulesVersion?: unknown };
  if (store.defaultRulesVersion !== undefined && store.defaultRulesVersion !== 1) {
    throw new Error('通知规则默认项版本无效');
  }
  const rules = store.rules;
  for (const rule of rules) {
    const issue = validateNotificationRule(rule);
    if (issue !== undefined) {
      throw new Error('已保存的通知规则无效：' + issue.message);
    }
  }
  let migrated = migrateLegacyDefaultAmountPatterns(rules);
  if (store.defaultRulesVersion === undefined) {
    const hadBankDefaults = rules.some((rule: NotificationRule) =>
      (rule.id === 'icbc' && rule.entrySource === 'icbc') || (rule.id === 'citic' && rule.entrySource === 'citic'));
    if (hadBankDefaults) {
      const paymentDefaults = createDefaultNotificationRules().filter((rule: NotificationRule) =>
        rule.id === 'alipay' || rule.id === 'wechat');
      for (const rule of paymentDefaults) {
        if (!rules.some((savedRule: NotificationRule) => savedRule.id === rule.id)) {
          rules.push(rule);
        }
      }
    }
    migrated = true;
  }
  return migrated ? { rules, persistDefaults: false, migrated: true } : { rules, persistDefaults: false };
}

const DATE_TOKENS = ['yyyy', 'MM', 'dd', 'HH', 'mm', 'M', 'd'];

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

interface ParsedDateFields {
  year?: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
}

function parseDateFields(value: string, format: string): ParsedDateFields | undefined {
  const tokens: string[] = [];
  let pattern = '^';
  for (let index = 0; index < format.length;) {
    const token = DATE_TOKENS.find((candidate: string) => format.startsWith(candidate, index));
    if (token !== undefined) {
      tokens.push(token);
      if (token === 'yyyy') {
        pattern += '(\\d{4})';
      } else if (token === 'mm' || token === 'MM' || token === 'dd') {
        pattern += '(\\d{2})';
      } else {
        pattern += '(\\d{1,2})';
      }
      index += token.length;
    } else if (/\s/.test(format[index])) {
      pattern += '\\s*';
      index++;
    } else {
      pattern += escapeRegExp(format[index]);
      index++;
    }
  }
  pattern += '$';
  const match = new RegExp(pattern).exec(value);
  if (match === null) {
    return undefined;
  }
  const values: { [key: string]: number } = {};
  tokens.forEach((token: string, index: number) => {
    values[token] = Number(match[index + 1]);
  });
  if (values['M'] === undefined && values['MM'] === undefined) {
    return undefined;
  }
  if (values['d'] === undefined && values['dd'] === undefined) {
    return undefined;
  }
  return {
    year: values['yyyy'],
    month: values['MM'] ?? values['M'],
    day: values['dd'] ?? values['d'],
    hour: values['HH'] ?? 0,
    minute: values['mm'] ?? 0
  };
}

function makeLocalTimestamp(fields: ParsedDateFields, year: number): number | undefined {
  const date = new Date(year, fields.month - 1, fields.day, fields.hour, fields.minute, 0, 0);
  if (!Number.isFinite(date.getTime()) || date.getFullYear() !== year || date.getMonth() !== fields.month - 1 ||
    date.getDate() !== fields.day || date.getHours() !== fields.hour || date.getMinutes() !== fields.minute) {
    return undefined;
  }
  return date.getTime();
}

function parseHappenedAt(rule: NotificationRule, match: RegExpExecArray, input: NotificationInput): number | undefined {
  if (rule.dateStrategy === 'delivery-time') {
    const timestamp = typeof input.deliveryTime === 'number' && Number.isFinite(input.deliveryTime) && input.deliveryTime > 0
      ? input.deliveryTime
      : input.receivedAt;
    if (!Number.isFinite(timestamp) || timestamp <= 0) {
      return undefined;
    }
    const date = new Date(timestamp);
    if (!Number.isFinite(date.getTime())) {
      return undefined;
    }
    date.setSeconds(0, 0);
    return date.getTime();
  }
  const dateText = match[rule.dateGroup as number];
  if (dateText === undefined) {
    return undefined;
  }
  const fields = parseDateFields(dateText, rule.dateFormat);
  if (fields === undefined) {
    return undefined;
  }
  let year = fields.year;
  if (rule.dateStrategy === 'format') {
    if (year === undefined) {
      return undefined;
    }
  } else {
    if (!Number.isFinite(input.receivedAt)) {
      return undefined;
    }
    if (year === undefined) {
      year = new Date(input.receivedAt).getFullYear();
    }
  }
  let timestamp = makeLocalTimestamp(fields, year);
  if (timestamp === undefined) {
    return undefined;
  }
  if (rule.dateStrategy === 'infer-year' && fields.year === undefined) {
    if (timestamp - input.receivedAt > HALF_YEAR_MS) {
      year--;
    } else if (input.receivedAt - timestamp > HALF_YEAR_MS) {
      year++;
    }
    const inferred = makeLocalTimestamp(fields, year);
    if (inferred === undefined) {
      return undefined;
    }
    timestamp = inferred;
  }
  const date = new Date(timestamp);
  date.setSeconds(0, 0);
  return date.getTime();
}

function parseMatchedRule(
  rule: NotificationRule,
  match: RegExpExecArray,
  input: NotificationInput
): ParsedNotificationEntry | undefined {
  if (validateNotificationRule(rule) !== undefined) {
    return undefined;
  }
  const amountText = match[rule.amountGroup];
  const amountFen = amountText === undefined ? undefined : parseAmountFen(amountText);
  if (amountFen === undefined || amountFen <= 0) {
    return undefined;
  }
  const directionText = match[rule.directionGroup];
  let direction: 'income' | 'expense';
  if (directionText !== undefined && splitDirectionTexts(rule.incomeText).includes(directionText)) {
    direction = 'income';
  } else if (directionText !== undefined && splitDirectionTexts(rule.expenseText).includes(directionText)) {
    direction = 'expense';
  } else {
    return undefined;
  }
  const happenedAt = parseHappenedAt(rule, match, input);
  if (happenedAt === undefined) {
    return undefined;
  }
  let merchant = rule.merchantGroup === undefined ? '' : (match[rule.merchantGroup] ?? '').trim();
  if (rule.merchantPrefixToStrip.length > 0 && merchant.startsWith(rule.merchantPrefixToStrip)) {
    merchant = merchant.slice(rule.merchantPrefixToStrip.length).trim();
  }
  if (merchant.length === 0) {
    merchant = rule.defaultMerchant;
  }
  const categoryText = rule.categoryGroup === undefined ? '' : (match[rule.categoryGroup] ?? '').trim();
  let category = rule.defaultCategory;
  if (rule.categoryMappings.length > 0) {
    const mapping = rule.categoryMappings.find((candidate: NotificationCategoryMapping) =>
      candidate.matchMode === 'startsWith'
        ? categoryText.startsWith(candidate.text)
        : categoryText.includes(candidate.text));
    if (mapping !== undefined) {
      category = mapping.category;
    }
  } else if (rule.categoryGroup !== undefined && categoryText.length > 0) {
    category = categoryText;
  }
  const note = rule.noteTemplate.replace(/{{(\d+)}}/g, (_placeholder: string, groupText: string) =>
    match[Number(groupText)] ?? '');
  const source = typeof rule.entrySource === 'string' && rule.entrySource.length > 0 ? rule.entrySource : rule.name;
  return {
    id: 'notice-' + source + '-' + happenedAt + '-' + amountFen + '-' + direction + '-' + merchant,
    happenedAt,
    hasTime: true,
    amountFen,
    direction,
    source,
    merchant,
    category,
    note
  };
}

export function parseNotificationEntry(
  input: NotificationInput,
  rules: NotificationRule[]
): ParsedNotificationEntry | undefined {
  const notificationText = input.title === undefined || input.title.length === 0
    ? input.body
    : input.title + '\n' + input.body;
  if (BLOCKED_BODY_PATTERN.test(notificationText)) {
    return undefined;
  }
  const sourceText = (input.appName + ' ' + input.bundleName).toLowerCase();
  for (const rule of rules) {
    if (!rule.enabled || !rule.sourceKeywords.some((keyword: string) => sourceText.includes(keyword.toLowerCase()))) {
      continue;
    }
    let expression: RegExp;
    try {
      expression = new RegExp(rule.bodyPattern);
    } catch (_error) {
      continue;
    }
    const match = expression.exec(notificationText);
    if (match === null) {
      continue;
    }
    return parseMatchedRule(rule, match, input);
  }
  return undefined;
}
