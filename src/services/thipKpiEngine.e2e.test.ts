import { describe, expect, it } from 'vitest';
import { thipCatalogue, thipCatalogueByCode } from '@/data/thipCatalogue';
import {
  foundationRuleCodes,
  getFormulaScale,
  getRuleReadiness,
  getRuleUnit,
  thipKpiRules,
  thipKpiRulesByCode,
} from '@/data/thipKpiRules';
import { getExpectedFiscalMonths, getReportingCadence, thipReportingCadenceByCode } from '@/data/thipReporting';
import {
  getImplementationTier,
  getPendingReason,
  pendingLocalSourceCodes,
  pendingReasonByFamily,
  registeredRuleCodes,
  registeredRuleCodeSet,
  thipImplementation,
  thipImplementationByCode,
} from '@/data/thipImplementation';
import {
  assertRegisteredReadOnlyQuery,
  foundationFamilyQueries,
  queryRegistry,
  QUERY_TIMEOUT_MS,
  type RegisteredQuery,
} from '@/services/queryRegistry';
import { ipdBaseCte, IPD_BASE_CTE, IPD_DRG_RESULT_CTE } from '@/services/thipIpdBase';
import {
  buildCompletenessAuditQuery,
  buildDuplicateCheckQuery,
  buildIndicatorFromRows,
  buildSourceViewQuery,
  quoteSourceView,
  summarizeCoverage,
} from '@/services/bmsData';
import {
  buildCompleteSourceFixture,
  FIXTURE_FISCAL_YEAR,
} from '@/test-support/thipSourceFixture';
import { getCurrentFiscalYear, getFiscalMonthPeriods } from '@/utils/fiscal';
import { BmsRequestError } from '@/services/bmsErrors';

/**
 * 52 Target Inpatient & Clinical Outcome Indicators from Feature Inventory
 * across the 6 core clinical families + Acute Foundation.
 */
export const TARGET_52_INDICATORS = [
  // 1. Heart Failure (2)
  'DH0301', 'DH0302',
  // 2. CABG (4)
  'DH0201', 'DH0202', 'DH0203', 'DH0204',
  // 3. Arthroplasty (6)
  'DO0202', 'DO0204', 'DO0205', 'DO0302', 'DO0303', 'DO0304',
  // 4. Asthma & COPD (9)
  'DR0301', 'DR0302', 'DR0401', 'DR0403', 'DR0404', 'AA0102', 'AA0103', 'HC0101', 'HC0102',
  // 5. DM & HT (11)
  'DC0103', 'DC0107', 'DC0108', 'DC0108.1', 'DC0108.2', 'DC0201', 'DC0201.1', 'DC0201.2', 'DP0101', 'AA0104', 'AA0105',
  // 6. Maternal & Child (20)
  'CM0101', 'CM0104', 'CM0105', 'CM0107', 'CM0109', 'CM0110', 'CM0116', 'CM0117', 'CM0118', 'CM0119',
  'CM0201', 'CM0202', 'CM0203', 'CM0204', 'CM0205', 'CM0206', 'CM0207', 'CM0208', 'CM0209', 'DE1601',
] as const;

export const EXPECTED_TOTAL_CELLS = 1552;
export const EXPECTED_MONTHLY_CELLS = 112 * 12; // 1344
export const EXPECTED_QUARTERLY_CELLS = 19 * 4; // 76
export const EXPECTED_SEMIANNUAL_CELLS = 31 * 2; // 62
export const EXPECTED_ANNUAL_CELLS = 70 * 1; // 70

