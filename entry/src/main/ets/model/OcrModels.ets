import type { DraftEntry } from './LedgerModels';

export interface OcrLine {
  text: string;
  left: number;
  top: number;
  right: number;
  bottom: number;
  centerY: number;
  height: number;
}

export interface OcrRecognizedPage {
  pageNumber: number;
  lines: OcrLine[];
  rawText: string;
  captureTime?: number;
}

export interface OcrRecognitionResult {
  pages: OcrRecognizedPage[];
}

export interface UnclassifiedOcrPage {
  pageNumber: number;
  lines: OcrLine[];
  captureTime?: number;
}

export interface OcrImportResult {
  drafts: DraftEntry[];
  rawText: string;
  unclassifiedPages: UnclassifiedOcrPage[];
}

export interface DraftValidationError {
  id: string;
  message: string;
}
