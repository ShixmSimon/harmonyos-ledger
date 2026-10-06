import { notificationExtensionSubscription } from '@kit.NotificationKit';
import { LedgerEntry } from '../model/LedgerModels';
import { NotificationRule } from './notificationRules/NotificationRuleModels';
import { parseNotificationEntry } from './notificationRules/NotificationRuleEngine';

export function parseBankNotificationEntry(
  info: notificationExtensionSubscription.NotificationInfo,
  receivedAt: number,
  rules: NotificationRule[]
): LedgerEntry | undefined {
  return parseNotificationEntry({
    appName: info.appName ?? '',
    bundleName: info.bundleName,
    title: info.content?.title ?? '',
    body: info.content?.text ?? '',
    deliveryTime: info.deliveryTime,
    receivedAt: receivedAt
  }, rules);
}
