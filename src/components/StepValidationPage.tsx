import { useEffect, useRef, useState, useMemo, useCallback, memo, useDeferredValue } from 'react';
import { ArrowRight, Pause, Play, RefreshCw, Square } from 'lucide-react';
import type { BmsRuntimeConfig } from '@/services/bmsSession';
import { createThipStepLoader, type StepSnapshot, type ThipStepLoader, type CandidateAggregate } from '@/services/thipStepLoader';
import { runtimeCatalogue as thipCatalogue, runtimeCatalogueByCode as thipCatalogueByCode } from '@/data/thipRuntime';
import { monitoringUnitLabels } from '@/monitoring/rules';
import { getReportingCadence, reportingCadenceLabels } from '@/data/thipReporting';
import { formatThaiDate, formatThaiDateTime, getCurrentFiscalYear, formatFiscalYear, toBuddhistYear } from '@/utils/fiscal';
import { groupMeta } from '@/data/thipMeta';
import type { IndicatorGroup } from '@/types/thip';
import { createStepCache, IndexedDbCacheRepository, ResilientCacheRepository } from '@/services/thipStepCache';
import { CohortProfilesPanel } from './CohortProfilesPanel';
import { aggregateQueryLane } from '@/services/aggregateQueryLane';
import { loadThipEvidence } from '@/data/thipEvidenceLoader';
import type { CohortDefinition } from '@/data/cohortTypes';

const cacheListeners = new Set<() => void>();
let persistentCacheUnavailable = false;
const cacheRepository = new ResilientCacheRepository(new IndexedDbCacheRepository(), () => {
  persistentCacheUnavailable = true; cacheListeners.forEach((listener) => listener());
});

type Props = { runtime: BmsRuntimeConfig | null; fiscalYear: number; onFiscalYearChange(year: number): void; group: IndicatorGroup | 'all'; search: string; onSearchChange(value: string): void; onGroupChange(value: IndicatorGroup | 'all'): void; onMonitoring(): void };
const statusLabels = { pending: 'รอโหลด', running: 'กำลังโหลด', success: 'query สำเร็จ', failed: 'ล้มเหลว', skipped: 'รอ external source' };
const number = (value: number | null) => value === null ? '—' : value.toLocaleString('th-TH', { maximumFractionDigits: 4 });

function AggregateDetails({ rows }: { rows: readonly CandidateAggregate[] }) {
  const [opened, setOpened] = useState(false);
  return <details onToggle={(event) => setOpened(event.currentTarget.open)}><summary>ดู aggregate {rows.length} งวด · มีค่า {rows.filter((row) => row.sourceValue !== null).length} งวด</summary>
    {opened && <div className="step-detail-scroll"><table><caption>ผลรายงวดเพื่อสอบทาน ยังไม่รับรอง</caption><thead><tr>{['เริ่มงวด', 'ตัวตั้ง', 'ตัวหาร', 'source value', 'คำนวณสอบทาน', 'หน่วย / version / เหตุผล'].map((label) => <th scope="col" key={label}>{label}</th>)}</tr></thead><tbody>{rows.map((row) => <tr key={row.fiscalMonth}>
      <th scope="row">{formatThaiDate(row.periodStart)}</th><td>{number(row.numerator)}</td><td>{number(row.denominator)}</td><td>{number(row.sourceValue)}</td><td>{number(row.derivedValue)}{row.discrepancy && ' (ต่างจาก source)'}</td>
      <td>{monitoringUnitLabels[row.unit]} · {row.ruleVersion}<p>{row.reason ?? 'มี aggregate; สูตรยังไม่รับรอง'}</p><small>อ่านเมื่อ {formatThaiDateTime(row.observedAt)} · data-through/refresh ยังไม่ยืนยัน</small></td>
    </tr>)}</tbody></table></div>}
  </details>;
}

