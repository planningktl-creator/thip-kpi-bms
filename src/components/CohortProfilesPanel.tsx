import { useEffect, useRef, useState } from 'react';
import { cohortProfiles, emptyProfile, loadCohortProfile, profileFailure, type CohortProfileResult, type CohortProfileKey } from '@/services/cohortProfiles';
import type { CacheRepository } from '@/services/thipStepCache';
import type { BmsRuntimeConfig } from '@/services/bmsSession';
import { BmsRequestError } from '@/services/bmsErrors';
import { aggregateQueryLane } from '@/services/aggregateQueryLane';
import { formatThaiDateTime, getFiscalMonthPeriods } from '@/utils/fiscal';

type Props = { runtime: BmsRuntimeConfig | null; fiscalYear: number; repository: CacheRepository; clearEpoch: number; locked: boolean; onSourceHold(error: BmsRequestError): void };
const labels: Record<CohortProfileResult['status'], string> = { pending: 'ยังไม่โหลด', running: 'รอคิว/กำลังอ่าน', success: 'อ่านยอดฐานสำเร็จ', 'zero-cohort': 'ไม่มี episode ในช่วงนี้', 'unverified-source': 'ทะเบียนยังไม่ยืนยัน', 'missing-source': 'อ่าน source ไม่สำเร็จ', future: 'เดือนอนาคต' };
const highlights: Record<CohortProfileKey, string[]> = { patient: ['distinct_hn'], visits: ['distinct_visits', 'distinct_patients'], admissions: ['admitted_episodes', 'discharged_episodes'], person: ['distinct_persons', 'ambiguous_link'], employees: ['candidate_month_end_headcount', 'unknown_temporal_staff'], accounts: ['distinct_accounts'] };
export function CohortProfilesPanel({ runtime, fiscalYear, repository, clearEpoch, locked, onSourceHold }: Props) {
  const [month, setMonth] = useState(1);
  const [state, setState] = useState<{ runtime: BmsRuntimeConfig | null; fiscalYear: number; month: number; epoch: number; rows: CohortProfileResult[] } | null>(null);
  const [busy, setBusy] = useState(false);
  const [retryAt, setRetryAt] = useState(0); const [now, setNow] = useState(Date.now()); const [sessionBlocked, setSessionBlocked] = useState(false);
  const abort = useRef<AbortController | null>(null);
  useEffect(() => { abort.current?.abort(); setState(null); setBusy(false); setRetryAt(0); setSessionBlocked(false); return () => abort.current?.abort(); }, [runtime, fiscalYear, month, clearEpoch]);
  useEffect(() => { if (!retryAt || retryAt <= Date.now()) return; const timer = setInterval(() => { const value = Date.now(); setNow(value); if (value >= retryAt) clearInterval(timer); }, 500); return () => clearInterval(timer); }, [retryAt]);
  const current = state?.runtime === runtime && state.fiscalYear === fiscalYear && state.month === month && state.epoch === clearEpoch ? state.rows : cohortProfiles.map((p) => emptyProfile(p.key, fiscalYear, month));
  function cancel() {
    abort.current?.abort(); setBusy(false);
    setState((previous) => previous ? { ...previous, rows: previous.rows.map((row) => row.status === 'running' ? { ...row, status: 'pending', reason: 'ยกเลิกยอดฐาน; ยังไม่มีผลวัด' } : row) } : previous);
  }
  async function load(fresh: boolean) {
    if (!runtime || locked || sessionBlocked || Date.now() < retryAt) return;
    abort.current?.abort(); const controller = new AbortController(); abort.current = controller;
    aggregateQueryLane(runtime).allow();
    setBusy(true); let failures = 0;
    const rows = cohortProfiles.map((p) => emptyProfile(p.key, fiscalYear, month));
    const publish = () => { if (!controller.signal.aborted) setState({ runtime, fiscalYear, month, epoch: clearEpoch, rows: rows.map((r) => ({ ...r, metrics: { ...r.metrics } })) }); };
    publish();
    for (let index = 0; index < cohortProfiles.length; index++) {
      if (controller.signal.aborted) break;
      rows[index] = { ...rows[index], status: 'running', reason: 'ใช้คิวเดียวกับ KPI; ไม่ส่งคำขอซ้อน' }; publish();
      try { rows[index] = await loadCohortProfile(runtime, rows[index].key, fiscalYear, month, repository, controller.signal, fresh); failures = 0; }
      catch (error) {
        if (controller.signal.aborted) break;
        const info = profileFailure(error); rows[index] = { ...emptyProfile(rows[index].key, fiscalYear, month), status: 'missing-source', reason: info.reason };
        failures = info.global ? failures + 1 : 0;
        if (info.stop || failures >= 3) {
          const request = error instanceof BmsRequestError ? error : new BmsRequestError('api', 'http', 'Source unavailable', 503);
          aggregateQueryLane(runtime).hold(request); onSourceHold(request); setSessionBlocked(info.session); setRetryAt(info.retryAt); publish(); break;
        }
      }
      publish();
    }
    if (!controller.signal.aborted) setBusy(false);
  }
  return <section className="cohort-panel" aria-labelledby="cohort-heading">
    <div className="cohort-heading"><div><h2 id="cohort-heading">ยอดฐานและคุณภาพการเชื่อมข้อมูล</h2><p>ยอดเพื่อสอบทาน · ไม่ใช้แทนตัวหารของทุก KPI · ไม่แสดงรหัสบุคคล</p></div>
      <label>เดือนสอบทาน<select aria-label="เดือนสอบทานยอดฐาน" value={month} onChange={(event) => { cancel(); setMonth(Number(event.target.value)); }}>{getFiscalMonthPeriods(fiscalYear).map((period) => <option key={period.fiscalMonth} value={period.fiscalMonth}>{period.label}</option>)}</select></label>
    </div>
    <div className="step-controls"><button className="secondary-button" disabled={!runtime || busy || locked || sessionBlocked || retryAt > now} onClick={() => { void load(false); }}>โหลด/ใช้ cache ยอดฐาน</button><button className="secondary-button" disabled={!runtime || busy || locked || sessionBlocked || retryAt > now} onClick={() => { void load(true); }}>อ่านยอดฐานใหม่</button><button className="secondary-button" disabled={!busy} onClick={cancel}>ยกเลิกยอดฐาน</button></div>
    <p role="status" aria-live="polite">{busy ? 'กำลังสอบทานยอดฐานผ่านคิวร่วม' : 'ยอดฐานแยกจากผล KPI'}{retryAt > now && ` · รออีก ${Math.ceil((retryAt - now) / 1000)} วินาที`}</p>
    <div className="cohort-grid">{cohortProfiles.map((profile, index) => { const row = current[index]; return <article className="cohort-card" key={profile.key} data-profile={profile.key}>
      <h3>{profile.title}</h3><p>{profile.scope === 'current-register' ? 'ทะเบียนปัจจุบัน ณ เวลาตรวจ — ไม่ใช่ยอดย้อนหลัง' : `ช่วงสอบทาน ${getFiscalMonthPeriods(fiscalYear)[month - 1].label}`}</p><strong>{labels[row.status]}{row.origin === 'cache' && ' · จาก cache'}</strong>
      <dl className="cohort-highlights">{highlights[profile.key].map((key) => <div key={key}><dt>{profile.metrics.find((m) => m.key === key)!.label}</dt><dd>{row.metrics[key]?.toLocaleString('th-TH') ?? '—'}</dd></div>)}</dl>
      <details><summary>ดูยอดและวิธีนับ</summary><dl>{profile.metrics.map((m) => <div key={m.key}><dt>{m.label}</dt><dd>{row.metrics[m.key]?.toLocaleString('th-TH') ?? '—'}</dd></div>)}</dl><p>{profile.explanation}</p></details>
      <p>{row.reason}</p>{row.observedAt && <small>อ่านเมื่อ {formatThaiDateTime(row.observedAt)}{row.expiresAt && ` · cache หมดอายุ ${formatThaiDateTime(row.expiresAt)}`}</small>}
    </article>; })}</div>
  </section>;
}
