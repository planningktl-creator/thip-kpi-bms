import { useEffect, useState } from 'react';
import { Pause, Play, Square, RefreshCw } from 'lucide-react';
import { useKpiData } from './KpiDataContext';
import { getCurrentFiscalYear, toBuddhistYear } from '@/utils/fiscal';
import type { KpiMode } from '@/services/kpiTypes';
export function KpiLoadBar({
  mode,
  onMode,
  onYear,
}: {
  mode: KpiMode;
  onMode(mode: KpiMode): void;
  onYear(year: number): void;
}) {
  const { store, snapshot } = useKpiData();
  const progress = snapshot.progress;
  const retryAt = snapshot.retryAt;
  const [now, setNow] = useState(Date.now());
  useEffect(() => {
    if (!retryAt || retryAt <= Date.now()) return;
    const timer = setInterval(() => {
      setNow(Date.now());
      if (Date.now() >= retryAt) clearInterval(timer);
    }, 1000);
    return () => clearInterval(timer);
  }, [retryAt]);
  const locked = snapshot.blockedBySession || (retryAt ?? 0) > now;
  const busy =
    progress?.state === 'running' ||
    progress?.state === 'pausing' ||
    snapshot.preparing;
  const measured = store
    .grid('thip-report', 'review')
    .flatMap((row) => row.cells)
    .filter((cell) => cell.value !== null).length;
  const approved = store
    .grid('thip-report', 'approved')
    .flatMap((row) => row.cells)
    .filter((cell) => cell.value !== null).length;
  const years = [
    ...new Set([
      snapshot.fiscalYear,
      ...Array.from({ length: 6 }, (_, i) => getCurrentFiscalYear() - i),
    ]),
  ].sort((a, b) => b - a);
  return (
    <section className="kpi-load-bar" aria-label="ข้อมูลร่วมทุกหน้า">
      <div className="kpi-context">
        <span className="kpi-hospital">
          โรงพยาบาล{' '}
          {(snapshot.owner as { hospitalCode?: string } | null)?.hospitalCode ??
            'ยังไม่เชื่อมต่อ'}
        </span>
        <label>
          ปีงบประมาณ{' '}
          <select
            aria-label="เลือกปีงบประมาณ"
            value={snapshot.fiscalYear}
            onChange={(e) => onYear(Number(e.target.value))}
          >
            {years.map((year) => (
              <option key={year} value={year}>
                {toBuddhistYear(year)}
              </option>
            ))}
          </select>
        </label>
        <div className="kpi-segment" role="group" aria-label="โหมดข้อมูล">
          <button
            aria-pressed={mode === 'review'}
            onClick={() => onMode('review')}
          >
            สอบทาน
          </button>
          <button
            aria-pressed={mode === 'approved'}
            onClick={() => onMode('approved')}
          >
            รับรองแล้ว
          </button>
        </div>
        <strong className={`kpi-mode-label ${mode}`}>
          {mode === 'review'
            ? 'ข้อมูลสอบทาน — ยังไม่รับรอง'
            : 'ผลผ่าน publication gate'}
        </strong>
      </div>
      <div className="kpi-progress-line">
        <span role="status">
          {snapshot.preparing
            ? 'กำลังเตรียมคลังข้อมูลกลาง…'
            : progress?.activeCode
              ? `กำลังโหลด ${progress.activeCode.replace('monitoring/', 'Monitoring ')} — ขั้นที่ ${Math.min(progress.finished + 1, progress.total)}/${progress.total}`
              : progress
                ? `ประมวลผล ${progress.finished}/${progress.total} · ${progress.state === 'complete' ? 'ครบคิว' : progress.state === 'paused' ? 'พักคิว' : progress.state === 'cancelled' ? 'ยกเลิกแล้ว' : 'รอโหลด'}`
                : snapshot.stopped
                  ? 'หยุดคิวแล้ว กดเริ่มโหลดเพื่อเริ่มใหม่'
                  : 'เชื่อมต่อ session เพื่อเริ่มโหลด'}
        </span>
        <small>โหลดครั้งเดียว · ใช้ร่วมทุกหน้า</small>
      </div>
      <progress
        max={progress?.total ?? 177}
        value={progress?.finished ?? 0}
        aria-label="จำนวน KPI ที่ประมวลผลแล้ว"
      />
      <p
        className="step-counts"
        data-cache-hits={progress?.cacheHits ?? 0}
        data-query-successes={progress?.querySucceeded ?? 0}
      >
        จาก cache {progress?.cacheHits ?? 0} · query สำเร็จรอบนี้{' '}
        {progress?.querySucceeded ?? 0} · ล้มเหลว {progress?.failed ?? 0} ·
        มีค่า THIP {measured}/1,552 · รับรอง {approved}/1,552
      </p>
      <div className="step-controls">
        <button
          className="secondary-button"
          disabled={!snapshot.owner || busy || locked}
          onClick={() => {
            void (progress?.state === 'paused'
              ? store.resume()
              : store.start());
          }}
        >
          <Play size={14} />
          {progress?.state === 'paused' ? 'ต่อ' : 'เริ่มโหลด'}
        </button>
        <button
          className="secondary-button"
          disabled={progress?.state !== 'running'}
          onClick={store.pause}
        >
          <Pause size={14} />
          พัก
        </button>
        <button
          className="secondary-button"
          disabled={!busy && progress?.state !== 'paused'}
          onClick={store.cancel}
        >
          <Square size={14} />
          ยกเลิก
        </button>
        <button
          className="secondary-button"
          disabled={
            !progress?.failed ||
            busy ||
            locked ||
            progress?.state === 'cancelled'
          }
          onClick={() => {
            void store.retryFailed();
          }}
        >
          ลองใหม่เฉพาะที่ล้มเหลว
        </button>
        <details className="kpi-cache-menu">
          <summary>จัดการ cache</summary>
          <button
            className="secondary-button"
            disabled={!snapshot.owner || locked}
            onClick={() => {
              void store.refresh();
            }}
          >
            <RefreshCw size={14} />
            โหลดใหม่ทั้งคิว
          </button>
          <button
            className="secondary-button"
            onClick={() => {
              void store.clearAll();
            }}
          >
            ล้าง cache ทั้งหมด
          </button>
        </details>
      </div>
      {progress?.pauseReason && (
        <p role={locked ? 'alert' : 'status'} className="step-pause-note">
          {progress.pauseReason}
          {retryAt > now &&
            ` · รออีก ${Math.ceil((retryAt - now) / 1000)} วินาที`}
        </p>
      )}
      {snapshot.blockedBySession && !progress && (
        <p role="alert">
          Session หมดอายุหรือไม่มีสิทธิ์ กรุณาเชื่อมต่อใหม่ก่อนเริ่มคิวหรือคืน
          cache
        </p>
      )}
      {snapshot.cacheUnavailable && (
        <p role="status">
          Cache ข้าม refresh ไม่พร้อม ใช้ memory และโหลดต่อได้
        </p>
      )}
      {snapshot.error && <p role="alert">{snapshot.error}</p>}
      {snapshot.stopped && !snapshot.progress && (
        <p role="status">
          {snapshot.clearIncomplete
            ? 'ล้างผลใน memory แล้ว; cache บนเครื่องยังล้างไม่ได้เพราะ storage ไม่พร้อม'
            : 'ล้าง cache แล้ว'}{' '}
          · กดเริ่มโหลดเพื่อเริ่มใหม่
        </p>
      )}
    </section>
  );
}
