import { useEffect, useMemo, useState } from 'react';
import { Menu, RefreshCw, WifiOff } from 'lucide-react';
import { Sidebar, type View } from '@/components/Sidebar';
import { DashboardPage } from '@/components/DashboardPage';
import { DetailView } from '@/components/DetailView';
import { CatalogPage } from '@/components/CatalogPage';
import { DEMO_FISCAL_YEAR, demoIndicators, groupMeta } from '@/data/thipData';
import { createNoDataIndicator, thipCatalogue, thipCatalogueByCode } from '@/data/thipCatalogue';
import { connectBmsSession, type BmsRuntimeConfig } from '@/services/bmsSession';
import { foundationIndicatorCodes, loadBmsIndicators } from '@/services/bmsData';
import { getBmsConnectionErrorMessage } from '@/services/bmsErrors';
import type { BmsConnection, IndicatorGroup } from '@/types/thip';
import { formatFiscalYear } from '@/utils/fiscal';

type DataSourceState = 'demo' | 'loading' | 'live' | 'partial' | 'unavailable';

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
  const [connectionAttempt, setConnectionAttempt] = useState(0);
  const [runtime, setRuntime] = useState<BmsRuntimeConfig | null>(null);
  const [indicators, setIndicators] = useState(demoIndicators);
  const [dataSource, setDataSource] = useState<DataSourceState>('demo');
  const [dataMessage, setDataMessage] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void connectBmsSession().then((result) => {
      if (cancelled) return;
      setConnection(result.connection);
      const connectedRuntime = result.connection.status === 'connected' ? result.runtime ?? null : null;
      setRuntime(connectedRuntime);
      if (!connectedRuntime) setDataSource('demo');
    });
    return () => { cancelled = true; };
  }, [connectionAttempt]);

  useEffect(() => {
    if (!runtime) return;
    let cancelled = false;
    setDataSource('loading');
    setDataMessage(null);
    void loadBmsIndicators(runtime, fiscalYear).then((result) => {
      if (cancelled) return;
      if (!result.rowCount) {
        setIndicators(demoIndicators);
        setDataSource('unavailable');
        setDataMessage('BMS query สำเร็จ แต่ยังไม่พบผลลัพธ์ในช่วงปีงบประมาณที่เลือก');
        return;
      }
      setIndicators(result.indicators);
      setDataSource(result.sourceView || result.liveCodes.length === foundationIndicatorCodes.length ? 'live' : 'partial');
      setDataMessage(result.sourceView
        ? `อ่านข้อมูลจาก source view ${result.sourceView} แล้ว`
        : `อ่านข้อมูลจริง ${result.liveCodes.length} ตัวชี้วัดจาก HOSxP แล้ว`);
    }).catch((error: unknown) => {
      if (cancelled) return;
      setIndicators(demoIndicators);
      setDataSource('unavailable');
      setDataMessage(getBmsConnectionErrorMessage(error));
    });
    return () => { cancelled = true; };
  }, [runtime, fiscalYear]);

  const filteredIndicators = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();
    return indicators.filter((indicator) => {
      const matchesGroup = activeGroup === 'all' || indicator.group === activeGroup;
      const matchesSearch = !normalizedSearch || [indicator.code, indicator.title, indicator.titleTh, indicator.category].some((text) => text.toLowerCase().includes(normalizedSearch));
      return matchesGroup && matchesSearch;
    });
  }, [activeGroup, indicators, search]);

  const selectedIndicator = selectedCode
    ? indicators.find((indicator) => indicator.code === selectedCode) ?? (thipCatalogueByCode.get(selectedCode) ? createNoDataIndicator(thipCatalogueByCode.get(selectedCode)!) : null)
    : null;

  const dataLabel = dataSource === 'live'
    ? 'Live data'
    : dataSource === 'partial'
      ? 'Live + demo'
      : dataSource === 'loading'
        ? 'กำลังอ่านข้อมูล'
        : 'Demo data';

  function retryBms() {
    setConnection({ status: 'connecting', message: 'กำลังเชื่อมต่อ BMS ใหม่...' });
    setRuntime(null);
    setIndicators(demoIndicators);
    setDataSource('loading');
    setDataMessage(null);
    setConnectionAttempt((attempt) => attempt + 1);
  }

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
      <a className="skip-link" href="#main-content">ข้ามไปยังเนื้อหาหลัก</a>
      <Sidebar
        view={view}
        activeGroup={activeGroup}
        onNavigate={(nextView) => navigate(nextView, nextView === 'dashboard' ? null : selectedCode)}
        onGroupChange={setActiveGroup}
        connection={connection}
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />

      <main id="main-content" className="app-main" tabIndex={-1} aria-label="เนื้อหา THIP KPI">
        <div className="mobile-topbar">
          <button className="icon-button mobile-menu-button" type="button" onClick={() => setSidebarOpen(true)} aria-label="เปิดเมนู"><Menu size={20} /></button>
          <div className="mobile-brand"><span className="mobile-brand-dot" /> THIP <em>KPI</em></div>
          <span className="mobile-status"><span className={`connection-led connection-led-${connection.status}`} /></span>
        </div>

        {connection.status === 'connected' && (
          <div className={`connection-banner ${dataSource === 'unavailable' ? 'connection-banner-warning' : 'connection-banner-success'}`} role="status" aria-live="polite"><RefreshCw size={15} /><span>{dataSource === 'unavailable' ? dataMessage : connection.message}</span><strong>{dataSource === 'unavailable' ? 'ใช้ demo' : dataLabel}</strong>{dataSource === 'unavailable' && <button className="connection-banner-action" type="button" onClick={retryBms}>ลองอีกครั้ง</button>}</div>
        )}
        {connection.status === 'error' && (
          <div className="connection-banner connection-banner-error" role="alert"><WifiOff size={15} /><span>{connection.message}</span><strong>กลับไปใช้ demo</strong><button className="connection-banner-action" type="button" onClick={retryBms}>ลองเชื่อมต่ออีกครั้ง</button></div>
        )}

        {view === 'detail' && selectedIndicator ? (
          <DetailView indicator={selectedIndicator} onBack={() => navigate('dashboard', null)} />
        ) : view === 'catalog' ? (
          <CatalogPage
            entries={thipCatalogue}
            wiredCodes={new Set(indicators.filter((indicator) => indicator.dataSource !== 'no-data').map((indicator) => indicator.code))}
            activeGroup={activeGroup}
            search={search}
            onSearchChange={setSearch}
            onGroupChange={setActiveGroup}
            onOpen={openIndicator}
          />
        ) : (
          <DashboardPage
            indicators={filteredIndicators}
            allIndicators={indicators}
            activeGroup={activeGroup}
            onGroupChange={(group) => { setActiveGroup(group); setSearch(''); }}
            search={search}
            onSearchChange={setSearch}
            monthIndex={monthIndex}
            onMonthChange={setMonthIndex}
            fiscalYear={fiscalYear}
            onFiscalYearChange={setFiscalYear}
            onOpenIndicator={openIndicator}
            onOpenCatalog={() => navigate('catalog', null)}
            connection={connection}
            dataSource={dataSource}
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
