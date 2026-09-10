import {
  ArrowLeft,
  CalendarRange,
  CheckCircle2,
  ClipboardList,
  Database,
  Download,
  Info,
  Layers3,
  TrendingDown,
  TrendingUp,
} from 'lucide-react';
import type { Indicator } from '@/types/thip';
import { fiscalMonthLabels, groupMeta } from '@/data/thipData';
import { formatDelta, formatIndicatorValue, formatNumber } from '@/utils/format';
import { exportIndicatorCsv } from '@/utils/export';
import { StatusPill } from '@/components/StatusPill';
import { TrendChart } from '@/components/TrendChart';

type Props = {
  indicator: Indicator;
  onBack: () => void;
};

export function DetailView({ indicator, onBack }: Props) {
  const latest = indicator.monthly[indicator.monthly.length - 1];
  const previous = indicator.monthly[indicator.monthly.length - 2];
  const first = indicator.monthly.find((month) => month.value !== null);
  const improving = latest.value !== null && previous.value !== null
    ? indicator.direction === 'lower-is-better' ? latest.value < previous.value : latest.value > previous.value
    : null;
  const dataMonths = indicator.monthly.filter((month) => month.value !== null).length;
  const hasMonthlyData = dataMonths > 0;

  return (
    <div className="page-stack detail-page">
      <div className="detail-toolbar">
        <button className="back-button" type="button" onClick={onBack}><ArrowLeft size={17} /> กลับไปภาพรวม</button>
        <div className="detail-toolbar-actions"><span className="demo-label"><Info size={14} /> {hasMonthlyData ? 'demo contract' : 'ยังไม่ผูก source view'}</span><button className="secondary-button" type="button" onClick={() => exportIndicatorCsv(indicator)}><Download size={16} /> ส่งออก CSV</button></div>
      </div>

      <section className="detail-title-block">
        <div className="detail-title-main">
          <div className="detail-code-line"><span className="detail-group-letter" style={{ backgroundColor: groupMeta[indicator.group].color }}>{indicator.group}</span><span className="detail-code">{indicator.code}</span><span className="detail-category">{indicator.category}</span></div>
          <h1>{indicator.titleTh}</h1>
          <p>{indicator.title}</p>
        </div>
        <StatusPill status={latest.status} />
      </section>

      <section className="detail-kpi-grid">
        <div className="detail-kpi detail-kpi-primary"><span className="detail-kpi-label">ผลงานล่าสุด · ก.ย. 2569</span><strong>{formatIndicatorValue(indicator, latest.value)}</strong><span className="detail-kpi-meta">จาก {formatNumber(latest.denominator)} รายการ</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">เป้าหมาย</span><strong>{formatIndicatorValue(indicator, indicator.target)}</strong><span className="detail-kpi-meta">{indicator.direction === 'lower-is-better' ? 'ค่าต่ำกว่าดีกว่า' : 'ค่าสูงกว่าดีกว่า'}</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">เทียบเดือนก่อน</span><strong className={improving === true ? 'text-good' : improving === false ? 'text-bad' : ''}>{formatDelta(latest.value, previous.value, indicator).split(' ').slice(0, 2).join(' ')}</strong><span className="detail-kpi-meta">{improving === true ? <><TrendingUp size={13} /> แนวโน้มดีขึ้น</> : improving === false ? <><TrendingDown size={13} /> ต้องติดตาม</> : 'ไม่มีฐานเปรียบเทียบ'}</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">ความต่อเนื่องของข้อมูล</span><strong>{dataMonths}/12</strong><span className="detail-kpi-meta"><CheckCircle2 size={13} /> เดือนที่มีข้อมูล</span></div>
      </section>

      <section className="detail-grid-main">
        <article className="panel detail-chart-panel">
          <div className="panel-heading"><div><span className="panel-eyebrow">MONTHLY PERFORMANCE</span><h3>ผลลัพธ์รายเดือน · FY2569</h3></div><div className="chart-legend"><span><i className="legend-line legend-aqua" /> ผลงาน</span><span><i className="legend-line legend-amber" /> เป้าหมาย</span></div></div>
          <TrendChart indicator={indicator} />
          <div className="detail-chart-footer"><span><CalendarRange size={15} /> ต.ค. 2568 — ก.ย. 2569</span><span><Layers3 size={15} /> Percentile ล่าสุด {latest.percentile ?? '—'}</span></div>
        </article>
        <article className="panel definition-panel">
          <div className="panel-heading"><div><span className="panel-eyebrow">INDICATOR CONTRACT</span><h3>นิยามที่ใช้คำนวณ</h3></div><ClipboardList size={18} className="heading-icon" /></div>
          <div className="definition-block"><span className="definition-label">สูตรคำนวณ</span><strong>{indicator.formula}</strong></div>
          <div className="definition-split"><div><span className="definition-label">ตัวตั้ง (a)</span><p>{indicator.numeratorLabel}</p></div><div><span className="definition-label">ตัวหาร (b)</span><p>{indicator.denominatorLabel}</p></div></div>
          <div className="definition-block"><span className="definition-label">นิยาม / ขอบเขต</span><p>{indicator.definition}</p></div>
          <div className="definition-meta"><span><Database size={14} /> {indicator.sourceTables.length ? indicator.sourceTables.join(' · ') : 'รอผูก source view'}</span><span><CalendarRange size={14} /> {indicator.frequency}</span></div>
        </article>
      </section>

      <section className="panel monthly-detail-panel">
        <div className="panel-heading"><div><span className="panel-eyebrow">12-MONTH DETAIL</span><h3>ตัวตั้ง ตัวหาร และสถานะของทุกเดือน</h3><p>{hasMonthlyData ? 'ตัวเลขในตารางเป็นข้อมูล demo เพื่อแสดง contract ของหน้ารายละเอียด' : 'ยังไม่มีผลลัพธ์รายเดือนของโรงพยาบาล จึงแสดงค่าว่างแทนการคาดเดา'}</p></div><span className="reference-note">{indicator.reference}</span></div>
        <div className="monthly-table-wrap">
          <table className="monthly-table">
            <thead><tr><th>เดือนงบประมาณ</th><th>ตัวตั้ง (a)</th><th>ตัวหาร (b)</th><th>ผลลัพธ์</th><th>เป้าหมาย</th><th>Percentile</th><th>สถานะ</th></tr></thead>
            <tbody>{indicator.monthly.map((month, index) => <tr key={month.fiscalMonth} className={index === indicator.monthly.length - 1 ? 'is-latest' : ''}><td><strong>{month.label}</strong><span>FY2569 · เดือนที่ {month.fiscalMonth}</span></td><td>{formatNumber(month.numerator)}</td><td>{formatNumber(month.denominator)}</td><td><strong>{formatIndicatorValue(indicator, month.value)}</strong></td><td>{formatIndicatorValue(indicator, month.target)}</td><td>{month.percentile === null ? '—' : <span className="percentile-cell"><i style={{ width: `${month.percentile}%` }} />{month.percentile}</span>}</td><td><StatusPill status={month.status} compact /></td></tr>)}</tbody>
          </table>
        </div>
      </section>

      <div className="source-callout"><Info size={16} /><span>เกณฑ์อ้างอิง: {indicator.reference} · เมื่อเชื่อม BMS จริง ระบบจะอ่านผลลัพธ์จาก registered query ที่มี grain เป็น 1 indicator × 1 fiscal month และแสดง source freshness แยกจากค่าผลลัพธ์</span></div>
    </div>
  );
}
