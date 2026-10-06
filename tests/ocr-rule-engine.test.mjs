import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createDefaultOcrRules,
  decodeOcrRuleStore,
  selectOcrRule,
  validateOcrRule
} from '../entry/src/main/ets/services/ocrRules/OcrRuleEngine.ets';
import { OcrImportCoordinator } from '../entry/src/main/ets/services/OcrImportCoordinator.ets';

function line(text, centerY, left = 10, right = 290) {
  return { text, left, top: centerY - 10, right, bottom: centerY + 10, centerY, height: 20 };
}

function page(lines, rawText, captureTime = new Date(2026, 9, 31, 12).getTime()) {
  return { pageNumber: 1, lines, rawText, captureTime };
}

test('default OCR rules cover the three existing sources and retain detector thresholds', () => {
  const rules = createDefaultOcrRules();
  assert.deepEqual(rules.map((rule) => rule.source), ['wechat', 'alipay', 'icbc']);
  assert.deepEqual(rules.map((rule) => rule.layoutStrategy), ['receipt-list', 'receipt-list', 'icbc-statement']);
  assert.ok(rules.every((rule) => rule.minimumScore === 4 && rule.scoreMargin === 2));
});

test('default source expressions retain current WeChat, Alipay, and ICBC detection', () => {
  const rules = createDefaultOcrRules();
  assert.equal(selectOcrRule('微信支付 全部账单 收支统计 查找交易', rules)?.source, 'wechat');
  assert.equal(selectOcrRule('查找交易 全部账单 收支统计', rules)?.source, 'wechat');
  assert.equal(selectOcrRule('支付宝 搜索交易记录 芝麻', rules)?.source, 'alipay');
  assert.equal(selectOcrRule('中国工商银行 工商银行 当页汇总笔数', rules)?.source, 'icbc');
});

test('weighted matchers select the highest scoring source and reject scores below threshold', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: rule.source, weight: rule.source === 'wechat' ? 8 : 5 }],
    minimumScore: 6,
    scoreMargin: 2
  }));
  assert.equal(selectOcrRule('wechat', rules)?.source, 'wechat');
  assert.equal(selectOcrRule('alipay', rules), undefined);
});

test('source ambiguity is rejected when the score difference is too small', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared', weight: 6 }]
  }));
  assert.equal(selectOcrRule('shared', rules), undefined);
});

test('identical scores from different sources remain ambiguous when the configured margin is zero', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared', weight: 6 }],
    scoreMargin: 0
  }));
  assert.equal(selectOcrRule('shared', rules), undefined);
});

test('manual source selection stays within that source despite stronger competing matches', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared', weight: rule.source === 'wechat' ? 20 : 6 }]
  }));
  assert.equal(selectOcrRule('shared', rules)?.source, 'wechat');
  assert.equal(selectOcrRule('shared', rules, 'alipay')?.source, 'alipay');
});

test('same-source profiles preserve list order when their scores tie', () => {
  const [first, second] = createDefaultOcrRules();
  const duplicate = { ...second, id: 'alipay-second', sourceMatchers: first.sourceMatchers };
  const rules = [{ ...first, enabled: false }, second, duplicate].map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'alipay', weight: 7 }]
  }));
  assert.equal(selectOcrRule('alipay', rules)?.id, 'alipay-default');
});

test('validation rejects malformed expressions, missing capture groups, and invalid scores', () => {
  const rule = createDefaultOcrRules()[0];
  assert.equal(validateOcrRule({ ...rule, amountPattern: { pattern: '(', groupIndex: 1 } })?.field,
    'amountPattern');
  assert.equal(validateOcrRule({ ...rule, datePattern: { pattern: '\\d+', groupIndex: 2 } })?.field,
    'datePattern');
  assert.equal(validateOcrRule({ ...rule, sourceMatchers: [{ pattern: '微信', weight: 0 }] })?.field,
    'sourceMatchers');
  assert.equal(validateOcrRule({ ...rule, minimumScore: 0 })?.field, 'minimumScore');
});

test('capture validation counts named captures but ignores escapes, character classes, and non-capturing groups', () => {
  const rule = createDefaultOcrRules()[0];
  const expression = String.raw`\([()] (?:abc) (?<date>2026)`;
  assert.equal(validateOcrRule({ ...rule, datePattern: { pattern: expression, groupIndex: 1 } }), undefined);
  assert.equal(validateOcrRule({ ...rule, datePattern: { pattern: expression, groupIndex: 2 } })?.field,
    'datePattern');
});

test('income and expense terms are literal keywords and allow regex punctuation', () => {
  const rule = createDefaultOcrRules()[0];
  assert.equal(validateOcrRule({ ...rule, incomeKeywords: ['+收'] }), undefined);
});

test('missing OCR rule storage seeds defaults while a saved empty list remains empty', () => {
  const missing = decodeOcrRuleStore(undefined);
  const empty = decodeOcrRuleStore(JSON.stringify({ version: 1, rules: [] }));
  assert.equal(missing.persistDefaults, true);
  assert.equal(missing.rules.length, 3);
  assert.deepEqual(empty, { rules: [], persistDefaults: false });
});

