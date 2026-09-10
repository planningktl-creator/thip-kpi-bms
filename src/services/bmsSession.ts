import { executeRegisteredQuery, queryRegistry } from '@/services/queryRegistry';
import { BmsRequestError, getBmsConnectionErrorMessage } from '@/services/bmsErrors';
import type { BmsConnection } from '@/types/thip';

const appIdentifier = import.meta.env.VITE_BMS_APP_IDENTIFIER || 'THIP.KPI.BMS';
const pasteJsonUrl = 'https://hosxp.net/phapi/PasteJSON';

type RawSession = {
  result?: {
    user_info?: {
      name?: string;
      hospital_code?: string;
      bms_url?: string;
      bms_session_code?: string;
      bms_database_type?: string;
    };
    key_value?: string;
  };
};

export type BmsRuntimeConfig = {
  apiUrl: string;
  bearerToken: string;
  appIdentifier: string;
  marketplaceToken?: string;
  hospitalCode?: string;
  userName?: string;
};

export function getLaunchContext(): {
  sessionId: string | null;
  marketplaceToken: string | null;
} {
  const params = new URLSearchParams(window.location.search);
  return {
    sessionId: params.get('bms-session-id'),
    marketplaceToken: params.get('marketplace-token') ?? params.get('marketplace_token'),
  };
}

async function retrieveSession(sessionId: string): Promise<RawSession> {
  let response: Response;
  try {
    response = await fetch(`${pasteJsonUrl}?Action=GET&code=${encodeURIComponent(sessionId)}`);
  } catch (error) {
    throw new BmsRequestError('session', 'network', 'PasteJSON request failed', undefined, { cause: error });
  }
  if (!response.ok) {
    throw new BmsRequestError('session', 'http', `PasteJSON returned HTTP ${response.status}`, response.status);
  }
  try {
    return (await response.json()) as RawSession;
  } catch (error) {
    throw new BmsRequestError('session', 'response', 'PasteJSON returned invalid JSON', response.status, { cause: error });
  }
}

export async function connectBmsSession(): Promise<{
  connection: BmsConnection;
  runtime?: BmsRuntimeConfig;
}> {
  const { sessionId, marketplaceToken } = getLaunchContext();
  if (!sessionId) {
    return { connection: { status: 'demo', message: 'ยังไม่ได้เปิดจาก BMS launcher' } };
  }

  try {
    const raw = await retrieveSession(sessionId);
    const info = raw.result?.user_info;
    const apiUrl = info?.bms_url?.trim();
    const bearerToken = info?.bms_session_code || raw.result?.key_value;
    if (!apiUrl || !bearerToken) throw new Error('BMS session ไม่มี endpoint หรือ bearer token');

    const runtime: BmsRuntimeConfig = {
      apiUrl,
      bearerToken,
      appIdentifier,
      marketplaceToken: marketplaceToken ?? undefined,
      hospitalCode: info?.hospital_code,
      userName: info?.name,
    };
    const probe = await executeRegisteredQuery(queryRegistry.versionProbe, runtime, undefined, marketplaceToken ?? undefined);
    const version = String((probe.data?.[0] ?? probe.result?.[0])?.version ?? '');
    const databaseType = /postgres/i.test(version) || /postgres/i.test(info?.bms_database_type ?? '')
      ? 'PostgreSQL'
      : info?.bms_database_type || 'ไม่ทราบชนิดฐานข้อมูล';

    return {
      runtime,
      connection: {
        status: databaseType === 'PostgreSQL' ? 'connected' : 'unsupported',
        hospitalCode: info?.hospital_code,
        userName: info?.name,
        apiUrl,
        databaseType,
        message: databaseType === 'PostgreSQL'
          ? 'เชื่อมต่อ BMS สำเร็จ · ตรวจสอบสิทธิ์ query แบบ read-only แล้ว'
          : 'เชื่อมต่อแล้ว แต่ต้องใช้ PostgreSQL สำหรับ query foundation นี้',
      },
    };
  } catch (error) {
    return {
      connection: {
        status: 'error',
        message: getBmsConnectionErrorMessage(error),
      },
    };
  }
}
