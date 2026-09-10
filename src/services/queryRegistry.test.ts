import { describe, expect, it } from 'vitest';
import { assertRegisteredReadOnlyQuery, queryRegistry } from '@/services/queryRegistry';

describe('BMS query registry', () => {
  it('accepts the registered read-only probes', () => {
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.versionProbe)).not.toThrow();
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.ipdMonthlyFoundation)).not.toThrow();
    expect(() => assertRegisteredReadOnlyQuery(queryRegistry.thipIpdFoundation)).not.toThrow();
    expect(queryRegistry.thipIpdFoundation.sql).toContain('has_acs_sdx');
    expect(queryRegistry.thipIpdFoundation.sql).toContain('died_from_acs');
    expect(queryRegistry.thipIpdFoundation.sql).toContain('has_sepsis_diag');
    expect(queryRegistry.thipIpdFoundation.sql).toContain('CE0101');
    expect(queryRegistry.thipIpdFoundation.sql).toContain('CI0101');
    expect(queryRegistry.thipIpdFoundation.sql).toContain('DH0102');
  });

  it('rejects write statements even if someone adds one to a query object', () => {
    expect(() => assertRegisteredReadOnlyQuery({
      key: 'bad',
      description: 'test',
      sql: 'UPDATE ipt SET drg = :drg',
    })).toThrow(/read-only/);
  });
});
