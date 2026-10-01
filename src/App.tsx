import { useEffect, useMemo, useRef, useState } from 'react';
import { Menu, RefreshCw, WifiOff } from 'lucide-react';
import { Sidebar, type View } from '@/components/Sidebar';
import { DashboardPage } from '@/components/DashboardPage';
import { DetailView } from '@/components/DetailView';
import { MonitoringPage } from '@/components/MonitoringPage';
import { StepValidationPage } from '@/components/StepValidationPage';
import { monitoringPreviewEnabled } from '@/monitoring/provider';
import { publishApprovedThip } from '@/services/publication';
import { stripLaunchCredentialsFromUrl } from '@/services/bmsSession';
import { CatalogPage } from '@/components/CatalogPage';
import { groupMeta } from '@/data/thipMeta';
import { createNoDataIndicator, thipCatalogue, thipCatalogueByCode } from '@/data/thipCatalogue';
import { connectBmsSession, type BmsRuntimeConfig } from '@/services/bmsSession';
import { loadBmsIndicators } from '@/services/bmsData';
import { getBmsConnectionErrorMessage } from '@/services/bmsErrors';
import type { BmsConnection, FiscalYear, Indicator, IndicatorGroup, RefreshedAt } from '@/types/thip';
import type { BmsCoverage } from '@/services/bmsData';
import { formatFiscalYear, getCurrentFiscalYear } from '@/utils/fiscal';

type DataSourceState = 'loading' | 'live' | 'partial' | 'unavailable';

const emptyCoverage: BmsCoverage = {
  expectedIndicatorCount: 232,
  liveIndicatorCount: 0,
  measuredIndicatorCount: 0,
  expectedCellCount: 1552,
  coveredCellCount: 0,
  availableCellCount: 0,
  unavailableCellCount: 0,
  unexpectedCellCount: 0,
  complete: false,
  liveCodes: [],
};

function getInitialRoute(): { view: View; code: string | null } {
  const params = new URLSearchParams(window.location.search);
  const code = params.get('indicator');
  const view = params.get('view') === 'validation' ? 'validation' : params.get('view') === 'catalog' ? 'catalog' : code ? 'detail' : params.get('view') === 'dashboard' ? 'dashboard' : 'monitoring';
  return { view, code };
}

