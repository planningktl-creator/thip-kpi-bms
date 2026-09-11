import {
  ArrowUpRight,
  BarChart3,
  CheckCircle2,
  ChevronDown,
  Clock3,
  Filter,
  Search,
  Target,
  TriangleAlert,
  TrendingUp,
} from 'lucide-react';
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { BmsConnection, FiscalYear, Indicator, IndicatorGroup, IndicatorStatus, RefreshedAt } from '@/types/thip';
import { groupMeta, sourceDictionaryCount } from '@/data/thipMeta';
import { getLatestApplicableFiscalMonth } from '@/data/thipReporting';
import { formatFiscalYear, formatFiscalYearShort, getFiscalMonthPeriods } from '@/utils/fiscal';
import { formatIndicatorValue, formatPercent, formatRefreshTime } from '@/utils/format';
import { MetricCard } from '@/components/MetricCard';
import { IndicatorTable } from '@/components/IndicatorTable';
import { StatusPill } from '@/components/StatusPill';

type Props = {
  indicators: Indicator[];
  allIndicators: Indicator[];
  activeGroup: IndicatorGroup | 'all';
  onGroupChange: (group: IndicatorGroup | 'all') => void;
  search: string;
  onSearchChange: (value: string) => void;
  monthIndex: number;
  onMonthChange: (index: number) => void;
  fiscalYear: FiscalYear;
  onFiscalYearChange: (fiscalYear: FiscalYear) => void;
  onOpenIndicator: (code: string) => void;
  onOpenCatalog: () => void;
  connection: BmsConnection;
  dataSource: 'loading' | 'live' | 'partial' | 'unavailable';
  refreshedAt: RefreshedAt | null;
};

/** Fiscal years offered in the selector: the current year plus the two before it. */
function selectableFiscalYears(current: FiscalYear): FiscalYear[] {
  return [current, current - 1, current - 2];
}

