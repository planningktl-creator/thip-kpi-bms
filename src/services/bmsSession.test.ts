import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { clearInMemoryLaunchContext, connectBmsSession, getLaunchContext, stripLaunchCredentialsFromUrl } from '@/services/bmsSession';

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
    clearInMemoryLaunchContext();
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

  it('reports an idle connection when no session id is present', async () => {
    const result = await connectBmsSession();
    expect(result.connection.status).toBe('idle');
    expect(result.runtime).toBeUndefined();
  });

  it('accepts and strips the sessionId launcher alias while preserving view state', () => {
    setUrl('?sessionId=alias&view=validation&fy=2026');
    expect(getLaunchContext().sessionId).toBe('alias');
    stripLaunchCredentialsFromUrl(); applyUrlUpdate();
    expect(window.location.search).toBe('?view=validation&fy=2026');
  });

  it('connects a manually supplied session without putting credentials in the URL', async () => {
    setUrl('?view=validation&fy=2026');
    const fetchMock = vi.fn((url: string | URL | Request) => Promise.resolve(new Response(JSON.stringify(String(url).includes('PasteJSON') ? pasteJsonPayload : { result: [{ version: 'PostgreSQL 16' }] }), { status: 200 })));
    vi.stubGlobal('fetch', fetchMock);
    const result = await connectBmsSession(' TEST_MANUAL ');
    expect(result.connection.status).toBe('connected');
    expect(result.runtime?.apiUrl).toBe('https://bms.test');
    expect(String(fetchMock.mock.calls[0][0])).toContain('code=TEST_MANUAL');
    expect(window.location.search).toBe('?view=validation&fy=2026');
  });

  it('refuses credential-bearing or remote HTTP API URLs before any SQL request', async () => {
    for (const url of ['https://name:password@synthetic.invalid', 'http://synthetic.invalid', 'https://synthetic.invalid?token=TEST_ONLY', 'https://synthetic.invalid#secret']) {
      const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ result: { user_info: { ...pasteJsonPayload.result.user_info, bms_url: url } } }), { status: 200 }));
      vi.stubGlobal('fetch', fetchMock);
      expect((await connectBmsSession('TEST_MANUAL')).connection.status).toBe('error');
      expect(fetchMock).toHaveBeenCalledTimes(1);
    }
  });

  it('clears rejected capabilities from PasteJSON MessageCode even with HTTP 200', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ MessageCode: '401' }), { status: 200 })));
    expect((await connectBmsSession('TEST_ONLY')).connection.status).toBe('error');
    expect(getLaunchContext().sessionId).toBeNull();
  });

  it('does not accept a PostgreSQL declaration if VERSION proves a different database', async () => {
    vi.stubGlobal('fetch', vi.fn((url: string | URL | Request) => Promise.resolve(new Response(JSON.stringify(String(url).includes('PasteJSON') ? pasteJsonPayload : { result: [{ version: 'MySQL 8' }] }), { status: 200 }))));
    expect((await connectBmsSession('TEST_ONLY')).connection.status).toBe('unsupported');
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

  it('keeps a transiently failed launcher capability in memory for retry', async () => {
    setUrl('?bms-session-id=transient-session&marketplace-token=marketplace');
    let pasteAttempts = 0;
    vi.stubGlobal('fetch', vi.fn((url: string | URL | Request) => {
      const href = String(url);
      if (href.includes('PasteJSON')) {
        pasteAttempts += 1;
        if (pasteAttempts === 1) return Promise.reject(new TypeError('network unavailable'));
        return Promise.resolve(new Response(JSON.stringify(pasteJsonPayload), { status: 200 }));
      }
      return Promise.resolve(new Response(JSON.stringify({ data: [{ version: 'PostgreSQL 16.2' }] }), { status: 200 }));
    }));

    const first = await connectBmsSession();
    applyUrlUpdate();
    expect(first.connection.status).toBe('error');
    expect(window.location.search).toBe('');
    expect(getLaunchContext()).toEqual({ sessionId: 'transient-session', marketplaceToken: 'marketplace' });

    const second = await connectBmsSession();
    expect(second.connection.status).toBe('connected');
    expect(pasteAttempts).toBe(2);
  });

  it('forgets the in-memory capability after an explicit session rejection', async () => {
    setUrl('?bms-session-id=expired-session');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('expired', { status: 401 })));

    const result = await connectBmsSession();
    applyUrlUpdate();
    expect(result.connection.status).toBe('error');
    expect(getLaunchContext()).toEqual({ sessionId: null, marketplaceToken: null });
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
