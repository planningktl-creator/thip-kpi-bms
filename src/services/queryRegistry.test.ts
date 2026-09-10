import { describe, expect, it } from 'vitest';
import { assertRegisteredReadOnlyQuery, queryRegistry } from '@/services/queryRegistry';

describe('BMS query registry', () => {
  it('accepts the registered read-only probes', () => {
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.versionProbe)).not.toThrow();
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.ipdMonthlyFoundation)).not.toThrow();
  });

  it('rejects write statements even if someone adds one to a query object', () => {
    expect(() => assertRegisteredReadOnlyQuery({
      key: 'bad',
      description: 'test',
      sql: 'UPDATE ipt SET drg = :drg',
    })).toThrow(/read-only/);
  });
});
