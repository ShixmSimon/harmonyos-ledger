import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { indexStorage } from '../state/IndexStorage';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    indexStorage.setOrCreate('shareImportMode', false);
    indexStorage.setOrCreate('sharedImageUris', []);
    indexStorage.setOrCreate('shareImportError', '');
    windowStage.loadContent('pages/Index', indexStorage).then(() => {
      hilog.info(0x0000, 'HarmonyLedger', '主页加载完成');
    }).catch((error: Error) => {
      hilog.error(0x0000, 'HarmonyLedger', '主页加载失败: ' + error.message);
    });
  }
}