export function DashboardPage({
  indicators,
  allIndicators,
  activeGroup,
  onGroupChange,
  search,
  onSearchChange,
  monthIndex,
  onMonthChange,
  fiscalYear,
  onFiscalYearChange,
  onOpenIndicator,
  onOpenCatalog,
  connection,
  dataSource,
  refreshedAt,
}: Props) {
  const fiscalMonths = getFiscalMonthPeriods(fiscalYear);
  const selectedMonth = fiscalMonths[monthIndex] ?? fiscalMonths[11]!;
  const periodIndexFor = (indicator: Indicator) => getLatestApplicableFiscalMonth(indicator.code, monthIndex + 1) - 1;
  const currentPeriods = indicators.map((indicator) => indicator.monthly[periodIndexFor(indicator)]);
  const currentValues = currentPeriods.map((period) => period?.value).filter((value): value is number => value !== null && value !== undefined);
  const observedPeriods = currentPeriods.filter((period) => period && (
    period.numerator !== null
    || period.denominator !== null
    || period.value !== null
    || period.target !== null
    || period.percentile !== null
  ));
  const healthScores = indicators
    .map((indicator) => {
      const period = indicator.monthly[periodIndexFor(indicator)];
      return getHealthScore(indicator, period?.value ?? null, period?.target ?? null);
    })
    .filter((value): value is number => value !== null);
  const averageCurrent = healthScores.length ? healthScores.reduce((sum, value) => sum + value, 0) / healthScores.length : null;
  const onTrackCount = indicators.filter((indicator) => indicator.monthly[periodIndexFor(indicator)]?.status === 'on-track').length;
  const actionCount = indicators.filter((indicator) => ['action', 'watch'].includes(indicator.monthly[periodIndexFor(indicator)]?.status ?? '')).length;
  const unbenchmarkedCount = indicators.filter((indicator) => indicator.monthly[periodIndexFor(indicator)]?.status === 'unbenchmarked').length;
  const pulseScore = averageCurrent === null
    ? null
    : Math.round(averageCurrent);
  const currentCompleteness = Math.round((observedPeriods.length / Math.max(indicators.length, 1)) * 100);
  const hasPulseData = healthScores.length > 0;
  const visibleGroupLabel = activeGroup === 'all' ? 'ทุกกลุ่ม THIP' : `${groupMeta[activeGroup].shortLabel} · ${groupMeta[activeGroup].label}`;

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <div className="eyebrow"><span className="eyebrow-dot" /> THIP / QUALITY SIGNALS</div>
          <h1>ภาพรวมคุณภาพ <span>ปีงบประมาณ</span></h1>
          <p className="page-subtitle">อ่านสัญญาณคุณภาพจากตัวตั้งและตัวหารของตัวชี้วัด ก่อนลงรายละเอียดที่ต้องขยับ</p>
        </div>
        <div className="page-actions">
          <label className="fiscal-year-control"><span>ปีงบประมาณ</span><select aria-label="เลือกปีงบประมาณ" value={fiscalYear} onChange={(event) => onFiscalYearChange(Number(event.target.value))}>{selectableFiscalYears(fiscalYear).map((year) => <option key={year} value={year}>{formatFiscalYear(year)}</option>)}</select><ChevronDown size={14} aria-hidden="true" /></label>
          <div className={`connection-chip connection-chip-${connection.status}`}><span className="connection-led" />{dataSource === 'live' ? 'BMS live data' : dataSource === 'partial' ? 'BMS live data บางส่วน' : dataSource === 'loading' ? 'กำลังอ่านข้อมูลจริง' : 'ยังไม่มีข้อมูลจริง'}</div>
          <span className="secondary-button dashboard-refresh-note" role="status"><Clock3 size={16} /> {refreshedAt ? `อัปเดตล่าสุด ${formatRefreshTime(refreshedAt)}` : 'ยังไม่มีการอ่านข้อมูลจริง'} · {selectedMonth.label}</span>
        </div>
      </div>

      <section className="pulse-hero">
        <div className="pulse-orb" role="img" aria-label={`คะแนนสัญญาณคุณภาพ ${pulseScore === null ? 'ยังไม่มีข้อมูล' : `${pulseScore} คะแนน`}`}>
          <div className="pulse-orb-ring ring-one" />
          <div className="pulse-orb-ring ring-two" />
          <div className="pulse-orb-core"><strong>{pulseScore ?? '—'}</strong>{pulseScore !== null && <span>/ 100</span>}</div>
        </div>
        <div className="pulse-copy">
          <span className="hero-kicker">TARGET ATTAINMENT · {formatFiscalYearShort(fiscalYear)}</span>
          <h2>สัญญาณเดือน{selectedMonth.monthLabel}<br /><em>{pulseScore === null ? 'รอข้อมูลจาก BMS' : pulseScore >= 100 ? 'บรรลุเป้าหมายรวม' : 'มีช่องว่างจากเป้าหมาย'}</em></h2>
          <p>ดัชนีนี้คำนวณจากสัดส่วนการบรรลุเป้าหมายของข้อมูลจริงในกลุ่ม <strong>{visibleGroupLabel}</strong> · ตามเป้าหมาย {onTrackCount} จาก {indicators.length || 0} รายการ มี {actionCount} รายการที่ควรเปิดดูต่อ และ {unbenchmarkedCount} รายการที่ยังไม่มีเป้าหมายอ้างอิง</p>
          <div className="hero-badges"><span><CheckCircle2 size={14} /> {onTrackCount} ตามเป้าหมาย</span><span><TriangleAlert size={14} /> {actionCount} เฝ้าดู</span><span><Target size={14} /> {unbenchmarkedCount} ยังไม่กำหนดเป้าหมาย</span></div>
        </div>
        <div className="hero-aside">
          <div className="hero-aside-label">ความใกล้เป้าหมายเฉลี่ย</div>
          <div className="hero-aside-value">{formatPercent(averageCurrent)}</div>
          <div className="hero-aside-caption">คะแนนเทียบเป้าหมายของข้อมูลล่าสุดไม่เกินงวด {selectedMonth.label}</div>
          <div className="hero-aside-line"><span style={{ width: `${pulseScore ?? 0}%` }} /></div>
          <div className="hero-aside-foot"><span>Data completeness</span><strong>{currentCompleteness}%</strong></div>
        </div>
      </section>

      <section className="metric-grid" aria-label="สรุปตัวชี้วัด">
        <MetricCard eyebrow="ตัวชี้วัดใน dictionary" value={String(sourceDictionaryCount)} helper="รายการตาม THIP 2025" icon={BarChart3} tone="aqua" trend="เต็มชุด" />
        <MetricCard eyebrow="กำลังติดตามใน workspace" value={`${indicators.length} รายการ`} helper="รายการจาก catalogue" icon={Target} tone="amber" trend={`${indicators.filter((indicator) => indicator.dataSource === 'bms').length} live`} />
        <MetricCard eyebrow="ข้อมูลครบถ้วน" value={`${currentCompleteness}%`} helper={`ถึงงวด${selectedMonth.label}`} icon={CheckCircle2} tone="violet" trend={currentValues.length ? 'อ่านได้' : 'รอข้อมูล'} />
        <MetricCard eyebrow="ต้องเปิดดูต่อ" value={`${actionCount} รายการ`} helper="watch + action จากข้อมูลจริง" icon={TriangleAlert} tone="coral" trend={actionCount ? 'มีงาน' : currentValues.length ? 'เรียบร้อย' : 'รอข้อมูล'} />
      </section>

      <section className="dashboard-grid dashboard-grid-main">
        <article className="panel trend-panel">
          <div className="panel-heading">
            <div><span className="panel-eyebrow">12 MONTH SIGNAL</span><h3>จังหวะคุณภาพตลอดปีงบประมาณ</h3></div>
            <div className="chart-legend"><span><i className="legend-line legend-aqua" /> การบรรลุเป้าหมาย</span>{hasPulseData && <span><i className="legend-line legend-amber" /> ถึงเป้าหมาย 100</span>}</div>
          </div>
          <QualityPulseChart indicators={indicators} fiscalYear={fiscalYear} />
          <div className="chart-footnote"><span>{hasPulseData ? <><TrendingUp size={15} /> คำนวณจากผลลัพธ์จริงของตัวชี้วัดที่มีข้อมูล</> : 'ยังไม่มีข้อมูลจริงสำหรับคำนวณแนวโน้ม'}</span><strong>{formatFiscalYearShort(fiscalYear)} · {fiscalMonths[0].label} — {fiscalMonths[11].label}</strong></div>
        </article>

        <article className="panel group-panel">
          <div className="panel-heading"><div><span className="panel-eyebrow">GROUP SIGNALS</span><h3>แผนที่ 5 กลุ่ม THIP</h3></div><button className="panel-more" type="button" onClick={onOpenCatalog}>ดูทั้งหมด <ArrowUpRight size={15} /></button></div>
          <div className="group-signal-list">
            {(Object.keys(groupMeta) as IndicatorGroup[]).map((group) => {
              const groupIndicators = allIndicators.filter((item) => item.group === group);
              const scoped = indicators.filter((item) => item.group === group);
              const source = scoped.length ? scoped : groupIndicators;
              const sourceWithData = source.filter((item) => item.monthly[periodIndexFor(item)]?.value !== null && item.monthly[periodIndexFor(item)]?.status !== 'unbenchmarked');
              const good = sourceWithData.filter((item) => item.monthly[periodIndexFor(item)]?.status === 'on-track').length;
              const score = sourceWithData.length ? Math.round((good / sourceWithData.length) * 100) : null;
              const status: IndicatorStatus = score === null ? 'no-data' : score >= 80 ? 'on-track' : score >= 55 ? 'watch' : 'action';
              return (
                <button className={`group-signal-row ${activeGroup === group ? 'is-selected' : ''}`} key={group} onClick={() => onGroupChange(group)}>
                  <span className="group-signal-icon" style={{ backgroundColor: groupMeta[group].color }}>{group}</span>
                  <span className="group-signal-name"><strong>{groupMeta[group].shortLabel}</strong><small>{source.length} ตัวชี้วัดใน view</small></span>
                  <span className="group-score-bar"><i style={{ width: `${score ?? 0}%`, backgroundColor: groupMeta[group].color }} /></span>
                  <span className="group-score">{score === null ? '—' : `${score}%`}</span>
                  <StatusPill status={status} compact />
                </button>
              );
            })}
          </div>
          <div className="group-panel-note"><ShieldNote /> {dataSource === 'live' ? 'แสดงผลจากข้อมูล BMS จริงตาม source view ที่ลงทะเบียนแล้ว' : dataSource === 'partial' ? 'บางรายการมีผลลัพธ์จาก BMS แล้ว ส่วนรายการที่ยังไม่มีผลลัพธ์จะแสดง no-data' : dataSource === 'loading' ? 'กำลังอ่านผลลัพธ์จริงจาก BMS' : 'ยังไม่มีข้อมูลจริงจาก BMS · เปิดแอปผ่าน BMS launcher เพื่ออ่านข้อมูล'}</div>
        </article>
      </section>

      <section className="panel indicator-panel">
        <div className="panel-heading table-heading">
          <div><span className="panel-eyebrow">REPORTING-PERIOD WORKLIST</span><h3>สัญญาณที่ควรดูในงวดนี้</h3><p>กดแถวเพื่อเปิดตัวตั้ง ตัวหาร และรายละเอียดตามรอบรายงาน</p></div>
          <div className="table-actions">
            <label className="search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">ค้นหารหัสหรือชื่อตัวชี้วัด</span><input aria-label="ค้นหารหัสหรือชื่อตัวชี้วัด" value={search} onChange={(event) => onSearchChange(event.target.value)} placeholder="ค้นหารหัสหรือชื่อตัวชี้วัด" /></label>
            <label className="select-field"><CalendarIcon /><span className="sr-only">เลือกเดือนงบประมาณ</span><select aria-label="เลือกเดือนงบประมาณ" value={monthIndex} onChange={(event) => onMonthChange(Number(event.target.value))}>{fiscalMonths.map((month, index) => <option key={month.periodStart} value={index}>{month.label}</option>)}</select><ChevronDown size={15} aria-hidden="true" /></label>
            <button className="filter-button" type="button" onClick={() => onGroupChange(activeGroup === 'all' ? 'D' : 'all')}><Filter size={15} /> {activeGroup === 'all' ? 'กรองกลุ่ม' : groupMeta[activeGroup].shortLabel}</button>
          </div>
        </div>
        <IndicatorTable indicators={indicators} onOpen={onOpenIndicator} monthIndex={monthIndex} />
        <div className="table-footer"><span>แสดง {indicators.length} จาก {allIndicators.length} ตัวชี้วัดที่มีใน workspace</span><button type="button" onClick={() => { onGroupChange('all'); onSearchChange(''); }}>ล้างตัวกรอง <span>↗</span></button></div>
      </section>
    </div>
  );
}

