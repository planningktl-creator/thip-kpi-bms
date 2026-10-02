import { useState } from 'react';
import { useKpiData } from './KpiDataContext';
import type { KpiMode, KpiSeries } from '@/services/kpiTypes';
import type { IndicatorGroup } from '@/types/thip';
import { runtimeCatalogueByCode } from '@/data/thipRuntime';
import { monitoringUnitLabels } from '@/monitoring/rules';
import { formatFiscalYear, formatThaiDate } from '@/utils/fiscal';
import { KpiCellDetails } from './KpiCellDetails';
import { kpiStatusLabels } from './KpiMatrixPage';
import { downloadSharedKpiCsv } from '@/services/kpiExport';
import { KpiResultViewControl, useKpiResultView } from './KpiResultView';
import { SharedKpiChart } from './SharedKpiChart';
const format = (value: number | null) =>
  value === null
    ? '—'
    : value.toLocaleString('th-TH', { maximumFractionDigits: 2 });
type Props = {
  mode: KpiMode;
  series: KpiSeries;
  onOpen(code: string): void;
  group: IndicatorGroup | 'all';
  search: string;
  onSearchChange(value: string): void;
};
export function SharedKpiOverview({
  mode,
  series,
  onOpen,
  group,
  search,
  onSearchChange,
}: Props) {
  const { store, snapshot } = useKpiData();
  const rows = store.grid(series, mode);
  const filtered = rows.filter((row) => {
    const entry = runtimeCatalogueByCode.get(row.code)!;
    return (
      (group === 'all' || entry.group === group) &&
      `${row.code} ${entry.title}`
        .toLowerCase()
        .includes(search.trim().toLowerCase())
    );
  });
  const measured = filtered.filter((row) =>
    row.cells.some((cell) => cell.value !== null)
  );
  return (
    <div className="page-stack">
      <header className="monitoring-heading">
        <div>
          <h1>ภาพรวมคุณภาพ</h1>
          <p>
            {formatFiscalYear(snapshot.fiscalYear)} ·{' '}
            {series === 'thip-report' ? 'รายงาน THIP' : 'ติดตามรายเดือน'} ·{' '}
            {mode === 'review'
              ? 'ข้อมูลสอบทาน ยังไม่รับรอง'
              : 'ผลที่ผ่าน publication gate'}
          </p>
        </div>
      </header>
      <section className="kpi-overview-counts">
        <div>
          <strong>
            {measured.length}
            <small>/{filtered.length}</small>
          </strong>
          <span>รหัสที่มีค่า</span>
        </div>
        <div>
          <strong>
            {
              filtered
                .flatMap((row) => row.cells)
                .filter((cell) => cell.discrepancy).length
            }
          </strong>
          <span>งวดที่ arithmetic ต้องสอบทาน</span>
        </div>
        <div>
          <strong>
            {
              filtered
                .flatMap((row) => row.cells)
                .filter((cell) => cell.status === 'rule-unapproved').length
            }
          </strong>
          <span>งวดรอรับรอง</span>
        </div>
      </section>
      <label className="kpi-overview-search">
        ค้นหารหัสหรือชื่อ
        <input
          aria-label="ค้นหารหัสหรือชื่อ KPI"
          value={search}
          onChange={(e) => onSearchChange(e.target.value)}
        />
      </label>
      <p className="monitoring-help">
        ค่าล่าสุดตามงวดที่มีข้อมูล · ไม่รวม KPI ต่างหน่วยเข้าด้วยกัน ·
        ผลรายปีไม่ถูกแบ่งเป็นเดือน
      </p>
      <div className="kpi-overview-list">
        {filtered.map((row) => {
          const cell = row.cells.filter((cell) => cell.value !== null).at(-1),
            entry = runtimeCatalogueByCode.get(row.code)!;
          return (
            <button
              className="kpi-overview-row"
              key={row.code}
              onClick={() => onOpen(row.code)}
            >
              <strong>{row.code}</strong>
              <span>{entry.title}</span>
              <span>
                {cell
                  ? `${format(cell.value)} ${monitoringUnitLabels[cell.unit]}`
                  : 'ยังไม่มีผลวัด'}
              </span>
              <small>
                {cell
                  ? `${formatThaiDate(cell.periodStart)} · ${cell.discrepancy ? 'arithmetic ต้องสอบทาน' : mode === 'review' ? 'ยังไม่รับรอง' : 'รับรองแล้ว'}`
                  : kpiStatusLabels[
                      row.cells.find(
                        (cell) => cell.status !== 'not-applicable'
                      )!.status
                    ]}
              </small>
            </button>
          );
        })}
      </div>
    </div>
  );
}
export function SharedKpiDetail({
  code,
  mode,
  series,
  onBack,
}: {
  code: string;
  mode: KpiMode;
  series: KpiSeries;
  onBack(): void;
}) {
  const { store, snapshot } = useKpiData();
  const row = store.grid(series, mode).find((row) => row.code === code);
  const [month, setMonth] = useState(1);
  const [resultView, setResultView] = useKpiResultView();
  const [chart, setChart] = useState<'trend' | 'control'>('trend');
  if (!row) return <p>ไม่พบรหัส {code}</p>;
  const cell = row.cells[month - 1];
  const entry = runtimeCatalogueByCode.get(code)!;
  return (
    <div className="page-stack">
      <button className="secondary-button" onClick={onBack}>
        กลับภาพรวม
      </button>
      <header className="monitoring-heading">
        <div>
          <h1>
            {code} · {entry.title}
          </h1>
          <p>
            {formatFiscalYear(snapshot.fiscalYear)} ·{' '}
            {mode === 'review'
              ? 'ข้อมูลสอบทาน — ยังไม่รับรอง'
              : 'ผลที่ผ่าน publication gate'}
          </p>
        </div>
        <button
          className="secondary-button"
          onClick={() =>
            downloadSharedKpiCsv([row], snapshot.fiscalYear, series, mode)
          }
        >
          CSV {mode === 'review' ? 'สอบทาน' : 'รับรอง'}
        </button>
      </header>
      <div className="kpi-detail-controls">
        <KpiResultViewControl view={resultView} onChange={setResultView} />
        <div className="kpi-segment" role="group" aria-label="รูปแบบกราฟ">
          <button aria-pressed={chart === 'trend'} onClick={() => setChart('trend')}>แนวโน้ม</button>
          <button aria-pressed={chart === 'control'} onClick={() => setChart('control')}>Control chart</button>
        </div>
      </div>
      <SharedKpiChart cells={row.cells} resultView={resultView} control={chart === 'control'} />
      <div className="kpi-detail-table">
        <table className="kpi-detail-periods" role="table">
          <caption>{resultView === 'cumulative' ? 'ผลสะสมตั้งแต่ ต.ค. ตามกฎของ KPI; ไม่ใช้เป้ารายงวดประเมินยอดสะสม' : 'ค่าจาก source ตามงวด; * arithmetic ต่างจากค่าคำนวณ'}</caption>
          <thead role="rowgroup">
            <tr role="row">
              <th scope="col" role="columnheader">งวด</th>
              <th scope="col" role="columnheader">ตัวตั้ง{resultView === 'cumulative' && 'สะสม'}</th>
              <th scope="col" role="columnheader">ตัวหาร{resultView === 'cumulative' && 'สะสม'}</th>
              <th scope="col" role="columnheader">ค่า{resultView === 'cumulative' && 'สะสม'}</th>
              <th scope="col" role="columnheader">สถานะ</th>
            </tr>
          </thead>
          <tbody role="rowgroup">
            {row.cells.map((point) => (
              <tr key={point.fiscalMonth} role="row" data-month={point.fiscalMonth}>
                <th scope="row" role="rowheader">
                  <button
                    className="secondary-button"
                    aria-pressed={point.fiscalMonth === month}
                    onClick={() => setMonth(point.fiscalMonth)}
                  >
                    {point.label}
                  </button>
                </th>
                <td role="cell" data-label="ตัวตั้ง">{format(resultView === 'cumulative' ? point.cumulative.numerator : point.numerator)}</td>
                <td role="cell" data-label="ตัวหาร">{format(resultView === 'cumulative' ? point.cumulative.denominator : point.denominator)}</td>
                <td role="cell" data-label={resultView === 'cumulative' ? 'ค่าสะสม' : 'ค่า'}>
                  {format(resultView === 'cumulative' ? point.cumulative.value : point.value)}
                  {resultView === 'period' && point.discrepancy ? ' *' : ''}{' '}
                  {(resultView === 'cumulative' ? point.cumulative.value : point.value) !== null && monitoringUnitLabels[point.unit]}
                </td>
                <td role="cell" data-label="สถานะ" title={resultView === 'cumulative' ? point.cumulativeReason : point.reason}>
                  {resultView === 'period' ? kpiStatusLabels[point.status] : point.cumulative.value === null
                    ? point.cumulativeReason : point.cumulative.complete ? 'ครบช่วงที่แหล่งข้อมูลยืนยัน' : 'สะสมสอบทาน — ยังไม่ยืนยันความครบช่วง'}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <h2>รายละเอียดงวด {cell.label}</h2>
      <KpiCellDetails cell={cell} />
    </div>
  );
}
