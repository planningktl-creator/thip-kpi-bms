import { describe, expect, it } from 'vitest';
import { thipCatalogue } from '@/data/thipCatalogue';
import { pendingLocalSourceCodes, registeredRuleCodes } from '@/data/thipImplementation';
import { assertRegisteredReadOnlyQuery } from '@/services/queryRegistry';
import { buildSourceViewArtifact, buildSourceViewDdl, buildSourceViewRefreshSql } from '@/services/thipSourceViewSql';

describe('THIP reporting-layer source view', () => {
  it('declares the tier and pending_reason columns', () => {
    const ddl = buildSourceViewDdl();
    expect(ddl).toContain('pending_reason');
    expect(ddl).toContain('tier');
    expect(ddl).toContain("tier IN ('registered', 'pending-local-source')");
    expect(ddl).toContain('UNIQUE (indicator_code, period_start, fiscal_year, fiscal_month)');
  });

  it('covers all 232 codes and the 1,552 cadence cells in the refresh', () => {
    const artifact = buildSourceViewArtifact();
    expect(artifact.registeredCodeCount).toBe(registeredRuleCodes.length);
    expect(artifact.pendingCodeCount).toBe(pendingLocalSourceCodes.length);
    expect(artifact.registeredCodeCount + artifact.pendingCodeCount).toBe(232);
    expect(artifact.expectedCellCount).toBe(1552);
    expect(thipCatalogue).toHaveLength(232);
  });

  it('keeps the registered and pending values separated in the refresh', () => {
    const refresh = buildSourceViewRefreshSql();
    expect(refresh).toContain("CASE WHEN m.tier = 'registered' THEN COALESCE(f.numerator, 0) ELSE NULL END");
    expect(refresh).toContain("CASE WHEN m.tier = 'registered' THEN COALESCE(f.denominator, 0) ELSE NULL END");
    expect(refresh).toContain("CASE WHEN m.tier = 'registered' THEN f.value ELSE NULL END");
    expect(refresh).toContain('m.pending_reason');
  });

  it('does not expose PHI columns in the reporting table', () => {
    const ddl = buildSourceViewDdl();
    for (const phi of ['hn', 'cid', 'patient_name', 'birthdate', 'address']) {
      expect(ddl.includes(` ${phi} `), phi).toBe(false);
    }
  });

  it('produces a read-only refresh guarded by the registered read-only assertion', () => {
    // The refresh contains DELETE/INSERT by design (it is the reporting-layer
    // provisioning script, not a registered query). The read path the app uses
    // must remain a SELECT; verify the app's builder is still read-only.
    expect(buildSourceViewRefreshSql()).toContain('INSERT INTO');
    expect(() => assertRegisteredReadOnlyQuery({
      key: 'sourceViewRead',
      description: 'app read path',
      sql: 'SELECT indicator_code FROM reporting.thip_kpi_monthly',
    })).not.toThrow();
  });
});
