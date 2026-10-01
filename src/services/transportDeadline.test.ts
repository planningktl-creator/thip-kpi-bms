import { afterEach, expect, it, vi } from 'vitest';
import { executeRegisteredQuery, queryRegistry } from './queryRegistry';
import { connectBmsSession, clearInMemoryLaunchContext } from './bmsSession';
afterEach(() => { vi.unstubAllGlobals(); vi.useRealTimers(); clearInMemoryLaunchContext(); });
it('times out a response body after successful HTTP headers', async () => {
  vi.useFakeTimers();
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 200, text: () => new Promise(() => {}) }));
  const request = executeRegisteredQuery(queryRegistry.versionProbe, { apiUrl:'https://synthetic.test',bearerToken:'synthetic',appIdentifier:'test' },undefined,undefined,{timeoutMs:50});
  const assertion = expect(request).rejects.toMatchObject({ failure:'timeout' });
  await vi.advanceTimersByTimeAsync(51); await assertion;
});
it('aborts an unfinished response body when the selected year changes', async () => {
  vi.stubGlobal('fetch', vi.fn().mockResolvedValue({ ok: true, status: 200, text: () => new Promise(() => {}) }));
  const controller = new AbortController();
  const request = executeRegisteredQuery(queryRegistry.versionProbe,{apiUrl:'https://synthetic.test',bearerToken:'synthetic',appIdentifier:'test'},undefined,undefined,{signal:controller.signal});
  const assertion = expect(request).rejects.toMatchObject({ failure:'timeout' });
  await Promise.resolve(); controller.abort(); await assertion;
});
it('keeps the PasteJSON deadline active through the response body', async () => {
  vi.useFakeTimers();
  vi.stubGlobal('window',{location:{search:'?bms-session-id=synthetic-deadline',pathname:'/'},history:{replaceState:vi.fn()}});
  vi.stubGlobal('fetch',vi.fn().mockResolvedValue({ok:true,status:200,json:()=>new Promise(()=>{})}));
  const request = connectBmsSession(); await vi.advanceTimersByTimeAsync(15001);
  expect((await request).connection).toMatchObject({status:'error'});
  expect((await request).connection.message).toContain('หมดเวลา');
});
