import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { notificationExtensionSubscription } from '@kit.NotificationKit';

const PREFERENCES_NAME: string = 'notification_probe';

export interface NotificationProbeSnapshot {
  receivedCount: number;
  bundleName: string;
  appName: string;
  deliveryTime: number;
  title: string;
  body: string;
  titleLength: number;
  bodyLength: number;
}

export function emptyNotificationProbe(): NotificationProbeSnapshot {
  return {
    receivedCount: 0,
    bundleName: '',
    appName: '',
    deliveryTime: 0,
    title: '',
    body: '',
    titleLength: 0,
    bodyLength: 0
  };
}

export async function recordNotificationProbe(
  context: common.Context,
  info: notificationExtensionSubscription.NotificationInfo
): Promise<void> {
  const store = await preferences.getPreferences(context, PREFERENCES_NAME);
  const savedCount = store.getSync('receivedCount', 0);
  const receivedCount = typeof savedCount === 'number' ? savedCount : 0;
  const title = info.content?.title ?? '';
  const body = info.content?.text ?? '';

  store.putSync('receivedCount', receivedCount + 1);
  store.putSync('bundleName', info.bundleName);
  store.putSync('appName', info.appName ?? '');
  store.putSync('deliveryTime', info.deliveryTime ?? Date.now());
  store.putSync('title', title);
  store.putSync('body', body);
  store.putSync('titleLength', title.length);
  store.putSync('bodyLength', body.length);
  await store.flush();
}

export async function loadNotificationProbe(context: common.Context): Promise<NotificationProbeSnapshot> {
  await preferences.removePreferencesFromCache(context, PREFERENCES_NAME);
  const store = await preferences.getPreferences(context, PREFERENCES_NAME);
  const receivedCount = store.getSync('receivedCount', 0);
  const deliveryTime = store.getSync('deliveryTime', 0);
  const title = store.getSync('title', '');
  const body = store.getSync('body', '');
  const titleLength = store.getSync('titleLength', 0);
  const bodyLength = store.getSync('bodyLength', 0);
  const bundleName = store.getSync('bundleName', '');
  const appName = store.getSync('appName', '');

  return {
    receivedCount: typeof receivedCount === 'number' ? receivedCount : 0,
    bundleName: typeof bundleName === 'string' ? bundleName : '',
    appName: typeof appName === 'string' ? appName : '',
    deliveryTime: typeof deliveryTime === 'number' ? deliveryTime : 0,
    title: typeof title === 'string' ? title : '',
    body: typeof body === 'string' ? body : '',
    titleLength: typeof titleLength === 'number' ? titleLength : 0,
    bodyLength: typeof bodyLength === 'number' ? bodyLength : 0
  };
}

export async function clearNotificationProbe(context: common.Context): Promise<void> {
  const store = await preferences.getPreferences(context, PREFERENCES_NAME);
  store.putSync('receivedCount', 0);
  store.putSync('bundleName', '');
  store.putSync('appName', '');
  store.putSync('deliveryTime', 0);
  store.putSync('title', '');
  store.putSync('body', '');
  store.putSync('titleLength', 0);
  store.putSync('bodyLength', 0);
  await store.flush();
}
