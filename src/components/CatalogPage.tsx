import { ArrowUpRight, BookOpen, CheckCircle2, Search, ShieldAlert } from 'lucide-react';
import type { ThipCatalogueEntry } from '@/data/thipCatalogue';
import type { IndicatorGroup } from '@/types/thip';
import { groupMeta, sourceDictionaryCount } from '@/data/thipMeta';

type Props = {
  entries: readonly ThipCatalogueEntry[];
  wiredCodes: Set<string>;
  activeGroup: IndicatorGroup | 'all';
  search: string;
  onSearchChange: (value: string) => void;
  onGroupChange: (group: IndicatorGroup | 'all') => void;
  onOpen: (code: string) => void;
};

export function CatalogPage({ entries, wiredCodes, activeGroup, search, onSearchChange, onGroupChange, onOpen }: Props) {
  const normalized = search.trim().toLowerCase();
  const filtered = entries.filter((entry) => {
    const matchesGroup = activeGroup === 'all' || entry.group === activeGroup;
    const matchesSearch = !normalized || `${entry.code} ${entry.title} ${entry.titleTh}`.toLowerCase().includes(normalized);
    return matchesGroup && matchesSearch;
  });
  const groupCounts = (Object.keys(groupMeta) as IndicatorGroup[]).map((group) => ({
    group,
    count: entries.filter((entry) => entry.group === group).length,
  }));

  return (
    <div className="page-stack catalog-page">
      <div className="page-header">
        <div>
          <div className="eyebrow"><span className="eyebrow-dot" /> THIP / INDICATOR LIBRARY</div>
          <h1>คลังตัวชี้วัด <span>THIP 2025</span></h1>
          <p className="page-subtitle">รายการตัวชี้วัดทั้งหมดจาก dictionary พร้อมสถานะว่าแต่ละรายการมี data contract แล้วหรือยัง</p>
        </div>
        <div className="page-actions"><div className="catalog-count-chip"><BookOpen size={15} /> {sourceDictionaryCount} indicators</div></div>
      </div>

      <section className="catalog-summary-grid">
        <div className="catalog-summary-card"><span className="catalog-summary-icon catalog-summary-aqua"><BookOpen size={17} /></span><div><strong>{sourceDictionaryCount}</strong><span>รายการใน dictionary</span></div></div>
        <div className="catalog-summary-card"><span className="catalog-summary-icon catalog-summary-green"><CheckCircle2 size={17} /></span><div><strong>{wiredCodes.size}</strong><span>มี data contract</span></div></div>
        <div className="catalog-summary-card"><span className="catalog-summary-icon catalog-summary-amber"><ShieldAlert size={17} /></span><div><strong>{sourceDictionaryCount - wiredCodes.size}</strong><span>รอผูก source view</span></div></div>
        <div className="catalog-group-strip" role="group" aria-label="กรองตามกลุ่ม THIP">{groupCounts.map(({ group, count }) => <button key={group} type="button" className={activeGroup === group ? 'is-selected' : ''} aria-pressed={activeGroup === group} aria-label={`${groupMeta[group].shortLabel} ${count} รายการ`} onClick={() => onGroupChange(activeGroup === group ? 'all' : group)}><span aria-hidden="true" style={{ backgroundColor: groupMeta[group].color }}>{group}</span><strong>{count}</strong></button>)}</div>
      </section>

      <section className="panel catalog-panel">
        <div className="panel-heading catalog-heading"><div><span className="panel-eyebrow">DICTIONARY INDEX</span><h3>ตัวชี้วัดตามรหัส THIP</h3><p>กดรายการใดก็ได้เพื่อดูโครงสร้าง detail ตามรอบรายงาน; รายการที่ยังไม่ผูกข้อมูลจะแสดงสถานะ no-data อย่างตรงไปตรงมา</p></div><div className="catalog-controls"><label className="search-field catalog-search"><Search size={16} aria-hidden="true" /><span className="sr-only">ค้นหาตัวชี้วัดใน dictionary</span><input aria-label="ค้นหาตัวชี้วัดใน dictionary" value={search} onChange={(event) => onSearchChange(event.target.value)} placeholder="ค้นหารหัสหรือชื่อ KPI" /></label><button className="catalog-all-button" type="button" aria-pressed={activeGroup === 'all'} onClick={() => onGroupChange('all')}>ทั้งหมด <ArrowUpRight size={14} aria-hidden="true" /></button></div></div>
        <div className="catalog-table-wrap">
          <table className="catalog-table">
            <caption className="sr-only">คลังตัวชี้วัด THIP 2025 จำนวน {filtered.length} รายการที่กรองแล้ว</caption>
            <thead><tr><th scope="col">รหัส</th><th scope="col">ชื่อตัวชี้วัดจาก dictionary</th><th scope="col">กลุ่ม</th><th scope="col">สถานะข้อมูล</th><th scope="col" aria-label="เปิดรายละเอียด" /></tr></thead>
            <tbody>{filtered.map((entry) => { const wired = wiredCodes.has(entry.code); return <tr key={entry.code} aria-label={`เปิดรายละเอียด ${entry.code} ${entry.titleTh || entry.title}`} tabIndex={0} onClick={() => onOpen(entry.code)} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); onOpen(entry.code); } }}><td><strong className="catalog-code">{entry.code}</strong></td><td><div className="catalog-title-cell"><strong className="catalog-title-th">{entry.titleTh}</strong><span className="catalog-title-en">{entry.title}</span></div></td><td><span className="catalog-group"><i aria-hidden="true" style={{ backgroundColor: groupMeta[entry.group].color }}>{entry.group}</i>{groupMeta[entry.group].shortLabel}</span></td><td><span className={`catalog-state ${wired ? 'catalog-state-wired' : 'catalog-state-pending'}`}><span aria-hidden="true" />{wired ? 'มี data contract' : 'รอผูก source view'}</span></td><td><span className="catalog-arrow" aria-hidden="true">↗</span></td></tr>; })}</tbody>
          </table>
          {!filtered.length && <div className="table-empty"><BookOpen size={22} /><strong>ไม่พบรายการใน dictionary</strong><span>ลองเปลี่ยนคำค้นหาหรือกลุ่ม</span></div>}
        </div>
        <div className="table-footer"><span>แสดง {filtered.length} จาก {entries.length} รายการ</span><span>Source: THIP KPI Dictionary 2025</span></div>
      </section>
    </div>
  );
}
