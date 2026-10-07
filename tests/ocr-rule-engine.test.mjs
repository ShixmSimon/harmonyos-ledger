import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createDefaultOcrRules,
  decodeOcrRuleStore,
  selectOcrRule,
  validateOcrRule
} from '../entry/src/main/ets/services/ocrRules/OcrRuleEngine.ets';
import { OcrImportCoordinator } from '../entry/src/main/ets/services/OcrImportCoordinator.ets';
import { OcrSourceDetector } from '../entry/src/main/ets/services/OcrSourceDetector.ets';

function line(text, centerY, left = 10, right = 290) {
  return { text, left, top: centerY - 10, right, bottom: centerY + 10, centerY, height: 20 };
}

function page(lines, rawText, captureTime = new Date(2026, 9, 31, 12).getTime(), imageWidth = 1000) {
  return { pageNumber: 1, lines, rawText, captureTime, imageWidth };
}

function genericRule(overrides = {}) {
  return {
    ...createDefaultOcrRules()[0],
    id: 'generic-wallet-rule',
    name: '自定义钱包版式',
    source: 'generic-wallet',
    sourceName: '自定义钱包',
    layoutStrategy: 'generic',
    record: { mode: 'row' },
    sourceMatchers: [{ pattern: 'WalletX' }],
    amountPattern: { pattern: '金额[:：]\\s*([+-]?\\s*[¥￥]?\\s*[\\d,.]+)', groupIndex: 1 },
    datePattern: { pattern: '日期[:：]\\s*(20\\d{2}-\\d{1,2}-\\d{1,2})', groupIndex: 1 },
    timePattern: undefined,
    directionPattern: { pattern: '(收入|支出)', groupIndex: 1 },
    merchantPattern: { pattern: '商户[:：]\\s*([^\\s]+)', groupIndex: 1 },
    dateFormat: 'auto',
    incomeKeywords: ['收入'],
    expenseKeywords: ['支出'],
    ...overrides
  };
}

test('default OCR rules retain the built-in sources and display names without detector thresholds', () => {
  const rules = createDefaultOcrRules();
  assert.deepEqual(rules.map((rule) => rule.source), ['wechat', 'alipay', 'icbc']);
  assert.deepEqual(rules.map((rule) => rule.sourceName), ['微信支付', '支付宝', '工商银行']);
  assert.deepEqual(rules.map((rule) => rule.layoutStrategy), ['generic', 'generic', 'icbc-statement']);
  assert.ok(rules.every((rule) => rule.minimumScore === undefined && rule.scoreMargin === undefined));
});

test('default source expressions retain current WeChat, Alipay, and ICBC detection', () => {
  const rules = createDefaultOcrRules();
  assert.equal(selectOcrRule('微信支付 全部账单 收支统计 查找交易', rules)?.source, 'wechat');
  assert.equal(selectOcrRule('查找交易 全部账单 收支统计', rules)?.source, 'wechat');
  assert.equal(selectOcrRule('支付宝 搜索交易记录 芝麻', rules)?.source, 'alipay');
  assert.equal(selectOcrRule('中国工商银行 工商银行 当页汇总笔数', rules)?.source, 'icbc');
});

test('source selection counts matched expressions and ignores legacy score thresholds', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: rule.source === 'wechat' ? [
      { pattern: 'WalletX', weight: 1 }, { pattern: '账单列表', weight: 1 }
    ] : [{ pattern: 'WalletX', weight: 20 }],
    minimumScore: 100,
    scoreMargin: 100
  }));

  assert.equal(selectOcrRule('WalletX 账单列表', rules)?.source, 'wechat');
});

test('a unique source score is accepted without thresholds and ties remain unresolved', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: rule.source === 'wechat' ? 'wallet' : 'bank', weight: 1 }],
    minimumScore: 0,
    scoreMargin: 0
  }));

  assert.equal(selectOcrRule('wallet', rules)?.source, 'wechat');
  const tied = rules.map((rule) => ({ ...rule, sourceMatchers: [{ pattern: 'shared', weight: 1 }] }));
  assert.equal(selectOcrRule('shared', tied), undefined);
  assert.equal(selectOcrRule('unmatched', rules), undefined);
});

test('custom source ids and display names pass OCR rule validation', () => {
  const rule = {
    ...createDefaultOcrRules()[0],
    source: 'example-wallet',
    sourceName: '示例钱包',
    sourceMatchers: [{ pattern: 'Example Wallet' }]
  };

  assert.equal(validateOcrRule(rule), undefined);
});

test('generic OCR validation requires valid record mode, first captures, and normalized columns', () => {
  const rule = genericRule();
  assert.equal(validateOcrRule({ ...rule, record: undefined })?.field, 'record');
  assert.equal(validateOcrRule({ ...rule, record: { mode: 'anchor' } })?.field, 'record.anchorPattern');
  assert.equal(validateOcrRule({ ...rule, amountPattern: { pattern: '(x)(y)', groupIndex: 2 } })?.field,
    'amountPattern');
  assert.equal(validateOcrRule({ ...rule, columns: { amount: { left: 0.8, right: 0.2 } } })?.field,
    'columns.amount');
});