function CohortDetails({ code }: { code: string }) {
  const [cohort, setCohort] = useState<CohortDefinition | null>(null);
  const [opened, setOpened] = useState(false);
  const [failed, setFailed] = useState(false);
  useEffect(() => { if (!opened || cohort) return; let cancelled = false; void loadThipEvidence(code).then((evidence) => { if (!cancelled) setCohort(evidence?.cohort ?? null); }).catch(() => { if (!cancelled) setFailed(true); }); return () => { cancelled = true; }; }, [opened, code, cohort]);
  return <details className="cohort-evidence" onToggle={(event) => setOpened(event.currentTarget.open)}><summary>นิยามตัวตั้ง–ตัวหาร / วิธีนับ</summary>
    {opened && (cohort ? <>
    <p><strong>ตัวตั้งตาม THIP:</strong> {cohort.numeratorDefinition ?? 'ยังไม่มีหลักฐาน'}</p>
    <p><strong>ตัวหารตาม THIP:</strong> {cohort.denominatorDefinition ?? 'ยังไม่มีหลักฐาน'}</p>
    <p>สูตร: {cohort.formula} · หน่วยตาม dictionary: {cohort.dictionaryUnit}</p>
    <p>หน่วยนับใน SQL: {cohort.currentGrain} · ตัวตั้ง {cohort.numeratorKind} / ตัวหาร {cohort.denominatorKind}</p>
    <p>คีย์ที่รอยืนยัน: {cohort.keyCandidates.join(', ') || 'รอตรวจ source'}<br />วันที่ที่รอยืนยัน: {cohort.eventDateCandidates.join(', ') || 'รอตรวจ source'}</p>
    <p>Observation window: {cohort.observationWindow}</p>
    <p>Inclusion: {cohort.inclusion.join('; ') || 'ยังไม่ได้แยกจากนิยาม'}<br />Exclusion: {cohort.exclusion.join('; ') || 'ยังไม่ได้แยกจากนิยาม'}</p>
    <p>PDF หน้า {cohort.pdfPage} (หน้าพิมพ์ {cohort.printedPages.join(', ')}) · {cohort.ruleVersion} · ยังไม่รับรอง</p>
    <ul>{cohort.limitations.map((reason, index) => <li key={index}>{reason}</li>)}</ul>
    </> : <p role="status">{failed ? 'โหลดหลักฐานไม่สำเร็จ; ปิดแล้วเปิดเพื่อลองอีกครั้ง' : 'กำลังโหลดหลักฐาน cohort…'}</p>)}
  </details>;
}

