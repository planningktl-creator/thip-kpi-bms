export type BmsRequestPhase = 'session' | 'api' | 'data';
export type BmsRequestFailure = 'network' | 'http' | 'response' | 'message';

export class BmsRequestError extends Error {
  constructor(
    public readonly phase: BmsRequestPhase,
    public readonly failure: BmsRequestFailure,
    message: string,
    public readonly status?: number,
    options?: ErrorOptions,
  ) {
    super(message, options);
    this.name = 'BmsRequestError';
  }
}

export function getBmsConnectionErrorMessage(error: unknown): string {
  if (!(error instanceof BmsRequestError)) {
    return 'เชื่อมต่อ BMS ไม่สำเร็จ · ตรวจสอบ session, CORS และ tunnel';
  }

  if (error.phase === 'session') {
    if (error.failure === 'http' && error.status) {
      return `อ่าน BMS session ไม่สำเร็จ (HTTP ${error.status})`;
    }
    return 'อ่าน BMS session ไม่ได้ · ตรวจสอบ PasteJSON และ CORS';
  }

  if (error.phase === 'data') {
    if (error.failure === 'http' && error.status && error.status >= 500) {
      return `อ่านข้อมูล THIP KPI ไม่ได้ (HTTP ${error.status}) · ตรวจสอบ tunnel และ upstream /api/sql`;
    }
    if (error.failure === 'message') {
      return 'ยังอ่านข้อมูล THIP KPI ไม่ได้ · ตรวจสอบ source view และสิทธิ์ read-only';
    }
    if (error.failure === 'response') {
      return 'ข้อมูล THIP KPI จาก BMS มีรูปแบบไม่ถูกต้อง · ตรวจสอบ source view';
    }
    return 'อ่านข้อมูล THIP KPI ไม่ได้ · ตรวจสอบ source view, CORS และ tunnel';
  }

  if (error.failure === 'http' && error.status && error.status >= 500) {
    return `BMS API ไม่พร้อม (HTTP ${error.status}) · ตรวจสอบ tunnel และ upstream /api/sql`;
  }
  if (error.failure === 'http' && error.status) {
    return `BMS API ปฏิเสธคำขอ (HTTP ${error.status}) · ตรวจสอบสิทธิ์และ app identifier`;
  }
  if (error.failure === 'message') {
    return 'BMS API ไม่อนุญาต query นี้ · ตรวจสอบ app identifier และสิทธิ์ read-only';
  }
  if (error.failure === 'response') {
    return 'BMS API ส่ง response ที่อ่านไม่ได้ · ตรวจสอบ gateway และ /api/sql';
  }
  return 'เชื่อมต่อ BMS API ไม่ได้ · ตรวจสอบ CORS และ tunnel';
}
