import test from 'node:test';
import assert from 'node:assert/strict';
import { createOcrRule, previewOcrRule } from '../entry/src/main/ets/services/ruleImport/OcrRuleImportAdapter.ets';
import { parseRuleImport } from '../entry/src/main/ets/services/ruleImport/RuleImportEngine.ets';

const description = {
  name: '示例钱包',
  source: { id: 'example-wallet', name: '示例钱包', patterns: ['Example Wallet'] },
  record: { mode: 'row' },
  fields: {
    amount: '金额[:：]\\s*([+-]?\\s*[¥￥]?\\s*[\\d,.]+)',
    date: '日期[:：]\\s*((?:20\\d{2}[-/.年])?\\d{1,2}[-/.月]\\d{1,2}日?)',
    direction: '(收入|支出)',
    merchant: '商户[:：]\\s*(.+)',
    category: '分类[:：]\\s*(.+)'
  },
  incomeKeywords: ['收入'],
  expenseKeywords: ['支出'],
  defaultCategory: '其他'
};

test('compiles compact OCR descriptions and allocates a non-conflicting runtime id', () => {
  const existing = [{ id: 'ocr-ai-example-wallet', source: 'example-wallet' }];
  const rule = createOcrRule(description, existing);

  assert.equal(rule.id, 'ocr-ai-example-wallet-2');
  assert.equal(rule.source, 'example-wallet');
  assert.equal(rule.sourceName, '示例钱包');
  assert.equal(rule.layoutStrategy, 'generic');
  assert.equal(rule.amountPattern.groupIndex, 1);
  assert.equal(Object.hasOwn(rule, 'examples'), false);
});

test('previews OCR examples through the runtime parser without persisting samples', () => {
  const parsed = parseRuleImport(JSON.stringify({
    schemaVersion: 1,
    kind: 'ocr',
    rule: description,
    examples: [{
      input: '日期：2026-10-03\n商户：午餐店\n支出 金额：1,031.10\n分类：餐饮',
      expected: { amount: '1,031.10', date: '2026-10-03', direction: 'expense', merchant: '午餐店', category: '餐饮' }
    }]
  }), 'ocr');
  assert.equal(parsed.valid, true);

  const rule = createOcrRule(parsed.rule, []);
  const previews = previewOcrRule(rule, parsed.examples);

  assert.equal(previews.length, 1);
  assert.equal(previews[0].matched, true, JSON.stringify(previews[0]));
  assert.deepEqual(previews[0].actual, {
    amount: '1031.10', date: '2026-10-03', direction: 'expense', merchant: '午餐店', category: '餐饮'
  });
  assert.equal(Object.hasOwn(rule, 'examples'), false);
});

test('text-only OCR previews explain that visual column ranges could not be checked', () => {
  const rule = createOcrRule({ ...description, columns: { amount: { left: 0.65, right: 0.98 } } }, []);
  const previews = previewOcrRule(rule, [{
    input: '日期：2026-10-03\n商户：午餐\n支出 金额：12.34',
    expected: { amount: '12.34', direction: 'expense' }
  }]);

  assert.equal(previews[0].matched, true);
  assert.match(previews[0].message, /不含坐标/);
  assert.deepEqual(rule.columns.amount, { left: 0.65, right: 0.98 });
});