export function StepValidationPage({ runtime, fiscalYear, onFiscalYearChange, group, search, onSearchChange, onGroupChange, onMonitoring }: Props) {
  const [snapshot, setSnapshot] = useState<StepSnapshot | null>(null);
  const [refresh, setRefresh] = useState(0);
  const [now, setNow] = useState(Date.now());
  const [cacheUnavailable, setCacheUnavailable] = useState(persistentCacheUnavailable);
  const [stopped, setStopped] = useState(false);
  const [clearing, setClearing] = useState(false);
  const [clearIncomplete, setClearIncomplete] = useState(false);
  const [clearEpoch, setClearEpoch] = useState(0);
  const loader = useRef<ThipStepLoader | null>(null);
  const cacheAbort = useRef<AbortController | null>(null);
  const forceReload = useRef(false);
  const snapshotOwner = useRef<BmsRuntimeConfig | null>(null);
  useEffect(() => { const listener = () => setCacheUnavailable(true); cacheListeners.add(listener); return () => { cacheListeners.delete(listener); }; }, []);
  useEffect(() => {
    let alive = true;
    setSnapshot(null);
    if (!runtime || stopped) return;
    const abort = new AbortController(); cacheAbort.current = abort;
    const fresh = forceReload.current; forceReload.current = false;
    let controller: ThipStepLoader | null = null;
    void (async () => {
      let cache;
      try { cache = await createStepCache(runtime, fiscalYear, cacheRepository, abort.signal); if (fresh && !abort.signal.aborted) await cache.clear(); }
      catch { if (!abort.signal.aborted) setCacheUnavailable(true); }
      if (!alive || abort.signal.aborted) return;
      controller = createThipStepLoader(runtime, fiscalYear, (next) => { if (alive) { snapshotOwner.current = runtime; setSnapshot(next); } }, cache);
      loader.current = controller;
      await controller.start();
    })();
    return () => { alive = false; abort.abort(); controller?.cancel(); loader.current = null; };
  }, [runtime, fiscalYear, refresh, stopped]);
  function restart() {
    if (runtime) aggregateQueryLane(runtime).allow();
    cacheAbort.current?.abort(); loader.current?.cancel(); setSnapshot(null);
    forceReload.current = true; setClearIncomplete(false); setStopped(false); setRefresh((value) => value + 1);
  }
  async function clearCache() {
    cacheAbort.current?.abort(); loader.current?.cancel(); setSnapshot(null); setStopped(true); setClearing(true);
    setClearEpoch((value) => value + 1);
    setClearIncomplete(false);
    try { await cacheRepository.clear(); } catch { setClearIncomplete(true); } finally { setClearing(false); }
  }
  useEffect(() => {
    if (!snapshot?.retryAt || snapshot.state !== 'paused' || snapshot.retryAt <= Date.now()) return;
    setNow(Date.now());
    const timer = setInterval(() => { const value = Date.now(); setNow(value); if (value >= snapshot.retryAt) clearInterval(timer); }, 1000);
    return () => clearInterval(timer);
  }, [snapshot?.retryAt, snapshot?.state]);
  const current = snapshot?.fiscalYear === fiscalYear && runtime && snapshotOwner.current === runtime ? snapshot : null;
  const steps = useMemo(() => new Map(current?.steps.map((step) => [step.code, step])), [current?.steps]);
  const deferredSearch = useDeferredValue(search);
  const orderedCodes = useMemo(() => current ? current.steps.map((step) => step.code) : ['DH0101', 'DH0112', ...thipCatalogue.map((entry) => entry.code).filter((code) => !['DH0101', 'DH0112'].includes(code))], [Boolean(current)]);
  const visible = orderedCodes.map((code) => thipCatalogueByCode.get(code)!).filter((entry) => (group === 'all' || group === entry.group) && `${entry.code} ${entry.title}`.toLowerCase().includes(deferredSearch.toLowerCase().trim()));
  const visibleCodes = new Set(visible.map(entry => entry.code));
  const retryCode = useCallback((code: string) => { if (runtime) aggregateQueryLane(runtime).allow(); void loader.current?.retryFailed(code); }, [runtime]);
  const nonNull = current?.steps.flatMap((step) => step.rows).filter((row) => row.sourceValue !== null).length ?? 0;
  const years = [...new Set([fiscalYear, getCurrentFiscalYear(), ...Array.from({ length: 5 }, (_, i) => getCurrentFiscalYear() - i - 1)])].sort((a, b) => b - a);
  const busy = current?.state === 'running' || current?.state === 'pausing';
  const locked = Boolean(current?.blockedBySession) || (current?.retryAt ?? 0) > now;
  const saving = Boolean(current?.activeCode && steps.get(current.activeCode)?.status === 'success');
  return <div className="page-stack step-page">
    <header className="monitoring-heading"><div><h1>ตรวจข้อมูลทีละ KPI</h1><p>หนึ่งคำขอต่อรหัส · เว้น 1 วินาที · ผลรายงวด THIP {formatFiscalYear(fiscalYear)}</p></div><button className="secondary-button" onClick={onMonitoring}>ตารางรายเดือน <ArrowRight size={16} /></button></header>
    <div className="step-disclaimer"><strong>ข้อมูลจริงเพื่อสอบทาน — สูตรยังไม่รับรอง</strong><p>ผล query ไม่ใช่ผล THIP ที่รับรอง ไม่เพิ่ม approved coverage และไม่มีการส่งออกจากหน้านี้</p></div>
    <p className="monitoring-help">Cache aggregate อายุ 24 ชั่วโมง · ใช้ได้หลังตรวจ session เดิม · เวลาอ่านผลไม่ใช่ source freshness</p>
    {cacheUnavailable && <p role="status" className="step-pause-note">Cache ข้าม refresh ไม่พร้อม ใช้ memory ระหว่างเปิดเว็บและโหลดต่อได้</p>}
    {stopped && <p role="status">{clearIncomplete ? 'ล้างผลใน memory แล้ว; cache บนเครื่องยังล้างไม่ได้เพราะ storage ไม่พร้อม' : 'ล้าง cache แล้ว'} · กดโหลดใหม่ทั้งคิวเพื่อเริ่มอีกครั้ง</p>}
    <ol className="step-stages"><li>1 · Session และ PostgreSQL {runtime ? 'ตรวจผ่าน' : 'รอเชื่อมต่อ'}</li><li>2 · {current ? `คิว ${current.total} รหัส native + 55 external รอ source` : 'รอสร้างคิว'}</li><li>3 · {current?.activeCode ? `กำลังโหลด ${current.activeCode}` : current?.state === 'complete' ? 'ประมวลผลครบคิว' : current?.state === 'paused' ? 'พักคิว' : current?.state === 'cancelled' ? 'ยกเลิกคิว' : 'รอเริ่มโหลด'}</li></ol>
    <section className="monitoring-toolbar" aria-label="ค้นหาและกรองผลสอบทาน">
      <label>ปีงบประมาณ<select aria-label="เลือกปีงบประมาณ" value={fiscalYear} onChange={(event) => onFiscalYearChange(Number(event.target.value))}>{years.map((year) => <option key={year} value={year}>{toBuddhistYear(year)}</option>)}</select></label>
      <label className="monitoring-search">ค้นหารหัสหรือชื่อ<div><input aria-label="ค้นหารหัสหรือชื่อ KPI" value={search} onChange={(event) => onSearchChange(event.target.value)} placeholder="เช่น DH0101" /></div></label>
      <label>กลุ่ม<select aria-label="กรองกลุ่ม KPI" value={group} onChange={(event) => onGroupChange(event.target.value as IndicatorGroup | 'all')}><option value="all">ทุกกลุ่ม</option>{Object.values(groupMeta).map((meta) => <option value={meta.key} key={meta.key}>{meta.key} · {meta.shortLabel}</option>)}</select></label>
    </section>
    {!runtime && <p className="monitoring-error">เปิดจาก BMS launcher หรือกรอก session ด้านบนเพื่อเริ่มตรวจ PostgreSQL และโหลดทีละ KPI</p>}
    <section className="step-progress" aria-label="ความคืบหน้าการโหลด">
      <p role="status" aria-live="polite">{current?.activeCode ? `${saving ? 'กำลังบันทึก cache' : 'กำลังโหลด'} ${current.activeCode} — ขั้นที่ ${current.finished + (saving ? 0 : 1)}/${current.total}` : `จบแล้ว ${current?.finished ?? 0}/${current?.total ?? 177} ขั้น`}{current?.state === 'pausing' && ' · จะพักหลังคำขอปัจจุบันจบ'}</p>
      <progress max={current?.total ?? 177} value={current?.finished ?? 0} aria-label="จำนวน KPI ที่ประมวลผลแล้ว" />
      <p className="step-counts" data-cache-hits={current?.cacheHits ?? 0} data-query-successes={current?.querySucceeded ?? 0}>ใช้จาก cache {current?.cacheHits ?? 0} · query สำเร็จรอบนี้ {current?.querySucceeded ?? 0} · ล้มเหลว {current?.failed ?? 0} · มีค่า {nonNull}/1,552 reporting cells · approved coverage จากหน้านี้ 0 · monitoring แยก 2,784 ช่อง</p>
      <div className="step-controls">
        <button className="secondary-button" disabled={!current || current.state !== 'running'} onClick={() => loader.current?.pause()}><Pause size={16} /> พัก</button>
        <button className="secondary-button" disabled={!current || current.state !== 'paused' || locked} onClick={() => { if (runtime) aggregateQueryLane(runtime).allow(); void loader.current?.resume(); }}><Play size={16} /> ต่อ</button>
        <button className="secondary-button" disabled={!current || !['running', 'pausing', 'paused'].includes(current.state)} onClick={() => loader.current?.cancel()}><Square size={16} /> ยกเลิก</button>
        <button className="secondary-button" disabled={!current?.failed || busy || locked || current.state === 'cancelled'} onClick={() => { if (runtime) aggregateQueryLane(runtime).allow(); void loader.current?.retryFailed(); }}><RefreshCw size={16} /> ลองใหม่เฉพาะที่ล้มเหลว</button>
        <button className="secondary-button" disabled={!runtime || clearing || current?.blockedBySession || (current?.retryAt ?? 0) > now} onClick={restart}>โหลดใหม่ทั้งคิว</button>
        <button className="secondary-button" disabled={clearing} onClick={() => { void clearCache(); }}>ล้าง cache ทั้งหมด</button>
      </div>
      {current?.pauseReason && <p className={current.pauseReason === 'พักโดยผู้ใช้' ? 'step-pause-note' : 'monitoring-error'} role={current.pauseReason === 'พักโดยผู้ใช้' ? 'status' : 'alert'}>{current.pauseReason}{current.retryAt > now && ` · รออีก ${Math.ceil((current.retryAt - now) / 1000)} วินาที`}</p>}
    </section>
    <CohortProfilesPanel runtime={runtime} fiscalYear={fiscalYear} repository={cacheRepository} clearEpoch={clearEpoch} locked={locked || clearing} onSourceHold={(error) => loader.current?.holdSource(error)} />
    <p className="monitoring-help">ขยายแถวเพื่อดูตัวตั้ง/ตัวหารและ source value เทียบค่าคำนวณ · ไม่แบ่งวันที่ · ค่ารายปี/ไตรมาสไม่ซ้ำเป็นรายเดือน</p>
    <div className="step-table-scroll" role="region" aria-label="ผลการโหลดแต่ละ KPI" tabIndex={0}><table className="step-table"><caption className="sr-only">ผลสอบทาน KPI ทั้ง 232 รหัส</caption><thead><tr><th scope="col">รหัส / ตัวชี้วัด</th><th scope="col">สถานะ / เวลา</th><th scope="col">ผลและเหตุผล</th></tr></thead><tbody>{orderedCodes.map(code => <StepRow key={code} entry={thipCatalogueByCode.get(code)!} step={steps.get(code)} hidden={!visibleCodes.has(code)} busy={busy} locked={locked} cancelled={current?.state === 'cancelled'} onRetry={retryCode} />)}</tbody></table></div>
    {!visible.length && <p>ไม่พบรหัสที่ตรงกับคำค้นหรือกลุ่มที่เลือก</p>}
  </div>;
}