test('version one OCR rules migrate with their parser identity and version two keeps empty stores empty', () => {
  const legacyRule = { ...createDefaultOcrRules()[0], layoutStrategy: 'receipt-list',
    sourceMatchers: [{ pattern: 'legacy clue', weight: 8 }] };
  delete legacyRule.record;
  delete legacyRule.sourceName;
  const migrated = decodeOcrRuleStore(JSON.stringify({ version: 1, rules: [legacyRule] }));
  const emptyV2 = decodeOcrRuleStore(JSON.stringify({ version: 2, rules: [] }));

  assert.equal(migrated.migrated, true);
  assert.equal(migrated.rules[0].layoutStrategy, 'receipt-list');
  assert.equal(migrated.rules[0].sourceName, '微信支付');
  assert.equal(migrated.rules[0].sourceMatchers[0].weight, 8);
  assert.deepEqual(emptyV2, { rules: [], persistDefaults: false, migrated: false });
});

test('OCR detection returns the dynamic source identity and pages show its configured name', () => {
  const walletRule = {
    ...createDefaultOcrRules()[0],
    source: 'example-wallet',
    sourceName: '示例钱包',
    sourceMatchers: [{ pattern: 'Example Wallet' }]
  };
  const detected = OcrSourceDetector.detect('Example Wallet', [walletRule]);
  const result = OcrImportCoordinator.parsePages([
    page([line('Example Wallet', 20)], 'Example Wallet')
  ], [], [walletRule]);

  assert.equal(detected?.source, 'example-wallet');
  assert.match(result.rawText, /识别来源：示例钱包/);
});

test('generic row mode extracts multiple transactions and standard thousand-grouped amounts', () => {
  const rule = genericRule();
  const lines = [
    line('WalletX 2026-10-03', 100),
    line('日期：2026-10-03', 100, 10, 220),
    line('商户：午餐店', 100, 230, 450),
    line('支出', 100, 460, 520),
    line('金额：1,031.10', 100, 700, 950),
    line('日期：2026-10-04', 150, 10, 220),
    line('商户：设备店', 150, 230, 450),
    line('支出', 150, 460, 520),
    line('金额：12,345,678.90', 150, 700, 950)
  ];
  const rawText = 'WalletX\n' + lines.map((item) => item.text).join('\n');

  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], [rule]);

  assert.equal(result.drafts.length, 2);
  assert.equal(result.drafts[0].source, 'generic-wallet');
  assert.equal(result.drafts[0].dateText, '2026-10-03');
  assert.equal(result.drafts[0].amountText, '1031.10');
  assert.equal(result.drafts[1].amountText, '12345678.90');
});

test('generic anchor mode groups fields across rows until the next transaction anchor', () => {
  const rule = genericRule({
    record: { mode: 'anchor', anchorPattern: '^交易[:：]' },
    amountPattern: { pattern: '金额[:：]\\s*([\\d,.]+)', groupIndex: 1 },
    datePattern: { pattern: '日期[:：]\\s*(20\\d{2}-\\d{1,2}-\\d{1,2})', groupIndex: 1 }
  });
  const lines = [
    line('交易：A', 40), line('日期：2026-10-03', 70), line('商户：早餐店', 100),
    line('支出', 130), line('金额：12.34', 160),
    line('交易：B', 220), line('日期：2026-10-04', 250), line('商户：书店', 280),
    line('收入', 310), line('金额：56.78', 340)
  ];
  const rawText = 'WalletX\n' + lines.map((item) => item.text).join('\n');

  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], [rule]);

  assert.equal(result.drafts.length, 2);
  assert.equal(result.drafts[0].merchant, '早餐店');
  assert.equal(result.drafts[0].dateText, '2026-10-03');
  assert.equal(result.drafts[1].merchant, '书店');
  assert.equal(result.drafts[1].direction, 'income');
});

test('generic field columns prevent a nearby number from replacing the amount', () => {
  const rule = genericRule({
    columns: { amount: { left: 0.65, right: 0.98 } },
    amountPattern: { pattern: '([\\d,.]+)', groupIndex: 1 }
  });
  const lines = [
    line('日期：2026-10-03', 100, 10, 220),
    line('编号 99', 100, 250, 390),
    line('商户：午餐店', 100, 400, 600),
    line('支出', 100, 610, 680),
    line('金额：1,031.10', 100, 700, 950)
  ];
  const rawText = 'WalletX\n' + lines.map((item) => item.text).join('\n');

  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], [rule]);

  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].amountText, '1031.10');
});

