import {
  useState,
  useMemo,
  useEffect,
  useDeferredValue,
  useRef,
  useCallback,
  memo,
  type KeyboardEvent,
} from 'react';
import { Download, X } from 'lucide-react';
import { useKpiData } from './KpiDataContext';
import type {
  KpiMode,
  KpiSeries,
  KpiGridRow,
  KpiCellViewModel,
  KpiAvailability,
  KpiResultView,
} from '@/services/kpiTypes';
import type { IndicatorGroup } from '@/types/thip';
import { runtimeCatalogue, runtimeCatalogueByCode } from '@/data/thipRuntime';
import {
  reportingCadenceLabels,
  getReportingCadence,
} from '@/data/thipReporting';
import { monitoringUnitLabels } from '@/monitoring/rules';
import { groupMeta } from '@/data/thipMeta';
import {
  getFiscalMonthPeriods,
  formatFiscalYear,
  toBuddhistYear,
} from '@/utils/fiscal';
import { downloadSharedKpiCsv } from '@/services/kpiExport';
import { KpiCellDetails } from './KpiCellDetails';
import { KpiResultViewControl, useKpiResultView } from './KpiResultView';
export const kpiStatusLabels: Record<KpiAvailability, string> = {
  pending: 'รอโหลด',
  loading: 'กำลังโหลด',
  measured: 'มีผลวัด',
  'zero-cohort': 'ไม่มีกลุ่มตัวอย่าง',
  'missing-source': 'ไม่มีแหล่งข้อมูล',
  failed: 'ล้มเหลว',
  future: 'เดือนอนาคต',
  'rule-unapproved': 'รอรับรองสูตร',
  'not-applicable': 'ไม่มีงวด',
  expired: 'Cache หมดอายุ',
};
const assessments = {
  'on-track': 'ผ่านเป้า',
  watch: 'เฝ้าระวัง',
  action: 'ต้องดำเนินการ',
  'no-target': 'ไม่มีเป้าหมาย',
  'not-assessable': 'ยังประเมินไม่ได้',
};
const formatter = new Intl.NumberFormat('th-TH', { maximumFractionDigits: 2 });
const read = (key: string) =>
  new URLSearchParams(location.search).get(key) ?? 'all';
