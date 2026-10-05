import { ImportSource } from '../model/LedgerModels';

export class OcrSourceDetector {
  static detect(text: string): ImportSource | undefined {
    const normalized = text.replace(/\s/g, '').toLowerCase();
    let wechatScore = 0;
    let alipayScore = 0;
    let icbcScore = 0;

    if (/微信支付|微信账单|微信钱包/.test(normalized)) {
      wechatScore += 6;
    }
    if (/全部账单|收支统计|查找交易/.test(normalized)) {
      wechatScore += 2;
    }
    if (/全部账单/.test(normalized) && /收支统计/.test(normalized) && /查找交易/.test(normalized)) {
      wechatScore += 4;
    }
    if (/支付宝/.test(normalized)) {
      alipayScore += 7;
    }
    if (/搜索交易记录/.test(normalized)) {
      alipayScore += 5;
    }
    if (/芝麻|花呗|余额宝/.test(normalized)) {
      alipayScore += 2;
    }
    if (/中国工商银行/.test(normalized)) {
      icbcScore += 7;
    }
    if (/工商银行|工银借记卡|工银信用卡/.test(normalized)) {
      icbcScore += 5;
    }
    if (/当页汇总笔数|人民币余额|借记卡\(i类\)/.test(normalized)) {
      icbcScore += 3;
    }

    const scores: number[] = [wechatScore, alipayScore, icbcScore];
    let bestIndex = 0;
    let bestScore = scores[0];
    let secondScore = 0;
    for (let index = 1; index < scores.length; index++) {
      if (scores[index] > bestScore) {
        secondScore = bestScore;
        bestScore = scores[index];
        bestIndex = index;
      } else if (scores[index] > secondScore) {
        secondScore = scores[index];
      }
    }
    if (bestScore < 4 || bestScore - secondScore < 2) {
      return undefined;
    }
    if (bestIndex === 0) {
      return 'wechat';
    }
    return bestIndex === 1 ? 'alipay' : 'icbc';
  }
}
