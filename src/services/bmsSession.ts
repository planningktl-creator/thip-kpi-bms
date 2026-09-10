import { executeRegisteredQuery, queryRegistry } from '@/services/queryRegistry';
import { BmsRequestError, getBmsConnectionErrorMessage } from '@/services/bmsErrors';
import type { BmsConnection } from '@/types/thip';

const appIdentifier = import.meta.env.VITE_BMS_APP_IDENTIFIER || 'THIP.KPI.BMS';
const pasteJsonUrl = 'https://hosxp.net/phapi/PasteJSON';
const SESSION_TIMEOUT_MS = 15_000;

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

/**
 * Removes launch credentials from the address bar once the PasteJSON round-trip
 * has completed, so the session id and marketplace token do not persist in
 * browser history, screenshots, or copy-pasted links. View state params
 * (`view`, `indicator`) are preserved.
 */
export function stripLaunchCredentialsFromUrl(): void {
  const params = new URLSearchParams(window.location.search);
  if (!params.has('bms-session-id') && !params.has('marketplace-token') && !params.has('marketplace_token')) {
    return;
  }
  params.delete('bms-session-id');
  params.delete('marketplace-token');
  params.delete('marketplace_token');
  const query = params.toString();
  window.history.replaceState({}, '', `${window.location.pathname}${query ? `?${query}` : ''}`);
}

async function retrieveSession(sessionId: string): Promise<RawSession> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), SESSION_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch(`${pasteJsonUrl}?Action=GET&code=${encodeURIComponent(sessionId)}`, { signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) {
      throw new BmsRequestError('session', 'timeout', `PasteJSON request timed out after ${SESSION_TIMEOUT_MS} ms`, undefined, { cause: error });
    }
    throw new BmsRequestError('session', 'network', 'PasteJSON request failed', undefined, { cause: error });
  } finally {
    clearTimeout(timer);
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
    // The session id is a bearer capability for PasteJSON; drop it from the
    // address bar as soon as the handshake succeeds (or fails) so it does not
    // linger in history or shared links.
    stripLaunchCredentialsFromUrl();
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
    // Also strip credentials on a failed handshake — the session id is no
    // longer useful once PasteJSON rejected it.
    stripLaunchCredentialsFromUrl();
    return {
      connection: {
        status: 'error',
        message: getBmsConnectionErrorMessage(error),
      },
    };
  }
}
