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
import type { BmsConnection, Indicator, IndicatorGroup } from '@/types/thip';
import { fiscalMonthLabels, groupMeta, sourceDictionaryCount } from '@/data/thipData';
import { formatCompact, formatIndicatorValue } from '@/utils/format';
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
  onOpenIndicator: (code: string) => void;
  connection: BmsConnection;
};

export function DashboardPage({
  indicators,
  allIndicators,
  activeGroup,
  onGroupChange,
  search,
  onSearchChange,
  monthIndex,
  onMonthChange,
  onOpenIndicator,
  connection,
}: Props) {
  const selectedMonth = fiscalMonthLabels[monthIndex] ?? fiscalMonthLabels[11];
  const currentValues = indicators.map((indicator) => indicator.monthly[monthIndex]?.value).filter((value): value is number => value !== null && value !== undefined);
  const healthScores = indicators.map((indicator) => getHealthScore(indicator, indicator.monthly[monthIndex]?.value ?? null)).filter((value): value is number => value !== null);
  const averageCurrent = healthScores.length ? healthScores.reduce((sum, value) => sum + value, 0) / healthScores.length : 0;
  const onTrackCount = indicators.filter((indicator) => indicator.monthly[monthIndex]?.status === 'on-track').length;
  const actionCount = indicators.filter((indicator) => ['action', 'watch'].includes(indicator.monthly[monthIndex]?.status ?? '')).length;
  const pulseScore = Math.min(99, Math.max(68, Math.round(averageCurrent * 0.72 + (onTrackCount / Math.max(indicators.length, 1)) * 100 * 0.28)));
  const visibleGroupLabel = activeGroup === 'all' ? 'ทุกกลุ่ม THIP' : `${groupMeta[activeGroup].shortLabel} · ${groupMeta[activeGroup].label}`;

  return (
    <div className="page-stack">
      <div className="page-header">
        <div>
          <div className="eyebrow"><span className="eyebrow-dot" /> THIP / QUALITY SIGNALS</div>
          <h1>ภาพรวมคุณภาพ <span>ประจำเดือน</span></h1>
          <p className="page-subtitle">อ่านสัญญาณคุณภาพจากตัวตั้งและตัวหารของตัวชี้วัด ก่อนลงรายละเอียดที่ต้องขยับ</p>
        </div>
        <div className="page-actions">
          <div className={`connection-chip connection-chip-${connection.status}`}><span className="connection-led" />{connection.status === 'connected' ? 'BMS connected' : 'Demo data'}</div>
          <button className="secondary-button" type="button"><Clock3 size={16} /> อัปเดตล่าสุด 08:45</button>
        </div>
      </div>

      <section className="pulse-hero">
        <div className="pulse-orb" aria-label={`คะแนนสัญญาณคุณภาพ ${pulseScore} คะแนน`}>
          <div className="pulse-orb-ring ring-one" />
          <div className="pulse-orb-ring ring-two" />
          <div className="pulse-orb-core"><strong>{pulseScore}</strong><span>/ 100</span></div>
        </div>
        <div className="pulse-copy">
          <span className="hero-kicker">QUALITY PULSE · FY2569</span>
          <h2>สัญญาณเดือน{selectedMonth.replace('.', '')}<br /><em>{pulseScore >= 85 ? 'อยู่ในจังหวะที่ดี' : 'มีจุดต้องเร่งดู'}</em></h2>
          <p>กลุ่ม <strong>{visibleGroupLabel}</strong> มีตัวชี้วัดที่ตามเป้าหมาย {onTrackCount} จาก {indicators.length || 0} รายการ และมี {actionCount} รายการที่ควรเปิดดูต่อ</p>
          <div className="hero-badges"><span><CheckCircle2 size={14} /> {onTrackCount} ตามเป้าหมาย</span><span><TriangleAlert size={14} /> {actionCount} เฝ้าดู</span></div>
        </div>
        <div className="hero-aside">
          <div className="hero-aside-label">ความใกล้เป้าหมายเฉลี่ย</div>
          <div className="hero-aside-value">{formatIndicatorValue({ unit: 'percent' } as Indicator, averageCurrent)}</div>
          <div className="hero-aside-caption">คะแนนเทียบเป้าหมายของตัวชี้วัดที่มีข้อมูลในเดือน{selectedMonth}</div>
          <div className="hero-aside-line"><span style={{ width: `${Math.min(100, pulseScore)}%` }} /></div>
          <div className="hero-aside-foot"><span>Data completeness</span><strong>{Math.round((currentValues.length / Math.max(indicators.length, 1)) * 100)}%</strong></div>
        </div>
      </section>

      <section className="metric-grid" aria-label="สรุปตัวชี้วัด">
        <MetricCard eyebrow="ตัวชี้วัดใน dictionary" value={String(sourceDictionaryCount)} helper="รายการตาม THIP 2025" icon={BarChart3} tone="aqua" trend="เต็มชุด" />
        <MetricCard eyebrow="กำลังติดตามใน workspace" value={`${indicators.length} รายการ`} helper="ตัวอย่างที่มี data contract" icon={Target} tone="amber" trend={`${allIndicators.length} wired`} />
        <MetricCard eyebrow="ข้อมูลครบถ้วน" value={`${Math.round((currentValues.length / Math.max(indicators.length, 1)) * 100)}%`} helper={`เดือน${selectedMonth}`} icon={CheckCircle2} tone="violet" trend="พร้อมอ่าน" />
        <MetricCard eyebrow="ต้องเปิดดูต่อ" value={`${actionCount} รายการ`} helper="watch + action" icon={TriangleAlert} tone="coral" trend={actionCount ? 'มีงาน' : 'เรียบร้อย'} />
      </section>

      <section className="dashboard-grid dashboard-grid-main">
        <article className="panel trend-panel">
          <div className="panel-heading">
            <div><span className="panel-eyebrow">12 MONTH SIGNAL</span><h3>จังหวะคุณภาพตลอดปีงบประมาณ</h3></div>
            <div className="chart-legend"><span><i className="legend-line legend-aqua" /> pulse score</span><span><i className="legend-line legend-amber" /> เป้าหมาย 85</span></div>
          </div>
          <QualityPulseChart indicators={indicators} />
          <div className="chart-footnote"><span><TrendingUp size={15} /> แนวโน้มปรับดีขึ้นจากต้นปีงบประมาณ</span><strong>FY2569 · ต.ค. — ก.ย.</strong></div>
        </article>

        <article className="panel group-panel">
          <div className="panel-heading"><div><span className="panel-eyebrow">GROUP SIGNALS</span><h3>แผนที่ 5 กลุ่ม THIP</h3></div><button className="panel-more" type="button">ดูทั้งหมด <ArrowUpRight size={15} /></button></div>
          <div className="group-signal-list">
            {(Object.keys(groupMeta) as IndicatorGroup[]).map((group) => {
              const groupIndicators = allIndicators.filter((item) => item.group === group);
              const scoped = indicators.filter((item) => item.group === group);
              const source = scoped.length ? scoped : groupIndicators;
              const good = source.filter((item) => item.monthly[monthIndex]?.status === 'on-track').length;
              const score = source.length ? Math.round((good / source.length) * 100) : 0;
              const status = score >= 80 ? 'on-track' : score >= 55 ? 'watch' : 'action';
              return (
                <button className={`group-signal-row ${activeGroup === group ? 'is-selected' : ''}`} key={group} onClick={() => onGroupChange(group)}>
                  <span className="group-signal-icon" style={{ backgroundColor: groupMeta[group].color }}>{group}</span>
                  <span className="group-signal-name"><strong>{groupMeta[group].shortLabel}</strong><small>{source.length} ตัวชี้วัดใน view</small></span>
                  <span className="group-score-bar"><i style={{ width: `${score}%`, backgroundColor: groupMeta[group].color }} /></span>
                  <span className="group-score">{score}%</span>
                  <StatusPill status={status} compact />
                </button>
              );
            })}
          </div>
          <div className="group-panel-note"><ShieldNote /> ขณะนี้แสดงผลจาก demo contract · live mapping จะยึด source view ที่ยืนยันกับโรงพยาบาล</div>
        </article>
      </section>

      <section className="panel indicator-panel">
        <div className="panel-heading table-heading">
          <div><span className="panel-eyebrow">MONTHLY WORKLIST</span><h3>สัญญาณที่ควรดูเดือนนี้</h3><p>กดแถวเพื่อเปิดตัวตั้ง ตัวหาร และรายละเอียดทั้ง 12 เดือน</p></div>
          <div className="table-actions">
            <label className="search-field"><Search size={16} /><input value={search} onChange={(event) => onSearchChange(event.target.value)} placeholder="ค้นหารหัสหรือชื่อตัวชี้วัด" /></label>
            <label className="select-field"><CalendarIcon /><select value={monthIndex} onChange={(event) => onMonthChange(Number(event.target.value))}>{fiscalMonthLabels.map((month, index) => <option key={month} value={index}>{month} 2569</option>)}</select><ChevronDown size={15} /></label>
            <button className="filter-button" type="button" onClick={() => onGroupChange(activeGroup === 'all' ? 'D' : 'all')}><Filter size={15} /> {activeGroup === 'all' ? 'กรองกลุ่ม' : groupMeta[activeGroup].shortLabel}</button>
          </div>
        </div>
        <IndicatorTable indicators={indicators} onOpen={onOpenIndicator} monthIndex={monthIndex} />
        <div className="table-footer"><span>แสดง {indicators.length} จาก {allIndicators.length} ตัวชี้วัดที่มีใน workspace</span><button type="button" onClick={() => onGroupChange('all')}>ล้างตัวกรอง <span>↗</span></button></div>
      </section>
    </div>
  );
}

