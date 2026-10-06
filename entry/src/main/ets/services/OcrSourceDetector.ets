import type { ImportSource } from '../model/LedgerModels';
import { createDefaultOcrRules, selectOcrRule } from './ocrRules/OcrRuleEngine';
import type { OcrRule } from './ocrRules/OcrRuleModels';

export class OcrSourceDetector {
  static detect(text: string, rules: OcrRule[] = createDefaultOcrRules()): ImportSource | undefined {
    return selectOcrRule(text, rules)?.source;
  }
}