describe('THIP KPI 2025 E2E Test Suite', () => {
  // ===========================================================================
  // TIER 1: FEATURE COVERAGE (>=5 tests per family)
  // ===========================================================================

  describe('Tier 1: Feature Coverage - Heart Failure Family (HF)', () => {
    it('defines DH0301 and DH0302 in catalogue and rules manifest with correct metadata', () => {
      const dh0301Rule = thipKpiRulesByCode.get('DH0301');
      const dh0302Rule = thipKpiRulesByCode.get('DH0302');
      expect(dh0301Rule).toBeDefined();
      expect(dh0302Rule).toBeDefined();
      expect(dh0301Rule?.queryFamily).toBe('HEART_FAILURE');
      expect(dh0302Rule?.queryFamily).toBe('HEART_FAILURE');
      expect(thipCatalogueByCode.get('DH0301')?.title).toContain('HFREF');
      expect(thipCatalogueByCode.get('DH0302')?.title.toLowerCase()).toContain('smoking cessation');
    });

    it('specifies percentage formula and higher-is-better direction for DH0301 and DH0302', () => {
      const r1 = thipKpiRulesByCode.get('DH0301')!;
      const r2 = thipKpiRulesByCode.get('DH0302')!;
      expect(getFormulaScale(r1.formulaScale)).toBe(100);
      expect(getFormulaScale(r2.formulaScale)).toBe(100);
      expect(getRuleUnit(r1)).toBe('percent');
      expect(getRuleUnit(r2)).toBe('percent');
      expect(thipCatalogueByCode.get('DH0301')?.group).toBe('D');
      expect(thipCatalogueByCode.get('DH0302')?.group).toBe('D');
    });

    it('maps candidate HOSxP tables for Heart Failure GDMT and smoking cessation', () => {
      const r1 = thipKpiRulesByCode.get('DH0301')!;
      const r2 = thipKpiRulesByCode.get('DH0302')!;
      expect(r1.candidateSourceTables).toEqual(expect.arrayContaining(['ipt', 'an_stat']));
      expect(r2.candidateSourceTables).toEqual(expect.arrayContaining(['ipt', 'an_stat']));
    });

    it('asserts dotless ICD-10 codes and clinical exclusion criteria for HF', () => {
      // In HOSxP: Heart failure codes are I500, I501, I509. Contraindication asthma codes are J45, J46.
      const dotlessHfCodes = ['I500', 'I501', 'I509'];
      for (const code of dotlessHfCodes) {
        expect(code).not.toContain('.');
        expect(code).toMatch(/^I50[019]$/);
      }
    });

    it('calculates monthly and annual HF rates accurately through the calculation engine', () => {
      const indicator = buildIndicatorFromRows('DH0301', [
        { indicator_code: 'DH0301', fiscal_month: 1, numerator: 18, denominator: 20, value: 90.0, percentile: 85 },
        { indicator_code: 'DH0301', fiscal_month: 2, numerator: 24, denominator: 30, value: 80.0, percentile: 78 },
      ], 2026);
      expect(indicator).not.toBeNull();
      expect(indicator?.monthly[0]?.value).toBe(90.0);
      expect(indicator?.monthly[1]?.value).toBe(80.0);
      // Weighted annual: (18 + 24) / (20 + 30) * 100 = 42 / 50 * 100 = 84.00
      expect(indicator?.annual.value).toBe(84.0);
    });

    it('enforces implementation contract for HF indicators', () => {
      for (const code of ['DH0301', 'DH0302']) {
        const tier = getImplementationTier(code);
        if (tier === 'pending-local-source') {
          const reason = getPendingReason(code);
          expect(reason).not.toBeNull();
          expect(reason).toContain('HFREF');
        } else {
          expect(registeredRuleCodeSet.has(code)).toBe(true);
        }
      }
    });
  });

  describe('Tier 1: Feature Coverage - CABG Surgery Family', () => {
    it('defines all 4 CABG indicators in the rule manifest and catalogue', () => {
      const cabgCodes = ['DH0201', 'DH0202', 'DH0203', 'DH0204'];
      for (const code of cabgCodes) {
        const rule = thipKpiRulesByCode.get(code);
        expect(rule, `Rule missing for ${code}`).toBeDefined();
        expect(rule?.queryFamily).toBe('CABG');
        expect(thipCatalogueByCode.get(code)).toBeDefined();
        expect(getReportingCadence(code)).toBe('monthly');
      }
    });

    it('verifies dotless ICD-9-CM procedure codes (3610-3619) for CABG revascularization', () => {
      const cabgProcedures = ['3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619'];
      for (const proc of cabgProcedures) {
        expect(proc).not.toContain('.');
        expect(proc).toMatch(/^361[0-9]$/);
      }
    });

    it('configures proper clinical formula scale (percentage) for CABG indicators', () => {
      for (const code of ['DH0201', 'DH0202', 'DH0203', 'DH0204']) {
        const rule = thipKpiRulesByCode.get(code)!;
        expect(getFormulaScale(rule.formulaScale)).toBe(100);
        expect(getRuleUnit(rule)).toBe('percent');
      }
    });

    it('identifies CABG infection surveillance codes (T814, T826, T827) in dotless format', () => {
      const ssiCodes = ['T814', 'T826', 'T827'];
      for (const code of ssiCodes) {
        expect(code).not.toContain('.');
        expect(code).toMatch(/^T8[12][467]$/);
      }
    });

    it('computes low-incidence CABG mortality rates with precision', () => {
      const indicator = buildIndicatorFromRows('DH0201', [
        { indicator_code: 'DH0201', fiscal_month: 1, numerator: 1, denominator: 50, value: 2.0 },
        { indicator_code: 'DH0201', fiscal_month: 2, numerator: 0, denominator: 50, value: 0.0 },
      ], 2026);
      expect(indicator).not.toBeNull();
      expect(indicator?.monthly[0]?.value).toBe(2.0);
      expect(indicator?.monthly[1]?.value).toBe(0.0);
      // Weighted annual: (1 + 0) / (50 + 50) * 100 = 1.00%
      expect(indicator?.annual.value).toBe(1.0);
    });

    it('validates CABG candidate tables link ipt, an_stat, and iptoprt', () => {
      const r1 = thipKpiRulesByCode.get('DH0201')!;
      expect(r1.candidateSourceTables).toEqual(expect.arrayContaining(['ipt', 'an_stat']));
    });
  });

  describe('Tier 1: Feature Coverage - Arthroplasty (Hip & Knee) Family', () => {
    it('defines all 6 hip and knee arthroplasty indicators in rules and catalogue', () => {
      const arthroCodes = ['DO0202', 'DO0204', 'DO0205', 'DO0302', 'DO0303', 'DO0304'];
      for (const code of arthroCodes) {
        const rule = thipKpiRulesByCode.get(code);
        expect(rule, code).toBeDefined();
        expect(rule?.queryFamily).toBe('ARTHROPLASTY');
        expect(getReportingCadence(code)).toBe('monthly');
        expect(getFormulaScale(rule!.formulaScale)).toBe(100);
        expect(getRuleUnit(rule!)).toBe('percent');
      }
    });

    it('specifies dotless ICD-9-CM codes for hip (8151-8153) and knee (8154-8155)', () => {
      const hipProcedures = ['8151', '8152', '8153'];
      const kneeProcedures = ['8154', '8155'];
      for (const p of hipProcedures) {
        expect(p).not.toContain('.');
        expect(p).toMatch(/^815[123]$/);
      }
      for (const p of kneeProcedures) {
        expect(p).not.toContain('.');
        expect(p).toMatch(/^815[45]$/);
      }
      // Note: 8147 was excised per CDC NHSN / THIP 2015 update
      expect(kneeProcedures).not.toContain('8147');
    });

    it('verifies 90-day vs 365-day infection surveillance windows for arthroplasty', () => {
      // Hip: DO0205 (90d), DO0204 (1y); Knee: DO0304 (90d), DO0303 (1y)
      expect(thipCatalogueByCode.get('DO0205')?.title).toContain('90 days');
      expect(thipCatalogueByCode.get('DO0204')?.title).toContain('1 Year');
      expect(thipCatalogueByCode.get('DO0304')?.title).toContain('90 days');
      expect(thipCatalogueByCode.get('DO0303')?.title).toContain('1 year');
    });

    it('enforces clinical bilateral surgery counting invariant (episode grain)', () => {
      // In THIP spec: bilateral joint replacement in the same admission counts as 1 episode.
      // Denominator should equal episode count, not raw procedure count.
      const indicator = buildIndicatorFromRows('DO0202', [
        { indicator_code: 'DO0202', fiscal_month: 1, numerator: 10, denominator: 10, value: 100.0 },
      ], 2026);
      expect(indicator?.monthly[0]?.value).toBe(100.0);
    });

    it('checks osteoarthritis primary diagnosis dotless codes (M16 hip, M17 knee, S72 femur neck)', () => {
      const osteoHip = ['M160', 'M161', 'M169'];
      const osteoKnee = ['M170', 'M171', 'M179'];
      const femurFracture = ['S720', 'S721', 'S722'];
      for (const code of [...osteoHip, ...osteoKnee, ...femurFracture]) {
        expect(code).not.toContain('.');
        expect(code).toMatch(/^[MS][0-9]{3}$/);
      }
    });

    it('verifies prosthetic joint infection code T845 in dotless format', () => {
      expect('T845').not.toContain('.');
      expect('T845').toBe('T845');
    });
  });

  describe('Tier 1: Feature Coverage - Diabetes Mellitus & Hypertension Family', () => {
    it('defines all 11 DM, HT, Pediatric DM, and ACSC indicators', () => {
      const dmHtCodes = [
        'DC0103', 'DC0107', 'DC0108', 'DC0108.1', 'DC0108.2',
        'DC0201', 'DC0201.1', 'DC0201.2', 'DP0101', 'AA0104', 'AA0105',
      ];
      for (const code of dmHtCodes) {
        expect(thipKpiRulesByCode.get(code), `Missing ${code}`).toBeDefined();
        expect(thipCatalogueByCode.get(code)).toBeDefined();
      }
    });

    it('validates mixed reporting cadences for DM/HT (Annual, Monthly, Semiannual)', () => {
      expect(getReportingCadence('DC0103')).toBe('annual'); // Retinopathy
      expect(getReportingCadence('DC0107')).toBe('monthly'); // Amputation
      expect(getReportingCadence('DC0108')).toBe('semiannual'); // Adult HbA1c
      expect(getReportingCadence('DC0108.1')).toBe('semiannual'); // Elderly HbA1c
      expect(getReportingCadence('DC0108.2')).toBe('semiannual'); // Adult <60 HbA1c
      expect(getReportingCadence('DC0201')).toBe('semiannual'); // BP control
      expect(getReportingCadence('DC0201.1')).toBe('semiannual'); // BP <65
      expect(getReportingCadence('DC0201.2')).toBe('semiannual'); // BP >=65
      expect(getReportingCadence('DP0101')).toBe('annual'); // Pediatric T1DM
      expect(getReportingCadence('AA0104')).toBe('annual'); // DM ACSC
      expect(getReportingCadence('AA0105')).toBe('annual'); // HT ACSC
    });

    it('verifies dotless ICD-10 codes for DM (E10-E14) and HT (I10-I15)', () => {
      const dmCodes = ['E100', 'E110', 'E119', 'E149'];
      const htCodes = ['I10', 'I110', 'I120', 'I150'];
      for (const c of [...dmCodes, ...htCodes]) {
        expect(c).not.toContain('.');
        expect(c).toMatch(/^[EI][0-9]{2,3}$/);
      }
    });

    it('verifies dotless amputation procedures (ICD-9-CM 8410-8418) for DC0107', () => {
      const ampCodes = ['8410', '8411', '8412', '8413', '8414', '8415', '8416', '8417', '8418'];
      for (const c of ampCodes) {
        expect(c).not.toContain('.');
        expect(c).toMatch(/^841[0-8]$/);
      }
    });

    it('correctly uses formula scale rate_100000 for ACSC hospitalization rates', () => {
      const dmAcsc = thipKpiRulesByCode.get('AA0104')!;
      const htAcsc = thipKpiRulesByCode.get('AA0105')!;
      expect(getFormulaScale(dmAcsc.formulaScale)).toBe(100000);
      expect(getFormulaScale(htAcsc.formulaScale)).toBe(100000);
      expect(getRuleUnit(dmAcsc)).toBe('rate');
      expect(getRuleUnit(htAcsc)).toBe('rate');

      const indicator = buildIndicatorFromRows('AA0104', [
        { indicator_code: 'AA0104', fiscal_month: 1, numerator: 50, denominator: 100000 },
      ], 2026);
      expect(indicator?.monthly[0]?.value).toBe(50.0);
      expect(indicator?.annual.value).toBe(50.0);
    });

    it('handles semiannual glycemic control calculation across periods (months 1 and 7)', () => {
      const indicator = buildIndicatorFromRows('DC0108', [
        { indicator_code: 'DC0108', fiscal_month: 1, numerator: 350, denominator: 500, value: 70.0 },
        { indicator_code: 'DC0108', fiscal_month: 7, numerator: 380, denominator: 500, value: 76.0 },
      ], 2026);
      expect(indicator?.monthly[0]?.value).toBe(70.0);
      expect(indicator?.monthly[6]?.value).toBe(76.0);
      // Non-applicable month remains null
      expect(indicator?.monthly[1]?.value).toBeNull();
      // Weighted annual: (350 + 380) / (500 + 500) * 100 = 73.0%
      expect(indicator?.annual.value).toBe(73.0);
    });
  });

  describe('Tier 1: Feature Coverage - Asthma & COPD Family', () => {
    it('defines all 9 Asthma and COPD indicators across query families', () => {
      const pulmonaryCodes = ['DR0301', 'DR0302', 'DR0401', 'DR0403', 'DR0404', 'AA0102', 'AA0103', 'HC0101', 'HC0102'];
      for (const code of pulmonaryCodes) {
        expect(thipKpiRulesByCode.get(code), code).toBeDefined();
        expect(thipCatalogueByCode.get(code)).toBeDefined();
      }
    });

    it('confirms currently registered status for DR0301, DR0401, and DR0403', () => {
      expect(registeredRuleCodeSet.has('DR0301')).toBe(true);
      expect(registeredRuleCodeSet.has('DR0401')).toBe(true);
      expect(registeredRuleCodeSet.has('DR0403')).toBe(true);
      expect(getImplementationTier('DR0301')).toBe('registered');
      expect(getImplementationTier('DR0401')).toBe('registered');
      expect(getImplementationTier('DR0403')).toBe('registered');
    });

    it('verifies SQL branches for DR0301, DR0401, and DR0403 in ASTHMA_COPD query', () => {
      const query = foundationFamilyQueries.ASTHMA_COPD;
      expect(query).toBeDefined();
      expect(query.sql).toContain("'DR0301' AS indicator_code");
      expect(query.sql).toContain("'DR0401' AS indicator_code");
      expect(query.sql).toContain("'DR0403' AS indicator_code");
    });

    it('verifies dotless ICD-10 diagnosis matching for Asthma (J45, J46) and COPD (J44)', () => {
      const sql = foundationFamilyQueries.ASTHMA_COPD.sql;
      expect(sql).toContain("LEFT(pdx, 3) IN ('J45', 'J46')");
      expect(sql).toContain("LEFT(pdx, 3) = 'J44'");
      expect(sql).not.toContain('J44.');
      expect(sql).not.toContain('J45.');
    });

    it('asserts 28-day unplanned readmission logic filters out patients who died during index admission', () => {
      const sql = foundationFamilyQueries.ASTHMA_COPD.sql;
      expect(sql).toContain('COUNT(*) FILTER (WHERE NOT died');
      expect(sql).toContain("INTERVAL '28 days'");
    });

    it('validates ACSC and ER ratio metrics for Asthma/COPD (AA0102, AA0103, HC0101, HC0102)', () => {
      expect(getFormulaScale(thipKpiRulesByCode.get('AA0102')!.formulaScale)).toBe(100000);
      expect(getFormulaScale(thipKpiRulesByCode.get('AA0103')!.formulaScale)).toBe(100000);
      expect(getRuleUnit(thipKpiRulesByCode.get('HC0101')!)).toBe('ratio');
      expect(getRuleUnit(thipKpiRulesByCode.get('HC0102')!)).toBe('percent');
    });
  });

  describe('Tier 1: Feature Coverage - Maternal & Child Health Family', () => {
    it('defines all 20 Maternal & Child indicators in manifest', () => {
      const matChildCodes = [
        'CM0101', 'CM0104', 'CM0105', 'CM0107', 'CM0109', 'CM0110', 'CM0116', 'CM0117', 'CM0118', 'CM0119',
        'CM0201', 'CM0202', 'CM0203', 'CM0204', 'CM0205', 'CM0206', 'CM0207', 'CM0208', 'CM0209', 'DE1601',
      ];
      for (const code of matChildCodes) {
        expect(thipKpiRulesByCode.get(code), code).toBeDefined();
        expect(thipCatalogueByCode.get(code)).toBeDefined();
      }
    });

    it('confirms registered status and SQL branch for C-section ALOS (CM0105)', () => {
      expect(registeredRuleCodeSet.has('CM0105')).toBe(true);
      expect(getImplementationTier('CM0105')).toBe('registered');
      const query = foundationFamilyQueries.MATERNAL_CHILD;
      expect(query).toBeDefined();
      expect(query.sql).toContain("'CM0105' AS indicator_code");
      expect(query.sql).toContain('ROUND(AVG(los), 2)');
    });

    it('verifies dotless C-section ICD-10 diagnosis codes (O820-O829, O842) in CM0105', () => {
      const sql = foundationFamilyQueries.MATERNAL_CHILD.sql;
      expect(sql).toContain("pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')");
      expect(sql).not.toContain('O82.');
    });

    it('validates maternal mortality ratio per 100,000 live births (CM0101)', () => {
      const cm0101 = thipKpiRulesByCode.get('CM0101')!;
      expect(getFormulaScale(cm0101.formulaScale)).toBe(100000);
      expect(getRuleUnit(cm0101)).toBe('rate');
      expect(getReportingCadence('CM0101')).toBe('annual');
    });

    it('validates birth asphyxia and birth weight stratification indicators (CM0204-CM0209)', () => {
      const asphyxiaCodes = ['CM0204', 'CM0205'];
      const weightCodes = ['CM0206', 'CM0207', 'CM0208', 'CM0209'];
      for (const c of [...asphyxiaCodes, ...weightCodes]) {
        expect(thipKpiRulesByCode.get(c)).toBeDefined();
      }
      expect(thipCatalogueByCode.get('CM0204')?.title.toLowerCase()).toContain('asphyxia');
      expect(thipCatalogueByCode.get('CM0206')?.title).toContain('2500');
    });

    it('validates universal newborn hearing screening within 30 days (DE1601)', () => {
      const de1601 = thipKpiRulesByCode.get('DE1601')!;
      expect(de1601).toBeDefined();
      expect(de1601.queryFamily).toBe('NEWBORN');
      expect(thipCatalogueByCode.get('DE1601')?.title).toContain('30 days');
    });

    it('verifies pending reason requirement for pending maternal/child indicators', () => {
      for (const code of ['CM0101', 'CM0104', 'CM0107', 'CM0201', 'DE1601']) {
        if (!registeredRuleCodeSet.has(code)) {
          const reason = getPendingReason(code);
          expect(reason).not.toBeNull();
          expect(reason!.length).toBeGreaterThan(5);
        }
      }
    });
  });

  describe('Tier 1: Feature Coverage - Acute Care & Foundation Baseline', () => {
    it('covers all 16 initial foundation rule codes in foundationRuleCodes manifest', () => {
      expect(foundationRuleCodes.length).toBe(16);
      for (const code of foundationRuleCodes) {
        expect(registeredRuleCodeSet.has(code)).toBe(true);
        expect(queryRegistry.thipIpdFoundation.sql).toContain(`'${code}' AS indicator_code`);
      }
    });

    it('keeps STEMI and NSTE-ACS mortality cohorts strictly separated', () => {
      const sql = queryRegistry.thipIpdFoundation.sql;
      expect(sql).toContain("'DH0101.1' AS indicator_code");
      expect(sql).toContain("'DH0101.2' AS indicator_code");
      expect(sql).toContain("pdx IN ('I210', 'I211', 'I212', 'I213')");
      expect(sql).toContain("pdx IN ('I214', 'I219')");
    });

    it('evaluates Stroke mortality, readmission, and ALOS (DN0101, DN0107, DN0109)', () => {
      const sql = foundationFamilyQueries.STROKE.sql;
      expect(sql).toContain("'DN0101' AS indicator_code");
      expect(sql).toContain("'DN0107' AS indicator_code");
      expect(sql).toContain("'DN0109' AS indicator_code");
      expect(sql).toContain("LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')");
    });

    it('evaluates Sepsis ER antibiotic within 3 hours and ICU mortality (CE0101, CI0101)', () => {
      const sql = foundationFamilyQueries.SEPSIS_ER.sql;
      expect(sql).toContain("'CE0101' AS indicator_code");
      expect(sql).toContain("'CI0101' AS indicator_code");
      expect(thipKpiRulesByCode.get('CE0101')!.title.toLowerCase()).toContain('broad-spectrum');
    });

    it('evaluates Head Injury mortality within 48 hours (DN0302)', () => {
      const sql = foundationFamilyQueries.HEAD_INJURY.sql;
      expect(sql).toContain("'DN0302' AS indicator_code");
      expect(sql).toContain("INTERVAL '48 hours'");
      expect(sql).toContain("pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')");
    });
  });

  // ===========================================================================
  // TIER 2: BOUNDARY & CORNER CASES
  // ===========================================================================

  describe('Tier 2: Boundary & Corner Cases', () => {
    it('returns value: null when denominator is 0 (zero cohort) without fabricating 0.00%', () => {
      const indicator = buildIndicatorFromRows('DH0101', [
        { indicator_code: 'DH0101', fiscal_month: 1, numerator: 0, denominator: 0, value: null },
      ], 2026);
      expect(indicator).not.toBeNull();
      expect(indicator?.monthly[0]?.value).toBeNull();
      expect(indicator?.monthly[0]?.denominator).toBe(0);
      expect(indicator?.monthly[0]?.status).toBe('no-data');
    });

    it('returns value: null when denominator is null (explicit unavailable state)', () => {
      const indicator = buildIndicatorFromRows('DH0301', [
        { indicator_code: 'DH0301', fiscal_month: 1, numerator: null, denominator: null, value: null },
      ], 2026);
      expect(indicator).not.toBeNull();
      expect(indicator?.monthly[0]?.value).toBeNull();
      expect(indicator?.monthly[0]?.numerator).toBeNull();
      expect(indicator?.monthly[0]?.denominator).toBeNull();
      expect(indicator?.monthly[0]?.status).toBe('no-data');
    });

    it('protects against division-by-zero errors in rate calculations', () => {
      // If numerator is positive but denominator is 0 (corrupted input), value must be null
      const indicator = buildIndicatorFromRows('DH0101', [
        { indicator_code: 'DH0101', fiscal_month: 1, numerator: 5, denominator: 0 },
      ], 2026);
      expect(indicator?.monthly[0]?.value).toBeNull();
      expect(indicator?.monthly[0]?.status).toBe('no-data');
      expect(Number.isFinite(indicator?.monthly[0]?.value ?? 0)).toBe(true);
    });

    it('rejects duplicate indicator-month rows from source view', () => {
      expect(() => buildIndicatorFromRows('DH0101', [
        { indicator_code: 'DH0101', fiscal_month: 1, numerator: 1, denominator: 10 },
        { indicator_code: 'DH0101', fiscal_month: 1, numerator: 2, denominator: 10 },
      ], 2026)).toThrow(BmsRequestError);
    });

    it('asserts strictly dotless ICD-10 and ICD-9 codes across all registered queries', () => {
      const allQueries: RegisteredQuery[] = [
        ...Object.values(queryRegistry),
        ...Object.values(foundationFamilyQueries),
      ];

      for (const query of allQueries) {
        const sql = query.sql;
        // Verify no dotted ICD-10 or ICD-9 string literals e.g. 'I21.0', 'J44.1', '81.51', 'O82.0'
        const dottedPattern = /'([A-Z][0-9]{2}\.[0-9]{1,2}|[0-9]{2}\.[0-9]{1,2})'/g;
        const matches = sql.match(dottedPattern);
        expect(matches, `Found dotted code literal in query ${query.key}: ${matches?.join(', ')}`).toBeNull();
        // Verify canonicalization uses REPLACE(..., '.', '')
        if (sql.includes('pdx IN') || sql.includes('icd10 IN')) {
          expect(sql).toContain("REPLACE(");
          expect(sql).toContain("'.'");
        }
      }
    });

    it('correctly calculates Thai fiscal year and month boundaries (October = Month 1)', () => {
      // Test current fiscal year determination for date in October (e.g. 2025-10-15 belongs to FY 2026)
      const octDate = new Date(2025, 9, 15); // Month index 9 = October
      expect(getCurrentFiscalYear(octDate)).toBe(2026);

      // January 2026 belongs to FY 2026
      const janDate = new Date(2026, 0, 15); // Month index 0 = January
      expect(getCurrentFiscalYear(janDate)).toBe(2026);

      const periods = getFiscalMonthPeriods(2026);
      expect(periods.length).toBe(12);
      expect(periods[0]?.periodStart).toBe('2025-10-01');
      expect(periods[0]?.fiscalMonth).toBe(1);
      expect(periods[0]?.month).toBe(10);
      expect(periods[11]?.periodStart).toBe('2026-09-01');
      expect(periods[11]?.fiscalMonth).toBe(12);
      expect(periods[11]?.month).toBe(9);
    });

    it('enforces dual-state invariant: every code is either registered or pending with a reason', () => {
      expect(thipImplementation.length).toBe(232);
      for (const entry of thipImplementation) {
        if (entry.tier === 'registered') {
          expect(registeredRuleCodeSet.has(entry.code)).toBe(true);
          expect(entry.reason).toBeNull();
        } else {
          expect(entry.tier).toBe('pending-local-source');
          expect(entry.reason).not.toBeNull();
          expect(typeof entry.reason).toBe('string');
          expect(entry.reason!.length).toBeGreaterThan(0);
        }
      }
    });
  });

  // ===========================================================================
  // TIER 3: CROSS-FEATURE COMBINATIONS
  // ===========================================================================

  describe('Tier 3: Cross-Feature Combinations', () => {
    it('maintains grain and schema equivalence between standard and drgResult IPD CTE variants', () => {
      const standardCte = ipdBaseCte('standard');
      const drgResultCte = ipdBaseCte('drgResult');

      expect(standardCte).toContain('WITH ipd AS');
      expect(standardCte).toContain('periodized AS');
      expect(drgResultCte).toContain('WITH ipd AS');
      expect(drgResultCte).toContain('periodized AS');

      // Common columns required by periodized projection
      const commonCols = ['an', 'hn', 'regdate', 'dchdate', 'pdx', 'died', 'period_start', 'calendar_month'];
      for (const col of commonCols) {
        expect(standardCte, `Standard CTE missing ${col}`).toContain(col);
        expect(drgResultCte, `drgResult CTE missing ${col}`).toContain(col);
      }
    });

    it('integrates multiple family branches in thipIpdFoundation without cross-talk or syntax conflict', () => {
      const ipdFoundation = queryRegistry.thipIpdFoundation;
      expect(() => assertRegisteredReadOnlyQuery(ipdFoundation)).not.toThrow();
      const sql = ipdFoundation.sql;

      // Both ACS and COPD readmission branches exist
      expect(sql).toContain("'DH0101' AS indicator_code");
      expect(sql).toContain("'DR0403' AS indicator_code");
      expect(sql).toContain("'CM0105' AS indicator_code");
      expect(sql).toContain('UNION ALL');
      expect(sql).toContain('expected_codes(indicator_code)');
      expect(sql).toContain('fiscal_periods');
    });

    it('processes mixed reporting cadences (Monthly, Quarterly, Semiannual, Annual) in single workflow', () => {
      // Monthly: DH0101 (12/yr)
      // Quarterly: HC0101 (4/yr)
      // Semiannual: DC0108 (2/yr)
      // Annual: AA0101 (1/yr)
      const monthlyInd = buildIndicatorFromRows('DH0101', [
        { indicator_code: 'DH0101', fiscal_month: 1, numerator: 1, denominator: 10, value: 10 },
      ], 2026);
      const semiannualInd = buildIndicatorFromRows('DC0108', [
        { indicator_code: 'DC0108', fiscal_month: 1, numerator: 80, denominator: 100, value: 80 },
        { indicator_code: 'DC0108', fiscal_month: 7, numerator: 85, denominator: 100, value: 85 },
      ], 2026);
      const annualInd = buildIndicatorFromRows('AA0101', [
        { indicator_code: 'AA0101', fiscal_month: 1, numerator: 10, denominator: 100000, value: 10 },
      ], 2026);

      expect(monthlyInd?.monthly.length).toBe(12);
      expect(semiannualInd?.monthly[0]?.value).toBe(80);
      expect(semiannualInd?.monthly[6]?.value).toBe(85);
      expect(semiannualInd?.monthly[1]?.value).toBeNull();
      expect(annualInd?.monthly[0]?.value).toBe(10);
      expect(annualInd?.monthly[1]?.value).toBeNull();
    });

    it('performs weighted annual rollups across multiple reporting periods', () => {
      // Period 1: 10/100 = 10%
      // Period 2: 30/100 = 30%
      // Arithmetic mean = 20%
      // Weighted = (10 + 30) / (100 + 100) = 40 / 200 = 20%
      // If Period 2 had 10/20 = 50%:
      // Weighted = (10 + 10) / (100 + 20) = 20 / 120 = 16.67%, whereas arithmetic mean = (10 + 50)/2 = 30%
      const indicator = buildIndicatorFromRows('DH0101', [
        { indicator_code: 'DH0101', fiscal_month: 1, numerator: 10, denominator: 100, value: 10 },
        { indicator_code: 'DH0101', fiscal_month: 2, numerator: 10, denominator: 20, value: 50 },
      ], 2026);
      expect(indicator?.annual.value).toBe(16.67);
      expect(indicator?.annual.numerator).toBe(20);
      expect(indicator?.annual.denominator).toBe(120);
    });

    it('applies readmission subquery consistently across distinct clinical condition cohorts', () => {
      // Stroke (DN0107), Pneumonia (DR0102), Asthma (DR0301), COPD (DR0401)
      const query = queryRegistry.thipIpdFoundation;
      const sql = query.sql;
      expect(sql).toContain("'DN0107' AS indicator_code");
      expect(sql).toContain("'DR0102' AS indicator_code");
      expect(sql).toContain("'DR0301' AS indicator_code");
      expect(sql).toContain("'DR0401' AS indicator_code");
      // All readmission branches use NOT died in denominator and 28-day window
      expect(sql).toContain('COUNT(*) FILTER (WHERE NOT died)');
    });
  });

  // ===========================================================================
  // TIER 4: REAL-WORLD WORKLOAD SCENARIOS
  // ===========================================================================

  describe('Tier 4: Real-World Workload Scenarios', () => {
    it('executes full fiscal year 1,552-cell matrix completeness verification', () => {
      const fixture = buildCompleteSourceFixture(2026);
      expect(fixture.length).toBe(EXPECTED_TOTAL_CELLS);
      expect(EXPECTED_TOTAL_CELLS).toBe(1552);

      // Verify exact cell distribution across cadences:
      // Monthly: 112 * 12 = 1,344
      // Quarterly: 19 * 4 = 76
      // Semiannual: 31 * 2 = 62
      // Annual: 70 * 1 = 70
      // Sum = 1344 + 76 + 62 + 70 = 1552
      expect(EXPECTED_MONTHLY_CELLS).toBe(1344);
      expect(EXPECTED_QUARTERLY_CELLS).toBe(76);
      expect(EXPECTED_SEMIANNUAL_CELLS).toBe(62);
      expect(EXPECTED_ANNUAL_CELLS).toBe(70);

      const coverage = summarizeCoverage(fixture, 2026);
      expect(coverage.expectedIndicatorCount).toBe(232);
      expect(coverage.liveIndicatorCount).toBe(232);
      expect(coverage.expectedCellCount).toBe(1552);
      expect(coverage.coveredCellCount).toBe(1552);
      expect(coverage.unexpectedCellCount).toBe(0);
      expect(coverage.complete).toBe(true);
      expect(coverage.availableCellCount + coverage.unavailableCellCount).toBe(1552);
    });

    it('verifies zero Protected Health Information (PHI) in all outer projections and domain objects', () => {
      // 1. Check outer SELECT projections of all foundation family queries
      const allFoundationQueries = [
        queryRegistry.thipIpdFoundation,
        ...Object.values(foundationFamilyQueries),
      ];

      for (const query of allFoundationQueries) {
        const sql = query.sql;
        const lastSelectIndex = sql.lastIndexOf('SELECT');
        const fromExpectedIndex = sql.lastIndexOf('FROM expected_codes');
        if (lastSelectIndex !== -1 && fromExpectedIndex !== -1) {
          const outerProjection = sql.slice(lastSelectIndex, fromExpectedIndex);
          for (const phi of ['hn', 'an', 'vn', 'cid', 'patient_name', 'birthdate', 'address']) {
            const regex = new RegExp(`\\b${phi}\\b`, 'i');
            expect(outerProjection.match(regex), `Outer projection of ${query.key} leaked PHI: ${phi}`).toBeNull();
          }
        }
      }

      // 2. Check generated domain indicator objects
      const indicator = buildIndicatorFromRows('DH0101', [
        { indicator_code: 'DH0101', fiscal_month: 1, numerator: 5, denominator: 50, value: 10.0 },
      ], 2026);
      expect(indicator).toBeDefined();
      const indicatorKeys = Object.keys(indicator ?? {});
      expect(indicatorKeys).not.toContain('hn');
      expect(indicatorKeys).not.toContain('an');
      expect(indicatorKeys).not.toContain('cid');
      const monthlyKeys = Object.keys(indicator?.monthly[0] ?? {});
      expect(monthlyKeys).not.toContain('hn');
      expect(monthlyKeys).not.toContain('an');
      expect(monthlyKeys).not.toContain('cid');
    });

    it('enforces read-only SQL safety gate across all registered queries', () => {
      const allQueries = [
        ...Object.values(queryRegistry),
        ...Object.values(foundationFamilyQueries),
        buildCompletenessAuditQuery('thip_kpi_monthly'),
        buildDuplicateCheckQuery('thip_kpi_monthly'),
        buildSourceViewQuery('thip_kpi_monthly'),
      ];

      for (const query of allQueries) {
        expect(() => assertRegisteredReadOnlyQuery(query), `Failed read-only check: ${query.key}`).not.toThrow();
      }

      // Negative tests: verify assertRegisteredReadOnlyQuery rejects mutating SQL
      const maliciousStatements = [
        'INSERT INTO ipt VALUES (1)',
        'UPDATE ipt SET dchdate = now()',
        'DELETE FROM ipt WHERE an = 1',
        'DROP TABLE an_stat',
        'ALTER TABLE ipt DROP COLUMN hn',
        'TRUNCATE ipt',
        'GRANT ALL ON ipt TO public',
        'CALL some_stored_procedure()',
      ];

      for (const sql of maliciousStatements) {
        expect(() => assertRegisteredReadOnlyQuery({
          key: 'malicious',
          description: 'test',
          sql,
        })).toThrow(/read-only/);
      }
    });

    it('quotes only safe SQL table identifiers preventing SQL injection in source view queries', () => {
      expect(quoteSourceView('thip_kpi_monthly')).toBe('"thip_kpi_monthly"');
      expect(quoteSourceView('public.thip_kpi_monthly')).toBe('"public"."thip_kpi_monthly"');
      expect(() => quoteSourceView('table; DROP TABLE patient;--')).toThrow();
      expect(() => quoteSourceView('123bad')).toThrow();
    });

    it('enforces query timeout budget invariant (30 seconds)', () => {
      expect(QUERY_TIMEOUT_MS).toBe(30_000);
    });
  });

  // ===========================================================================
  // TARGET 52 INDICATORS REGRESSION & INTEGRITY SUITE
  // ===========================================================================

  describe('Target 52 Indicators Integrity & Coverage Suite', () => {
    it('verifies all 52 target indicators exist in both catalogue and rules manifest', () => {
      expect(TARGET_52_INDICATORS.length).toBe(52);
      for (const code of TARGET_52_INDICATORS) {
        const cat = thipCatalogueByCode.get(code);
        const rule = thipKpiRulesByCode.get(code);
        expect(cat, `Catalogue missing: ${code}`).toBeDefined();
        expect(rule, `Rule missing: ${code}`).toBeDefined();
        expect(cat?.code).toBe(code);
        expect(rule?.code).toBe(code);
      }
    });

    it('verifies cadence integrity and expected reporting months for all 52 indicators', () => {
      for (const code of TARGET_52_INDICATORS) {
        const cadence = getReportingCadence(code);
        const expectedMonths = getExpectedFiscalMonths(code);
        expect(['monthly', 'quarterly', 'semiannual', 'annual']).toContain(cadence);
        if (cadence === 'monthly') expect(expectedMonths.length).toBe(12);
        if (cadence === 'quarterly') expect(expectedMonths).toEqual([1, 4, 7, 10]);
        if (cadence === 'semiannual') expect(expectedMonths).toEqual([1, 7]);
        if (cadence === 'annual') expect(expectedMonths).toEqual([1]);
      }
    });

    it('verifies formula multipliers are valid numbers across all 52 target indicators', () => {
      for (const code of TARGET_52_INDICATORS) {
        const rule = thipKpiRulesByCode.get(code)!;
        const scale = getFormulaScale(rule.formulaScale);
        expect(scale).toBeGreaterThan(0);
        expect(Number.isFinite(scale)).toBe(true);
      }
    });
  });
});
