import { useEffect, useId, useRef, useState } from 'react';
import type { KpiCellViewModel, KpiResultView } from '@/services/kpiTypes';
import { sharedControlChart } from '@/services/kpiAnalysis';
import { monitoringUnitLabels } from '@/monitoring/rules';

const format = (value: number | null) => value === null ? '—' : value.toLocaleString('th-TH', { maximumFractionDigits: 2 });
export function SharedKpiChart({ cells, resultView, control }: {
  cells: readonly KpiCellViewModel[]; resultView: KpiResultView; control: boolean;
}) {
  const figure = useRef<HTMLElement>(null);
  const [width, setWidth] = useState(720);
  const id = useId();
  useEffect(() => {
    const element = figure.current;
    if (!element) return;
    const observer = new ResizeObserver(entries => setWidth(Math.max(280, Math.round(entries[0].contentRect.width))));
    observer.observe(element);
    return () => observer.disconnect();
  }, []);
  const { model, reason, excluded } = sharedControlChart(cells);
  const cumulative = !control && resultView === 'cumulative';
  const points = control ? model.points : cells.map(cell => ({
    fiscalMonth: cell.fiscalMonth, label: cell.label,
    value: cumulative ? cell.cumulative.value : cell.value,
    ucl: null, lcl: null, signal: cell.discrepancy && !cumulative ? 'discrepancy' : 'none',
  }));
  const values = points.flatMap(point => [point.value, point.ucl, point.lcl]).filter((value): value is number => value !== null);
  const max = Math.max(...values, 1) * 1.08;
  const min = Math.min(...values, 0);
  const unit = cells[0] ? monitoringUnitLabels[cells[0].unit] : '';
  const right = width - 38;
  const x = (month: number) => 54 + (month - 1) * (right - 54) / 11;
  const y = (value: number) => 226 - (value - min) / (max - min) * 190;
  const line = (field: 'value' | 'ucl' | 'lcl') => {
    let previous: (typeof points)[number] | null = null;
    return points.map(point => {
      const value = point[field];
      if (value === null) { previous = null; return ''; }
      const joined = previous !== null && cells.some(cell => cell.fiscalMonth === previous!.fiscalMonth &&
        cell.periodEnd === cells.find(candidate => candidate.fiscalMonth === point.fiscalMonth)?.periodStart);
      previous = point;
      return `${joined ? 'L' : 'M'}${x(point.fiscalMonth)},${y(value)}`;
    }).join(' ');
  };
  const heading = control ? 'Control chart · ค่ารายเดือน / งวด' : cumulative ? 'แนวโน้มผลสะสมตั้งแต่ ต.ค.' : 'แนวโน้มรายเดือน / งวด';
  return <figure ref={figure} className={`kpi-trend kpi-analysis-chart${control ? ' kpi-control-chart' : ''}`}>
    <h2>{heading}</h2>
    {control && <>
      <p className="monitoring-help">ใช้ค่าของแต่ละงวดแยกกัน · ไม่ใช้ยอดสะสมเป็นจุดควบคุม · ขอบเขตเบื้องต้นจากข้อมูลปีที่เลือก</p>
      <dl className="kpi-control-summary">
        <div><dt>วิธี</dt><dd>{model.methodLabel}</dd></div>
        <div><dt>งวดที่วิเคราะห์</dt><dd>{model.measuredPointCount}</dd></div>
        <div><dt>เส้นกลาง CL</dt><dd>{format(model.cl)} {unit}</dd></div>
      </dl>
      {reason && <p className="monitoring-help" role="status">{reason}</p>}
    </>}
    {!values.length ? <p className="kpi-empty-trend">{cumulative ? 'ยังไม่มีผลสะสมที่คำนวณได้ ดูเหตุผลในรายละเอียดงวด' : 'ยังไม่มีค่ารายงวดสำหรับวาดกราฟ'}</p> : <svg
      viewBox={`0 0 ${width} 270`} role="img" aria-labelledby={`${id}-title ${id}-description`}>
      <title id={`${id}-title`}>{heading}</title>
      <desc id={`${id}-description`}>{control ? `${model.methodLabel}; CL ${format(model.cl)}; ${model.beyondLimitsCount} จุดนอกขอบเขต; ${model.runSignalCount} รัน 8 งวด` : 'แสดงงวดที่มีข้อมูล เว้นช่องว่างเมื่อค่าไม่พร้อม'} หน่วย {unit}</desc>
      {Array.from({ length: 5 }, (_, index) => {
        const value = min + (max - min) * index / 4;
        return <g key={index}><line x1="54" x2={right} y1={y(value)} y2={y(value)} className="kpi-chart-grid" />
          <text x="46" y={y(value) + 4} textAnchor="end" className="kpi-chart-axis">{format(value)}</text></g>;
      })}
      {control && model.cl !== null && <g><line x1="54" x2={right} y1={y(model.cl)} y2={y(model.cl)} className="kpi-chart-cl" />
        <text x={right + 4} y={y(model.cl) + 4} className="kpi-chart-axis">CL</text></g>}
      {control && model.hasLimits && <>
        <path d={line('ucl')} className="kpi-chart-limit" /><path d={line('lcl')} className="kpi-chart-limit" />
        {(['ucl', 'lcl'] as const).map(field => {
          const last = points.filter(point => point[field] !== null).at(-1);
          return last && <text key={field} x={right + 4} y={y(last[field]!) - 5} className="kpi-chart-axis">{field.toUpperCase()}</text>;
        })}
      </>}
      <path d={line('value')} className="kpi-chart-value" />
      {points.map(point => <g key={point.fiscalMonth}>
        {point.value !== null && <circle data-month={point.fiscalMonth} data-signal={point.signal} cx={x(point.fiscalMonth)} cy={y(point.value)} r="4.5" className={`kpi-chart-point signal-${point.signal}`}>
          <title>{point.label}: {format(point.value)} {unit}{control ? `; UCL ${format(point.ucl)}; LCL ${format(point.lcl)}; ${point.signal === 'beyond-limits' ? 'นอกขอบควบคุม' : point.signal === 'run' ? 'รัน 8 งวดข้างเดียว' : 'ไม่มีสัญญาณที่ตรวจพบ'}` : ''}</title>
        </circle>}
        {(width >= 620 || (point.fiscalMonth - 1) % (width < 400 ? 3 : 2) === 0 || point.fiscalMonth === 12) &&
          <text x={x(point.fiscalMonth)} y="252" textAnchor="middle" className="kpi-chart-axis">{point.label.split(' ')[0]}</text>}
      </g>)}
    </svg>}
    <figcaption>{control ? <>
      {model.sigmaLabel} · ขอบควบคุมเป็นสถิติ ไม่ใช่เป้าหมายโรงพยาบาล<br />
      จุดแดง: นอกขอบ 3σ {model.beyondLimitsCount} จุด · จุดเหลือง: รัน 8 งวดติดกันข้างเดียว {model.runSignalCount} รัน
      {excluded > 0 && ` · เว้น ${excluded} งวดที่ arithmetic ต้องสอบทาน`}
      {' · ฐานควบคุมและสมมติฐานทางสถิติยังต้องสอบทานก่อนใช้ตัดสินผล'}
    </> : cumulative ? 'ผลสะสมตามกฎของ KPI · ช่วงที่คำนวณไม่ได้เว้นว่าง · ค่าที่คำนวณจากรายงวดยังไม่ยืนยันความครบของข้อมูลต้นทาง'
      : 'ค่ารายงวดจากแหล่งข้อมูล · จุดสีส้มต้องสอบทานตัวตั้ง/ตัวหาร · ไม่เชื่อมข้ามงวดที่ไม่มีข้อมูล'}</figcaption>
    {control && model.measuredPointCount > 0 && <details className="kpi-chart-facts"><summary>ค่าที่ใช้ใน Control chart</summary>
      <div className="kpi-detail-table"><table className="kpi-detail-periods" role="table"><thead role="rowgroup"><tr role="row">
        <th scope="col" role="columnheader">งวด</th><th scope="col" role="columnheader">ค่า</th><th scope="col" role="columnheader">LCL</th><th scope="col" role="columnheader">UCL</th><th scope="col" role="columnheader">สัญญาณ</th>
      </tr></thead><tbody role="rowgroup">{model.points.map(point => <tr role="row" key={point.fiscalMonth}>
        <th scope="row" role="rowheader">{point.label}</th><td role="cell" data-label="ค่า">{format(point.value)}</td>
        <td role="cell" data-label="LCL">{format(point.lcl)}</td><td role="cell" data-label="UCL">{format(point.ucl)}</td>
        <td role="cell" data-label="สัญญาณ">{point.value === null ? 'ไม่มีค่าที่พร้อม' : point.signal === 'beyond-limits' ? 'นอกขอบควบคุม' : point.signal === 'run' ? 'รันข้างเดียว' : model.hasLimits ? 'ไม่พบ' : 'ขอบเขตยังไม่พร้อม'}</td>
      </tr>)}</tbody></table></div>
    </details>}
  </figure>;
}
