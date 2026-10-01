import { abortable } from './abortable';
import { executeRegisteredQuery, versionProbe } from '@/services/queryTransport';
import { BmsRequestError, getBmsConnectionErrorMessage } from '@/services/bmsErrors';
import type { BmsConnection } from '@/types/thip';

const appIdentifier = import.meta.env.VITE_BMS_APP_IDENTIFIER || 'THIP.KPI.BMS';
const pasteJsonUrl = 'https://hosxp.net/phapi/PasteJSON';
const SESSION_TIMEOUT_MS = 15_000;

type LaunchContext = {
  sessionId: string;
  marketplaceToken: string | null;
};

// The launcher URL is a bearer-capability transport, not durable application
// state. Keep it only in this module's memory after removing it from the URL so
// a transient network/CORS failure can be retried without exposing credentials
// in browser history, screenshots, or copied links.
let inMemoryLaunchContext: LaunchContext | null = null;

type RawSession = {
  MessageCode?: number | string;
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
  const urlSessionId = params.get('bms-session-id') ?? params.get('sessionId');
  const urlMarketplaceToken = params.get('marketplace-token') ?? params.get('marketplace_token');
  if (urlSessionId) {
    return { sessionId: urlSessionId, marketplaceToken: urlMarketplaceToken };
  }
  return {
    sessionId: inMemoryLaunchContext?.sessionId ?? null,
    marketplaceToken: inMemoryLaunchContext?.marketplaceToken ?? null,
  };
}

/**
 * Forget the in-memory launcher capability. The app uses this when BMS has
 * explicitly rejected the session; tests also use it to isolate browser runs.
 */
export function clearInMemoryLaunchContext(): void {
  inMemoryLaunchContext = null;
}

/**
 * Removes launch credentials from the address bar once the PasteJSON round-trip
 * has completed, so the session id and marketplace token do not persist in
 * browser history, screenshots, or copy-pasted links. View state params
 * (`view`, `indicator`) are preserved.
 */
export function stripLaunchCredentialsFromUrl(): void {
  const params = new URLSearchParams(window.location.search);
  if (!params.has('bms-session-id') && !params.has('sessionId') && !params.has('marketplace-token') && !params.has('marketplace_token')) {
    return;
  }
  params.delete('bms-session-id');
  params.delete('sessionId');
  params.delete('marketplace-token');
  params.delete('marketplace_token');
  const query = params.toString();
  window.history.replaceState({}, '', `${window.location.pathname}${query ? `?${query}` : ''}`);
}

async function retrieveSession(sessionId: string, parentSignal?: AbortSignal): Promise<RawSession> {
  const controller = new AbortController();
  const cancel = () => controller.abort();
  if (parentSignal?.aborted) controller.abort(); else parentSignal?.addEventListener('abort', cancel, { once: true });
  const timer = setTimeout(() => controller.abort(), SESSION_TIMEOUT_MS);
  try {
    const response = await abortable(fetch(`${pasteJsonUrl}?Action=GET&code=${encodeURIComponent(sessionId)}`, { signal: controller.signal }), controller.signal);
    if (!response.ok) throw new BmsRequestError('session', 'http', `PasteJSON returned HTTP ${response.status}`, response.status);
    try { return (await abortable(response.json(), controller.signal)) as RawSession; }
    catch (error) {
      if (controller.signal.aborted) throw error;
      throw new BmsRequestError('session', 'response', 'PasteJSON returned invalid JSON', response.status, { cause: error });
    }
  } catch (error) {
    if (controller.signal.aborted) throw new BmsRequestError('session', 'timeout', `PasteJSON request timed out after ${SESSION_TIMEOUT_MS} ms`, undefined, { cause: error });
    if (error instanceof BmsRequestError) throw error;
    throw new BmsRequestError('session', 'network', 'PasteJSON request failed', undefined, { cause: error });
  } finally { clearTimeout(timer); parentSignal?.removeEventListener('abort', cancel); }
}

export async function connectBmsSession(manualSessionId?: string, signal?: AbortSignal): Promise<{
  connection: BmsConnection;
  runtime?: BmsRuntimeConfig;
}> {
  const launch = getLaunchContext();
  const sessionId = manualSessionId?.trim() || launch.sessionId;
  const marketplaceToken = manualSessionId && manualSessionId.trim() !== launch.sessionId ? null : launch.marketplaceToken;
  if (!sessionId) {
    return { connection: { status: 'idle', message: 'ยังไม่ได้เปิดจาก BMS launcher จึงยังไม่มีข้อมูลจริง' } };
  }

  inMemoryLaunchContext = { sessionId, marketplaceToken };
  // Remove credentials before making the network request. The capability stays
  // available only in memory for a retry during this page lifetime.
  stripLaunchCredentialsFromUrl();

  try {
    const raw = await retrieveSession(sessionId, signal);
    const messageCode = Number(raw.MessageCode);
    if (Number.isFinite(messageCode) && messageCode >= 400) throw new BmsRequestError('session', 'http', 'Session rejected', messageCode);
    const info = raw.result?.user_info;
    const rawApiUrl = info?.bms_url?.trim();
    const bearerToken = info?.bms_session_code || raw.result?.key_value;
    if (!rawApiUrl || !bearerToken) throw new Error('BMS session ไม่มี endpoint หรือ bearer token');
    const parsedUrl = new URL(rawApiUrl);
    const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(parsedUrl.hostname);
    if ((parsedUrl.protocol !== 'https:' && !(parsedUrl.protocol === 'http:' && loopback)) || parsedUrl.username || parsedUrl.password || parsedUrl.search || parsedUrl.hash) throw new Error('Invalid BMS URL');
    const apiUrl = parsedUrl.toString().replace(/\/+$/, '');

    const runtime: BmsRuntimeConfig = {
      apiUrl,
      bearerToken,
      appIdentifier,
      marketplaceToken: marketplaceToken ?? undefined,
      hospitalCode: info?.hospital_code,
      userName: info?.name,
    };
    const probe = await executeRegisteredQuery(versionProbe, runtime, undefined, marketplaceToken ?? undefined, { signal });
    const version = String((probe.data?.[0] ?? probe.result?.[0])?.version ?? '');
    const databaseType = /postgres/i.test(version)
      ? 'PostgreSQL'
      : /mysql/i.test(version) ? 'MySQL' : version ? 'ฐานข้อมูลที่ยังไม่รองรับ' : 'ไม่ทราบชนิดฐานข้อมูล';

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
    if (isExpiredOrRejectedSession(error)) {
      clearInMemoryLaunchContext();
    }
    return {
      connection: {
        status: 'error',
        message: getBmsConnectionErrorMessage(error),
      },
    };
  }
}

function isExpiredOrRejectedSession(error: unknown): boolean {
  if (error instanceof BmsRequestError) {
    if (error.messageCode === 401 || error.messageCode === 403) return true;
    if (error.phase === 'session' && error.failure === 'http') {
      return [401, 403, 404].includes(error.status ?? 0);
    }
    if (error.phase === 'session' && error.failure === 'response') return true;
    if (error.phase === 'api' && error.failure === 'http') {
      return [401, 403].includes(error.status ?? 0);
    }
  }
  // A successful PasteJSON response without usable connection fields is not a
  // retryable transport failure; it is a malformed/expired launch payload.
  return error instanceof Error && error.message.includes('BMS session ไม่มี endpoint หรือ bearer token');
}
