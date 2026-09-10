import { useEffect, useMemo, useState } from 'react';
import { Menu, RefreshCw, WifiOff } from 'lucide-react';
import { Sidebar, type View } from '@/components/Sidebar';
import { DashboardPage } from '@/components/DashboardPage';
import { DetailView } from '@/components/DetailView';
import { CatalogPage } from '@/components/CatalogPage';
import { DEMO_FISCAL_YEAR, demoIndicators, groupMeta } from '@/data/thipData';
import { createNoDataIndicator, thipCatalogue, thipCatalogueByCode } from '@/data/thipCatalogue';
import { connectBmsSession } from '@/services/bmsSession';
import type { BmsConnection, IndicatorGroup } from '@/types/thip';
import { formatFiscalYear } from '@/utils/fiscal';

function getInitialRoute(): { view: View; code: string | null } {
  const params = new URLSearchParams(window.location.search);
  const code = params.get('indicator');
  const view = params.get('view') === 'catalog' ? 'catalog' : code ? 'detail' : 'dashboard';
  return { view, code };
}

export default function App() {
  const initialRoute = getInitialRoute();
  const [view, setView] = useState<View>(initialRoute.view);
  const [selectedCode, setSelectedCode] = useState<string | null>(initialRoute.code);
  const [activeGroup, setActiveGroup] = useState<IndicatorGroup | 'all'>('all');
  const [search, setSearch] = useState('');
  const [monthIndex, setMonthIndex] = useState(11);
  const [fiscalYear, setFiscalYear] = useState(DEMO_FISCAL_YEAR);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [connection, setConnection] = useState<BmsConnection>({ status: 'demo', message: 'ยังไม่ได้เปิดจาก BMS launcher' });

  useEffect(() => {
    let cancelled = false;
    void connectBmsSession().then((result) => {
      if (!cancelled) setConnection(result.connection);
    });
    return () => { cancelled = true; };
  }, []);

  const filteredIndicators = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();
    return demoIndicators.filter((indicator) => {
      const matchesGroup = activeGroup === 'all' || indicator.group === activeGroup;
      const matchesSearch = !normalizedSearch || [indicator.code, indicator.title, indicator.titleTh, indicator.category].some((text) => text.toLowerCase().includes(normalizedSearch));
      return matchesGroup && matchesSearch;
    });
  }, [activeGroup, search]);

  const selectedIndicator = selectedCode
    ? demoIndicators.find((indicator) => indicator.code === selectedCode) ?? (thipCatalogueByCode.get(selectedCode) ? createNoDataIndicator(thipCatalogueByCode.get(selectedCode)!) : null)
    : null;

  function navigate(nextView: View, code: string | null = selectedCode) {
    setView(nextView);
    setSelectedCode(code);
    const params = new URLSearchParams(window.location.search);
    if (nextView === 'detail' && code) {
      params.set('view', 'detail');
      params.set('indicator', code);
    } else {
      params.delete('view');
      params.delete('indicator');
    }
    window.history.replaceState({}, '', `${window.location.pathname}${params.toString() ? `?${params.toString()}` : ''}`);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function openIndicator(code: string) {
    navigate('detail', code);
  }

  return (
    <div className="app-shell">
      <Sidebar
        view={view}
        activeGroup={activeGroup}
        onNavigate={(nextView) => navigate(nextView, nextView === 'dashboard' ? null : selectedCode)}
        onGroupChange={setActiveGroup}
        connection={connection}
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />

      <main className="app-main">
        <div className="mobile-topbar">
          <button className="icon-button mobile-menu-button" onClick={() => setSidebarOpen(true)} aria-label="เปิดเมนู"><Menu size={20} /></button>
          <div className="mobile-brand"><span className="mobile-brand-dot" /> THIP <em>KPI</em></div>
          <span className="mobile-status"><span className={`connection-led connection-led-${connection.status}`} /></span>
        </div>

        {connection.status === 'connected' && (
          <div className="connection-banner connection-banner-success"><RefreshCw size={15} /><span>{connection.message}</span><strong>{connection.hospitalCode || 'BMS'}</strong></div>
        )}
        {connection.status === 'error' && (
          <div className="connection-banner connection-banner-error"><WifiOff size={15} /><span>{connection.message}</span><strong>กลับไปใช้ demo</strong></div>
        )}

        {view === 'detail' && selectedIndicator ? (
          <DetailView indicator={selectedIndicator} onBack={() => navigate('dashboard', null)} />
        ) : view === 'catalog' ? (
          <CatalogPage
            entries={thipCatalogue}
            wiredCodes={new Set(demoIndicators.map((indicator) => indicator.code))}
            activeGroup={activeGroup}
            search={search}
            onSearchChange={setSearch}
            onGroupChange={setActiveGroup}
            onOpen={openIndicator}
          />
        ) : (
          <DashboardPage
            indicators={filteredIndicators}
            allIndicators={demoIndicators}
            activeGroup={activeGroup}
            onGroupChange={(group) => { setActiveGroup(group); setSearch(''); }}
            search={search}
            onSearchChange={setSearch}
            monthIndex={monthIndex}
            onMonthChange={setMonthIndex}
            fiscalYear={fiscalYear}
            onFiscalYearChange={setFiscalYear}
            onOpenIndicator={openIndicator}
            connection={connection}
          />
        )}

        <footer className="app-footer"><span><span className="footer-pulse" /> THIP KPI · BMS Marketplace workbench</span><span>{formatFiscalYear(fiscalYear)} · Read-only data boundary</span></footer>
      </main>
    </div>
  );
}

export function getGroupLabel(group: IndicatorGroup | 'all'): string {
  return group === 'all' ? 'ทุกกลุ่ม THIP' : groupMeta[group].shortLabel;
}
