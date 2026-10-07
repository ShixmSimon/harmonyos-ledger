import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createNotificationRule,
  previewNotificationRule
} from '../entry/src/main/ets/services/ruleImport/NotificationRuleImportAdapter.ets';
import { parseRuleImport } from '../entry/src/main/ets/services/ruleImport/RuleImportEngine.ets';

const description = {
  name: '示例支付',
  sourceKeywords: ['MockPay'],
  bodyPattern: '(?<direction>收入|支出).*?金额[:：]\\s*(?<amount>[¥￥]?[\\d,.]+)元(?:.*?商户[:：](?<merchant>[^\\s]+))?',
  incomeText: '收入',
  expenseText: '支出',
  dateFormat: '',
  dateStrategy: 'delivery-time',
  defaultMerchant: '示例支付',
  defaultCategory: '其他',
  entrySource: 'mock-pay'
};

test('compiles compact notification rules to semantic runtime capture mode', () => {
  const rule = createNotificationRule(description, [{ id: 'notice-ai-MockPay' }]);

  assert.equal(rule.id, 'notice-ai-MockPay-2');
  assert.equal(rule.semanticCaptures, true);
  assert.equal(rule.amountGroup, undefined);
  assert.equal(rule.directionGroup, undefined);
  assert.equal(rule.entrySource, 'mock-pay');
});

test('previews notification examples through the production parser and compares grouped amounts', () => {
  const parsed = parseRuleImport(JSON.stringify({
    schemaVersion: 1,
    kind: 'notification',
    rule: description,
    examples: [
      { input: '支出 金额：1,031.10元 商户：午餐店', expected: { amount: '1,031.10', direction: 'expense', merchant: '午餐店' } },
      { input: '收入 金额：12,345,678.90元', expected: { amount: '12,345,678.90', direction: 'income', merchant: '示例支付' } }
    ]
  }), 'notification');
  assert.equal(parsed.valid, true);

  const rule = createNotificationRule(parsed.rule, []);
  const previews = previewNotificationRule(rule, parsed.examples);

  assert.equal(previews.length, 2);
  assert.equal(previews.every((preview) => preview.matched), true);
  assert.equal(previews[0].actual.amount, '1031.10');
  assert.equal(previews[0].actual.merchant, '午餐店');
  assert.equal(Object.hasOwn(rule, 'examples'), false);
});
