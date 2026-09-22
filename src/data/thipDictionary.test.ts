import { describe, expect, it } from 'vitest';
import rawDictionary from '@/data/thipKpiDictionary.json';
import {
  benchmarkSourceFromTarget,
  getDictionaryEntry,
  parseBenchmark,
  thipDictionaryByCode,
} from '@/data/thipDictionary';

const raw = rawDictionary as Record<string, Record<string, unknown>>;

describe('parseBenchmark', () => {
  it('extracts a value only from clear printed figures', () => {
    expect(parseBenchmark('ร้อยละ 80 ศูนย์ข้อมูลระบบประสาท ปี 2555-2558')).toMatchObject({ value: 80 });
    expect(parseBenchmark('UK 8% (ศูนย์ข้อมูลระบบประสาทฯ ค่าเฉลี่ยข้อมูลตั้งแต่ ค.ศ. 2010 ไม่เกิน 7.5%)')).toMatchObject({ value: 8 });
    expect(parseBenchmark('U.S.A. National Median : 84')).toMatchObject({ value: 84 });
    expect(parseBenchmark('65% ศูนย์ข้อมูลระบบประสาท สถาบันประสาทวิทยา กรมการแพทย์ปี 2557-2558')).toMatchObject({ value: 65 });
    expect(parseBenchmark('5.9 วัน (ค่า SD 2.2) ศูนย์ข้อมูลระบบประสาท ปี 2557')).toMatchObject({ value: 5.9 });
    expect(parseBenchmark('U.S.A. 2005 = 92.1')).toMatchObject({ value: 92.1 });
    // The canonical shapes from the extraction rules hold verbatim too.
    expect(parseBenchmark('ร้อยละ 80 ...').value).toBe(80);
    expect(parseBenchmark('UK 8% (...)').value).toBe(8);
    expect(parseBenchmark('65% ...').value).toBe(65);
    expect(parseBenchmark('5.9 วัน (ค่า SD 2.2) ...').value).toBe(5.9);
    expect(parseBenchmark('UK 1-3 %').value).toBeNull();
    expect(parseBenchmark('Dejkhamron P., ... P520').value).toBeNull();
  });

  it('never reads a range as one target number and keeps the verbatim label', () => {
    const range = parseBenchmark('UK 1-3 %');
    expect(range.value).toBeNull();
    expect(range.comparator).toBeNull();
    expect(range.label).toBe('UK 1-3 %');
    expect(parseBenchmark('England : 3.3-6.8 per 1,000 total births').value).toBeNull();
  });

  it('never reads a citation as a target and keeps the verbatim label', () => {
    const citation = parseBenchmark(
      'Dejkhamron P., Likitmaskul S., Deerochanawong C., Santiprabhob J., Tharavanij T.,et al. Outcomes of Type 1 Diabetes management and outcomes: a multicenter study in Thailand. J Diabetes Investig.2020 Aug 19. doi:10.1111/jdi.13390 online ahead of print. Figure1 ,P520',
    );
    expect(citation.value).toBeNull();
    expect(citation.label).toContain('Dejkhamron P.');
    expect(parseBenchmark('Crit Care Med 2007; 35 (4): 1105 – 12').value).toBeNull();
    expect(parseBenchmark('Definition CDC 2014').value).toBeNull();
    expect(parseBenchmark('BMC Health Services Research/2019').value).toBeNull();
  });

  it('reads the printed comparator wording next to the figure', () => {
    expect(parseBenchmark('ไม่เกิน 40 วัน (คำนวณจากจำนวนเดือนสำรองคลังคูณด้วย 30) (เครือข่ายโรงพยาบาลกลุ่มสถาบันแพทยศาสตร์แห่งประเทศไทย/ 2561)'))
      .toMatchObject({ value: 40, comparator: '<=' });
    expect(parseBenchmark('น้อยกว่าร้อยละ 10 (คณะกรรมการตัวชี้วัดแผลกดทับ ชมรมเครือข่ายพัฒนาคุณภาพการ พยาบาล UHNDC)'))
      .toMatchObject({ value: 10, comparator: '<' });
    expect(parseBenchmark('มากกว่าร้อยละ 95')).toMatchObject({ value: 95, comparator: '>' });
    // The wording lives inside the supporting parenthesis, not next to the
    // chosen figure, so it must not be attributed to the target.
    expect(parseBenchmark('UK 8% (ศูนย์ข้อมูลระบบประสาทฯ ค่าเฉลี่ยข้อมูลตั้งแต่ ค.ศ. 2010 ไม่เกิน 7.5%)'))
      .toMatchObject({ value: 8, comparator: null });
  });

  it('refuses ambiguous multi-benchmark strings instead of guessing', () => {
    expect(parseBenchmark('UISA / Malaysia = 4 , UK = 3 , UN= 4').value).toBeNull();
    expect(parseBenchmark('ปี 2555–2557 ข้อมูลจาก สปสช. ร้อยละ 17 ---> 15').value).toBeNull();
  });

  it('returns all-null for missing or empty benchmark text', () => {
    expect(parseBenchmark(null)).toEqual({ value: null, comparator: null, label: null });
    expect(parseBenchmark('   ')).toEqual({ value: null, comparator: null, label: null });
  });
});

