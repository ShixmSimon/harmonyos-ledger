export interface NotificationArchiveEntry {
  id: number;
  hashCode: string;
  slotType: number;
  bundleName: string;
  appName: string;
  deliveryTime: number;
  groupName: string;
  appIndex: number;
  title: string;
  body: string;
  receivedAt: number;
  eventTime: number;
}

export interface NotificationSource {
  bundleName: string;
  appName: string;
}

export interface NotificationArchiveFilter {
  bundleName: string;
  keyword: string;
  startTime?: number;
  endTimeExclusive?: number;
}

export interface NotificationArchiveCursor {
  eventTime: number;
  id: number;
}

export interface NotificationArchivePage {
  entries: NotificationArchiveEntry[];
  nextCursor?: NotificationArchiveCursor;
}
