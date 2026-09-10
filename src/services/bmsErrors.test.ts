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
});
