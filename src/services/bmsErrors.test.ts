import { describe, expect, it } from 'vitest';
import { BmsRequestError, getBmsConnectionErrorMessage } from '@/services/bmsErrors';

describe('BMS connection error messages', () => {
  it('identifies a failed BMS tunnel', () => {
    const error = new BmsRequestError('api', 'http', 'bad gateway', 502);
    expect(getBmsConnectionErrorMessage(error)).toContain('HTTP 502');
    expect(getBmsConnectionErrorMessage(error)).toContain('tunnel');
  });

  it('identifies a CORS or network failure', () => {
    const error = new BmsRequestError('api', 'network', 'fetch failed');
    expect(getBmsConnectionErrorMessage(error)).toContain('CORS');
  });

  it('keeps PasteJSON failures separate from API failures', () => {
    const error = new BmsRequestError('session', 'http', 'not found', 404);
    expect(getBmsConnectionErrorMessage(error)).toContain('BMS session');
    expect(getBmsConnectionErrorMessage(error)).not.toContain('BMS API');
  });

  it('identifies a failed KPI data query separately from the handshake', () => {
    const error = new BmsRequestError('data', 'http', 'upstream failure', 501);
    expect(getBmsConnectionErrorMessage(error)).toContain('ข้อมูล THIP KPI');
    expect(getBmsConnectionErrorMessage(error)).toContain('upstream /api/sql');
  });

  it('explains an expired BMS session with a 401-specific message', () => {
    const error = new BmsRequestError('data', 'http', 'unauthorized', 401);
    expect(getBmsConnectionErrorMessage(error)).toContain('401');
    expect(getBmsConnectionErrorMessage(error)).toContain('BMS launcher');
  });

  it('explains a timed-out query differently from a network failure', () => {
    const error = new BmsRequestError('api', 'timeout', 'request timed out');
    expect(getBmsConnectionErrorMessage(error)).toContain('หมดเวลา');
    expect(getBmsConnectionErrorMessage(error)).not.toContain('CORS');
  });

  it('explains the production source-view gate', () => {
    const error = new BmsRequestError('data', 'config', 'source view is required');
    expect(getBmsConnectionErrorMessage(error)).toContain('source view');
    expect(getBmsConnectionErrorMessage(error)).toContain('232');
  });

  it('explains incomplete source-view coverage instead of hiding the audit failure', () => {
    const error = new BmsRequestError(
      'data',
      'response',
      'Normalized THIP source view thip_kpi_monthly is incomplete: 1/1552 reporting cells and 1/232 indicators were returned',
    );
    expect(getBmsConnectionErrorMessage(error)).toContain('1,552');
    expect(getBmsConnectionErrorMessage(error)).toContain('missing');
  });

  it('explains an empty configured source view', () => {
    const error = new BmsRequestError(
      'data',
      'response',
      'Configured THIP source view thip_kpi_monthly returned no rows',
    );
    expect(getBmsConnectionErrorMessage(error)).toContain('1,552');
  });
});
