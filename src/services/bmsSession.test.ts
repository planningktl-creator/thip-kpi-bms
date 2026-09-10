import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { connectBmsSession, getLaunchContext, stripLaunchCredentialsFromUrl } from '@/services/bmsSession';

const pasteJsonPayload = {
  result: {
    user_info: {
      name: 'Smoke Tester',
      hospital_code: '10729',
      bms_url: 'https://bms.test/',
      bms_session_code: 'bearer-token-123',
      bms_database_type: 'PostgreSQL',
    },
  },
};

function setUrl(search: string): void {
  (window.location as { search: string }).search = search;
}

function applyUrlUpdate(): void {
  const replaceState = vi.mocked(window.history.replaceState);
  const call = replaceState.mock.calls[replaceState.mock.calls.length - 1];
  const url = call?.[2];
  if (typeof url === 'string') {
    const queryIndex = url.indexOf('?');
    (window.location as { search: string }).search = queryIndex >= 0 ? url.slice(queryIndex) : '';
  }
}

describe('BMS launch context', () => {
  beforeEach(() => {
    vi.stubGlobal('window', {
      history: {
        replaceState: vi.fn(),
      },
      location: {
        pathname: '/',
        search: '',
      },
    });
  });

  afterEach(() => {
    setUrl('');
    vi.unstubAllGlobals();
  });

  it('reads the launcher session id and marketplace token from the URL', () => {
    setUrl('?bms-session-id=abc&marketplace-token=xyz&view=detail&indicator=DH0101');
    expect(getLaunchContext()).toEqual({ sessionId: 'abc', marketplaceToken: 'xyz' });
  });

  it('accepts the snake_case marketplace token variant', () => {
    setUrl('?bms-session-id=abc&marketplace_token=xyz');
    expect(getLaunchContext().marketplaceToken).toBe('xyz');
  });

  it('strips launch credentials while preserving view state params', () => {
    setUrl('?bms-session-id=abc&marketplace-token=xyz&view=detail&indicator=DH0101');
    stripLaunchCredentialsFromUrl();
    applyUrlUpdate();
    const params = new URLSearchParams(window.location.search);
    expect(params.has('bms-session-id')).toBe(false);
    expect(params.has('marketplace-token')).toBe(false);
    expect(params.get('view')).toBe('detail');
    expect(params.get('indicator')).toBe('DH0101');
  });

  it('leaves the URL untouched when no credentials are present', () => {
    setUrl('?view=catalog');
    stripLaunchCredentialsFromUrl();
    expect(window.location.search).toBe('?view=catalog');
  });

  it('reports a demo connection when no session id is present', async () => {
    const result = await connectBmsSession();
    expect(result.connection.status).toBe('demo');
    expect(result.runtime).toBeUndefined();
  });

  it('connects through PasteJSON and probes the database type', async () => {
    setUrl('?bms-session-id=abc');
    vi.stubGlobal('fetch', vi.fn((url: string | URL | Request) => {
      const href = String(url);
      if (href.includes('PasteJSON')) {
        return Promise.resolve(new Response(JSON.stringify(pasteJsonPayload), { status: 200 }));
      }
      return Promise.resolve(new Response(JSON.stringify({ data: [{ version: 'PostgreSQL 16.2' }] }), { status: 200 }));
    }));

    const result = await connectBmsSession();
    applyUrlUpdate();
    expect(result.connection.status).toBe('connected');
    expect(result.connection.databaseType).toBe('PostgreSQL');
    expect(result.runtime?.bearerToken).toBe('bearer-token-123');
    // Credentials must be gone from the address bar after the handshake.
    expect(window.location.search).toBe('');
  });

  it('maps a PasteJSON HTTP failure to a session error', async () => {
    setUrl('?bms-session-id=abc');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('not found', { status: 404 })));

    const result = await connectBmsSession();
    expect(result.connection.status).toBe('error');
    expect(result.connection.message).toContain('BMS session');
  });

  it('refuses a non-PostgreSQL BMS database', async () => {
    setUrl('?bms-session-id=abc');
    vi.stubGlobal('fetch', vi.fn((url: string | URL | Request) => {
      const href = String(url);
      if (href.includes('PasteJSON')) {
        return Promise.resolve(new Response(JSON.stringify({
          result: { user_info: { ...pasteJsonPayload.result.user_info, bms_database_type: 'SQL Server' } },
        }), { status: 200 }));
      }
      return Promise.resolve(new Response(JSON.stringify({ data: [{ version: 'Microsoft SQL Server 2019' }] }), { status: 200 }));
    }));

    const result = await connectBmsSession();
    expect(result.connection.status).toBe('unsupported');
  });
});