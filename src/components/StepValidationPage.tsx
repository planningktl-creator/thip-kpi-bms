import {
  useEffect,
  useRef,
  useState,
  useMemo,
  useCallback,
  memo,
  useDeferredValue,
} from 'react';
import { ArrowRight, Pause, Play, RefreshCw, Square } from 'lucide-react';
import type { BmsRuntimeConfig } from '@/services/bmsSession';
import {
  type StepSnapshot,
  type CandidateAggregate,
} from '@/services/thipStepLoader';
import {
  runtimeCatalogue as thipCatalogue,
  runtimeCatalogueByCode as thipCatalogueByCode,
} from '@/data/thipRuntime';
import { monitoringUnitLabels } from '@/monitoring/rules';
import {
  getReportingCadence,
  reportingCadenceLabels,
} from '@/data/thipReporting';
import {
  formatThaiDate,
  formatThaiDateTime,
  getCurrentFiscalYear,
  formatFiscalYear,
  toBuddhistYear,
} from '@/utils/fiscal';
import { groupMeta } from '@/data/thipMeta';
import type { IndicatorGroup } from '@/types/thip';
import { MemoryCacheRepository } from '@/services/thipStepCache';
import { useKpiData } from './KpiDataContext';
import { CohortProfilesPanel } from './CohortProfilesPanel';
import { aggregateQueryLane } from '@/services/aggregateQueryLane';
import { loadThipEvidence } from '@/data/thipEvidenceLoader';
import type { CohortDefinition } from '@/data/cohortTypes';

const emptyRepository = new MemoryCacheRepository();

type Props = {
  runtime: BmsRuntimeConfig | null;
  fiscalYear: number;
  onFiscalYearChange(year: number): void;
  group: IndicatorGroup | 'all';
  search: string;
  onSearchChange(value: string): void;
  onGroupChange(value: IndicatorGroup | 'all'): void;
  onMonitoring(): void;
};
const statusLabels = {
  pending: 'รอโหลด',
  running: 'กำลังโหลด',
  success: 'query สำเร็จ',
  failed: 'ล้มเหลว',
  skipped: 'รอ external source',
};
const number = (value: number | null) =>
  value === null
    ? '—'
    : value.toLocaleString('th-TH', { maximumFractionDigits: 4 });

