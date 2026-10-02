import { useEffect, useRef, useState, Suspense } from 'react';
import { Menu, WifiOff } from 'lucide-react';
import { Sidebar, type View } from '@/components/Sidebar';
import { monitoringPreviewEnabled } from '@/monitoring/provider';
import {
  connectBmsSession,
  stripLaunchCredentialsFromUrl,
  type BmsRuntimeConfig,
} from '@/services/bmsSession';
import { groupMeta } from '@/data/thipMeta';
import { runtimeCatalogue } from '@/data/thipRuntime';
import { lazyRoute } from '@/components/RouteBoundary';
import { KpiDataStore } from '@/services/kpiDataStore';
import { KpiDataContext, useKpiData } from '@/components/KpiDataContext';
import { KpiLoadBar } from '@/components/KpiLoadBar';
import type { KpiMode, KpiSeries } from '@/services/kpiTypes';
import type { BmsConnection, IndicatorGroup } from '@/types/thip';
import { formatFiscalYear, getCurrentFiscalYear } from '@/utils/fiscal';
const KpiMatrixPage = lazyRoute(
  () => import('@/components/KpiMatrixPage'),
  'KpiMatrixPage'
);
const MonitoringPage = lazyRoute(
  () => import('@/components/MonitoringPage'),
  'MonitoringPage'
);
const StepValidationPage = lazyRoute(
  () => import('@/components/StepValidationPage'),
  'StepValidationPage'
);
const CatalogPage = lazyRoute(
  () => import('@/components/CatalogPage'),
  'CatalogPage'
);
const SharedKpiOverview = lazyRoute(
  () => import('@/components/SharedKpiViews'),
  'SharedKpiOverview'
);
const ApprovedReportingPage = lazyRoute(
  () => import('@/components/ApprovedReportingPage'),
  'ApprovedReportingPage'
);
const SharedKpiDetail = lazyRoute(
  () => import('@/components/SharedKpiViews'),
  'SharedKpiDetail'
);
function initialRoute() {
  const p = new URLSearchParams(location.search),
    code = p.get('indicator');
  const view: View =
    p.get('view') === 'validation'
      ? 'validation'
      : p.get('view') === 'catalog'
        ? 'catalog'
        : code
          ? 'detail'
          : p.get('view') === 'dashboard'
            ? 'dashboard'
            : 'monitoring';
  const y = Number(p.get('fy'));
  const g = p.get('group');
  return {
    view,
    code,
    year:
      Number.isInteger(y) && y >= 2000 && y <= 2100
        ? y
        : getCurrentFiscalYear(),
    group: g && g in groupMeta ? (g as IndicatorGroup) : ('all' as const),
    search: p.get('q') ?? '',
    mode:
      p.get('mode') === 'approved'
        ? ('approved' as const)
        : ('review' as const),
    series:
      p.get('series') === 'monthly-monitoring'
        ? ('monthly-monitoring' as const)
        : ('thip-report' as const),
  };
}
export default function App() {
  const [initial] = useState(initialRoute);
  const [store] = useState(() => new KpiDataStore(initial.year));
  return (
    <KpiDataContext.Provider value={store}>
      <Workspace initial={initial} />
    </KpiDataContext.Provider>
  );
}
function Workspace({ initial }: { initial: ReturnType<typeof initialRoute> }) {
  const { store, snapshot } = useKpiData();
  const [view, setView] = useState(initial.view),
    [selectedCode, setCode] = useState(initial.code),
    [year, setYear] = useState(initial.year),
    [group, setGroup] = useState(initial.group),
    [search, setSearch] = useState(initial.search),
    [mode, setMode] = useState<KpiMode>(initial.mode),
    [series, setSeries] = useState<KpiSeries>(initial.series);
  const [sidebarOpen, setSidebarOpen] = useState(false),
    [connection, setConnection] = useState<BmsConnection>({
      status: 'idle',
      message: 'เชื่อมต่อ BMS session เพื่ออ่าน aggregate',
    }),
    [attempt, setAttempt] = useState(0),
    [sessionInput, setSessionInput] = useState(''),
    [runtime, setRuntime] = useState<BmsRuntimeConfig | null>(null);
  const manualSession = useRef<string | undefined>(undefined);
  useEffect(() => {
    const abort = new AbortController();
    if (monitoringPreviewEnabled) {
      stripLaunchCredentialsFromUrl();
      return;
    }
    const requested = manualSession.current;
    manualSession.current = undefined;
    void connectBmsSession(requested, abort.signal).then((result) => {
      if (abort.signal.aborted) return;
      setConnection(result.connection);
      setRuntime(
        result.connection.status === 'connected'
          ? (result.runtime ?? null)
          : null
      );
    });
    return () => abort.abort();
  }, [attempt]);
  useEffect(() => {
    store.configure(monitoringPreviewEnabled ? null : runtime, year);
  }, [store, runtime, year]);
  useEffect(() => {
    const visible = () => {
      if (document.visibilityState === 'visible') store.invalidateExpired();
    };
    document.addEventListener('visibilitychange', visible);
    return () => {
      document.removeEventListener('visibilitychange', visible);
      store.dispose();
    };
  }, [store]);
  function persist(key: string, value: string) {
    const p = new URLSearchParams(location.search);
    !value || value === 'all' ? p.delete(key) : p.set(key, value);
    history.pushState({}, '', `${location.pathname}${p.size ? `?${p}` : ''}`);
  }
  function changeYear(next: number, push = true) {
    store.configure(runtime, next);
    setYear(next);
    if (push) persist('fy', String(next));
  }
  function changeGroup(next: IndicatorGroup | 'all') {
    setGroup(next);
    persist('group', next);
  }
  function changeSearch(next: string) {
    setSearch(next);
    persist('q', next);
  }
  function changeMode(next: KpiMode) {
    setMode(next);
    persist('mode', next);
  }
  function changeSeries(next: KpiSeries) {
    setSeries(next);
    persist('series', next);
  }
  function navigate(next: View, code: string | null = null) {
    setView(next);
    setCode(code);
    const p = new URLSearchParams(location.search);
    next === 'monitoring' ? p.delete('view') : p.set('view', next);
    next === 'detail' && code
      ? p.set('indicator', code)
      : p.delete('indicator');
    history.pushState({}, '', `${location.pathname}${p.size ? `?${p}` : ''}`);
    window.scrollTo({ top: 0, behavior: 'instant' });
  }
  useEffect(() => {
    const pop = () => {
      const r = initialRoute();
      setView(r.view);
      setCode(r.code);
      setGroup(r.group);
      setSearch(r.search);
      setMode(r.mode);
      setSeries(r.series);
      store.configure(
        store.snapshot().owner as BmsRuntimeConfig | null,
        r.year
      );
      setYear(r.year);
    };
    window.addEventListener('popstate', pop);
    return () => window.removeEventListener('popstate', pop);
  }, []);
  function reconnect() {
    store.configure(null, year);
    setRuntime(null);
    setConnection({
      status: 'connecting',
      message: 'กำลังตรวจ session และ PostgreSQL…',
    });
    setAttempt((value) => value + 1);
  }
  const wired = new Set(
    store
      .grid(series, mode)
      .filter((row) => row.cells.some((cell) => cell.value !== null))
      .map((row) => row.code)
  );
  return (
    <div className="app-shell">
      <a className="skip-link" href="#main-content">
        ข้ามไปยังเนื้อหาหลัก
      </a>
      <Sidebar
        view={view}
        activeGroup={group}
        onNavigate={(next) => navigate(next)}
        onGroupChange={changeGroup}
        connection={connection}
        isOpen={sidebarOpen}
        onClose={() => setSidebarOpen(false)}
      />
      <main
        id="main-content"
        className="app-main"
        tabIndex={-1}
        aria-label="เนื้อหา THIP KPI"
      >
        <div className="mobile-topbar">
          <button
            className="icon-button mobile-menu-button"
            onClick={() => setSidebarOpen(true)}
            aria-label="เปิดเมนู"
          >
            <Menu size={20} />
          </button>
          <div className="mobile-brand">
            THIP <em>KPI</em>
          </div>
          <span
            className={`connection-led connection-led-${connection.status}`}
          />
        </div>
        {!monitoringPreviewEnabled && (
          <>
            <details className="kpi-session-panel" open={!runtime}>
              <summary>
                BMS connection ·{' '}
                {connection.status === 'connected'
                  ? 'เชื่อมต่อแล้ว'
                  : 'รอเชื่อมต่อ'}
              </summary>
              <form
                className="step-session"
                onSubmit={(e) => {
                  e.preventDefault();
                  if (!sessionInput.trim()) return;
                  manualSession.current = sessionInput.trim();
                  setSessionInput('');
                  reconnect();
                }}
              >
                <label htmlFor="step-session-id">BMS Session ID</label>
                <input
                  id="step-session-id"
                  type="password"
                  autoComplete="off"
                  value={sessionInput}
                  onChange={(e) => setSessionInput(e.target.value)}
                  placeholder="Session จาก BMS launcher"
                />
                <button
                  className="secondary-button"
                  disabled={
                    !sessionInput.trim() || connection.status === 'connecting'
                  }
                >
                  เชื่อมต่อ
                </button>
                <button
                  type="button"
                  className="secondary-button"
                  onClick={reconnect}
                >
                  รีเฟรช session
                </button>
              </form>
              <p>{connection.message} · เก็บ credential ใน memory เท่านั้น</p>
            </details>
            {(connection.status === 'error' ||
              connection.status === 'unsupported') && (
              <p
                className="connection-banner connection-banner-error"
                role="alert"
              >
                <WifiOff size={16} />
                {connection.message}
              </p>
            )}
            <KpiLoadBar mode={mode} onMode={changeMode} onYear={changeYear} />
          </>
        )}
        <Suspense fallback={<p role="status">กำลังโหลดหน้าจอ…</p>}>
          {mode === 'approved' &&
          series === 'thip-report' &&
          (view === 'dashboard' || view === 'detail') ? (
            <ApprovedReportingPage
              code={view === 'detail' ? selectedCode : null}
              group={group}
              search={search}
              onGroup={changeGroup}
              onSearch={changeSearch}
              onYear={changeYear}
              onOpen={(code) => navigate('detail', code)}
              onCatalog={() => navigate('catalog')}
              onBack={() => navigate('dashboard')}
              connection={connection}
            />
          ) : view === 'validation' ? (
            <StepValidationPage
              runtime={runtime}
              fiscalYear={year}
              onFiscalYearChange={changeYear}
              group={group}
              search={search}
              onSearchChange={changeSearch}
              onGroupChange={changeGroup}
              onMonitoring={() => navigate('monitoring')}
            />
          ) : view === 'catalog' ? (
            <CatalogPage
              entries={runtimeCatalogue}
              wiredCodes={wired}
              activeGroup={group}
              search={search}
              onSearchChange={changeSearch}
              onGroupChange={changeGroup}
              onOpen={(code) => navigate('detail', code)}
            />
          ) : view === 'detail' && selectedCode ? (
            <SharedKpiDetail
              code={selectedCode}
              mode={mode}
              series={series}
              onBack={() => navigate('dashboard')}
            />
          ) : view === 'dashboard' ? (
            <SharedKpiOverview
              mode={mode}
              series={series}
              group={group}
              search={search}
              onSearchChange={changeSearch}
              onOpen={(code) => navigate('detail', code)}
            />
          ) : monitoringPreviewEnabled ? (
            <MonitoringPage
              runtime={null}
              fiscalYear={year}
              onFiscalYearChange={changeYear}
              group={group}
              onGroupChange={changeGroup}
              search={search}
              onSearchChange={changeSearch}
              onOverview={() => navigate('dashboard')}
            />
          ) : (
            <KpiMatrixPage
              fiscalYear={year}
              mode={mode}
              series={series}
              onSeries={changeSeries}
              group={group}
              onGroupChange={changeGroup}
              search={search}
              onSearchChange={changeSearch}
              onOpen={(code) => navigate('detail', code)}
            />
          )}
        </Suspense>
        <footer className="app-footer">
          <span>THIP KPI · BMS Marketplace</span>
          <span>{formatFiscalYear(year)} · Read-only</span>
        </footer>
      </main>
    </div>
  );
}
export function getGroupLabel(group: IndicatorGroup | 'all') {
  return group === 'all' ? 'ทุกกลุ่ม THIP' : groupMeta[group].shortLabel;
}
