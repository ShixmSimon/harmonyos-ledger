import { ShareExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { systemShare } from '@kit.ShareKit';
import { indexStorage } from '../state/IndexStorage';

export default class ShareImportExtension extends ShareExtensionAbility {
  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    void this.loadSharedImages(want, session);
  }

  private async loadSharedImages(want: Want, session: UIExtensionContentSession): Promise<void> {
    try {
      const sharedData = await systemShare.getSharedData(want);
      const imageUris: string[] = [];
      sharedData.getRecords().forEach((record: systemShare.SharedRecord) => {
        if (record.uri === undefined) {
          return;
        }
        const imageType = record.utd === uniformTypeDescriptor.UniformDataType.IMAGE ||
          uniformTypeDescriptor.getTypeDescriptor(record.utd)
            .belongsTo(uniformTypeDescriptor.UniformDataType.IMAGE);
        if (imageType && imageUris.length < 20) {
          imageUris.push(record.uri);
        }
      });
      const errorMessage = imageUris.length === 0 ? '分享内容中没有找到图片。' : '';
      this.loadImportPage(session, imageUris, errorMessage);
    } catch (error) {
      const businessError = error as BusinessError;
      this.loadImportPage(session, [], '读取分享图片失败：' + businessError.message);
    }
  }

  private loadImportPage(session: UIExtensionContentSession, imageUris: string[], errorMessage: string): void {
    indexStorage.setOrCreate('shareImportMode', true);
    indexStorage.setOrCreate('sharedImageUris', imageUris);
    indexStorage.setOrCreate('shareImportError', errorMessage);
    session.loadContent('pages/Index', indexStorage);
  }
}