function AggregateDetails({ rows }: { rows: readonly CandidateAggregate[] }) {
  const [opened, setOpened] = useState(false);
  return (
    <details onToggle={(event) => setOpened(event.currentTarget.open)}>
      <summary>
        ดู aggregate {rows.length} งวด · มีค่า{' '}
        {rows.filter((row) => row.sourceValue !== null).length} งวด
      </summary>
      {opened && (
        <div className="step-detail-scroll">
          <table>
            <caption>ผลรายงวดเพื่อสอบทาน ยังไม่รับรอง</caption>
            <thead>
              <tr>
                {[
                  'เริ่มงวด',
                  'ตัวตั้ง',
                  'ตัวหาร',
                  'source value',
                  'คำนวณสอบทาน',
                  'หน่วย / version / เหตุผล',
                ].map((label) => (
                  <th scope="col" key={label}>
                    {label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.fiscalMonth}>
                  <th scope="row">{formatThaiDate(row.periodStart)}</th>
                  <td>{number(row.numerator)}</td>
                  <td>{number(row.denominator)}</td>
                  <td>{number(row.sourceValue)}</td>
                  <td>
                    {number(row.derivedValue)}
                    {row.discrepancy && ' (ต่างจาก source)'}
                  </td>
                  <td>
                    {monitoringUnitLabels[row.unit]} · {row.ruleVersion}
                    <p>{row.reason ?? 'มี aggregate; สูตรยังไม่รับรอง'}</p>
                    <small>
                      อ่านเมื่อ {formatThaiDateTime(row.observedAt)} ·
                      data-through/refresh ยังไม่ยืนยัน
                    </small>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </details>
  );
}

function CohortDetails({ code }: { code: string }) {
  const [cohort, setCohort] = useState<CohortDefinition | null>(null);
  const [opened, setOpened] = useState(false);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    if (!opened || cohort) return;
    let cancelled = false;
    void loadThipEvidence(code)
      .then((evidence) => {
        if (!cancelled) setCohort(evidence?.cohort ?? null);
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });
    return () => {
      cancelled = true;
    };
  }, [opened, code, cohort]);
  return (
    <details
      className="cohort-evidence"
      onToggle={(event) => setOpened(event.currentTarget.open)}
    >
      <summary>นิยามตัวตั้ง–ตัวหาร / วิธีนับ</summary>
      {opened &&
        (cohort ? (
          <>
            <p>
              <strong>ตัวตั้งตาม THIP:</strong>{' '}
              {cohort.numeratorDefinition ?? 'ยังไม่มีหลักฐาน'}
            </p>
            <p>
              <strong>ตัวหารตาม THIP:</strong>{' '}
              {cohort.denominatorDefinition ?? 'ยังไม่มีหลักฐาน'}
            </p>
            <p>
              สูตร: {cohort.formula} · หน่วยตาม dictionary:{' '}
              {cohort.dictionaryUnit}
            </p>
            <p>
              หน่วยนับใน SQL: {cohort.currentGrain} · ตัวตั้ง{' '}
              {cohort.numeratorKind} / ตัวหาร {cohort.denominatorKind}
            </p>
            <p>
              คีย์ที่รอยืนยัน:{' '}
              {cohort.keyCandidates.join(', ') || 'รอตรวจ source'}
              <br />
              วันที่ที่รอยืนยัน:{' '}
              {cohort.eventDateCandidates.join(', ') || 'รอตรวจ source'}
            </p>
            <p>Observation window: {cohort.observationWindow}</p>
            <p>
              Inclusion: {cohort.inclusion.join('; ') || 'ยังไม่ได้แยกจากนิยาม'}
              <br />
              Exclusion: {cohort.exclusion.join('; ') || 'ยังไม่ได้แยกจากนิยาม'}
            </p>
            <p>
              PDF หน้า {cohort.pdfPage} (หน้าพิมพ์{' '}
              {cohort.printedPages.join(', ')}) · {cohort.ruleVersion} ·
              ยังไม่รับรอง
            </p>
            <ul>
              {cohort.limitations.map((reason, index) => (
                <li key={index}>{reason}</li>
              ))}
            </ul>
          </>
        ) : (
          <p role="status">
            {failed
              ? 'โหลดหลักฐานไม่สำเร็จ; ปิดแล้วเปิดเพื่อลองอีกครั้ง'
              : 'กำลังโหลดหลักฐาน cohort…'}
          </p>
        ))}
    </details>
  );
}

export function StepValidationPage({
  runtime,
  fiscalYear,
  onFiscalYearChange,
  group,
  search,
  onSearchChange,
  onGroupChange,
  onMonitoring,
}: Props) {
  const { store, snapshot } = useKpiData();
  const current =
    snapshot.owner === runtime && snapshot.fiscalYear === fiscalYear
      ? snapshot.progress
      : null;
  const reportingSteps = store.reportingSteps();
  const steps = useMemo(
    () => new Map(reportingSteps.map((step) => [step.code, step])),
    [current]
  );
  const deferredSearch = useDeferredValue(search);
  const orderedCodes = useMemo(
    () => [
      'DH0101',
      'DH0112',
      ...thipCatalogue
        .map((entry) => entry.code)
        .filter((code) => !['DH0101', 'DH0112'].includes(code))
        .sort(),
    ],
    []
  );
  const visibleCodes = new Set(
    thipCatalogue
      .filter(
        (entry) =>
          (group === 'all' || entry.group === group) &&
          `${entry.code} ${entry.title}`
            .toLowerCase()
            .includes(deferredSearch.trim().toLowerCase())
      )
      .map((entry) => entry.code)
  );
  const retryCode = useCallback(
    (code: string) => {
      void store.retryFailed(code);
    },
    [store]
  );
  const busy = current?.state === 'running' || current?.state === 'pausing';
  const locked =
    snapshot.blockedBySession || snapshot.retryAt > Date.now();
  return (
    <div className="page-stack step-page">
      <header className="monitoring-heading">
        <div>
          <h1>ตรวจข้อมูลทีละ KPI</h1>
          <p>คิวกลางใช้ร่วมทุกหน้า · {formatFiscalYear(fiscalYear)}</p>
        </div>
        <button className="secondary-button" onClick={onMonitoring}>
          ตารางตัวชี้วัด <ArrowRight size={16} />
        </button>
      </header>
      <div className="step-disclaimer">
        <strong>ข้อมูลจริงเพื่อสอบทาน — สูตรยังไม่รับรอง</strong>
        <p>
          ผล query และ cache ไม่เพิ่ม approved coverage;
          การควบคุมคิวอยู่ที่แถบข้อมูลกลางด้านบน
        </p>
      </div>
      <section className="monitoring-toolbar" aria-label="ค้นหาและกรองผลสอบทาน">
        <label className="monitoring-search">
          ค้นหารหัสหรือชื่อ
          <input
            aria-label="ค้นหารหัสหรือชื่อ KPI"
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
          />
        </label>
        <label>
          กลุ่ม
          <select
            aria-label="กรองกลุ่ม KPI"
            value={group}
            onChange={(e) =>
              onGroupChange(e.target.value as IndicatorGroup | 'all')
            }
          >
            <option value="all">ทุกกลุ่ม</option>
            {Object.values(groupMeta).map((meta) => (
              <option key={meta.key} value={meta.key}>
                {meta.shortLabel}
              </option>
            ))}
          </select>
        </label>
      </section>
      <CohortProfilesPanel
        runtime={runtime}
        fiscalYear={fiscalYear}
        repository={store.repository ?? emptyRepository}
        clearEpoch={store.clearEpoch}
        locked={locked}
        onSourceHold={store.holdSource}
      />
      <p className="monitoring-help">
        ขยายแถวดู source value เทียบค่าคำนวณ · ไม่แบ่งวันที่ · Cache 24 ชั่วโมง
        เวลาอ่านผลไม่ใช่ source freshness
      </p>
      <div
        className="step-table-scroll"
        role="region"
        aria-label="ผลการโหลดแต่ละ KPI"
        tabIndex={0}
      >
        <table className="step-table">
          <caption className="sr-only">ผลสอบทาน KPI ทั้ง 232 รหัส</caption>
          <thead>
            <tr>
              <th scope="col">รหัส / ตัวชี้วัด</th>
              <th scope="col">สถานะ / เวลา</th>
              <th scope="col">ผลและเหตุผล</th>
            </tr>
          </thead>
          <tbody>
            {orderedCodes.map((code) => (
              <StepRow
                key={code}
                entry={thipCatalogueByCode.get(code)!}
                step={steps.get(code)}
                hidden={!visibleCodes.has(code)}
                busy={busy}
                locked={locked}
                cancelled={current?.state === 'cancelled'}
                onRetry={retryCode}
              />
            ))}
          </tbody>
        </table>
      </div>
      {!visibleCodes.size && <p>ไม่พบรหัสที่ตรงกับคำค้น</p>}
    </div>
  );
}

type StepRowProps = {
  entry: (typeof thipCatalogue)[number];
  step?: StepSnapshot['steps'][number];
  hidden: boolean;
  busy: boolean;
  locked: boolean;
  cancelled: boolean;
  onRetry(code: string): void;
};
const StepRow = memo(
  function StepRow({
    entry,
    step,
    hidden,
    busy,
    locked,
    cancelled,
    onRetry,
  }: StepRowProps) {
    return (
      <tr hidden={hidden} data-code={entry.code}>
        <th scope="row">
          <strong>{entry.code}</strong>
          <span>{entry.title}</span>
          <small>
            {reportingCadenceLabels[getReportingCadence(entry.code)]}
          </small>
        </th>
        <td>
          <strong>{step ? statusLabels[step.status] : 'รอโหลด'}</strong>
          {step?.origin === 'cache' && <small>จาก cache</small>}
          <small>
            {step?.latencyMs === null || step?.latencyMs === undefined
              ? '—'
              : `${(step.latencyMs / 1000).toFixed(2)} วินาที`}
          </small>
          {step?.cachedAt && (
            <small>อ่านเมื่อ {formatThaiDateTime(step.cachedAt)}</small>
          )}
          {step?.expiresAt && (
            <small>หมดอายุ {formatThaiDateTime(step.expiresAt)}</small>
          )}
          {step?.status === 'failed' && (
            <button
              className="secondary-button"
              disabled={busy || locked || cancelled}
              onClick={() => onRetry(entry.code)}
            >
              ลองใหม่ {entry.code}
            </button>
          )}
        </td>
        <td>
          <CohortDetails code={entry.code} />
          {step?.reason && <p>{step.reason}</p>}
          {step?.rows.length ? (
            <AggregateDetails rows={step.rows} />
          ) : (
            <span>
              {step?.status === 'pending' || !step
                ? 'ยังไม่โหลด; ค่าเป็น NULL'
                : step.status === 'running'
                  ? 'รอคำขอจบ'
                  : 'ไม่มีผลวัดที่ยืนยัน; ไม่เติมศูนย์'}
            </span>
          )}
        </td>
      </tr>
    );
  },
  (a, b) =>
    a.entry === b.entry &&
    a.step === b.step &&
    a.hidden === b.hidden &&
    a.onRetry === b.onRetry &&
    (b.step?.status !== 'failed' ||
      (a.busy === b.busy &&
        a.locked === b.locked &&
        a.cancelled === b.cancelled))
);
