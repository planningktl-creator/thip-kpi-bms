import { useState } from 'react';
import { useKpiData } from './KpiDataContext';
import type { KpiMode, KpiSeries, KpiCellViewModel } from '@/services/kpiTypes';
import type { IndicatorGroup } from '@/types/thip';
import { runtimeCatalogueByCode } from '@/data/thipRuntime';
import { monitoringUnitLabels } from '@/monitoring/rules';
import { formatFiscalYear, formatThaiDate } from '@/utils/fiscal';
import { KpiCellDetails } from './KpiCellDetails';
import { kpiStatusLabels } from './KpiMatrixPage';
import { downloadSharedKpiCsv } from '@/services/kpiExport';
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
      <Trend cells={row.cells} />
      <div className="step-detail-scroll">
        <table className="kpi-detail-periods">
          <caption>ค่าจาก source ตามงวด; * arithmetic ต่างจากค่าคำนวณ</caption>
          <thead>
            <tr>
              <th>เริ่มงวด</th>
              <th>ตัวตั้ง</th>
              <th>ตัวหาร</th>
              <th>ค่า</th>
              <th>สถานะ</th>
            </tr>
          </thead>
          <tbody>
            {row.cells.map((point) => (
              <tr key={point.fiscalMonth}>
                <th>
                  <button
                    className="secondary-button"
                    aria-pressed={point.fiscalMonth === month}
                    onClick={() => setMonth(point.fiscalMonth)}
                  >
                    {formatThaiDate(point.periodStart)}
                  </button>
                </th>
                <td>{format(point.numerator)}</td>
                <td>{format(point.denominator)}</td>
                <td>
                  {format(point.value)}
                  {point.discrepancy ? ' *' : ''}{' '}
                  {point.value !== null && monitoringUnitLabels[point.unit]}
                </td>
                <td>{kpiStatusLabels[point.status]}</td>
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
function Trend({ cells }: { cells: readonly KpiCellViewModel[] }) {
  const values = cells.filter((cell) => cell.value !== null);
  if (!values.length)
    return <p className="kpi-empty-trend">ยังไม่มีค่าเพื่อวาดแนวโน้ม</p>;
  const max = Math.max(...values.map((cell) => cell.value!), 1),
    min = Math.min(...values.map((cell) => cell.value!), 0),
    range = max - min || 1;
  const x = (month: number) => 30 + (month - 1) * 54,
    y = (value: number) => 170 - ((value - min) / range) * 135;
  const clean = values.filter((cell) => !cell.discrepancy),
    mean = clean.length
      ? clean.reduce((sum, cell) => sum + cell.value!, 0) / clean.length
      : null;
  return (
    <figure className="kpi-trend">
      <svg
        viewBox="0 0 660 205"
        role="img"
        aria-label="แนวโน้มค่าจาก source ตามงวด"
      >
        <path
          d="M30 20V170H630"
          fill="none"
          stroke="currentColor"
          opacity=".25"
        />
        {mean !== null && (
          <line
            x1="30"
            x2="630"
            y1={y(mean)}
            y2={y(mean)}
            stroke="currentColor"
            strokeDasharray="5 5"
            opacity=".4"
          />
        )}
        {values.map((cell) => (
          <g key={cell.fiscalMonth}>
            <circle
              cx={x(cell.fiscalMonth)}
              cy={y(cell.value!)}
              r="5"
              fill={cell.discrepancy ? '#ae5528' : '#047b80'}
            >
              <title>
                {cell.label}: {format(cell.value)}{' '}
                {monitoringUnitLabels[cell.unit]}
              </title>
            </circle>
            <text
              x={x(cell.fiscalMonth)}
              y="192"
              textAnchor="middle"
              fontSize="11"
            >
              {cell.label.split(' ')[0]}
            </text>
          </g>
        ))}
      </svg>
      <figcaption>
        ค่าจาก source · จุดสีส้มต้องสอบทาน arithmetic ·
        เส้นค่าเฉลี่ยใช้เฉพาะจุดที่ arithmetic สอดคล้อง ไม่ใช่ผล SPC ที่รับรอง
      </figcaption>
    </figure>
  );
}