test('invalid OCR rule storage throws instead of restoring defaults', () => {
  assert.throws(() => decodeOcrRuleStore('{'), Error);
  assert.throws(() => decodeOcrRuleStore(JSON.stringify({ version: 2, rules: [] })), Error);
  const invalidRule = { ...createDefaultOcrRules()[0], amountPattern: { pattern: '(', groupIndex: 1 } };
  assert.throws(() => decodeOcrRuleStore(JSON.stringify({ version: 1, rules: [invalidRule] })), Error);
});

test('receipt parsing applies editable source and field rules while retaining nearby row layout', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'wechat' ? {
    ...rule,
    sourceMatchers: [{ pattern: 'WalletX', weight: 8 }],
    amountPattern: { pattern: '金额=(\\d+\\.\\d{2})', groupIndex: 1 },
    datePattern: { pattern: '日期=(\\d{4}-\\d{2}-\\d{2}\\s+\\d{2}:\\d{2})', groupIndex: 1 },
    directionPattern: { pattern: '(支出|收入)', groupIndex: 1 },
    merchantPattern: { pattern: '商户[:：](.+)', groupIndex: 1 },
    expenseKeywords: ['支出'],
    incomeKeywords: ['收入'],
    categoryMappings: [{ pattern: '早餐', category: '餐饮' }]
  } : rule);
  const lines = [
    line('WalletX', 20),
    line('商户：早餐铺', 100),
    line('金额=12.34 备用=99.99 支出', 120),
    line('日期=2026-10-03 12:23', 140)
  ];
  const result = OcrImportCoordinator.parsePages([page(lines, lines.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(result.unclassifiedPages.length, 0);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].source, 'wechat');
  assert.equal(result.drafts[0].merchant, '早餐铺');
  assert.equal(result.drafts[0].dateText, '2026-10-03 12:23');
  assert.equal(result.drafts[0].amountText, '12.34');
  assert.equal(result.drafts[0].direction, 'expense');
  assert.equal(result.drafts[0].category, '餐饮');
});

test('same-source profiles are tried in list order until one yields a dated transaction', () => {
  const [first, ...rest] = createDefaultOcrRules();
  const sourceMatchers = [{ pattern: 'WalletX', weight: 8 }];
  const unusable = {
    ...first, id: 'wechat-first', sourceMatchers, datePattern: { pattern: 'NEVER=(\\d+)', groupIndex: 1 }
  };
  const usable = { ...first, id: 'wechat-second', sourceMatchers };
  const lines = [line('早餐店', 100), line('-12.50', 120), line('2026-10-03 12:23', 140)];
  const rawText = 'WalletX\n' + lines.map((item) => item.text).join('\n');
  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], [unusable, usable, ...rest]);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].amountText, '12.50');
});

test('an ambiguous page stays unclassified and manual parsing uses only the selected source', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared-wallet', weight: 6 }]
  }));
  const lines = [line('午餐店', 100), line('-12.50', 120), line('2026-10-03 12:23', 140)];
  const rawText = 'shared-wallet\n' + lines.map((item) => item.text).join('\n');
  const pages = [page(lines, rawText)];
  const automatic = OcrImportCoordinator.parsePages(pages, [], rules);
  assert.equal(automatic.unclassifiedPages.length, 1);
  const manual = OcrImportCoordinator.parsePage(lines, 'alipay', [], rules, [], pages[0].captureTime);
  assert.equal(manual.length, 1);
  assert.equal(manual[0].source, 'alipay');
});

test('default Alipay receipt rows retain nearby merchant, date, and category', () => {
  const rules = createDefaultOcrRules();
  const lines = [
    line('早餐店', 100), line('-25.00', 120), line('餐饮美食', 140), line('2026-10-03 11:11', 160)
  ];
  const rawText = '支付宝 搜索交易记录\n' + lines.map((item) => item.text).join('\n');
  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].merchant, '早餐店');
  assert.equal(result.drafts[0].category, '餐饮美食');
  assert.equal(result.drafts[0].dateText, '2026-10-03 11:11');
});

test('default receipt amount parsing keeps the last unsigned decimal on a row', () => {
  const rules = createDefaultOcrRules();
  const lines = [line('早餐店 12.34 和 99.99', 100), line('2026-10-03 11:11', 120)];
  const rawText = '微信支付\n' + lines.map((item) => item.text).join('\n');
  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].amountText, '99.99');
});

test('a signed merchant transaction near a monthly summary label is not filtered as a total', () => {
  const rules = createDefaultOcrRules();
  const lines = [line('本月支出', 80), line('早餐店 -12.50', 110), line('2026-10-03 12:23', 140)];
  const result = OcrImportCoordinator.parsePages(
    [page(lines, '微信支付\n' + lines.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].merchant, '早餐店');
  assert.equal(result.drafts[0].amountText, '12.50');
});

test('receipt date format and time expression parse localized date text', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'wechat' ? {
    ...rule,
    datePattern: { pattern: '日期=(.+)', groupIndex: 1 },
    timePattern: { pattern: '(\\d{1,2}时\\d{2}分)', groupIndex: 1 },
    dateFormat: 'yyyy年MM月dd日 HH时mm分'
  } : rule);
  const lines = [line('商户：早餐店', 100), line('-12.50', 120), line('日期=2026年10月03日 12时23分', 140)];
  const rawText = '微信支付\n' + lines.map((item) => item.text).join('\n');
  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].dateText, '2026-10-03 12:23');
  assert.equal(result.drafts[0].hasTime, true);
});