function QualityPulseChart({ indicators }: { indicators: Indicator[] }) {
  const data = fiscalMonthLabels.map((label, index) => {
    const values = indicators.map((indicator) => indicator.monthly[index]).filter((month) => month?.value !== null && month?.value !== undefined);
    const score = values.length ? Math.round(values.reduce((sum, month) => sum + (month?.status === 'on-track' ? 92 : month?.status === 'watch' ? 77 : 59), 0) / values.length) : null;
    return { label, score, target: 85 };
  });
  return (
    <div className="quality-chart">
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

function PulseTooltip({ active, payload, label }: { active?: boolean; payload?: Array<{ dataKey?: string; value?: number | null }>; label?: string }) {
  if (!active || !payload?.length) return null;
  const score = payload.find((entry) => entry.dataKey === 'score')?.value;
  return <div className="chart-tooltip"><strong>{label} 2569</strong><span><i className="tooltip-dot tooltip-dot-aqua" />pulse score {typeof score === 'number' ? score : '—'}</span><span><i className="tooltip-dot tooltip-dot-amber" />เป้าหมาย 85</span></div>;
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

function getHealthScore(indicator: Indicator, value: number | null): number | null {
  if (value === null) return null;
  if (indicator.target === null || indicator.direction === 'neutral') return 100;
  const ratio = indicator.direction === 'lower-is-better'
    ? indicator.target / Math.max(value, 0.0001)
    : value / Math.max(indicator.target, 0.0001);
  return Math.min(100, Math.max(0, ratio * 100));
}
