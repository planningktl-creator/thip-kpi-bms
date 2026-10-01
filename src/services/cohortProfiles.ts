import { executeRegisteredQuery, type RegisteredQuery } from './queryRegistry';
import { aggregateQueryLane } from './aggregateQueryLane';
import type { BmsRuntimeConfig } from './bmsSession';
import { BmsRequestError } from './bmsErrors';
import { getFiscalMonthPeriods, fiscalPeriodEnd, bangkokDate } from '@/utils/fiscal';
import { cacheDigest, candidateCacheScope, candidateCacheExpiry, STEP_CACHE_VERSION, type CacheEntry, type CacheRepository } from './thipStepCache';

export type CohortProfileKey = 'patient' | 'visits' | 'admissions' | 'person' | 'employees' | 'accounts';
type Metric = { key: string; label: string; expression: string };
export type CohortProfileDefinition = { key: CohortProfileKey; title: string; scope: 'current-register' | 'selected-month'; explanation: string; base: string; metrics: readonly Metric[]; query: RegisteredQuery };
export type CohortProfileResult = {
  key: CohortProfileKey; fiscalYear: number; fiscalMonth: number; series: 'cohort-profile'; ruleVersion: 'cohort-profile/1';
  status: 'pending' | 'running' | 'success' | 'zero-cohort' | 'unverified-source' | 'missing-source' | 'future';
  metrics: Record<string, number | null>; reason: string | null; observedAt: string | null; expiresAt: number | null;
  origin: 'cache' | 'query' | null; latencyMs: number | null; approval: 'unapproved';
};
const metric = (key: string, label: string, expression: string): Metric => ({ key, label, expression });
const count = (column: string) => `COUNT(DISTINCT ${column})`;
const missing = (column: string) => `COUNT(*) FILTER (WHERE ${column} IS NULL)`;
const duplicate = (column: string) => `COUNT(${column}) - COUNT(DISTINCT ${column})`;
function define(key: CohortProfileKey, title: string, scope: CohortProfileDefinition['scope'], explanation: string, base: string, metrics: Metric[]): CohortProfileDefinition {
  const sql = `WITH ${base}, stats AS (SELECT ${metrics.map((m) => `(${m.expression})::bigint AS ${m.key}`).join(',\n')} FROM base)
SELECT '${key}'::text AS profile_key, metric.metric_key::text, metric.count_value
FROM stats CROSS JOIN LATERAL (VALUES ${metrics.map((m) => `('${m.key}', stats.${m.key})`).join(',\n')}) AS metric(metric_key, count_value)`;
  return { key, title, scope, explanation, base, metrics, query: { key: `cohortProfile_${key}`, description: title, sql } };
}
const identity = (prefix = '') => [metric('rows', 'จำนวนแถวทะเบียน', 'COUNT(*)'), metric('distinct_hn', 'HN ไม่ซ้ำ', count(`${prefix}hn_key`)), metric('distinct_cid', 'CID ไม่ซ้ำที่ไม่ว่าง', count(`${prefix}cid_key`)), metric('missing_hn', 'แถวที่ HN ว่าง', missing(`${prefix}hn_key`)), metric('missing_cid', 'แถวที่ CID ว่าง', missing(`${prefix}cid_key`)), metric('duplicate_hn_rows', 'แถว HN ซ้ำเพิ่มเติม', duplicate(`${prefix}hn_key`)), metric('duplicate_cid_rows', 'แถว CID ซ้ำเพิ่มเติม', duplicate(`${prefix}cid_key`))];
export const cohortProfiles: readonly CohortProfileDefinition[] = [
  define('patient', 'ทะเบียนผู้ป่วย', 'current-register', 'ทะเบียน ณ เวลาตรวจ; HN ไม่ซ้ำไม่เท่ากับคนไม่ซ้ำตาม CID และไม่ใช่ยอดย้อนหลัง', `base AS (SELECT NULLIF(TRIM(hn), '') AS hn_key, NULLIF(TRIM(cid), '') AS cid_key FROM patient)`, identity()),
  define('visits', 'บริการจาก ovst', 'selected-month', 'นับตาม vstdate; แยก VN ที่ผูก/ไม่ผูก AN ไม่ถือว่าทุกแถวเป็น OPD เฉพาะ และห้ามบวกคนรายเดือนเป็นคนทั้งปี', `base AS (SELECT NULLIF(TRIM(vn), '') AS visit_key, NULLIF(TRIM(hn), '') AS hn_key, NULLIF(TRIM(an), '') AS admission_key FROM ovst WHERE vstdate >= :start_date AND vstdate < :end_date)`, [
    metric('rows', 'แถวบริการในเดือน', 'COUNT(*)'), metric('distinct_visits', 'VN ไม่ซ้ำ', count('visit_key')), metric('distinct_patients', 'HN ไม่ซ้ำในเดือน', count('hn_key')),
    metric('linked_admission_visits', 'VN ที่ผูก AN', 'COUNT(DISTINCT visit_key) FILTER (WHERE admission_key IS NOT NULL)'), metric('unlinked_admission_visits', 'VN ที่ไม่ผูก AN', 'COUNT(DISTINCT visit_key) FILTER (WHERE admission_key IS NULL)'),
    metric('mixed_admission_visits', 'VN ซ้ำที่มีทั้งผูก/ไม่ผูก AN', `(SELECT COUNT(*) FROM (SELECT visit_key FROM base WHERE visit_key IS NOT NULL GROUP BY visit_key HAVING BOOL_OR(admission_key IS NULL) AND BOOL_OR(admission_key IS NOT NULL)) inconsistent)`),
    metric('missing_vn', 'แถวที่ VN ว่าง', missing('visit_key')), metric('missing_hn', 'แถวที่ HN ว่าง', missing('hn_key')), metric('duplicate_vn_rows', 'แถว VN ซ้ำเพิ่มเติม', duplicate('visit_key')),
  ]),
  define('admissions', 'ผู้ป่วยใน: รับเข้า/จำหน่าย', 'selected-month', 'รับเข้าตาม regdate และจำหน่ายตาม dchdate เป็นคนละยอด; นับ AN สำหรับครั้งนอน และ HN สำหรับคน ไม่บวกสองยอดเป็นผู้ป่วยทั้งหมด', `base AS (SELECT NULLIF(TRIM(an), '') AS admission_key, NULLIF(TRIM(hn), '') AS hn_key, regdate >= :start_date AND regdate < :end_date AS admitted, dchdate >= :start_date AND dchdate < :end_date AS discharged FROM ipt WHERE (regdate >= :start_date AND regdate < :end_date) OR (dchdate >= :start_date AND dchdate < :end_date))`, [
    metric('rows', 'แถว admission ที่เกี่ยวข้อง', 'COUNT(*)'), metric('admitted_episodes', 'AN รับเข้าในเดือน', 'COUNT(DISTINCT admission_key) FILTER (WHERE admitted)'), metric('discharged_episodes', 'AN จำหน่ายในเดือน', 'COUNT(DISTINCT admission_key) FILTER (WHERE discharged)'),
    metric('admitted_patients', 'HN รับเข้าไม่ซ้ำ', 'COUNT(DISTINCT hn_key) FILTER (WHERE admitted)'), metric('discharged_patients', 'HN จำหน่ายไม่ซ้ำ', 'COUNT(DISTINCT hn_key) FILTER (WHERE discharged)'), metric('missing_hn', 'แถวที่ HN ว่าง', missing('hn_key')), metric('missing_an', 'แถวที่ AN ว่าง', missing('admission_key')), metric('duplicate_an_rows', 'แถว AN ซ้ำเพิ่มเติม', duplicate('admission_key')),
  ]),
  define('person', 'บุคคลและการเชื่อมทะเบียน', 'current-register', 'เชื่อม patient_hn กับ hn หลัง aggregate คู่เชื่อมให้เหลือหนึ่งแถวต่อ HN; CID ใช้ตรวจความสอดคล้อง ไม่รวมคนหรือ fallback CID อัตโนมัติ จำนวนกลุ่มตรวจสอบอาจซ้อนกัน', `people AS (SELECT person_id, NULLIF(TRIM(patient_hn), '') AS hn_key, NULLIF(TRIM(cid), '') AS cid_key FROM person),
patients AS (SELECT NULLIF(TRIM(hn), '') AS hn_key, NULLIF(TRIM(cid), '') AS cid_key FROM patient),
patient_groups AS (SELECT hn_key, COUNT(*) AS patient_rows, ARRAY_AGG(DISTINCT cid_key) FILTER (WHERE cid_key IS NOT NULL) AS cid_keys FROM patients WHERE hn_key IS NOT NULL GROUP BY hn_key),
person_groups AS (SELECT hn_key, COUNT(*) AS person_rows FROM people WHERE hn_key IS NOT NULL GROUP BY hn_key),
base AS (SELECT p.*, t.hn_key IS NOT NULL AS linked, COALESCE(p.cid_key = ANY(t.cid_keys), FALSE) AS agrees,
p.cid_key IS NOT NULL AND COALESCE(CARDINALITY(t.cid_keys), 0) > CASE WHEN COALESCE(p.cid_key = ANY(t.cid_keys), FALSE) THEN 1 ELSE 0 END AS conflicts,
COALESCE(t.patient_rows, 0) > 1 OR COALESCE(g.person_rows, 0) > 1 AS ambiguous, COALESCE(CARDINALITY(t.cid_keys), 0) > 0 AS has_patient_cid
FROM people p LEFT JOIN patient_groups t ON t.hn_key=p.hn_key LEFT JOIN person_groups g ON g.hn_key=p.hn_key)`, [
    ...identity(), metric('distinct_persons', 'person_id ไม่ซ้ำ', count('person_id')), metric('linked_hn', 'แถว person ที่เชื่อม HN ได้', 'COUNT(*) FILTER (WHERE linked)'), metric('unlinked_hn', 'แถว person ที่เชื่อม HN ไม่ได้', 'COUNT(*) FILTER (WHERE NOT linked)'), metric('cid_agreement', 'เชื่อม HN และพบ CID ตรงกัน', 'COUNT(*) FILTER (WHERE agrees)'), metric('cid_conflict', 'เชื่อม HN แต่พบ CID ขัดแย้ง', 'COUNT(*) FILTER (WHERE conflicts)'), metric('ambiguous_link', 'แถวที่มีความสัมพันธ์หนึ่งต่อหลาย', 'COUNT(*) FILTER (WHERE ambiguous)'), metric('cid_unassessable', 'CID ของ person/คู่เชื่อมไม่ครบ', 'COUNT(*) FILTER (WHERE cid_key IS NULL OR NOT has_patient_cid)'),
  ]),
  define('employees', 'ทะเบียนบุคลากร emp', 'selected-month', 'Candidate headcount ณ วันสุดท้ายของเดือน: เริ่มงานไม่เกินวันนั้นและยังไม่สิ้นสุดงาน; end date ว่างถือว่ายังทำงานแบบ candidate ต้องเทียบ HR ก่อนใช้เป็นตัวหาร', `base AS (SELECT emp_id, NULLIF(TRIM(emp_cid), '') AS cid_key, emp_work_begindate AS started, emp_resign_enddate AS ended FROM emp)`, [
    metric('rows', 'แถวทะเบียน emp ปัจจุบัน', 'COUNT(*)'), metric('distinct_staff', 'emp_id ไม่ซ้ำในทะเบียน', count('emp_id')), metric('distinct_cid', 'CID ไม่ซ้ำที่ไม่ว่าง', count('cid_key')), metric('missing_cid', 'เจ้าหน้าที่ที่ CID ว่าง', missing('cid_key')), metric('duplicate_cid_rows', 'แถว CID ซ้ำเพิ่มเติม', duplicate('cid_key')),
    metric('missing_start', 'ไม่ระบุวันที่เริ่มงาน', 'COUNT(*) FILTER (WHERE started IS NULL)'), metric('missing_end', 'ไม่ระบุวันสิ้นสุดงาน (อาจยังทำงาน)', 'COUNT(*) FILTER (WHERE ended IS NULL)'), metric('invalid_dates', 'วันสิ้นสุดก่อนเริ่มงาน', 'COUNT(*) FILTER (WHERE ended < started)'), metric('unknown_temporal_staff', 'emp_id ที่ยังจัดกลุ่มตามเวลาไม่ได้', 'COUNT(DISTINCT emp_id) FILTER (WHERE started IS NULL OR ended < started)'),
    metric('candidate_month_end_headcount', 'Candidate emp_id ที่ทำงาน ณ สิ้นเดือน', `COUNT(DISTINCT emp_id) FILTER (WHERE started IS NOT NULL AND started <= CAST(:end_date AS date) - 1 AND (ended IS NULL OR ended >= CAST(:end_date AS date) - 1) AND (ended IS NULL OR ended >= started))`),
  ]),
  define('accounts', 'บัญชีผู้ใช้ HOSxP', 'current-register', 'บัญชี opduser ณ เวลาตรวจ ไม่ใช่จำนวนบุคลากรทั้งหมด ไม่อ่าน password หรือข้อมูลสิทธิ์', `base AS (SELECT NULLIF(TRIM(loginname), '') AS account_key, NULLIF(TRIM(cid), '') AS cid_key FROM opduser)`, [metric('rows', 'แถวบัญชี', 'COUNT(*)'), metric('distinct_accounts', 'loginname ไม่ซ้ำ', count('account_key')), metric('distinct_cid', 'CID ไม่ซ้ำที่ไม่ว่าง', count('cid_key')), metric('missing_cid', 'บัญชีที่ CID ว่าง', missing('cid_key')), metric('duplicate_cid_rows', 'แถว CID ซ้ำเพิ่มเติม', duplicate('cid_key'))]),
];
export const cohortProfileByKey = new Map(cohortProfiles.map((profile) => [profile.key, profile]));
export function emptyProfile(key: CohortProfileKey, fiscalYear: number, fiscalMonth: number): CohortProfileResult {
  return { key, fiscalYear, fiscalMonth, series: 'cohort-profile', ruleVersion: 'cohort-profile/1', status: 'pending', metrics: Object.fromEntries(cohortProfileByKey.get(key)!.metrics.map((m) => [m.key, null])), reason: 'ยังไม่โหลด', observedAt: null, expiresAt: null, origin: null, latencyMs: null, approval: 'unapproved' };
}
export function validateProfileRows(input: unknown, key: CohortProfileKey): Record<string, number> {
  const profile = cohortProfileByKey.get(key)!; const found = new Map<string, number>();
  if (!Array.isArray(input)) throw new Error('Invalid profile response');
  for (const row of input) {
    if (!row || typeof row !== 'object' || Array.isArray(row) || Object.keys(row).sort().join(',') !== 'count_value,metric_key,profile_key' || row.profile_key !== key || !profile.metrics.some((m) => m.key === row.metric_key) || found.has(row.metric_key)) throw new Error('Invalid profile aggregate');
    if (!['number', 'string'].includes(typeof row.count_value) || String(row.count_value).trim() === '') throw new Error('Invalid profile count');
    const value = Number(row.count_value); if (!Number.isSafeInteger(value) || value < 0) throw new Error('Invalid profile count');
    found.set(row.metric_key, value);
  }
  if (found.size !== profile.metrics.length) throw new Error('Incomplete profile response');
  return Object.fromEntries(found);
}
export function profileIsFuture(fiscalYear: number, fiscalMonth: number, now = new Date()): boolean {
  return getFiscalMonthPeriods(fiscalYear)[fiscalMonth - 1]!.periodStart > bangkokDate(now);
}
type ProfileEntry = CacheEntry & { series: 'cohort-profile'; fiscalMonth: number; metrics: Record<string, number> };
/** Patient/account registers are labelled current snapshots, never backdated to the selected month. */
export async function loadCohortProfile(runtime: BmsRuntimeConfig, key: CohortProfileKey, fiscalYear: number, fiscalMonth: number, repository: CacheRepository, signal: AbortSignal, fresh = false): Promise<CohortProfileResult> {
  if (!Number.isInteger(fiscalYear) || fiscalYear < 2000 || fiscalYear > 2100 || !Number.isInteger(fiscalMonth) || fiscalMonth < 1 || fiscalMonth > 12 || !cohortProfileByKey.has(key)) throw new Error('Invalid profile context');
  const profile = cohortProfileByKey.get(key)!; const period = getFiscalMonthPeriods(fiscalYear)[fiscalMonth - 1]!;
  const initial = emptyProfile(key, fiscalYear, fiscalMonth);
  if (profile.scope === 'selected-month' && profileIsFuture(fiscalYear, fiscalMonth)) return { ...initial, status: 'future', reason: 'เดือนอนาคตตาม Asia/Bangkok; ไม่เติมศูนย์' };
  const scope = await candidateCacheScope(runtime);
  const fingerprint = await cacheDigest([profile.query.sql, fiscalYear, fiscalMonth, 'cohort-profile/1']);
  const cacheKey = `${scope}:${fiscalYear}:cohort-profile:${key}:${fiscalMonth}:${fingerprint}`;
  await repository.prune(Date.now());
  function result(metrics: Record<string, number>, observedAt: string, expiresAt: number, origin: 'query' | 'cache', latencyMs: number | null): CohortProfileResult {
    const empty = metrics.rows === 0;
    const unverified = key === 'employees' || (empty && profile.scope === 'current-register');
    return { ...initial, metrics, observedAt, expiresAt, origin, latencyMs, status: unverified ? 'unverified-source' : empty ? 'zero-cohort' : 'success', reason: unverified ? empty ? 'ทะเบียนว่าง; ยังใช้เป็น population/บุคลากรทั้งหมดไม่ได้' : 'emp ยังไม่ยืนยันความครบกับ HR; headcount เป็น candidate' : empty ? 'ไม่พบ episode ในช่วงนี้; ยอดฐานเป็นศูนย์ ไม่ใช่ค่าอัตรา' : profile.explanation };
  }
  if (!fresh) {
    try {
      const cached = await repository.read(cacheKey) as ProfileEntry | undefined;
      if (cached && cached.key === cacheKey && cached.scope === scope && cached.version === STEP_CACHE_VERSION && cached.series === 'cohort-profile' && cached.code === key && cached.fiscalYear === fiscalYear && cached.fiscalMonth === fiscalMonth && cached.fingerprint === fingerprint && cached.ruleVersion === 'cohort-profile/1' && Number.isFinite(Date.parse(cached.observedAt)) && Date.parse(cached.observedAt) <= Date.now() && cached.expiresAt > Date.now() && cached.expiresAt <= candidateCacheExpiry(fiscalYear, Date.parse(cached.observedAt))) {
        const metrics = validateProfileRows(Object.entries(cached.metrics).map(([metric_key, count_value]) => ({ profile_key: key, metric_key, count_value })), key);
        if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
        return result(metrics, cached.observedAt, cached.expiresAt, 'cache', null);
      }
    } catch { if (signal.aborted) throw new DOMException('Cancelled', 'AbortError'); }
  }
  const started = Date.now();
  const payload = await aggregateQueryLane(runtime).run(signal, () => executeRegisteredQuery(profile.query, runtime, { start_date: { value: period.periodStart, value_type: 'date' }, end_date: { value: fiscalPeriodEnd(fiscalYear, fiscalMonth), value_type: 'date' } }, runtime.marketplaceToken, { signal }));
  const metrics = validateProfileRows(payload.data ?? payload.result, key); const observedAt = new Date().toISOString();
  if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
  const expiresAt = candidateCacheExpiry(fiscalYear, Date.parse(observedAt));
  const entry: ProfileEntry = { key: cacheKey, scope, version: STEP_CACHE_VERSION, fiscalYear, fiscalMonth, code: key, fingerprint, ruleVersion: 'cohort-profile/1', observedAt, expiresAt, facts: [], series: 'cohort-profile', metrics };
  try { await repository.write(entry, signal); } catch { /* The resilient repository reports persistent-storage failures. */ }
  if (signal.aborted) throw new DOMException('Cancelled', 'AbortError');
  return result(metrics, observedAt, expiresAt, 'query', Date.now() - started);
}
export function profileFailure(error: unknown): { reason: string; stop: boolean; global: boolean; session: boolean; retryAt: number } {
  const request = error instanceof BmsRequestError ? error : null; const status = request?.messageCode ?? request?.status;
  const session = status === 401 || status === 403; const rate = status === 429;
  return { reason: session ? 'session หมดอายุ; เชื่อมต่อใหม่' : rate ? 'พักตาม Retry-After; กดโหลดอีกครั้งเมื่อครบเวลา' : request?.failure === 'timeout' ? 'query timeout; ไม่แบ่งช่วงเวลาโดยเดา' : request?.status === 404 ? 'HTTP 404; ตรวจ route/config' : 'อ่าน aggregate ไม่สำเร็จ; ตรวจ source/รูปแบบข้อมูล', stop: session || rate, global: request?.failure === 'network' || (request?.failure === 'http' && (request.status ?? 0) >= 500), session, retryAt: rate ? Date.now() + (request?.retryAfterMs ?? 1000) : 0 };
}