function QualityPulseChart({ indicators, fiscalYear }: { indicators: Indicator[]; fiscalYear: FiscalYear }) {
  const data = getFiscalMonthPeriods(fiscalYear).map((period, index) => {
    const scores = indicators
      .map((indicator) => {
        const period = indicator.monthly[index];
        return getHealthScore(indicator, period?.value ?? null, period?.target ?? null);
      })
      .filter((score): score is number => score !== null);
    const score = scores.length ? Math.round(scores.reduce((sum, value) => sum + value, 0) / scores.length) : null;
    return { label: period.monthLabel, fullLabel: period.label, score, target: score === null ? null : 100 };
  });
  return (
    <div className="quality-chart" role="img" aria-label={`กราฟคะแนนสัญญาณคุณภาพ 12 เดือนของ ${formatFiscalYear(fiscalYear)}`}>
      <ResponsiveContainer width="100%" height={255}>
        <AreaChart data={data} margin={{ top: 16, right: 12, left: -22, bottom: 0 }}>
          <defs><linearGradient id="quality-pulse-fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#2dc9c5" stopOpacity={0.28} /><stop offset="100%" stopColor="#2dc9c5" stopOpacity={0.02} /></linearGradient></defs>
          <CartesianGrid stroke="#e1eaee" strokeDasharray="3 5" vertical={false} />
          <XAxis dataKey="label" axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} />
          <YAxis domain={[40, 100]} axisLine={false} tickLine={false} tick={{ fill: '#81919d', fontSize: 11 }} ticks={[40, 60, 80, 100]} width={30} />
          <Tooltip content={<PulseTooltip />} />
          <Area type="monotone" dataKey="score" stroke="#149e9b" strokeWidth={2.5} fill="url(#quality-pulse-fill)" connectNulls isAnimationActive={false} />
          <Area type="monotone" dataKey="target" stroke="#f4b942" strokeDasharray="5 5" strokeWidth={1.5} fill="none" isAnimationActive={false} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

function PulseTooltip({ active, payload }: { active?: boolean; payload?: Array<{ dataKey?: string; value?: number | null; payload?: { fullLabel?: string } }> }) {
  if (!active || !payload?.length) return null;
  const score = payload.find((entry) => entry.dataKey === 'score')?.value;
  return <div className="chart-tooltip"><strong>{payload[0]?.payload?.fullLabel ?? 'เดือนงบประมาณ'}</strong><span><i className="tooltip-dot tooltip-dot-aqua" />การบรรลุเป้าหมาย {typeof score === 'number' ? score : '—'}</span><span><i className="tooltip-dot tooltip-dot-amber" />ถึงเป้าหมาย 100</span></div>;
}

function CalendarIcon() {
  return <span className="mini-calendar" aria-hidden="true">{new Date().getDate()}</span>;
}

function ShieldNote() {
  return <span className="shield-note-icon"><ShieldCheckIcon /></span>;
}

function ShieldCheckIcon() {
  return <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 3 5 6v5c0 4.6 2.9 8.5 7 10 4.1-1.5 7-5.4 7-10V6l-7-3Z" /><path d="m9 12 2 2 4-4" /></svg>;
}

function getHealthScore(indicator: Indicator, value: number | null, target: number | null): number | null {
  if (value === null) return null;
  if (target === null || indicator.direction === 'neutral') return null;
  if (indicator.direction === 'higher-is-better') {
    if (value >= target) return 100;
    if (target <= 0) return 0;
    return Math.min(100, Math.max(0, (value / target) * 100));
  }
  if (value <= target) return 100;
  if (target <= 0) return 0;
  const ratio = target / value;
  return Math.min(100, Math.max(0, ratio * 100));
}