export default function App() {
  const [initialRoute] = useState(getInitialRoute);
  const [view, setView] = useState<View>(initialRoute.view);
  const [selectedCode, setSelectedCode] = useState<string | null>(initialRoute.code);
  const [activeGroup, setActiveGroup] = useState<IndicatorGroup | 'all'>(() => { const group = new URLSearchParams(window.location.search).get('group'); return group && group in groupMeta ? group as IndicatorGroup : 'all'; });
  const [search, setSearch] = useState(() => new URLSearchParams(window.location.search).get('q') ?? '');
  const [monthIndex, setMonthIndex] = useState(11);
  const [fiscalYear, setFiscalYear] = useState(() => { const year = Number(new URLSearchParams(window.location.search).get('fy')); return Number.isInteger(year) && year >= 2000 && year <= 2100 ? year : getCurrentFiscalYear(); });
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [connection, setConnection] = useState<BmsConnection>({ status: 'idle', message: 'ยังไม่ได้เปิดจาก BMS launcher จึงยังไม่มีข้อมูลจริง' });
  const [connectionAttempt, setConnectionAttempt] = useState(0);
  const [sessionInput, setSessionInput] = useState('');
  const manualSession = useRef<string | undefined>(undefined);
  const [runtime, setRuntime] = useState<BmsRuntimeConfig | null>(null);
  const [indicators, setIndicators] = useState<Indicator[]>(() => thipCatalogue.map((entry) => createNoDataIndicator(entry, getCurrentFiscalYear())));
  const [dataSource, setDataSource] = useState<DataSourceState>('unavailable');
  const [dataMessage, setDataMessage] = useState<string | null>(null);
  const [refreshedAt, setRefreshedAt] = useState<RefreshedAt | null>(null);
  const [coverage, setCoverage] = useState<BmsCoverage>(emptyCoverage);

  const defaultIndicators = useMemo(
    () => thipCatalogue.map((entry) => createNoDataIndicator(entry, fiscalYear)),
    [fiscalYear],
  );

  useEffect(() => {
    let cancelled = false;
    const controller = new AbortController();
    if (monitoringPreviewEnabled) { stripLaunchCredentialsFromUrl(); return; }
    const requestedSession = manualSession.current; manualSession.current = undefined;
    void connectBmsSession(requestedSession, controller.signal).then((result) => {
      if (cancelled) return;
      setConnection(result.connection);
      const connectedRuntime = result.connection.status === 'connected' ? result.runtime ?? null : null;
      setRuntime(connectedRuntime);
      if (!connectedRuntime) {
        setIndicators(defaultIndicators);
        setDataSource('unavailable');
        setRefreshedAt(null);
        setCoverage(emptyCoverage);
        setDataMessage(result.connection.message ?? 'ยังไม่มี BMS live session');
      }
    });
    return () => { cancelled = true; controller.abort(); };
  }, [connectionAttempt]);

  useEffect(() => {
    if (!runtime) setIndicators(defaultIndicators);
  }, [defaultIndicators, runtime]);

  useEffect(() => {
    if (!runtime || view === 'monitoring' || view === 'catalog' || view === 'validation') return;
    let cancelled = false;
    const controller = new AbortController();
    setIndicators(defaultIndicators); setCoverage(emptyCoverage); setRefreshedAt(null);
    setDataSource('loading');
    setDataMessage(null);
    void loadBmsIndicators(runtime, fiscalYear, { signal: controller.signal }).then((draft) => {
      const result = publishApprovedThip(draft);
      if (cancelled) return;
      if (!result.rowCount) {
        setIndicators(defaultIndicators);
        setDataSource('unavailable');
        setRefreshedAt(null);
        setCoverage(emptyCoverage);
        setDataMessage('BMS query สำเร็จ แต่ยังไม่พบผลลัพธ์ในช่วงปีงบประมาณที่เลือก');
        return;
      }
      setIndicators(result.indicators);
      setRefreshedAt(result.refreshedAt);
      setCoverage(result.coverage);
      const fullyMeasured = result.coverage.complete
        && result.coverage.unavailableCellCount === 0
        && result.coverage.liveIndicatorCount === result.coverage.expectedIndicatorCount;
      setDataSource(result.coverage.availableCellCount === 0 ? 'unavailable' : fullyMeasured ? 'live' : 'partial');
      setDataMessage(result.sourceView
        ? `รับ aggregate ${result.coverage.liveIndicatorCount}/${result.coverage.expectedIndicatorCount} รหัส · เผยแพร่ได้ ${result.coverage.measuredIndicatorCount} รหัส · ${result.coverage.coveredCellCount}/${result.coverage.expectedCellCount} งวดรายงานจาก source view ${result.sourceView} แล้ว`
        : `รับ aggregate ${result.coverage.liveIndicatorCount}/${result.coverage.expectedIndicatorCount} รหัส · เผยแพร่ได้ ${result.coverage.measuredIndicatorCount} รหัส · ${result.coverage.coveredCellCount}/${result.coverage.expectedCellCount} งวดรายงานจาก HOSxP แล้ว`);
    }).catch((error: unknown) => {
      if (cancelled) return;
      setIndicators(defaultIndicators);
      setDataSource('unavailable');
      setRefreshedAt(null);
      setCoverage(emptyCoverage);
      setDataMessage(getBmsConnectionErrorMessage(error));
    });
    return () => { cancelled = true; controller.abort(); };
  }, [runtime, fiscalYear, view]);

  const filteredIndicators = useMemo(() => {
    const normalizedSearch = search.trim().toLowerCase();
    return indicators.filter((indicator) => {
      const matchesGroup = activeGroup === 'all' || indicator.group === activeGroup;
      const matchesSearch = !normalizedSearch || [indicator.code, indicator.title, indicator.titleTh, indicator.category].some((text) => text.toLowerCase().includes(normalizedSearch));
      return matchesGroup && matchesSearch;
    });
  }, [activeGroup, indicators, search]);

  const selectedIndicator = selectedCode
    ? indicators.find((indicator) => indicator.code === selectedCode) ?? (thipCatalogueByCode.get(selectedCode) ? createNoDataIndicator(thipCatalogueByCode.get(selectedCode)!, fiscalYear) : null)
    : null;

  const dataLabel = dataSource === 'live'
    ? 'Live data'
    : dataSource === 'partial'
      ? 'Live data บางส่วน'
      : dataSource === 'loading'
        ? 'กำลังอ่านข้อมูล'
        : connection.status === 'connected' && coverage.coveredCellCount > 0 ? 'ผลยังไม่รับรอง' : 'No data source';

  function retryBms() {
    setConnection({ status: 'connecting', message: 'กำลังเชื่อมต่อ BMS ใหม่...' });
    setRuntime(null);
    setIndicators(defaultIndicators);
    setDataSource('loading');
    setCoverage(emptyCoverage);
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
      if (nextView === 'monitoring') params.delete('view'); else params.set('view', nextView);
      params.delete('indicator');
    }
    // pushState keeps the browser Back button working between views; the
    // popstate listener below restores the matching view state.
    window.history.pushState({}, '', `${window.location.pathname}${params.toString() ? `?${params.toString()}` : ''}`);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  useEffect(() => {
    function onPopState() {
      const route = getInitialRoute();
      setView(route.view);
      setSelectedCode(route.code);
      const params = new URLSearchParams(window.location.search);
      const group = params.get('group'); setActiveGroup(group && group in groupMeta ? group as IndicatorGroup : 'all');
      setSearch(params.get('q') ?? '');
      const year = Number(params.get('fy')); changeYear(Number.isInteger(year) && year >= 2000 && year <= 2100 ? year : getCurrentFiscalYear(), false);
    }
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  function persistFilter(key: string, value: string) {
    const params = new URLSearchParams(window.location.search);
    if (!value || value === 'all') params.delete(key); else params.set(key, value);
    window.history.pushState({}, '', `${window.location.pathname}${params.size ? `?${params}` : ''}`);
  }
  function changeGroup(group: IndicatorGroup | 'all') { setActiveGroup(group); persistFilter('group', group); }
  function changeSearch(value: string) { setSearch(value); persistFilter('q', value); }
  function changeYear(year: number, persist = true) {
    setFiscalYear(year); setIndicators(thipCatalogue.map((entry) => createNoDataIndicator(entry, year)));
    setCoverage(emptyCoverage); setRefreshedAt(null); setDataSource(runtime ? 'loading' : 'unavailable');
    if (persist) persistFilter('fy', String(year));
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
        onGroupChange={changeGroup}
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

        {view === 'validation' && !monitoringPreviewEnabled && <form className="step-session" onSubmit={(event) => { event.preventDefault(); if (!sessionInput.trim()) return; manualSession.current = sessionInput.trim(); setSessionInput(''); retryBms(); }}>
          <label htmlFor="step-session-id">BMS Session ID</label><input id="step-session-id" type="password" autoComplete="off" value={sessionInput} onChange={(event) => setSessionInput(event.target.value)} placeholder="กรอก session เพื่อเชื่อมต่อหรือ reconnect" />
          <button className="secondary-button" disabled={!sessionInput.trim() || connection.status === 'connecting'}>เชื่อมต่อ</button>
          <span>เก็บใน memory เท่านั้น · Step 1 ตรวจ PostgreSQL ก่อนเริ่มคิว</span>
        </form>}

        {connection.status === 'connected' && (
          <div className={`connection-banner ${!['monitoring', 'validation'].includes(view) && dataSource === 'unavailable' ? 'connection-banner-warning' : 'connection-banner-success'}`} role="status" aria-live="polite"><RefreshCw size={15} /><span>{['monitoring', 'validation'].includes(view) ? connection.message : dataMessage ?? connection.message}</span><strong>{['monitoring', 'validation'].includes(view) ? 'BMS connected' : dataLabel}</strong><button className="connection-banner-action" type="button" onClick={retryBms}>{['monitoring', 'validation'].includes(view) ? 'รีเฟรช session' : dataSource === 'unavailable' ? 'ลองอีกครั้ง' : 'รีเฟรชข้อมูล'}</button></div>
        )}
        {connection.status === 'idle' && !monitoringPreviewEnabled && (
          <div className="connection-banner connection-banner-warning" role="status" aria-live="polite"><WifiOff size={15} /><span>{connection.message}</span><strong>รอ BMS live session</strong><button className="connection-banner-action" type="button" onClick={retryBms}>ลองเชื่อมต่ออีกครั้ง</button></div>
        )}
        {(connection.status === 'error' || connection.status === 'unsupported') && (
          <div className="connection-banner connection-banner-error" role="alert"><WifiOff size={15} /><span>{connection.message}</span><strong>ยังไม่มีข้อมูลจริง</strong><button className="connection-banner-action" type="button" onClick={retryBms}>ลองเชื่อมต่ออีกครั้ง</button></div>
        )}

        {view === 'validation' ? (
          <StepValidationPage runtime={runtime} fiscalYear={fiscalYear} onFiscalYearChange={changeYear} group={activeGroup} search={search} onSearchChange={changeSearch} onGroupChange={changeGroup} onMonitoring={() => navigate('monitoring', null)} />
        ) : view === 'monitoring' ? (
          <MonitoringPage fiscalYear={fiscalYear} onFiscalYearChange={changeYear} group={activeGroup} onGroupChange={changeGroup} search={search} onSearchChange={changeSearch} runtime={runtime} onOverview={() => navigate('dashboard', null)} />
        ) : view === 'detail' && selectedIndicator ? (
          <DetailView indicator={selectedIndicator} onBack={() => navigate('dashboard', null)} />
        ) : view === 'catalog' ? (
          <CatalogPage
            entries={thipCatalogue}
            wiredCodes={new Set(indicators.filter((indicator) => indicator.dataSource !== 'no-data').map((indicator) => indicator.code))}
            activeGroup={activeGroup}
            search={search}
            onSearchChange={changeSearch}
            onGroupChange={changeGroup}
            onOpen={openIndicator}
          />
        ) : (
          <DashboardPage
            indicators={filteredIndicators}
            allIndicators={indicators}
            activeGroup={activeGroup}
            onGroupChange={(group) => { changeGroup(group); changeSearch(''); }}
            search={search}
            onSearchChange={changeSearch}
            monthIndex={monthIndex}
            onMonthChange={setMonthIndex}
            fiscalYear={fiscalYear}
            onFiscalYearChange={changeYear}
            onOpenIndicator={openIndicator}
            onOpenCatalog={() => navigate('catalog', null)}
            connection={connection}
            dataSource={dataSource}
            refreshedAt={refreshedAt}
            coverage={coverage}
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
