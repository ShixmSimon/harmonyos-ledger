import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { decodeNotificationRuleStore, validateNotificationRule } from './notificationRules/NotificationRuleEngine';
import { NotificationRule, NotificationRuleStore } from './notificationRules/NotificationRuleModels';

const PREFERENCES_NAME: string = 'notification_rules';
const RULES_KEY: string = 'ruleSet';

export async function loadNotificationRules(context: common.Context): Promise<NotificationRule[]> {
  await preferences.removePreferencesFromCache(context, PREFERENCES_NAME);
  const store = await preferences.getPreferences(context, PREFERENCES_NAME);
  let savedValue: string | undefined = undefined;
  if (store.hasSync(RULES_KEY)) {
    const value = store.getSync(RULES_KEY, '');
    if (typeof value !== 'string') {
      throw new Error('已保存的通知规则数据类型无效');
    }
    savedValue = value;
  }
  const state = decodeNotificationRuleStore(savedValue);
  if (state.persistDefaults || state.migrated === true) {
    const serialized: NotificationRuleStore = { version: 2, defaultRulesVersion: 1, rules: state.rules };
    store.putSync(RULES_KEY, JSON.stringify(serialized));
    await store.flush();
  }
  return state.rules;
}

export async function saveNotificationRules(context: common.Context, rules: NotificationRule[]): Promise<void> {
  if (!Array.isArray(rules)) {
    throw new Error('通知规则列表无效');
  }
  for (const rule of rules) {
    const issue = validateNotificationRule(rule);
    if (issue !== undefined) {
      throw new Error(issue.message);
    }
  }
  const store = await preferences.getPreferences(context, PREFERENCES_NAME);
  const serialized: NotificationRuleStore = { version: 2, defaultRulesVersion: 1, rules: rules };
  store.putSync(RULES_KEY, JSON.stringify(serialized));
  await store.flush();
}
