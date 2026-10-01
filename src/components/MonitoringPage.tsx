import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { Download, Search, RefreshCw, X, ArrowRight } from 'lucide-react';
import type { IndicatorGroup } from '@/types/thip';
import type { BmsRuntimeConfig } from '@/services/bmsSession';
import { groupMeta } from '@/data/thipMeta';
import { monitoringRules, monitoringRulesByCode, monitoringUnitLabels } from '@/monitoring/rules';
import { emptyMonitoring, loadMonitoring } from '@/monitoring/contract';
import { createMonitoringProvider, monitoringPreviewEnabled } from '@/monitoring/provider';
import { downloadMonitoringCsv } from '@/monitoring/export';
import type { MonitoringAssessment, MonitoringDataStatus, MonitoringLoadResult, MonthlyMonitoringResult } from '@/monitoring/types';
import { formatFiscalYear, getCurrentFiscalYear, getFiscalMonthPeriods, toBuddhistYear } from '@/utils/fiscal';

export const monitoringDataLabels: Record<MonitoringDataStatus, string> = { measured: 'มีผลวัด', 'zero-cohort': 'ไม่มีกลุ่มตัวอย่าง', 'missing-source': 'ไม่มีแหล่งข้อมูล', 'rule-unapproved': 'รอรับรองสูตร', future: 'เดือนอนาคต' };
export const monitoringAssessmentLabels: Record<MonitoringAssessment, string> = { 'on-track': 'ผ่านเป้า', watch: 'เฝ้าระวัง', action: 'ต้องดำเนินการ', 'no-target': 'ไม่มีเป้าหมาย', 'not-assessable': 'ยังประเมินไม่ได้' };
const shortDataLabels = { ...monitoringDataLabels, 'zero-cohort': 'ไม่มีกลุ่ม', 'missing-source': 'ไม่มีแหล่ง', 'rule-unapproved': 'รอรับรอง' };
const readFilter = <T extends string,>(key: string, options: Record<T, string>): T | 'all' => {
  const value = new URLSearchParams(window.location.search).get(key);
  return value && value in options ? value as T : 'all';
};
type Props = { fiscalYear: number; onFiscalYearChange(year: number): void; group: IndicatorGroup | 'all'; onGroupChange(group: IndicatorGroup | 'all'): void; search: string; onSearchChange(search: string): void; runtime: BmsRuntimeConfig | null; onOverview(): void };
export function MonitoringPage({ fiscalYear, onFiscalYearChange, group, onGroupChange, search, onSearchChange, runtime, onOverview }: Props) {
  const [snapshot, setSnapshot] = useState<MonitoringLoadResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [refresh, setRefresh] = useState(0);
  const [dataFilter, setDataFilter] = useState<MonitoringDataStatus | 'all'>(() => readFilter('data', monitoringDataLabels));
  const [assessmentFilter, setAssessmentFilter] = useState<MonitoringAssessment | 'all'>(() => readFilter('assessment', monitoringAssessmentLabels));
  const [selected, setSelected] = useState<MonthlyMonitoringResult | null>(null);
  const [focusCell, setFocusCell] = useState('');
  const dialog = useRef<HTMLDialogElement>(null);
  const opener = useRef<HTMLElement | null>(null);
  const buttons = useRef(new Map<string, HTMLButtonElement>());
  const snapshotMatches = snapshot?.fiscalYear === fiscalYear;
  const current = snapshotMatches ? snapshot! : emptyMonitoring(fiscalYear, new Date(), monitoringPreviewEnabled);
  const periods = useMemo(() => getFiscalMonthPeriods(fiscalYear), [fiscalYear]);
  useEffect(() => {
    const controller = new AbortController();
    setSnapshot(null); setLoading(true); setSelected(null);
    void createMonitoringProvider(runtime).then((provider) => loadMonitoring(provider, fiscalYear, controller.signal)).then((result) => {
      if (!controller.signal.aborted) { setSnapshot(result); setLoading(false); }
    }).catch(() => {
      if (!controller.signal.aborted) {
        setSnapshot(emptyMonitoring(fiscalYear, new Date(), monitoringPreviewEnabled, 'อ่านผลติดตามรายเดือนไม่สำเร็จ กรุณาลองใหม่หรือให้ผู้ดูแลตรวจ source aggregate'));
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
  const visibleRules = monitoringRules.filter((rule) => (group === 'all' || rule.group === group)
    && (!search.trim() || `${rule.code} ${rule.title}`.toLowerCase().includes(search.trim().toLowerCase()))
    && rowsByCode.get(rule.code)!.some((row) => (dataFilter === 'all' || row.dataStatus === dataFilter) && (assessmentFilter === 'all' || row.assessment === assessmentFilter)));
  const firstCell = visibleRules.length ? `${visibleRules[0].code}:1` : '';
  const activeCell = visibleRules.some((rule) => focusCell.startsWith(`${rule.code}:`)) ? focusCell : firstCell;
  function filterChanged(key: string, value: string) {
    const params = new URLSearchParams(window.location.search);
    if (value === 'all') params.delete(key); else params.set(key, value);
    window.history.pushState({}, '', `${window.location.pathname}?${params}`);
  }
  function open(row: MonthlyMonitoringResult, button: HTMLElement) { opener.current = button; setSelected(row); }
  function close() { setSelected(null); opener.current?.focus(); }
  function keyDown(event: KeyboardEvent<HTMLButtonElement>, rowIndex: number, month: number) {
    let nextRow = rowIndex; let nextMonth = month;
    if (event.key === 'ArrowRight') nextMonth++;
    else if (event.key === 'ArrowLeft') nextMonth--;
    else if (event.key === 'ArrowDown') nextRow++;
    else if (event.key === 'ArrowUp') nextRow--;
    else if (event.key === 'Home') nextMonth = 1;
    else if (event.key === 'End') nextMonth = 12;
    else return;
    event.preventDefault();
    nextRow = Math.max(0, Math.min(visibleRules.length - 1, nextRow)); nextMonth = Math.max(1, Math.min(12, nextMonth));
    const key = `${visibleRules[nextRow].code}:${nextMonth}`; setFocusCell(key); buttons.current.get(key)?.focus();
  }
  const exportRows = visibleRules.flatMap((rule) => rowsByCode.get(rule.code)!);
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
    <div className="monitoring-actions"><p>แสดง {visibleRules.length}/232 รหัส · กรองแถวที่มีอย่างน้อยหนึ่งเดือนตรงกับสถานะที่เลือก</p><div><button className="secondary-button" onClick={() => setRefresh((value) => value + 1)} disabled={loading}><RefreshCw size={15} /> รีเฟรช</button><button className="secondary-button" disabled={loading || !snapshotMatches || Boolean(current.error) || !exportRows.length} onClick={() => downloadMonitoringCsv(current, exportRows, fiscalYear)}><Download size={15} /> ส่งออก CSV</button></div></div>
    <div className="monitoring-coverage" aria-live="polite">{loading || !snapshotMatches ? 'กำลังอ่านข้อมูลปีที่เลือก…' : `มีผลวัด ${current.measuredCells}/${current.totalCells} ช่อง · ${formatFiscalYear(fiscalYear)}`}{!loading && !current.preview && ' · สูตรจริงยังต้องได้รับการรับรองก่อนเผยแพร่'}{current.refreshedAt && ` · อัปเดต ${new Date(current.refreshedAt).toLocaleString('th-TH', { timeZone: 'Asia/Bangkok' })}`}</div>
    {current.error && <p className="monitoring-error" role="alert">{current.error}</p>}
    <p className="monitoring-help" id="matrix-help">ใช้ลูกศรย้ายช่อง · Enter ดูรายละเอียด · Escape ปิดรายละเอียด · สีเฝ้าระวังเป็นเกณฑ์ของระบบ (8% ของเป้าหมาย หรือ 0.02); เกณฑ์ช่วงใช้ watch เมื่อ rule กำหนดเท่านั้น</p>
    <div className="monitoring-scroll" role="region" aria-label="ตาราง KPI รายเดือน เลื่อนแนวนอนเพื่อดูเดือนถัดไป" tabIndex={0}>
      <table className="monitoring-matrix" aria-describedby="matrix-help" aria-busy={loading}><caption className="sr-only">ตารางติดตาม KPI 232 รหัส × 12 เดือน {formatFiscalYear(fiscalYear)}{current.preview ? ' ข้อมูลสังเคราะห์' : ''}</caption>
        <thead><tr><th scope="col" className="monitoring-identity">รหัส / ตัวชี้วัด</th>{periods.map((period) => <th scope="col" key={period.fiscalMonth}><span>{period.monthLabel}</span><small>{toBuddhistYear(period.calendarYear)}</small></th>)}</tr></thead>
        <tbody>{visibleRules.map((rule, rowIndex) => <tr key={rule.code}><th scope="row" className="monitoring-identity" title={rule.title}><strong>{rule.code}</strong><span>{rule.title}</span></th>{rowsByCode.get(rule.code)!.map((row) => {
          const key = `${row.code}:${row.fiscalMonth}`;
          return <td key={key}><button ref={(element) => { if (element) buttons.current.set(key, element); else buttons.current.delete(key); }} type="button" className={`monitoring-cell state-${row.dataStatus} assessment-${row.assessment}`} tabIndex={activeCell === key ? 0 : -1} onFocus={() => setFocusCell(key)} onKeyDown={(event) => keyDown(event, rowIndex, row.fiscalMonth)} onClick={(event) => open(row, event.currentTarget)} aria-label={`${row.code} ${periods[row.fiscalMonth - 1].label}: ${row.value === null ? monitoringDataLabels[row.dataStatus] : `${formatValue(row)} ${monitoringUnitLabels[row.unit]}, ${monitoringAssessmentLabels[row.assessment]}`}`}><strong>{row.value === null ? '—' : formatValue(row)}</strong><small>{row.dataStatus === 'measured' ? monitoringAssessmentLabels[row.assessment] : shortDataLabels[row.dataStatus]}</small>{row.value !== null && <span>{monitoringUnitLabels[row.unit]}</span>}</button></td>;
        })}</tr>)}</tbody>
      </table>
      {!visibleRules.length && <div className="monitoring-empty"><strong>ไม่พบ KPI ที่ตรงกับตัวกรอง</strong><p>ลองเปลี่ยนคำค้น กลุ่ม หรือสถานะข้อมูล</p><button className="secondary-button" onClick={() => { onSearchChange(''); onGroupChange('all'); setDataFilter('all'); setAssessmentFilter('all'); const params = new URLSearchParams(window.location.search); params.delete('data'); params.delete('assessment'); window.history.pushState({}, '', `${window.location.pathname}?${params}`); }}>ล้างตัวกรอง</button></div>}
    </div>
    <dialog className="monitoring-dialog" ref={dialog} aria-labelledby="monitoring-detail-title" onCancel={(event) => { event.preventDefault(); close(); }} onClose={() => { setSelected(null); opener.current?.focus(); }}>
      {selected && <><div className="monitoring-dialog-header"><h2 id="monitoring-detail-title">{selected.code} · {periods[selected.fiscalMonth - 1].label}</h2><button className="icon-button" autoFocus aria-label="ปิดรายละเอียด" onClick={close}><X size={20} /></button></div><p>{monitoringRulesByCode.get(selected.code)!.title}</p>{selected.synthetic && <p className="monitoring-preview"><strong>ข้อมูลสังเคราะห์</strong></p>}<dl className="monitoring-facts">
        <Fact label="ชนิดผล">ติดตามรายเดือน</Fact><Fact label="สถานะข้อมูล">{monitoringDataLabels[selected.dataStatus]}</Fact><Fact label="ผลเทียบเป้า">{monitoringAssessmentLabels[selected.assessment]}</Fact>
        <Fact label="ช่วงข้อมูล">{selected.periodStart} ถึง {selected.periodEnd} (ไม่รวมวันสิ้นสุด)</Fact><Fact label="ข้อมูลครอบคลุมถึง">{selected.dataThrough ?? 'ยังไม่มีข้อมูล'}</Fact>
        <Fact label="ตัวตั้ง">{selected.numerator ?? 'NULL'}</Fact><Fact label="ตัวหาร">{selected.denominator ?? 'NULL'}</Fact><Fact label="ค่า / หน่วย">{formatValue(selected)} {monitoringUnitLabels[selected.unit]}</Fact>
        <Fact label="เป้าหมายโรงพยาบาล">{selected.target ? selected.target.value ?? `${selected.target.lower}–${selected.target.upper}` : 'ยังไม่มีเป้าหมายที่ยืนยัน'}</Fact><Fact label="แหล่งเป้าหมาย / ช่วงที่ใช้">{selected.target ? `${selected.target.source} · ${selected.target.validFrom} ถึง ${selected.target.validTo}` : 'NULL — ไม่มี crosswalk ที่รับรอง'}</Fact>
        <Fact label="ผลสะสม">{selected.cumulative.value ?? 'NULL'} · ตัวตั้ง {selected.cumulative.numerator ?? 'NULL'} / ตัวหาร {selected.cumulative.denominator ?? 'NULL'} · {selected.cumulative.complete ? 'ครบช่วงสะสมที่ source ระบุ' : 'ยังไม่ครบหรือยังคำนวณไม่ได้'} · ถึง {selected.cumulative.through ?? '—'}</Fact>
        <Fact label="สูตรติดตามรายเดือน">{selected.formula}</Fact><Fact label="วิธีสะสม">{selected.accumulation} · {selected.method}</Fact><Fact label="เหตุผล">{selected.reason ?? 'มี aggregate ในเดือนนี้'}</Fact>
        <Fact label="Benchmark จากพจนานุกรม">{monitoringRulesByCode.get(selected.code)!.dictionaryBenchmark ?? 'ไม่ได้ระบุ'} (แยกจากเป้าหมายโรงพยาบาล)</Fact><Fact label="อ้างอิง">{monitoringRulesByCode.get(selected.code)!.reference}</Fact><Fact label="Rule version / refresh">{selected.ruleVersion} · {selected.refreshedAt ?? 'ยังไม่ refresh'}</Fact>
      </dl></>}
    </dialog>
  </div>;
}
function formatValue(row: MonthlyMonitoringResult): string { return row.value === null ? '—' : row.value.toLocaleString('th-TH', { maximumFractionDigits: monitoringRulesByCode.get(row.code)?.precision ?? 2 }); }
function Fact({ label, children }: { label: string; children: React.ReactNode }) { return <div><dt>{label}</dt><dd>{children}</dd></div>; }
