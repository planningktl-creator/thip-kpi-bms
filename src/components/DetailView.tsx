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
import { groupMeta } from '@/data/thipMeta';
import { getExpectedFiscalMonths } from '@/data/thipReporting';
import { formatDelta, formatIndicatorValue, formatNumber, formatTargetValue } from '@/utils/format';
import { exportIndicatorCsv } from '@/utils/export';
import { StatusPill } from '@/components/StatusPill';
import { TrendChart, type ChartMode } from '@/components/TrendChart';

type Props = {
  indicator: Indicator;
  onBack: () => void;
};

export function DetailView({ indicator, onBack }: Props) {
  const [chartMode, setChartMode] = useState<ChartMode>('bar');
  const expectedMonths = getExpectedFiscalMonths(indicator.code);
  const reportedMonths = indicator.monthly.filter((month) => month.value !== null);
  const latestApplicableMonth = expectedMonths[expectedMonths.length - 1] ?? 12;
  const latest = reportedMonths[reportedMonths.length - 1] ?? indicator.monthly[latestApplicableMonth - 1];
  const previous = reportedMonths[reportedMonths.length - 2] ?? null;
  const latestIndex = latest.fiscalMonth - 1;
  const latestTarget = indicator.targetScope === 'monthly' ? latest.target : indicator.annual.target;
  const improving = indicator.direction !== 'neutral' && latest.value !== null && previous?.value !== null && previous !== null
    ? indicator.direction === 'lower-is-better' ? latest.value < previous.value : latest.value > previous.value
    : null;
  const dataMonths = reportedMonths.length;
  const targetLabel = indicator.targetScope === 'annual' ? 'เป้าหมายทั้งปี' : 'เป้าหมายต่อรอบรายงาน';

  return (
    <div className="page-stack detail-page">
      <div className="detail-toolbar">
        <button className="back-button" type="button" onClick={onBack}><ArrowLeft size={17} /> กลับไปภาพรวม</button>
        <div className="detail-toolbar-actions"><span className="data-source-label"><Info size={14} /> {indicator.dataSource === 'bms' ? 'BMS live data' : 'ยังไม่มีข้อมูลจริง'}</span><button className="secondary-button" type="button" onClick={() => exportIndicatorCsv(indicator)}><Download size={16} /> ส่งออก CSV</button></div>
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
        <div className="detail-kpi"><span className="detail-kpi-label">{targetLabel}</span><strong>{formatTargetValue(indicator, latestTarget)}</strong><span className="detail-kpi-meta">{indicator.direction === 'lower-is-better' ? 'ค่าต่ำกว่าดีกว่า' : indicator.direction === 'higher-is-better' ? 'ค่าสูงกว่าดีกว่า' : 'ใช้เป็นข้อมูลอ้างอิง'}</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">เทียบรอบก่อน</span><strong className={improving === true ? 'text-good' : improving === false ? 'text-bad' : ''}>{formatDelta(latest.value, previous?.value ?? null, indicator).split(' ').slice(0, 2).join(' ')}</strong><span className="detail-kpi-meta">{improving === true ? <><TrendingUp size={13} /> แนวโน้มดีขึ้น</> : improving === false ? <><TrendingDown size={13} /> ต้องติดตาม</> : indicator.direction === 'neutral' && latest.value !== null && previous?.value !== null ? 'ไม่มีทิศทางเปรียบเทียบ' : 'ไม่มีฐานเปรียบเทียบ'}</span></div>
        <div className="detail-kpi"><span className="detail-kpi-label">ความต่อเนื่องของข้อมูล</span><strong>{dataMonths}/{expectedMonths.length}</strong><span className="detail-kpi-meta"><CheckCircle2 size={13} /> รอบรายงานที่มีข้อมูล</span></div>
      </section>

      <section className="panel annual-summary-panel">
        <div className="panel-heading"><div><span className="panel-eyebrow">FISCAL YEAR ROLLUP</span><h3>สรุปผลการดำเนินงาน · {formatFiscalYear(indicator.fiscalYear)}</h3><p>ฐานข้อมูลใช้วันที่ ISO ภายใน แต่การแสดงผลทั้งหมดใช้ปี พ.ศ. และรอบ ต.ค. — ก.ย.</p></div><span className="annual-year-badge">{formatFiscalYearShort(indicator.fiscalYear)}</span></div>
        <div className="annual-summary-grid">
          <div className="annual-summary-card annual-summary-primary"><span>ผลงานสะสมทั้งปี</span><strong>{formatIndicatorValue(indicator, indicator.annual.value)}</strong><small>จาก {formatNumber(indicator.annual.denominator)} รายการ</small></div>
          <div className="annual-summary-card"><span>{indicator.targetScope === 'annual' ? 'เป้าหมายทั้งปี' : 'เป้าหมายงวดล่าสุด'}</span><strong>{formatTargetValue(indicator, indicator.targetScope === 'annual' ? indicator.annual.target : latestTarget)}</strong><small>{indicator.targetScope === 'annual' ? 'ค่าที่ตั้งไว้ระดับปี' : 'เกณฑ์ของรอบรายงานล่าสุด'}</small></div>
          <div className="annual-summary-card"><span>สถานะทั้งปี</span><StatusPill status={indicator.annual.status} /><small>{dataMonths === expectedMonths.length ? 'ข้อมูลครบตามรอบรายงาน' : `มีข้อมูล ${dataMonths} จาก ${expectedMonths.length} รอบรายงาน`}</small></div>
          <div className="annual-summary-card"><span>ช่วงปีงบประมาณ</span><strong className="annual-range">{formatFiscalRange(indicator.fiscalYear)}</strong><small>{formatFiscalYearShort(indicator.fiscalYear)} · 12 เดือน</small></div>
        </div>
      </section>

      <section className="detail-grid-main">
        <article className="panel detail-chart-panel">
          <div className="panel-heading detail-chart-heading">
            <div><span className="panel-eyebrow">REPORTING-PERIOD PERFORMANCE</span><h3>ผลลัพธ์ตามรอบรายงาน · {formatFiscalYear(indicator.fiscalYear)}</h3><p>{indicator.dataSource === 'bms' ? 'แท่งสีฟ้าแสดงผลงานจริงของแต่ละงวดงบประมาณ' : 'รอผลลัพธ์จริงจาก BMS จึงจะแสดงกราฟ'}</p></div>
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
        <div className="panel-heading"><div><span className="panel-eyebrow">FISCAL-PERIOD DETAIL</span><h3>ตัวตั้ง ตัวหาร และสถานะของทุกงวดรายงาน</h3><p>{indicator.dataSource === 'bms' ? 'ตัวเลขในตารางอ่านจาก BMS แบบ read-only และจัดกลุ่มตามงวดงบประมาณ' : 'ยังไม่มีผลลัพธ์จริงของโรงพยาบาล จึงแสดงค่าว่างแทนการคาดเดา'}</p></div><span className="reference-note">{indicator.reference}</span></div>
        <div className="monthly-table-wrap">
          <table className="monthly-table">
            <thead><tr><th>เดือนงบประมาณ</th><th>ตัวตั้ง (a)</th><th>ตัวหาร (b)</th><th>ผลลัพธ์</th><th>{targetLabel}</th><th>Percentile</th><th>สถานะ</th></tr></thead>
            <tbody>{indicator.monthly.map((month, index) => <tr key={month.fiscalMonth} className={index === latestIndex ? 'is-latest' : ''}><td><strong>{month.label}</strong><span>{formatFiscalYearShort(indicator.fiscalYear)} · งวดที่ {month.fiscalMonth}</span></td><td>{formatNumber(month.numerator)}</td><td>{formatNumber(month.denominator)}</td><td><strong>{formatIndicatorValue(indicator, month.value)}</strong></td><td>{formatTargetValue(indicator, indicator.targetScope === 'monthly' ? month.target : null)}</td><td>{month.percentile === null ? '—' : <span className="percentile-cell"><i style={{ width: `${month.percentile}%` }} />{month.percentile}</span>}</td><td><StatusPill status={month.status} compact /></td></tr>)}</tbody>
          </table>
        </div>
      </section>

      <div className="source-callout"><Info size={16} /><span>เกณฑ์อ้างอิง: {indicator.reference} · เมื่อเชื่อม BMS จริง ระบบจะอ่านผลลัพธ์จาก registered query ที่มี grain เป็น 1 indicator × 1 reporting period และสรุปผลงานต่อปีงบประมาณโดยไม่แปลงวันที่ ISO ในฐานข้อมูล</span></div>
    </div>
  );
}
