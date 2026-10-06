export function parseAmountFen(value: string): number | undefined {
  const raw = value.trim().replace(/[¥￥\s]|元/g, '');
  if (!/^\d+(?:[.,]\d+)*$/.test(raw)) {
    return undefined;
  }
  const lastSeparator = Math.max(raw.lastIndexOf('.'), raw.lastIndexOf(','));
  const fraction = lastSeparator >= 0 ? raw.slice(lastSeparator + 1) : '';
  const hasDecimal = lastSeparator >= 0 && fraction.length > 0 && fraction.length <= 2;
  const yuanText = (hasDecimal ? raw.slice(0, lastSeparator) : raw).replace(/[.,]/g, '');
  const yuan = Number(yuanText);
  const fen = hasDecimal ? Number((fraction + '00').slice(0, 2)) : 0;
  if (!Number.isFinite(yuan) || !Number.isFinite(fen) || yuan < 0) {
    return undefined;
  }
  return yuan * 100 + fen;
}
