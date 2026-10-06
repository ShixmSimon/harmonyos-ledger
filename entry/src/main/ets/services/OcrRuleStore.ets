import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { decodeOcrRuleStore, validateOcrRule } from './ocrRules/OcrRuleEngine';
import type { OcrRule, OcrRuleStore } from './ocrRules/OcrRuleModels';

const PREFERENCES_NAME: string = 'ocr_recognition_rules';
const RULES_KEY: string = 'ruleSet';

export async function loadOcrRules(context: common.Context): Promise<OcrRule[]> {
  await preferences.removePreferencesFromCache(context, PREFERENCES_NAME);
  const preferencesStore = await preferences.getPreferences(context, PREFERENCES_NAME);
  let savedValue: string | undefined = undefined;
  if (preferencesStore.hasSync(RULES_KEY)) {
    const value = preferencesStore.getSync(RULES_KEY, '');
    if (typeof value !== 'string') {
      throw new Error('已保存的 OCR 识别规则数据类型无效');
    }
    savedValue = value;
  }
  const state = decodeOcrRuleStore(savedValue);
  if (state.persistDefaults) {
    const serialized: OcrRuleStore = { version: 1, rules: state.rules };
    preferencesStore.putSync(RULES_KEY, JSON.stringify(serialized));
    await preferencesStore.flush();
  }
  return state.rules;
}

export async function saveOcrRules(context: common.Context, rules: OcrRule[]): Promise<void> {
  if (!Array.isArray(rules)) {
    throw new Error('OCR 识别规则列表无效');
  }
  for (const rule of rules) {
    const issue = validateOcrRule(rule);
    if (issue !== undefined) {
      throw new Error(issue.message);
    }
  }
  const preferencesStore = await preferences.getPreferences(context, PREFERENCES_NAME);
  const serialized: OcrRuleStore = { version: 1, rules: rules };
  preferencesStore.putSync(RULES_KEY, JSON.stringify(serialized));
  await preferencesStore.flush();
}