type StepRowProps = { entry: (typeof thipCatalogue)[number]; step?: StepSnapshot['steps'][number]; hidden: boolean; busy: boolean; locked: boolean; cancelled: boolean; onRetry(code: string): void };
const StepRow = memo(function StepRow({ entry, step, hidden, busy, locked, cancelled, onRetry }: StepRowProps) {
  return <tr hidden={hidden} data-code={entry.code}><th scope="row"><strong>{entry.code}</strong><span>{entry.title}</span><small>{reportingCadenceLabels[getReportingCadence(entry.code)]}</small></th><td><strong>{step ? statusLabels[step.status] : 'รอโหลด'}</strong>{step?.origin === 'cache' && <small>จาก cache</small>}<small>{step?.latencyMs === null || step?.latencyMs === undefined ? '—' : `${(step.latencyMs / 1000).toFixed(2)} วินาที`}</small>{step?.cachedAt && <small>อ่านเมื่อ {formatThaiDateTime(step.cachedAt)}</small>}{step?.expiresAt && <small>หมดอายุ {formatThaiDateTime(step.expiresAt)}</small>}{step?.status === 'failed' && <button className="secondary-button" disabled={busy || locked || cancelled} onClick={() => onRetry(entry.code)}>ลองใหม่ {entry.code}</button>}</td><td>
        <CohortDetails code={entry.code} />
        {step?.reason && <p>{step.reason}</p>}
        {step?.rows.length ? <AggregateDetails rows={step.rows} /> : <span>{step?.status === 'pending' || !step ? 'ยังไม่โหลด; ค่าเป็น NULL' : step.status === 'running' ? 'รอคำขอจบ' : 'ไม่มีผลวัดที่ยืนยัน; ไม่เติมศูนย์'}</span>}
      </td></tr>;
}, (a, b) => a.entry === b.entry && a.step === b.step && a.hidden === b.hidden && a.onRetry === b.onRetry && (b.step?.status !== 'failed' || a.busy === b.busy && a.locked === b.locked && a.cancelled === b.cancelled));
