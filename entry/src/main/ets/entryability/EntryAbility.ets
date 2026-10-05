import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index').then(() => {
      hilog.info(0x0000, 'HarmonyLedger', 'Main page loaded');
    }).catch((error: Error) => {
      hilog.error(0x0000, 'HarmonyLedger', 'Main page load failed: ' + error.message);
    });
  }
}
