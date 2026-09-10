import { useState } from 'react';
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
import { formatFiscalRange, formatFiscalYear, formatFiscalYearShort } from '@/utils/fiscal';
import { groupMeta } from '@/data/thipData';
import { formatDelta, formatIndicatorValue, formatNumber } from '@/utils/format';
import { exportIndicatorCsv } from '@/utils/export';
import { StatusPill } from '@/components/StatusPill';
import { TrendChart, type ChartMode } from '@/components/TrendChart';

type Props = {
  indicator: Indicator;
  onBack: () => void;
};

export function DetailView({ indicator, onBack }: Props) {
  const [chartMode, setChartMode] = useState<ChartMode>('bar');
  const latest = indicator.monthly[indicator.monthly.length - 1];
  const previous = indicator.monthly[indicator.monthly.length - 2];
  const improving = latest.value !== null && previous.value !== null
    ? indicator.direction === 'lower-is-better' ? latest.value < previous.value : latest.value > previous.value
    : null;
  const dataMonths = indicator.monthly.filter((month) => month.value !== null).length;
  const hasMonthlyData = dataMonths > 0;
  const targetLabel = indicator.targetScope === 'annual' ? 'เป้าหมายทั้งปี' : 'เป้าหมายรายเดือน';

  return (
    <div className="page-stack detail-page">
      <div className="detail-toolbar">
        <button className="back-button" type="button" onClick={onBack}><ArrowLeft size={17} /> กลับไปภาพรวม</button>
        <div className="detail-toolbar-actions"><span className="demo-label"><Info size={14} /> {indicator.dataSource === 'bms' ? 'BMS live data' : hasMonthlyData ? 'demo contract' : 'ยังไม่ผูก source view'}</span><button className="secondary-button" type="button" onClick={() => exportIndicatorCsv(indicator)}><Download size={16} /> ส่งออก CSV</button></div>
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
        <div className="detail-kpi detail-kpi-primary"><span className="detail-kpi-label">ผลงานล่าสุด · {latest.label}</span><strong>{formatIndicatorValue(indicator, latest.value)}</strong><span className="detail-kpi-meta">จาก {formatNumber(latest.denominator)} รายการ</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">{targetLabel}</span><strong>{formatIndicatorValue(indicator, indicator.target)}</strong><span className="detail-kpi-meta">{indicator.direction === 'lower-is-better' ? 'ค่าต่ำกว่าดีกว่า' : indicator.direction === 'higher-is-better' ? 'ค่าสูงกว่าดีกว่า' : 'ใช้เป็นข้อมูลอ้างอิง'}</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">เทียบเดือนก่อน</span><strong className={improving === true ? 'text-good' : improving === false ? 'text-bad' : ''}>{formatDelta(latest.value, previous.value, indicator).split(' ').slice(0, 2).join(' ')}</strong><span className="detail-kpi-meta">{improving === true ? <><TrendingUp size={13} /> แนวโน้มดีขึ้น</> : improving === false ? <><TrendingDown size={13} /> ต้องติดตาม</> : 'ไม่มีฐานเปรียบเทียบ'}</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">ความต่อเนื่องของข้อมูล</span><strong>{dataMonths}/12</strong><span className="detail-kpi-meta"><CheckCircle2 size={13} /> เดือนที่มีข้อมูล</span></div>
      </section>

      <section className="panel annual-summary-panel">
        <div className="panel-heading"><div><span className="panel-eyebrow">FISCAL YEAR ROLLUP</span><h3>สรุปผลการดำเนินงาน · {formatFiscalYear(indicator.fiscalYear)}</h3><p>ฐานข้อมูลใช้วันที่ ISO ภายใน แต่การแสดงผลทั้งหมดใช้ปี พ.ศ. และรอบ ต.ค. — ก.ย.</p></div><span className="annual-year-badge">{formatFiscalYearShort(indicator.fiscalYear)}</span></div>
        <div className="annual-summary-grid">
          <div className="annual-summary-card annual-summary-primary"><span>ผลงานสะสมทั้งปี</span><strong>{formatIndicatorValue(indicator, indicator.annual.value)}</strong><small>จาก {formatNumber(indicator.annual.denominator)} รายการ</small></div>
          <div className="annual-summary-card"><span>{targetLabel}</span><strong>{formatIndicatorValue(indicator, indicator.annual.target)}</strong><small>{indicator.targetScope === 'annual' ? 'ค่าที่ตั้งไว้ระดับปี' : 'เกณฑ์เดียวกับการอ่านรายเดือน'}</small></div>
          <div className="annual-summary-card"><span>สถานะทั้งปี</span><StatusPill status={indicator.annual.status} /><small>{dataMonths === 12 ? 'ข้อมูลครบทุกเดือน' : `มีข้อมูล ${dataMonths} จาก 12 เดือน`}</small></div>
          <div className="annual-summary-card"><span>ช่วงปีงบประมาณ</span><strong className="annual-range">{formatFiscalRange(indicator.fiscalYear)}</strong><small>{formatFiscalYearShort(indicator.fiscalYear)} · 12 เดือน</small></div>
        </div>
      </section>

      <section className="detail-grid-main">
        <article className="panel detail-chart-panel">
          <div className="panel-heading detail-chart-heading">
            <div><span className="panel-eyebrow">MONTHLY PERFORMANCE</span><h3>ผลลัพธ์รายเดือน · {formatFiscalYear(indicator.fiscalYear)}</h3><p>แท่งสีฟ้าแสดงผลงานจริงของแต่ละเดือนงบประมาณ</p></div>
            <div className="detail-chart-tools">
              <div className="chart-legend"><span><i className="legend-bar legend-aqua" /> ผลงาน</span>{indicator.targetScope === 'monthly' && <span><i className="legend-line legend-amber" /> เป้าหมาย</span>}</div>
              <div className="chart-switcher" role="tablist" aria-label="รูปแบบกราฟ"><button type="button" className={chartMode === 'bar' ? 'is-active' : ''} role="tab" aria-selected={chartMode === 'bar'} onClick={() => setChartMode('bar')}>กราฟแท่ง</button><button type="button" className={chartMode === 'line' ? 'is-active' : ''} role="tab" aria-selected={chartMode === 'line'} onClick={() => setChartMode('line')}>แนวโน้ม</button></div>
            </div>
          </div>
          <TrendChart indicator={indicator} mode={chartMode} />
          <div className="detail-chart-footer"><span><CalendarRange size={15} /> {formatFiscalRange(indicator.fiscalYear)}</span><span><Layers3 size={15} /> Percentile ล่าสุด {latest.percentile ?? '—'}</span></div>
        </article>
        <article className="panel definition-panel">
          <div className="panel-heading"><div><span className="panel-eyebrow">INDICATOR CONTRACT</span><h3>นิยามที่ใช้คำนวณ</h3></div><ClipboardList size={18} className="heading-icon" /></div>
          <div className="definition-block"><span className="definition-label">สูตรคำนวณ</span><strong>{indicator.formula}</strong></div>
          <div className="definition-split"><div><span className="definition-label">ตัวตั้ง (a)</span><p>{indicator.numeratorLabel}</p></div><div><span className="definition-label">ตัวหาร (b)</span><p>{indicator.denominatorLabel}</p></div></div>
          <div className="definition-block"><span className="definition-label">นิยาม / ขอบเขต</span><p>{indicator.definition}</p></div>
          <div className="definition-meta"><span><Database size={14} /> {indicator.sourceTables.length ? indicator.sourceTables.join(' · ') : 'รอผูก source view'}</span><span><CalendarRange size={14} /> {indicator.frequency} · {formatFiscalYearShort(indicator.fiscalYear)}</span></div>
        </article>
      </section>

      <section className="panel monthly-detail-panel">
        <div className="panel-heading"><div><span className="panel-eyebrow">12-MONTH DETAIL</span><h3>ตัวตั้ง ตัวหาร และสถานะของทุกเดือน</h3><p>{indicator.dataSource === 'bms' ? 'ตัวเลขในตารางอ่านจาก BMS แบบ read-only และจัดกลุ่มตามเดือนงบประมาณ' : hasMonthlyData ? 'ตัวเลขในตารางเป็นข้อมูล demo เพื่อแสดง contract ของหน้ารายละเอียด' : 'ยังไม่มีผลลัพธ์รายเดือนของโรงพยาบาล จึงแสดงค่าว่างแทนการคาดเดา'}</p></div><span className="reference-note">{indicator.reference}</span></div>
        <div className="monthly-table-wrap">
          <table className="monthly-table">
            <thead><tr><th>เดือนงบประมาณ</th><th>ตัวตั้ง (a)</th><th>ตัวหาร (b)</th><th>ผลลัพธ์</th><th>{targetLabel}</th><th>Percentile</th><th>สถานะ</th></tr></thead>
            <tbody>{indicator.monthly.map((month, index) => <tr key={month.fiscalMonth} className={index === indicator.monthly.length - 1 ? 'is-latest' : ''}><td><strong>{month.label}</strong><span>{formatFiscalYearShort(indicator.fiscalYear)} · เดือนที่ {month.fiscalMonth}</span></td><td>{formatNumber(month.numerator)}</td><td>{formatNumber(month.denominator)}</td><td><strong>{formatIndicatorValue(indicator, month.value)}</strong></td><td>{formatIndicatorValue(indicator, indicator.targetScope === 'monthly' ? month.target : null)}</td><td>{month.percentile === null ? '—' : <span className="percentile-cell"><i style={{ width: `${month.percentile}%` }} />{month.percentile}</span>}</td><td><StatusPill status={month.status} compact /></td></tr>)}</tbody>
          </table>
        </div>
      </section>

      <div className="source-callout"><Info size={16} /><span>เกณฑ์อ้างอิง: {indicator.reference} · เมื่อเชื่อม BMS จริง ระบบจะอ่านผลลัพธ์จาก registered query ที่มี grain เป็น 1 indicator × 1 fiscal month และสรุปผลงานต่อปีงบประมาณโดยไม่แปลงวันที่ ISO ในฐานข้อมูล</span></div>
    </div>
  );
}
