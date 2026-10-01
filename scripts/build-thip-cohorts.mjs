import { readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { createServer } from 'vite';

// Scan only top-level tokens: a nested aggregate/subquery must not masquerade as the outer grain.
function topLevel(sql) {
  let depth = 0, quote = false; const tokens = [];
  for (let i = 0; i < sql.length; i++) {
    const char = sql[i];
    if (char === "'") { if (quote && sql[i + 1] === "'") { i++; continue; } quote = !quote; continue; }
    if (quote) continue;
    if (char === '(') depth++; else if (char === ')') depth--;
    else if (depth === 0 && /[A-Za-z_]/.test(char) && (i === 0 || !/[A-Za-z_0-9]/.test(sql[i - 1]))) {
      const word = /^[A-Za-z_][A-Za-z_0-9]*/.exec(sql.slice(i))[0]; tokens.push({ word: word.toUpperCase(), start: i, end: i + word.length }); i += word.length - 1;
    } else if (depth === 0 && char === ',') tokens.push({ word: ',', start: i, end: i + 1 });
  }
  return tokens;
}
function extract(sql) {
  const tokens = topLevel(sql); const from = tokens.find((t) => t.word === 'FROM');
  const selects = tokens.filter((t) => t.word === ',' && t.start < from.start);
  const cuts = [tokens.find((t) => t.word === 'SELECT').end, ...selects.map((t) => t.end), from.start];
  const fields = cuts.slice(0, -1).map((start, index) => sql.slice(start, index < selects.length ? selects[index].start : from.start).trim());
  const alias = (name) => fields.find((field) => new RegExp(`\\sAS\\s${name}$`, 'i').test(field))?.replace(new RegExp(`\\sAS\\s${name}$`, 'i'), '') ?? fields.find((field) => field === name) ?? null;
  const where = tokens.find((t) => t.word === 'WHERE'); const group = tokens.find((t) => t.word === 'GROUP');
  return { numerator: alias('numerator'), denominator: alias('denominator'), source: sql.slice(from.end, where?.start ?? group?.start ?? sql.length).trim(), cohort: where ? sql.slice(where.end, group?.start ?? sql.length).trim() : null };
}
const kind = (expression, external) => external ? 'external' : !expression ? 'unverified' : /COUNT\(/i.test(expression) && /SUM\(|AVG\(/i.test(expression) ? 'mixed' : /SUM\(|AVG\(/i.test(expression) ? 'sum' : /COUNT\(/i.test(expression) ? 'count' : 'unverified';
const hash = (sql) => createHash('sha256').update(sql).digest('hex');
const server = await createServer({ logLevel: 'error', server: { middlewareMode: true, hmr: false }, appType: 'custom' });
try {
  const registry = await server.ssrLoadModule('/src/services/queryRegistry.ts');
  const { branchCodeOf, thipBatchApproximations } = await server.ssrLoadModule('/src/services/thipFamilies/index.ts');
  const { planThipSteps } = await server.ssrLoadModule('/src/services/thipStepLoader.ts');
  const { thipDictionaryByCode } = await server.ssrLoadModule('/src/data/thipDictionary.ts');
  const { cohortProfiles } = await server.ssrLoadModule('/src/services/cohortProfiles.ts');
  const audit = JSON.parse(readFileSync('docs/THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json', 'utf8'));
  const byCode = new Map(audit.kpis.map((kpi) => [kpi.code, kpi]));
  const steps = new Map(planThipSteps(2026).map((step) => [step.code, step]));
  const special = {
    DH0101: 'ตัวตั้งครั้งจำหน่าย ACS ที่ตาย / ตัวหารครั้งจำหน่าย ACS ทุกสถานะ; ต้องยืนยัน I21/secondary ACS และ cause-of-death proxy ไม่ใช่จำนวน HN ทั้งทะเบียน',
    DH0112: 'ตัวตั้งผลรวมวันนอน / ตัวหาร COUNT admission ACS ที่จำหน่าย; dictionary ใช้คำว่าคน ต้องยืนยัน episode เทียบ distinct HN; ไม่เปลี่ยนเป็น COUNT HN โดยเดา',
    CE0102: 'เก็บเฉพาะวันที่ 5, 15, 25 ของ enter_er_time แล้ว; ยังใช้ vstdate/vsttime เป็น arrival proxy และต้องยืนยัน triage/exclusions กับ ER',
    CE0103: 'เก็บเฉพาะวันที่ 5, 15, 25 ของ enter_er_time แล้ว; ยังต้องยืนยัน sampling, triage และ exclusions กับ ER',
    HH0102: 'DISTINCT HN เป็น proxy ผู้สูบบุหรี่/รับคำแนะนำ; ต้องยืนยัน F17/Z720 และรหัสคำแนะนำ/ยา; distinct ข้ามเดือนต้องคำนวณเต็มช่วง',
    HE0101: 'ทะเบียน emp เป็น candidate; CID ใช้เชื่อมเหตุการณ์ด้วย EXISTS ไม่ตัดเจ้าหน้าที่ CID ว่างออกจากทะเบียนหลัก; checkup=1 ยังเป็น local proxy; วันที่สิ้นสุดก่อนเริ่มงานไม่สร้าง employee-month ต้องตรวจทะเบียนกับ HR',
    SH0101: 'รายปีใช้ค่าเฉลี่ยจำนวนลาออกสมัครใจรายเดือนกับค่าเฉลี่ย headcount ต้น/ปลายปีตาม dictionary; SUM(bigint) ใน PostgreSQL เป็น numeric; ห้ามแบ่ง annual turnover เป็น 12 ค่าเดือนโดยปริยาย',
  };
  const evidence = registry.registeredBranches.map((sql) => {
    const code = branchCodeOf(sql); const old = byCode.get(code); const dictionary = thipDictionaryByCode.get(code); const outer = extract(sql); const external = registry.externalRegisteredCodes.includes(code);
    if (!old || !dictionary || !outer.numerator || !outer.denominator) throw new Error(`Unmapped cohort ${code}`);
    let grain = 'custom aggregate; inspect source SQL before confirming grain', keys = [], dates = [];
    if (external) { grain = 'hospital-supplied aggregate'; keys = ['reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month']; dates = ['reporting.thip_external_facts.period_start']; }
    else if (/\bopd_periodized\b/.test(outer.source)) { grain = /COUNT\(DISTINCT\s+(?:\w+\.)?hn\b/i.test(outer.numerator + outer.denominator) ? 'distinct HN within reporting window (candidate)' : 'visit/event at ovst VN (candidate)'; keys = ['ovst.vn', 'ovst.hn']; dates = ['ovst.vstdate', 'ovst.vsttime']; }
    else if (/\bperiodized\b/.test(outer.source)) { grain = 'admission at ipt AN (candidate)'; keys = ['ipt.an', 'ipt.hn', 'an_stat.an']; dates = ['ipt.dchdate', 'ipt.regdate']; }
    else if (/\bemp\b|\bhr\b/.test(outer.source)) { grain = 'staff / month aggregate (candidate)'; keys = ['emp.emp_id', 'emp.emp_cid']; dates = ['emp.emp_work_begindate', 'emp.emp_resign_enddate']; }
    else { keys = [...new Set((old.currentSql.joinPredicates ?? []).flatMap((p) => [p.left, p.right]).filter(Boolean).map((p) => `${p.table}.${p.column}`))]; dates = (old.currentSql.queryTableFootprint ?? []).flatMap((t) => (t.referencedColumns ?? []).filter((c) => /date|time/i.test(c.name)).map((c) => `${t.name}.${c.name}`)); }
    const limitations = [thipBatchApproximations[code] ?? old.currentRuleManifest?.approximationOrKnownLimitation ?? 'ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล', ...(special[code] ? [special[code]] : []), 'ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target'];
    if (/\bopd_periodized\b/.test(outer.source)) limitations.push('base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ');
    if (/\bemp\b/.test(outer.source)) limitations.push('วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR');
    if (['AA0101','AA0102','AA0103','AA0104','AA0105'].includes(code)) limitations.push('patient HN ปัจจุบันไม่ใช่ population กลางปีอายุ 15–74 ในพื้นที่รับผิดชอบ; ต้องใช้ population denominator ภายนอก');
    if (!dictionary.denominatorDefinition) limitations.push('dictionary extraction ไม่มี denominator definition; ต้องตรวจหน้าต้นฉบับก่อนกำหนด denominator');
    return { code, pdfPage: dictionary.page, printedPages: old.pdf.printedPages, ruleVersion: 'cohort-evidence/1', population: dictionary.denominatorDefinition, numeratorDefinition: dictionary.numeratorDefinition, denominatorDefinition: dictionary.denominatorDefinition, dictionaryDefinition: dictionary.definition, dictionaryUnit: old.dictionaryRule.unit, formula: dictionary.formula, numeratorSql: outer.numerator, denominatorSql: outer.denominator, cohortSql: outer.cohort, numeratorKind: kind(outer.numerator, external), denominatorKind: kind(outer.denominator, external), currentGrain: grain, keyCandidates: keys, eventDateCandidates: dates,
      sourceSql: outer.source, inclusion: dictionary.inclusion, exclusion: dictionary.exclusion, structuredCriteria: dictionary.inclusion.length || dictionary.exclusion.length ? 'extracted' : 'not-structured',
      observationWindow: external ? 'hospital-provided cadence aggregate; window must be confirmed by source owner' : 'registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed',
      sourceTables: (old.currentSql.queryTableFootprint ?? []).map((t) => t.name), querySha256: hash(steps.get(code)?.query.sql ?? sql), evidence: [`THIP KPI.pdf:physical-page-${dictionary.page}`, 'docs/THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json', `registered-branch:${code}`, 'HOSxP Structure with primary key.json:structural-snapshot-only'], relationshipStatus: 'candidate-no-declared-FK', reviewStatus: 'awaiting-hospital-confirmation', publicationApproval: 'unapproved', limitations };
  }).sort((a,b) => a.code.localeCompare(b.code));
  if (evidence.length !== 232 || new Set(evidence.map((e) => e.code)).size !== 232) throw new Error('Cohort coverage must be 232 codes');
  const lines = ['# THIP cohort mapping — 232 รหัส', '', 'Generated from the verbatim dictionary, current registered SQL and structural audit. ทุกสูตรยังไม่ผ่าน hospital publication approval. ไม่มีการเรียกฐานจริง.', '', 'JSON schema snapshot: 6,109 tables / 56,891 columns. Obsidian July snapshot: 6,617 tables / 81,554 columns. ต่าง snapshot; ไม่ใช้ชื่อคอลัมน์หรือ primary key รับรอง cardinality. `patient` PK = hos_guid, ไม่ใช่ HN; `person.patient_hn` ไม่ใช่ person.hn; `emp` แยกจาก `opduser`.', '', 'Inclusion/exclusion ที่ยังไม่ได้แยกจากนิยามจะระบุ not-structured ไม่ได้แปลว่าไม่มีเงื่อนไข. Key/date/grain เป็น candidate ต้องยืนยันกับโรงพยาบาล. Query hash ใช้ SQL เต็มของ single-code query สำหรับ native; external ใช้ branch hash. Cadence THIP 1,552 ช่องและ monitoring 2,784 ช่องคงเดิม.', ''];
  const sqlBlock = (sql) => sql.split('\n').map((line) => line.trimEnd()).join('\n');
  for (const e of evidence) lines.push(`## ${e.code}`, '', `PDF physical ${e.pdfPage}; printed ${e.printedPages.join(', ')} · ${e.reviewStatus} · ${e.ruleVersion}`, '', `ตัวตั้ง: ${e.numeratorDefinition ?? 'ยังไม่มีหลักฐาน'}`, '', `ตัวหาร / population: ${e.denominatorDefinition ?? 'ยังไม่มีหลักฐาน'}`, '', `Grain: ${e.currentGrain}. Key candidates: ${e.keyCandidates.join(', ') || 'รอตรวจ SQL'}. Date candidates: ${e.eventDateCandidates.join(', ') || 'รอตรวจ SQL'}.`, '', `Unit: ${e.dictionaryUnit}; formula: ${e.formula}. Window: ${e.observationWindow}`, '', `Inclusion: ${e.inclusion.join('; ') || 'ยังไม่ structured — อ่าน definition ต้นฉบับ'}. Exclusion: ${e.exclusion.join('; ') || 'ยังไม่ structured — อ่าน definition ต้นฉบับ'}.`, '', '```sql', `-- numerator (${e.numeratorKind})`, sqlBlock(e.numeratorSql), `-- denominator (${e.denominatorKind})`, sqlBlock(e.denominatorSql), '-- outer FROM / source', sqlBlock(e.sourceSql), '-- outer cohort predicate', sqlBlock(e.cohortSql ?? '-- none; inspect source/base filters'), '```', '', ...e.limitations.map((l) => `- ${l.replace(/\n/g, ' ')}`), '', `Source tables: ${e.sourceTables.join(', ')}. SQL SHA256: ${e.querySha256}`, '');
  const profiles = { schemaVersion: 'cohort-profile/1', approval: 'unapproved', profiles: cohortProfiles.map(({ key, title, scope, explanation, query, metrics }) => { registry.assertRegisteredReadOnlyQuery(query); return { key, title, scope, explanation, sql: query.sql, sqlSha256: hash(query.sql), metrics: metrics.map(({key,label}) => ({key,label})) }; }), representativeBranches: registry.registeredBranches.filter((sql) => ['DH0101','DH0112','CE0102','HH0102','HE0101','SH0101'].includes(branchCodeOf(sql))).map((sql) => ({ code: branchCodeOf(sql), sql })) };
  const outputs = { 'src/data/thipCohortEvidence.json': JSON.stringify(evidence, null, 2) + '\n', 'docs/THIP-COHORT-MAPPING.md': lines.join('\n').replace(/\n+$/, '\n'), 'reporting/cohort_profiles.manifest.json': JSON.stringify(profiles, null, 2) + '\n' };
  for (const [path, text] of Object.entries(outputs)) { if (process.argv.includes('--check')) { if (readFileSync(path, 'utf8') !== text) throw new Error(`Generated cohort drift: ${path}`); } else writeFileSync(path, text, 'utf8'); }
  console.log(`${process.argv.includes('--check') ? 'Verified' : 'Generated'} 232 unapproved cohort definitions and 6 aggregate-only profiles`);
} finally { await server.close(); }