test('default receipt date matching preserves explicit years around OCR whitespace', () => {
  const rules = createDefaultOcrRules();
  const lines = [line('早餐店', 100), line('-12.50', 120), line('2025 / 10/03 12:23', 140)];
  const result = OcrImportCoordinator.parsePages([page(lines, '微信支付\n' +
    lines.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].dateText, '2025-10-03 12:23');
});

test('custom date formats reject out-of-range hour and minute values', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'wechat' ? {
    ...rule,
    datePattern: { pattern: '日期=(.+)', groupIndex: 1 },
    dateFormat: 'yyyy-MM-dd HH:mm'
  } : rule);
  const lines = [line('早餐店', 100), line('-12.50', 120), line('日期=2026-10-03 12:99', 140)];
  const result = OcrImportCoordinator.parsePages([page(lines, '微信支付\n' +
    lines.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(result.drafts.length, 0);
});

test('receipt filters use configured failure and summary expressions and keep refund direction for review', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'wechat' ? {
    ...rule,
    failurePatterns: [...rule.failurePatterns, 'NEEDS_REVIEW_FAILURE'],
    summaryPatterns: [...rule.summaryPatterns, 'CUSTOM_TOTAL']
  } : rule);
  const lines = [
    line('商户：失败订单', 80), line('NEEDS_REVIEW_FAILURE -45.00', 100), line('2026-10-03 10:00', 120),
    line('CUSTOM_TOTAL', 180), line('100.00', 200), line('2026-10-03 11:00', 220),
    line('交易列表', 260), line('日期筛选', 280),
    line('退款 早餐店', 340), line('+12.00', 360), line('2026-10-03 12:23', 380),
    line('无日期商户', 420), line('-9.99', 440)
  ];
  const rawText = '微信支付\n' + lines.map((item) => item.text).join('\n');
  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].isRefund, true);
  assert.equal(result.drafts[0].direction, undefined);
  assert.match(result.drafts[0].warnings.join(' '), /请确认收入或支出方向/);
});

test('ICBC rules apply configurable amount and category mappings inside coordinate-based blocks', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'icbc' ? {
    ...rule,
    amountPattern: { pattern: 'SIGNED=([+-]\\d+\\.\\d{2})', groupIndex: 1 },
    categoryMappings: [{ pattern: '自定义业务', category: '自定义分类' }]
  } : rule);
  const lines = [
    line('中国工商银行', 20), line('2026年10月', 60), line('3', 100),
    line('自定义业务', 140), line('SIGNED=-1031.10', 160), line('商户：交易对方', 180),
    line('人民币余额：8,000.00', 200)
  ];
  const rawText = lines.map((item) => item.text).join('\n');
  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].amountText, '1031.10');
  assert.equal(result.drafts[0].category, '自定义分类');
});

test('removing an ICBC category mapping leaves the configured default category in control', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'icbc' ? {
    ...rule,
    defaultCategory: 'CUSTOM',
    categoryMappings: []
  } : rule);
  const lines = [
    line('中国工商银行', 20), line('2026年10月', 60), line('3', 100), line('消费', 140),
    line('商户A', 160), line('-10.00', 180), line('人民币余额：1,000.00', 200)
  ];
  const result = OcrImportCoordinator.parsePages([page(lines, lines.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].category, 'CUSTOM');
});

test('ICBC amount and balance digits cannot replace or invent a transaction day', () => {
  const rules = createDefaultOcrRules();
  const lines = [
    line('中国工商银行', 20), line('2026年10月', 60), line('3', 100), line('消费', 140),
    line('商户A', 160), line('-1031.10', 180), line('人民币余额：8,000.00', 200)
  ];
  const result = OcrImportCoordinator.parsePages([page(lines, lines.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].dateText, '2026-10-03');

  const withoutDay = lines.filter((item) => item.text !== '3');
  const missingDate = OcrImportCoordinator.parsePages(
    [page(withoutDay, withoutDay.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(missingDate.drafts.length, 0);
});

test('ICBC direction expressions classify unsigned amounts from the configured keywords', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'icbc' ? {
    ...rule,
    amountPattern: { pattern: '金额=(\\d+\\.\\d{2})', groupIndex: 1 },
    directionPattern: { pattern: '(收入|支出)', groupIndex: 1 },
    incomeKeywords: ['收入'],
    expenseKeywords: ['支出']
  } : rule);
  const lines = [
    line('中国工商银行', 20), line('2026年10月', 60), line('3', 100),
    line('交易对方', 140), line('金额=500.00 支出', 160), line('人民币余额：8,000.00', 180)
  ];
  const result = OcrImportCoordinator.parsePages([page(lines, lines.map((item) => item.text).join('\n'))], [], rules);
  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].direction, 'expense');
});