test('generic rules with configured columns do not fall back to unfiltered OCR when image width is missing', () => {
  const rule = genericRule({
    columns: { amount: { left: 0.65, right: 0.98 } },
    amountPattern: { pattern: '([\\d,.]+)', groupIndex: 1 }
  });
  const lines = [
    line('日期：2026-10-03', 100, 10, 220),
    line('商户：午餐店', 100, 400, 600),
    line('金额：1,031.10', 100, 700, 950)
  ];
  const result = OcrImportCoordinator.parsePages([{
    pageNumber: 1,
    lines,
    rawText: 'WalletX\n' + lines.map((item) => item.text).join('\n')
  }], [], [rule]);
  assert.equal(result.drafts.length, 0);
});

test('generic parser drops failed summaries and keeps refunds for manual direction review', () => {
  const rule = genericRule({
    amountPattern: { pattern: '金额[:：]\\s*([\\d,.]+)', groupIndex: 1 },
    failurePatterns: ['交易失败'],
    refundPatterns: ['退款'],
    summaryPatterns: ['合计']
  });
  const lines = [
    line('日期：2026-10-03 商户：失败店 支出 金额：10.00 交易失败', 100),
    line('日期：2026-10-03 商户：汇总 支出 金额：20.00 合计', 150),
    line('日期：2026-10-03 商户：退款店 退款 金额：30.00', 200)
  ];
  const rawText = 'WalletX\n' + lines.map((item) => item.text).join('\n');

  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], [rule]);

  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].isRefund, true);
  assert.equal(result.drafts[0].direction, undefined);
  assert.equal(result.drafts[0].category, '退款');
});

test('generic parser rejects invalid dates and amounts but leaves unknown direction for review', () => {
  const rule = genericRule({ amountPattern: { pattern: '金额[:：]\\s*([\\d,.]+)', groupIndex: 1 } });
  const lines = [
    line('日期：2026-02-30 商户：坏日期 支出 金额：10.00', 100),
    line('日期：2026-10-03 商户：坏金额 支出 金额：not-money', 150),
    line('日期：2026-10-04 商户：方向不明 金额：12.34', 200)
  ];
  const rawText = 'WalletX\n' + lines.map((item) => item.text).join('\n');

  const result = OcrImportCoordinator.parsePages([page(lines, rawText)], [], [rule]);

  assert.equal(result.drafts.length, 1);
  assert.equal(result.drafts[0].merchant, '方向不明');
  assert.equal(result.drafts[0].direction, undefined);
  assert.ok(result.drafts[0].warnings.some((warning) => warning.includes('方向不明确')));
});

test('legacy matcher weights do not make an otherwise tied source win', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared', weight: rule.source === 'wechat' ? 8 : 5 }],
    minimumScore: 1,
    scoreMargin: 0
  }));
  assert.equal(selectOcrRule('shared', rules), undefined);
});

test('source ambiguity is rejected when the score difference is too small', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared', weight: 6 }]
  }));
  assert.equal(selectOcrRule('shared', rules), undefined);
});

test('identical source scores remain ambiguous even when a legacy margin is zero', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared', weight: 6 }],
    scoreMargin: 0
  }));
  assert.equal(selectOcrRule('shared', rules), undefined);
});

test('manual source selection resolves an automatic tie within the selected source', () => {
  const rules = createDefaultOcrRules().map((rule) => ({
    ...rule,
    sourceMatchers: [{ pattern: 'shared', weight: rule.source === 'wechat' ? 20 : 6 }]
  }));
  assert.equal(selectOcrRule('shared', rules), undefined);
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

test('validation rejects malformed expressions, missing capture groups, and invalid legacy scores', () => {
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
  const empty = decodeOcrRuleStore(JSON.stringify({ version: 2, rules: [] }));
  assert.equal(missing.persistDefaults, true);
  assert.equal(missing.rules.length, 3);
  assert.deepEqual(empty, { rules: [], persistDefaults: false, migrated: false });
});

test('invalid OCR rule storage throws instead of restoring defaults', () => {
  assert.throws(() => decodeOcrRuleStore('{'), Error);
  assert.throws(() => decodeOcrRuleStore(JSON.stringify({ version: 3, rules: [] })), Error);
  const invalidRule = { ...createDefaultOcrRules()[0], amountPattern: { pattern: '(', groupIndex: 1 } };
  assert.throws(() => decodeOcrRuleStore(JSON.stringify({ version: 1, rules: [invalidRule] })), Error);
});

test('receipt parsing applies editable source and field rules while retaining nearby row layout', () => {
  const rules = createDefaultOcrRules().map((rule) => rule.source === 'wechat' ? {
    ...rule,
    layoutStrategy: 'receipt-list',
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
    ...first, layoutStrategy: 'receipt-list', id: 'wechat-first', sourceMatchers,
    datePattern: { pattern: 'NEVER=(\\d+)', groupIndex: 1 }
  };
  const usable = { ...first, layoutStrategy: 'receipt-list', id: 'wechat-second', sourceMatchers };
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
