import { useEffect, useRef, useState } from 'react';
import {
  Activity,
  BarChart3,
  CalendarDays,
  ClipboardCheck,
  Database,
  HeartPulse,
  LayoutDashboard,
  Settings2,
  ShieldCheck,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { BmsConnection, IndicatorGroup } from '@/types/thip';
import { groupMeta } from '@/data/thipMeta';

export type View = 'monitoring' | 'dashboard' | 'catalog' | 'detail';

type Props = {
  view: View;
  activeGroup: IndicatorGroup | 'all';
  onNavigate: (view: View) => void;
  onGroupChange: (group: IndicatorGroup | 'all') => void;
  connection: BmsConnection;
  isOpen: boolean;
  onClose: () => void;
};

type NavItem = {
  label: string;
  hint: string;
  icon: LucideIcon;
  view: View;
};

const navItems: NavItem[] = [
  { label: 'ติดตามรายเดือน', hint: 'Monthly monitoring', icon: BarChart3, view: 'monitoring' },
  { label: 'ภาพรวมคุณภาพ', hint: 'Quality overview', icon: LayoutDashboard, view: 'dashboard' },
  { label: 'คลังตัวชี้วัด', hint: 'Indicator library', icon: CalendarDays, view: 'catalog' },
];

export function Sidebar({
  view,
  activeGroup,
  onNavigate,
  onGroupChange,
  connection,
  isOpen,
  onClose,
}: Props) {
  const [mobile, setMobile] = useState(() => window.matchMedia('(max-width: 680px)').matches);
  const aside = useRef<HTMLElement>(null);
  useEffect(() => {
    const media = window.matchMedia('(max-width: 680px)');
    const changed = () => setMobile(media.matches); media.addEventListener('change', changed);
    return () => media.removeEventListener('change', changed);
  }, []);
  useEffect(() => {
    if (!mobile || !isOpen) return;
    const previous = document.activeElement as HTMLElement;
    aside.current?.querySelector<HTMLButtonElement>('button')?.focus();
    const key = (event: globalThis.KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
      if (event.key === 'Tab') {
        const buttons = aside.current?.querySelectorAll<HTMLButtonElement>('button');
        if (!buttons?.length) return;
        const first = buttons[0], last = buttons[buttons.length - 1];
        if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
        else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
      }
    };
    window.addEventListener('keydown', key);
    return () => { window.removeEventListener('keydown', key); previous?.focus(); };
  }, [mobile, isOpen]);
  return (
    <>
      <div className={`sidebar-backdrop ${isOpen ? 'is-visible' : ''}`} onClick={onClose} aria-hidden="true" />
      <aside ref={aside} inert={mobile && !isOpen} className={`app-sidebar ${isOpen ? 'is-open' : ''}`} aria-label="เมนูหลัก">
        <div className="brand-lockup">
          <div className="brand-mark" aria-hidden="true">
            <HeartPulse size={21} strokeWidth={2.4} />
          </div>
          <div>
            <div className="brand-name">THIP <span>KPI</span></div>
            <div className="brand-caption">QUALITY INTELLIGENCE</div>
          </div>
          <div className="sidebar-close-wrap">
            <button className="icon-button sidebar-close" type="button" onClick={onClose} aria-label="ปิดเมนู">
              ×
            </button>
          </div>
        </div>

        <div className="sidebar-section-label">Workspace</div>
        <nav className="sidebar-nav" aria-label="เมนูพื้นที่ทำงาน">
          {navItems.map((item, index) => {
            const Icon = item.icon;
            const active = view === item.view;
            return (
              <button
                key={item.label}
                type="button"
                className={`sidebar-nav-item ${active ? 'is-active' : ''}`}
                aria-current={active ? 'page' : undefined}
                onClick={() => {
                  if (index === 0) onGroupChange('all');
                  onNavigate(item.view);
                  onClose();
                }}
              >
                <Icon size={17} strokeWidth={active ? 2.3 : 1.8} />
                <span>
                  <strong>{item.label}</strong>
                  <small>{item.hint}</small>
                </span>
                {active && <span className="active-rail" aria-hidden="true" />}
              </button>
            );
          })}
        </nav>

        <div className="sidebar-section-label group-label">THIP groups</div>
        <div className="group-nav" role="navigation" aria-label="กลุ่มตัวชี้วัด THIP">
          <button
            type="button"
            className={`group-nav-item ${activeGroup === 'all' ? 'is-active' : ''}`}
            onClick={() => { onGroupChange('all'); onNavigate(view === 'dashboard' ? 'dashboard' : 'monitoring'); onClose(); }}
          >
            <span className="group-letter all-letter">Σ</span>
            <span>ทุกกลุ่ม</span>
            <small>232</small>
          </button>
          {(Object.keys(groupMeta) as IndicatorGroup[]).map((group) => (
            <button
              key={group}
              type="button"
              className={`group-nav-item ${activeGroup === group ? 'is-active' : ''}`}
              onClick={() => { onGroupChange(group); onNavigate(view === 'dashboard' ? 'dashboard' : 'monitoring'); onClose(); }}
            >
              <span className="group-letter" style={{ backgroundColor: groupMeta[group].color }}>{group}</span>
              <span>{groupMeta[group].shortLabel}</span>
              <small>{group === 'D' ? '110' : group === 'C' ? '38' : group === 'S' ? '57' : group === 'H' ? '22' : '5'}</small>
            </button>
          ))}
        </div>

        <div className="sidebar-bottom">
          <div className="sidebar-section-label">Data layer</div>
          <div className={`connection-card connection-${connection.status}`} role="status" aria-label={connection.status === 'connected' ? `เชื่อมต่อ BMS แล้ว ${connection.hospitalCode || ''}` : 'ยังไม่มี BMS live session'}>
            <div className="connection-icon">
              {connection.status === 'connected' ? <ShieldCheck size={16} /> : <Database size={16} />}
            </div>
            <div className="connection-copy">
              <strong>{connection.status === 'connected' ? 'BMS connected' : 'รอ BMS live session'}</strong>
              <span>{connection.status === 'connected' ? connection.hospitalCode || 'Live session' : 'ยังไม่มีข้อมูลจริง'}</span>
            </div>
            <span className="connection-led" aria-hidden="true" />
          </div>
          <div className="sidebar-settings sidebar-settings-disabled" aria-label="ตั้งค่าการแสดงผล — เร็ว ๆ นี้">
            <Settings2 size={16} />
            <span>ตั้งค่าการแสดงผล</span>
            <small className="settings-trailing">เร็ว ๆ นี้</small>
          </div>
        </div>
      </aside>
    </>
  );
}
