import { useEffect, useMemo, useRef, useState, useDeferredValue, useCallback, memo, type KeyboardEvent } from 'react';
import { Download, Search, RefreshCw, X, ArrowRight } from 'lucide-react';
import type { IndicatorGroup } from '@/types/thip';
import type { BmsRuntimeConfig } from '@/services/bmsSession';
import { groupMeta } from '@/data/thipMeta';
import { monitoringRules, monitoringRulesByCode, monitoringUnitLabels } from '@/monitoring/rules';
import { emptyMonitoring, loadMonitoring } from '@/monitoring/contract';
import { createMonitoringProvider, monitoringPreviewEnabled } from '@/monitoring/provider';
import { downloadMonitoringCsv } from '@/monitoring/export';
import type { MonitoringAssessment, MonitoringDataStatus, MonitoringLoadResult, MonthlyMonitoringResult } from '@/monitoring/types';
import { formatThaiDate, formatThaiDateTime, formatFiscalYear, getCurrentFiscalYear, getFiscalMonthPeriods, toBuddhistYear } from '@/utils/fiscal';

export const monitoringDataLabels: Record<MonitoringDataStatus, string> = { measured: 'มีผลวัด', 'zero-cohort': 'ไม่มีกลุ่มตัวอย่าง', 'missing-source': 'ไม่มีแหล่งข้อมูล', 'rule-unapproved': 'รอรับรองสูตร', future: 'เดือนอนาคต' };
export const monitoringAssessmentLabels: Record<MonitoringAssessment, string> = { 'on-track': 'ผ่านเป้า', watch: 'เฝ้าระวัง', action: 'ต้องดำเนินการ', 'no-target': 'ไม่มีเป้าหมาย', 'not-assessable': 'ยังประเมินไม่ได้' };
const shortDataLabels = { ...monitoringDataLabels, 'zero-cohort': 'ไม่มีกลุ่ม', 'missing-source': 'ไม่มีแหล่ง', 'rule-unapproved': 'รอรับรอง' };
const readFilter = <T extends string,>(key: string, options: Record<T, string>): T | 'all' => {
  const value = new URLSearchParams(window.location.search).get(key);
  return value && value in options ? value as T : 'all';
};
type Props = { fiscalYear: number; onFiscalYearChange(year: number): void; group: IndicatorGroup | 'all'; onGroupChange(group: IndicatorGroup | 'all'): void; search: string; onSearchChange(search: string): void; runtime: BmsRuntimeConfig | null; onOverview(): void };
export function MonitoringPage({ fiscalYear, onFiscalYearChange, group, onGroupChange, search, onSearchChange, runtime, onOverview }: Props) {
  const [snapshot, setSnapshot] = useState<{ result: MonitoringLoadResult; runtime: BmsRuntimeConfig | null } | null>(null);
  const [loading, setLoading] = useState(true);
  const [refresh, setRefresh] = useState(0);
  const [dataFilter, setDataFilter] = useState<MonitoringDataStatus | 'all'>(() => readFilter('data', monitoringDataLabels));
  const [assessmentFilter, setAssessmentFilter] = useState<MonitoringAssessment | 'all'>(() => readFilter('assessment', monitoringAssessmentLabels));
  const [selection, setSelected] = useState<MonthlyMonitoringResult | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const opener = useRef<HTMLElement | null>(null);
  const snapshotMatches = snapshot?.result.fiscalYear === fiscalYear && snapshot.runtime === runtime;
  const empty = useMemo(() => emptyMonitoring(fiscalYear, new Date(), monitoringPreviewEnabled), [fiscalYear, runtime]);
  const current = snapshotMatches ? snapshot!.result : empty;
  const selected = snapshotMatches && selection?.fiscalYear === fiscalYear ? selection : null;
  const deferredSearch = useDeferredValue(search);
  const filtering = search !== deferredSearch;
  const periods = useMemo(() => getFiscalMonthPeriods(fiscalYear), [fiscalYear]);
  useEffect(() => {
    const controller = new AbortController();
    setSnapshot(null); setLoading(true); setSelected(null);
    void createMonitoringProvider(runtime).then((provider) => loadMonitoring(provider, fiscalYear, controller.signal)).then((result) => {
      if (!controller.signal.aborted) { setSnapshot({ result, runtime }); setLoading(false); }
    }).catch(() => {
      if (!controller.signal.aborted) {
        setSnapshot({ result: emptyMonitoring(fiscalYear, new Date(), monitoringPreviewEnabled, 'อ่านผลติดตามรายเดือนไม่สำเร็จ กรุณาลองใหม่หรือให้ผู้ดูแลตรวจ source aggregate'), runtime });
        setLoading(false);
      }
    });
    return () => controller.abort();
  }, [fiscalYear, runtime, refresh]);
  useEffect(() => {
    const restore = () => { setDataFilter(readFilter('data', monitoringDataLabels)); setAssessmentFilter(readFilter('assessment', monitoringAssessmentLabels)); };
    window.addEventListener('popstate', restore);
    return () => window.removeEventListener('popstate', restore);
  }, []);
  useEffect(() => {
    if (selected && dialog.current && !dialog.current.open) dialog.current.showModal();
    else if (!selected && dialog.current?.open) dialog.current.close();
  }, [selected]);
  const rowsByCode = useMemo(() => {
    const map = new Map<string, MonthlyMonitoringResult[]>();
    for (const row of current.rows) map.set(row.code, [...(map.get(row.code) ?? []), row]);
    return map;
  }, [current.rows]);
  const visibleRules = useMemo(() => {
    const query = deferredSearch.trim().toLowerCase();
    return monitoringRules.filter((rule) => (group === 'all' || rule.group === group)
      && (!query || searchIndex.get(rule.code)!.includes(query))
      && rowsByCode.get(rule.code)!.some((row) => (dataFilter === 'all' || row.dataStatus === dataFilter) && (assessmentFilter === 'all' || row.assessment === assessmentFilter)));
  }, [group, deferredSearch, rowsByCode, dataFilter, assessmentFilter]);
  const visibleCodes = useMemo(() => new Set(visibleRules.map(rule => rule.code)), [visibleRules]);
  function filterChanged(key: string, value: string) {
    const params = new URLSearchParams(window.location.search);
    if (value === 'all') params.delete(key); else params.set(key, value);
    window.history.pushState({}, '', `${window.location.pathname}?${params}`);
  }
  const open = useCallback((row: MonthlyMonitoringResult, button: HTMLElement) => { opener.current = button; setSelected(row); }, []);
  function close() { setSelected(null); opener.current?.focus(); }
  const exportRows = useMemo(() => visibleRules.flatMap((rule) => rowsByCode.get(rule.code)!), [visibleRules, rowsByCode]);
  const yearOptions = [...new Set([getCurrentFiscalYear(), fiscalYear, ...Array.from({ length: 5 }, (_, index) => getCurrentFiscalYear() - index - 1)])].sort((a, b) => b - a);
  return <div className="page-stack monitoring-page">
    <header className="monitoring-heading"><div><h1>ติดตาม KPI รายเดือน</h1><p>232 ตัวชี้วัด · ต.ค.–ก.ย. · ผลติดตามแยกจากรอบรายงาน THIP</p></div><button className="secondary-button" onClick={onOverview}>ภาพรวมรายงาน THIP <ArrowRight size={16} /></button></header>
    {current.preview && <div className="monitoring-preview" role="status"><strong>ข้อมูลสังเคราะห์</strong><span>Development preview · ใช้ทดลองการติดตามและหน้าจอ · ยังไม่ใช่ผลงานโรงพยาบาล</span></div>}
    <section className="monitoring-toolbar" aria-label="ค้นหาและกรอง KPI">
      <label>ปีงบประมาณ<select aria-label="เลือกปีงบประมาณ" value={fiscalYear} onChange={(event) => onFiscalYearChange(Number(event.target.value))}>{yearOptions.map((year) => <option key={year} value={year}>{toBuddhistYear(year)}</option>)}</select></label>
      <label className="monitoring-search">ค้นหารหัสหรือชื่อ<div><Search size={16} /><input aria-label="ค้นหารหัสหรือชื่อ KPI" placeholder="เช่น DH0101 หรือ การเสียชีวิต" value={search} onChange={(event) => onSearchChange(event.target.value)} /></div></label>
      <label>กลุ่ม<select aria-label="กรองกลุ่ม KPI" value={group} onChange={(event) => onGroupChange(event.target.value as IndicatorGroup | 'all')}><option value="all">ทุกกลุ่ม</option>{Object.values(groupMeta).map((meta) => <option key={meta.key} value={meta.key}>{meta.key} · {meta.shortLabel}</option>)}</select></label>
      <label>สถานะข้อมูล<select aria-label="กรองสถานะข้อมูล" value={dataFilter} onChange={(event) => { setDataFilter(event.target.value as MonitoringDataStatus | 'all'); filterChanged('data', event.target.value); }}><option value="all">ทุกสถานะข้อมูล</option>{Object.entries(monitoringDataLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
      <label>ผลเทียบเป้า<select aria-label="กรองผลเทียบเป้า" value={assessmentFilter} onChange={(event) => { setAssessmentFilter(event.target.value as MonitoringAssessment | 'all'); filterChanged('assessment', event.target.value); }}><option value="all">ทุกผลเทียบเป้า</option>{Object.entries(monitoringAssessmentLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
    </section>
    <div className="monitoring-actions"><p>แสดง {visibleRules.length}/232 รหัส · กรองแถวที่มีอย่างน้อยหนึ่งเดือนตรงกับสถานะที่เลือก{filtering && <span role="status"> · กำลังปรับตัวกรอง…</span>}</p><div><button className="secondary-button" onClick={() => setRefresh((value) => value + 1)} disabled={loading}><RefreshCw size={15} /> รีเฟรช</button><button className="secondary-button" disabled={loading || filtering || !snapshotMatches || Boolean(current.error) || !exportRows.length} onClick={() => downloadMonitoringCsv(current, exportRows, fiscalYear)}><Download size={15} /> ส่งออก CSV</button></div></div>
    <div className="monitoring-coverage" aria-live="polite">{loading || !snapshotMatches ? 'กำลังอ่านข้อมูลปีที่เลือก…' : `มีผลวัด ${current.measuredCells}/${current.totalCells} ช่อง · ${formatFiscalYear(fiscalYear)}`}{!loading && !current.preview && ' · สูตรจริงยังต้องได้รับการรับรองก่อนเผยแพร่'}{current.refreshedAt && ` · อัปเดต ${formatThaiDateTime(current.refreshedAt)}`}</div>
    {current.error && <p className="monitoring-error" role="alert">{current.error}</p>}
    <p className="monitoring-help" id="matrix-help">ใช้ลูกศรย้ายช่อง · Enter ดูรายละเอียด · Escape ปิดรายละเอียด · สีเฝ้าระวังเป็นเกณฑ์ของระบบ (8% ของเป้าหมาย หรือ 0.02); เกณฑ์ช่วงใช้ watch เมื่อ rule กำหนดเท่านั้น</p>
    <div className="monitoring-scroll" role="region" aria-label="ตาราง KPI รายเดือน">
      <MonitoringMatrix rowsByCode={rowsByCode} visibleCodes={visibleCodes} periods={periods} fiscalYear={fiscalYear} preview={current.preview} loading={loading || filtering} onOpen={open} />
      {!visibleRules.length && <div className="monitoring-empty"><strong>ไม่พบ KPI ที่ตรงกับตัวกรอง</strong><p>ลองเปลี่ยนคำค้น กลุ่ม หรือสถานะข้อมูล</p><button className="secondary-button" onClick={() => { onSearchChange(''); onGroupChange('all'); setDataFilter('all'); setAssessmentFilter('all'); const params = new URLSearchParams(window.location.search); params.delete('data'); params.delete('assessment'); window.history.pushState({}, '', `${window.location.pathname}?${params}`); }}>ล้างตัวกรอง</button></div>}
    </div>
    <dialog className="monitoring-dialog" ref={dialog} aria-labelledby="monitoring-detail-title" onCancel={(event) => { event.preventDefault(); close(); }} onClose={() => { setSelected(null); opener.current?.focus(); }}>
      {selected && <><div className="monitoring-dialog-header"><h2 id="monitoring-detail-title">{selected.code} · {periods[selected.fiscalMonth - 1].label}</h2><button className="icon-button" autoFocus aria-label="ปิดรายละเอียด" onClick={close}><X size={20} /></button></div><p>{monitoringRulesByCode.get(selected.code)!.title}</p>{selected.synthetic && <p className="monitoring-preview"><strong>ข้อมูลสังเคราะห์</strong></p>}<dl className="monitoring-facts">
        <Fact label="ชนิดผล">ติดตามรายเดือน</Fact><Fact label="สถานะข้อมูล">{monitoringDataLabels[selected.dataStatus]}</Fact><Fact label="ผลเทียบเป้า">{monitoringAssessmentLabels[selected.assessment]}</Fact>
        <Fact label="ช่วงข้อมูล">{formatThaiDate(selected.periodStart)} ถึง {formatThaiDate(selected.periodEnd)} (ไม่รวมวันสิ้นสุด)</Fact><Fact label="ข้อมูลครอบคลุมถึง">{selected.dataThrough ? formatThaiDate(selected.dataThrough) : 'ยังไม่มีข้อมูล'}</Fact>
        <Fact label="ตัวตั้ง">{selected.numerator ?? 'NULL'}</Fact><Fact label="ตัวหาร">{selected.denominator ?? 'NULL'}</Fact><Fact label="ค่า / หน่วย">{formatValue(selected)} {monitoringUnitLabels[selected.unit]}</Fact>
        <Fact label="เป้าหมายโรงพยาบาล">{selected.target ? selected.target.value ?? `${selected.target.lower}–${selected.target.upper}` : 'ยังไม่มีเป้าหมายที่ยืนยัน'}</Fact><Fact label="แหล่งเป้าหมาย / ช่วงที่ใช้">{selected.target ? `${selected.target.source} · ${formatThaiDate(selected.target.validFrom)} ถึง ${formatThaiDate(selected.target.validTo)}` : 'NULL — ไม่มี crosswalk ที่รับรอง'}</Fact>
        <Fact label="ผลสะสม">{selected.cumulative.value ?? 'NULL'} · ตัวตั้ง {selected.cumulative.numerator ?? 'NULL'} / ตัวหาร {selected.cumulative.denominator ?? 'NULL'} · {selected.cumulative.complete ? 'ครบช่วงสะสมที่ source ระบุ' : 'ยังไม่ครบหรือยังคำนวณไม่ได้'} · ถึง {formatThaiDate(selected.cumulative.through)}</Fact>
        <Fact label="สูตรติดตามรายเดือน">{selected.formula}</Fact><Fact label="วิธีสะสม">{selected.accumulation} · {selected.method}</Fact><Fact label="เหตุผล">{selected.reason ?? 'มี aggregate ในเดือนนี้'}</Fact>
        <Fact label="Benchmark จากพจนานุกรม">{monitoringRulesByCode.get(selected.code)!.dictionaryBenchmark ?? 'ไม่ได้ระบุ'} (แยกจากเป้าหมายโรงพยาบาล)</Fact><Fact label="อ้างอิง">{monitoringRulesByCode.get(selected.code)!.reference}</Fact><Fact label="Rule version / refresh">{selected.ruleVersion} · {selected.refreshedAt ? formatThaiDateTime(selected.refreshedAt) : 'ยังไม่ refresh'}</Fact>
      </dl></>}
    </dialog>
  </div>;
}
const formatters = new Map<number, Intl.NumberFormat>();
function formatValue(row: MonthlyMonitoringResult): string {
  if (row.value === null) return '—';
  const precision = monitoringRulesByCode.get(row.code)?.precision ?? 2;
  if (!formatters.has(precision)) formatters.set(precision, new Intl.NumberFormat('th-TH', { maximumFractionDigits: precision }));
  return formatters.get(precision)!.format(row.value);
}
function Fact({ label, children }: { label: string; children: React.ReactNode }) { return <div><dt>{label}</dt><dd>{children}</dd></div>; }

const searchIndex = new Map(monitoringRules.map(rule => [rule.code, `${rule.code} ${rule.title}`.toLowerCase()]));
type Periods = ReturnType<typeof getFiscalMonthPeriods>;
type MatrixProps = { rowsByCode: Map<string, MonthlyMonitoringResult[]>; visibleCodes: Set<string>; periods: Periods; fiscalYear: number; preview: boolean; loading: boolean; onOpen(row: MonthlyMonitoringResult, button: HTMLElement): void };
const MonitoringMatrix = memo(function MonitoringMatrix({ rowsByCode, visibleCodes, periods, fiscalYear, preview, loading, onOpen }: MatrixProps) {
  const [focusCell, setFocusCell] = useState('');
  const visible = useMemo(() => monitoringRules.filter(rule => visibleCodes.has(rule.code)).map(rule => rule.code), [visibleCodes]);
  const active = visible.some(code => focusCell.startsWith(`${code}:`)) ? focusCell : visible.length ? `${visible[0]}:1` : '';
  const button = (target: EventTarget | null) => target instanceof Element ? target.closest<HTMLButtonElement>('button[data-monitoring-key]') : null;
  function keyDown(event: KeyboardEvent<HTMLTableElement>) {
    const cell = button(event.target); if (!cell) return;
    const [code, monthText] = cell.dataset.monitoringKey!.split(':');
    let index = visible.indexOf(code), month = Number(monthText);
    if (event.key === 'ArrowRight') month++;
    else if (event.key === 'ArrowLeft') month--;
    else if (event.key === 'ArrowDown') index++;
    else if (event.key === 'ArrowUp') index--;
    else if (event.key === 'Home') month = 1;
    else if (event.key === 'End') month = 12;
    else return;
    event.preventDefault();
    index = Math.max(0, Math.min(visible.length - 1, index)); month = Math.max(1, Math.min(12, month));
    document.getElementById(`monitoring-${visible[index]}-${month}`)?.focus();
  }
  return <table className="monitoring-matrix" role="table" aria-describedby="matrix-help" aria-busy={loading} onKeyDown={keyDown}
    onFocus={(event) => { const cell = button(event.target); if (cell) setFocusCell(cell.dataset.monitoringKey!); }}
    onClick={(event) => { const cell = button(event.target); if (!cell) return; const [code, month] = cell.dataset.monitoringKey!.split(':'); const row = rowsByCode.get(code)?.find(row => row.fiscalMonth === Number(month)); if (row) onOpen(row, cell); }}>
    <caption className="sr-only">ตารางติดตาม KPI 232 รหัส × 12 เดือน {formatFiscalYear(fiscalYear)}{preview ? ' ข้อมูลสังเคราะห์' : ''}</caption>
    <thead role="rowgroup"><tr role="row"><th scope="col" role="columnheader" className="monitoring-identity">รหัส / ตัวชี้วัด</th>{periods.map(period => <th scope="col" role="columnheader" key={period.fiscalMonth}><span>{period.monthLabel}</span><small>{toBuddhistYear(period.calendarYear)}</small></th>)}</tr></thead>
    <tbody role="rowgroup">{monitoringRules.map(rule => <MonitoringMatrixRow key={rule.code} code={rule.code} rows={rowsByCode.get(rule.code)!} periods={periods} hidden={!visibleCodes.has(rule.code)} activeMonth={active.startsWith(`${rule.code}:`) ? Number(active.split(':')[1]) : 0} />)}</tbody>
  </table>;
});
type RowProps = { code: string; rows: MonthlyMonitoringResult[]; periods: Periods; hidden: boolean; activeMonth: number };
const MonitoringMatrixRow = memo(function MonitoringMatrixRow({ code, rows, periods, hidden, activeMonth }: RowProps) {
  const rule = monitoringRulesByCode.get(code)!;
  return <tr hidden={hidden} data-code={code} role="row"><th scope="row" role="rowheader" className="monitoring-identity" title={rule.title}><strong>{code}</strong><span>{rule.title}</span></th>{rows.map(row => <MonitoringMatrixCell key={row.fiscalMonth} row={row} label={periods[row.fiscalMonth - 1].label} active={activeMonth === row.fiscalMonth} />)}</tr>;
}, (a, b) => a.code === b.code && a.periods === b.periods && a.hidden === b.hidden && a.activeMonth === b.activeMonth && a.rows.length === b.rows.length && a.rows.every((row, index) => sameCell(row, b.rows[index])));
function sameCell(a: MonthlyMonitoringResult, b: MonthlyMonitoringResult): boolean { return a.fiscalMonth === b.fiscalMonth && a.value === b.value && a.unit === b.unit && a.dataStatus === b.dataStatus && a.assessment === b.assessment; }
const MonitoringMatrixCell = memo(function MonitoringMatrixCell({ row, label, active }: { row: MonthlyMonitoringResult; label: string; active: boolean }) {
  const value = formatValue(row);
  return <td role="cell" data-month-label={label}><button id={`monitoring-${row.code}-${row.fiscalMonth}`} data-monitoring-key={`${row.code}:${row.fiscalMonth}`} type="button" className={`monitoring-cell state-${row.dataStatus} assessment-${row.assessment}`} tabIndex={active ? 0 : -1} aria-label={`${row.code} ${label}: ${row.value === null ? monitoringDataLabels[row.dataStatus] : `${value} ${monitoringUnitLabels[row.unit]}, ${monitoringAssessmentLabels[row.assessment]}`}`}><strong>{value}</strong><small>{row.dataStatus === 'measured' ? monitoringAssessmentLabels[row.assessment] : shortDataLabels[row.dataStatus]}</small>{row.value !== null && <span>{monitoringUnitLabels[row.unit]}</span>}</button></td>;
}, (a, b) => a.label === b.label && a.active === b.active && sameCell(a.row, b.row));
