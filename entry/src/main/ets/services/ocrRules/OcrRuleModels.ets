import type { ImportSource } from '../../model/LedgerModels';

export type OcrLayoutStrategy = 'receipt-list' | 'icbc-statement';

export interface OcrPattern {
  pattern: string;
  groupIndex: number;
}

export interface OcrSourceMatcher {
  pattern: string;
  weight: number;
}

export interface OcrCategoryMapping {
  pattern: string;
  category: string;
}

export interface OcrRule {
  id: string;
  name: string;
  enabled: boolean;
  source: ImportSource;
  layoutStrategy: OcrLayoutStrategy;
  sourceMatchers: OcrSourceMatcher[];
  minimumScore: number;
  scoreMargin: number;
  amountPattern: OcrPattern;
  datePattern: OcrPattern;
  timePattern?: OcrPattern;
  directionPattern?: OcrPattern;
  merchantPattern?: OcrPattern;
  categoryPattern?: OcrPattern;
  dateFormat: string;
  incomeKeywords: string[];
  expenseKeywords: string[];
  failurePatterns: string[];
  refundPatterns: string[];
  summaryPatterns: string[];
  defaultCategory: string;
  categoryMappings: OcrCategoryMapping[];
}

export interface OcrRuleStore {
  version: 1;
  rules: OcrRule[];
}

export interface OcrRuleLoadResult {
  rules: OcrRule[];
  persistDefaults: boolean;
}

export interface OcrRuleValidationIssue {
  field: string;
  message: string;
}