type Props = {
  fiscalYear: number;
  mode: KpiMode;
  series: KpiSeries;
  onSeries(series: KpiSeries): void;
  group: IndicatorGroup | 'all';
  onGroupChange(group: IndicatorGroup | 'all'): void;
  search: string;
  onSearchChange(value: string): void;
  onOpen(code: string): void;
};
export function KpiMatrixPage({
  fiscalYear,
  mode,
  series,
  onSeries,
  group,
  onGroupChange,
  search,
  onSearchChange,
  onOpen,
}: Props) {
  const { store, snapshot } = useKpiData();
  const [resultView, setResultView] = useKpiResultView();
  const rows = store.grid(series, mode);
  const [dataFilter, setDataFilter] = useState(() => read('data'));
  const [assessmentFilter, setAssessmentFilter] = useState(() =>
    read('assessment')
  );
  const deferredSearch = useDeferredValue(search);
  const pending = deferredSearch !== search;
  const [selection, setSelection] = useState<{
    code: string;
    month: number;
    year: number;
    series: KpiSeries;
    mode: KpiMode;
  } | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const opener = useRef<HTMLButtonElement | null>(null);
  const selected =
    selection?.year === fiscalYear &&
    selection.series === series &&
    selection.mode === mode
      ? rows.find((row) => row.code === selection.code)?.cells[
          selection.month - 1
        ]
      : null;
  const close = useCallback(() => {
    setSelection(null);
    opener.current?.focus();
  }, []);
  useEffect(() => {
    if (selected && !dialog.current?.open) dialog.current?.showModal();
    else if (!selected) dialog.current?.close();
  }, [selected]);
  useEffect(() => {
    const restore = () => {
      setDataFilter(read('data'));
      setAssessmentFilter(read('assessment'));
    };
    window.addEventListener('popstate', restore);
    return () => window.removeEventListener('popstate', restore);
  }, []);
  const visible = useMemo(
    () =>
      rows.filter((row) => {
        const entry = runtimeCatalogueByCode.get(row.code)!;
        return (
          (group === 'all' || entry.group === group) &&
          `${row.code} ${entry.title}`
            .toLowerCase()
            .includes(deferredSearch.trim().toLowerCase()) &&
          (dataFilter === 'all' ||
            row.cells.some((cell) => cell.status === dataFilter)) &&
          (assessmentFilter === 'all' ||
            row.cells.some((cell) => cell.assessment === assessmentFilter))
        );
      }),
    [rows, group, deferredSearch, dataFilter, assessmentFilter]
  );
  const visibleCodes = useMemo(
    () => new Set(visible.map((row) => row.code)),
    [visible]
  );
  function filter(key: string, value: string) {
    const params = new URLSearchParams(location.search);
    value === 'all' ? params.delete(key) : params.set(key, value);
    history.pushState({}, '', `${location.pathname}?${params}`);
    key === 'data' ? setDataFilter(value) : setAssessmentFilter(value);
  }
  const open = useCallback(
    (cell: KpiCellViewModel, button: HTMLButtonElement) => {
      opener.current = button;
      setSelection({
        code: cell.code,
        month: cell.fiscalMonth,
        year: cell.fiscalYear,
        series: cell.series,
        mode,
      });
    },
    [mode]
  );
  return (
    <div className="page-stack">
      <header className="monitoring-heading">
        <div>
          <p className="section-eyebrow">THIP QUALITY WORKSPACE</p>
          <h1>ตารางตัวชี้วัด</h1>
          <p>
            {formatFiscalYear(fiscalYear)} · 232 รหัส ·{' '}
            {series === 'thip-report'
              ? '1,552 งวดตาม cadence'
              : '2,784 ช่องติดตามรายเดือน'}
          </p>
        </div>
        <button
          className="secondary-button"
          disabled={
            pending || snapshot.fiscalYear !== fiscalYear || snapshot.preparing
          }
          onClick={() =>
            downloadSharedKpiCsv(visible, fiscalYear, series, mode)
          }
        >
          <Download size={16} />
          CSV {mode === 'review' ? 'สอบทาน' : 'รับรอง'}
        </button>
      </header>
      <div
        className="kpi-segment kpi-series"
        role="group"
        aria-label="ชุดผลตัวชี้วัด"
      >
        <button
          aria-pressed={series === 'thip-report'}
          onClick={() => onSeries('thip-report')}
        >
          รายงาน THIP
        </button>
        <button
          aria-pressed={series === 'monthly-monitoring'}
          onClick={() => onSeries('monthly-monitoring')}
        >
          ติดตามรายเดือน
        </button>
      </div>
      <p className="monitoring-help">
        {series === 'thip-report'
          ? 'ผลไตรมาส/ครึ่งปี/ปีอยู่ที่เดือนเริ่มงวดเท่านั้น กดช่องเพื่อดูช่วงข้อมูล'
          : 'ใช้สูตร monitoring แยก หรือ bridge รายเดือนที่มีหลักฐานตรงกัน; ไม่แบ่งผลรายปีเป็นเดือน'}{' '}
        · Cache 24 ชั่วโมง · เฝ้าระวังเป็นเกณฑ์ของระบบ
      </p>
      <KpiResultViewControl view={resultView} onChange={setResultView} />
      {resultView === 'cumulative' && <p className="monitoring-help">
        สะสมตั้งแต่ ต.ค. ถึงแต่ละงวดตามกฎของ KPI · อัตราใช้ผลรวมตัวตั้ง ÷ ผลรวมตัวหาร ไม่เฉลี่ยร้อยละ
        · ข้อมูลขาดแสดงเหตุผล · snapshot ใช้ค่าล่าสุด · ตัวกรองสถานะ/ผลเทียบเป้าอ้างอิงรายงวด
      </p>}
      <section className="monitoring-toolbar" aria-label="ค้นหาและกรอง">
        <label className="monitoring-search">
          ค้นหารหัสหรือชื่อ
          <input
            aria-label="ค้นหารหัสหรือชื่อ KPI"
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="เช่น DH0101"
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
        <label>
          สถานะข้อมูล
          <select
            aria-label="กรองสถานะข้อมูล"
            value={dataFilter}
            onChange={(e) => filter('data', e.target.value)}
          >
            <option value="all">ทุกสถานะ</option>
            {Object.entries(kpiStatusLabels).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </label>
        <label>
          ผลเทียบเป้า
          <select
            aria-label="กรองผลเทียบเป้า"
            value={assessmentFilter}
            onChange={(e) => filter('assessment', e.target.value)}
          >
            <option value="all">ทั้งหมด</option>
            {Object.entries(assessments).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </section>
      <p id="matrix-help" className="monitoring-help">
        แสดง {visible.length}/232 รหัส · Filter
        เก็บแถวที่พบสถานะอย่างน้อยหนึ่งเดือน · ลูกศรย้ายช่อง Enter ดูรายละเอียด
        Escape ปิด{pending && ' · กำลังปรับตัวกรอง…'}
      </p>
      <div
        className="monitoring-scroll"
        role="region"
        aria-label="ตาราง KPI"
      >
        <Matrix
          rows={rows}
          visibleCodes={visibleCodes}
          fiscalYear={fiscalYear}
          resultView={resultView}
          onCell={open}
        />
      </div>
      {!visible.length && <p role="status">ไม่พบ KPI ที่ตรงกับตัวกรอง</p>}
      <dialog
        ref={dialog}
        className="monitoring-dialog"
        aria-labelledby="kpi-dialog-title"
        onCancel={(e) => {
          e.preventDefault();
          close();
        }}
        onClose={close}
      >
        {selected && (
          <>
            <div className="monitoring-dialog-header">
              <h2 id="kpi-dialog-title">
                {selected.code} · {selected.label}
              </h2>
              <button
                className="icon-button"
                aria-label="ปิดรายละเอียด"
                onClick={close}
              >
                <X size={20} />
              </button>
            </div>
            <KpiCellDetails cell={selected} />
            <button
              className="secondary-button"
              onClick={() => {
                const code = selected.code;
                close();
                onOpen(code);
              }}
            >
              ดูทุกงวดของ {selected.code}
            </button>
          </>
        )}
      </dialog>
    </div>
  );
}
const Matrix = memo(function Matrix({
  rows,
  visibleCodes,
  fiscalYear,
  onCell,
  resultView,
}: {
  rows: readonly KpiGridRow[];
  visibleCodes: Set<string>;
  fiscalYear: number;
  resultView: KpiResultView;
  onCell(cell: KpiCellViewModel, button: HTMLButtonElement): void;
}) {
  const [focus, setFocus] = useState('');
  const periods = getFiscalMonthPeriods(fiscalYear);
  const visible = rows.filter((row) => visibleCodes.has(row.code));
  const active = visible.some((row) => focus.startsWith(`${row.code}:`))
    ? focus
    : `${visible[0]?.code}:1`;
  function keyDown(event: KeyboardEvent<HTMLTableElement>) {
    const button = (event.target as HTMLElement).closest<HTMLButtonElement>(
      'button[data-monitoring-key]'
    );
    if (!button) return;
    const [code, monthText] = button.dataset.monitoringKey!.split(':');
    let index = visible.findIndex((row) => row.code === code),
      month = Number(monthText);
    if (event.key === 'ArrowRight') month++;
    else if (event.key === 'ArrowLeft') month--;
    else if (event.key === 'ArrowDown') index++;
    else if (event.key === 'ArrowUp') index--;
    else if (event.key === 'Home') month = 1;
    else if (event.key === 'End') month = 12;
    else return;
    event.preventDefault();
    index = Math.max(0, Math.min(visible.length - 1, index));
    month = Math.max(1, Math.min(12, month));
    document
      .getElementById(`monitoring-${visible[index].code}-${month}`)
      ?.focus();
  }
  return (
    <table
      className="monitoring-matrix"
      role="table"
      aria-busy="false"
      aria-describedby="matrix-help"
      onKeyDown={keyDown}
      onFocus={(event) => {
        const button = (event.target as HTMLElement).closest<HTMLButtonElement>(
          'button[data-monitoring-key]'
        );
        if (button) setFocus(button.dataset.monitoringKey!);
      }}
    >
      <caption className="sr-only">232 รหัส × 12 เดือน</caption>
      <thead role="rowgroup">
        <tr role="row">
          <th className="monitoring-identity" scope="col" role="columnheader">
            รหัส / ตัวชี้วัด
          </th>
          {periods.map((period) => (
            <th key={period.fiscalMonth} scope="col" role="columnheader">
              {period.monthLabel}
              <small>{toBuddhistYear(period.calendarYear)}</small>
            </th>
          ))}
        </tr>
      </thead>
      <tbody role="rowgroup">
        {rows.map((row) => (
          <MatrixRow
            key={row.code}
            row={row}
            hidden={!visibleCodes.has(row.code)}
            active={
              active.startsWith(`${row.code}:`)
                ? Number(active.split(':')[1])
                : 0
            }
            onCell={onCell}
            resultView={resultView}
          />
        ))}
      </tbody>
    </table>
  );
});
const MatrixRow = memo(function MatrixRow({
  row,
  hidden,
  active,
  onCell,
  resultView,
}: {
  row: KpiGridRow;
  hidden: boolean;
  active: number;
  resultView: KpiResultView;
  onCell(cell: KpiCellViewModel, button: HTMLButtonElement): void;
}) {
  const entry = runtimeCatalogueByCode.get(row.code)!;
  return (
    <tr hidden={hidden} data-code={row.code} role="row">
      <th scope="row" className="monitoring-identity" role="rowheader">
        <strong>{row.code}</strong>
        <span>{entry.title}</span>
        <small>{reportingCadenceLabels[getReportingCadence(row.code)]}</small>
      </th>
      {row.cells.map((cell) => (
        <Cell
          key={cell.fiscalMonth}
          cell={cell}
          active={active === cell.fiscalMonth}
          onCell={onCell}
          resultView={resultView}
        />
      ))}
    </tr>
  );
});
const Cell = memo(function Cell({
  cell,
  active,
  onCell,
  resultView,
}: {
  cell: KpiCellViewModel;
  active: boolean;
  resultView: KpiResultView;
  onCell(cell: KpiCellViewModel, button: HTMLButtonElement): void;
}) {
  const cumulative = resultView === 'cumulative';
  const numeric = cumulative ? cell.cumulative.value : cell.value;
  const value = numeric === null ? '—' : formatter.format(numeric);
  const state = cumulative && numeric === null && ['measured', 'zero-cohort'].includes(cell.status) ? 'missing-source' : cell.status;
  const label = cumulative ? numeric === null
    ? ['measured', 'zero-cohort'].includes(cell.status) ? 'สะสมไม่ได้' : kpiStatusLabels[cell.status]
    : cell.cumulative.complete ? 'สะสมจากแหล่งข้อมูล' : 'สะสมสอบทาน'
    : cell.status === 'measured' ? assessments[cell.assessment] : kpiStatusLabels[cell.status];
  return (
    <td role="cell" data-month-label={cell.label}>
      <button
        id={`monitoring-${cell.code}-${cell.fiscalMonth}`}
        data-monitoring-key={`${cell.code}:${cell.fiscalMonth}`}
        className={`monitoring-cell state-${state} assessment-${cumulative ? numeric === null ? 'not-assessable' : 'no-target' : cell.assessment}`}
        tabIndex={active ? 0 : -1}
        onClick={(e) => onCell(cell, e.currentTarget)}
        aria-label={`${cell.code} ${cumulative ? 'ผลสะสมตั้งแต่ ต.ค. ถึง ' : ''}${cell.label}: ${numeric === null ? cumulative ? cell.cumulativeReason : kpiStatusLabels[cell.status] : `${value} ${monitoringUnitLabels[cell.unit]}, ${label}`}`}
        title={cumulative ? cell.cumulativeReason : cell.reason}
      >
        <strong>
          {value}
          {!cumulative && cell.discrepancy ? ' *' : ''}
        </strong>
        <small>
          {label}
        </small>
        {numeric !== null && <span>{monitoringUnitLabels[cell.unit]}</span>}
      </button>
    </td>
  );
});