describe('benchmarkSourceFromTarget', () => {
  it('keeps the citation part of the printed benchmark', () => {
    expect(benchmarkSourceFromTarget('U.S.A. National Median : 84')).toBe('U.S.A. National Median');
    expect(benchmarkSourceFromTarget('ร้อยละ 80 ศูนย์ข้อมูลระบบประสาท ปี 2555-2558')).toBe('ศูนย์ข้อมูลระบบประสาท ปี 2555-2558');
    expect(benchmarkSourceFromTarget('ไม่เกิน 40 วัน (คำนวณจากจำนวนเดือนสำรองคลังคูณด้วย 30) (เครือข่าย 2561)')).toContain('คำนวณจากจำนวนเดือนสำรองคลังคูณด้วย 30');
  });

  it('falls back to the full printed string when no figure is parsed', () => {
    expect(benchmarkSourceFromTarget('UK 1-3 %')).toBe('UK 1-3 %');
    expect(benchmarkSourceFromTarget(null)).toBeNull();
  });
});

describe('thipDictionaryByCode / getDictionaryEntry', () => {
  it('exposes every one of the 232 dictionary entries exactly once', () => {
    expect(thipDictionaryByCode.size).toBe(232);
    expect(Object.keys(raw)).toHaveLength(232);
    expect(getDictionaryEntry('missing-code')).toBeUndefined();
  });

  it('keeps definition and formula populated for all 232 entries', () => {
    for (const [code, entry] of thipDictionaryByCode) {
      expect(entry.definition.trim().length, code).toBeGreaterThan(0);
      expect(entry.formula.trim().length, code).toBeGreaterThan(0);
      expect(entry.definition, code).toBe(raw[code]?.definition);
      expect(entry.formula, code).toBe(raw[code]?.formula);
    }
  });

  it('keeps direction populated for all 232 entries', () => {
    for (const [code, entry] of thipDictionaryByCode) {
      expect(entry.direction, code).not.toBeNull();
      expect(['higher-is-better', 'lower-is-better', 'neutral'], code).toContain(entry.direction);
    }
  });

  it('returns DH0101 / AA0101 / SF0101 entries identical to the JSON source of truth', () => {
    for (const code of ['DH0101', 'AA0101', 'SF0101']) {
      const entry = getDictionaryEntry(code);
      expect(entry, code).toBeDefined();
      expect(entry).toEqual(raw[code]);
      expect(entry?.numeratorDefinition, code).toBe(raw[code]?.numeratorDefinition);
      expect(entry?.denominatorDefinition, code).toBe(raw[code]?.denominatorDefinition);
    }
    expect(getDictionaryEntry('DH0101')?.formula).toBe('(a/b) x 100');
    expect(getDictionaryEntry('AA0101')?.definition).toContain('ACSC');
    expect(getDictionaryEntry('SF0101')?.direction).toBe('higher-is-better');
  });
});
