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
  SlidersHorizontal,
  Stethoscope,
} from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import type { BmsConnection, IndicatorGroup } from '@/types/thip';
import { groupMeta } from '@/data/thipData';

export type View = 'dashboard' | 'catalog' | 'detail';

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
  return (
    <>
      <div className={`sidebar-backdrop ${isOpen ? 'is-visible' : ''}`} onClick={onClose} />
      <aside className={`app-sidebar ${isOpen ? 'is-open' : ''}`} aria-label="เมนูหลัก">
        <div className="brand-lockup">
          <div className="brand-mark" aria-hidden="true">
            <HeartPulse size={21} strokeWidth={2.4} />
          </div>
          <div>
            <div className="brand-name">THIP <span>KPI</span></div>
            <div className="brand-caption">QUALITY INTELLIGENCE</div>
          </div>
          <div className="sidebar-close-wrap">
            <button className="icon-button sidebar-close" onClick={onClose} aria-label="ปิดเมนู">
              ×
            </button>
          </div>
        </div>

        <div className="sidebar-section-label">Workspace</div>
        <nav className="sidebar-nav">
          {navItems.map((item, index) => {
            const Icon = item.icon;
            const active = view === item.view;
            return (
              <button
                key={item.label}
                className={`sidebar-nav-item ${active ? 'is-active' : ''}`}
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
        <div className="group-nav">
          <button
            className={`group-nav-item ${activeGroup === 'all' ? 'is-active' : ''}`}
            onClick={() => { onGroupChange('all'); onNavigate('dashboard'); onClose(); }}
          >
            <span className="group-letter all-letter">Σ</span>
            <span>ทุกกลุ่ม</span>
            <small>232</small>
          </button>
          {(Object.keys(groupMeta) as IndicatorGroup[]).map((group) => (
            <button
              key={group}
              className={`group-nav-item ${activeGroup === group ? 'is-active' : ''}`}
              onClick={() => { onGroupChange(group); onNavigate('dashboard'); onClose(); }}
            >
              <span className="group-letter" style={{ backgroundColor: groupMeta[group].color }}>{group}</span>
              <span>{groupMeta[group].shortLabel}</span>
              <small>{group === 'D' ? '110' : group === 'C' ? '38' : group === 'S' ? '57' : group === 'H' ? '22' : '5'}</small>
            </button>
          ))}
        </div>

        <div className="sidebar-bottom">
          <div className="sidebar-section-label">Data layer</div>
          <div className={`connection-card connection-${connection.status}`}>
            <div className="connection-icon">
              {connection.status === 'connected' ? <ShieldCheck size={16} /> : <Database size={16} />}
            </div>
            <div className="connection-copy">
              <strong>{connection.status === 'connected' ? 'BMS connected' : 'Demo workspace'}</strong>
              <span>{connection.status === 'connected' ? connection.hospitalCode || 'Live session' : 'Safe sample data'}</span>
            </div>
            <span className="connection-led" aria-hidden="true" />
          </div>
          <button className="sidebar-settings" type="button">
            <Settings2 size={16} />
            <span>ตั้งค่าการแสดงผล</span>
            <SlidersHorizontal size={15} className="settings-trailing" />
          </button>
        </div>
      </aside>
    </>
  );
}
