import { useEffect, useState } from 'react';
import type { KpiResultView } from '@/services/kpiTypes';

const read = (): KpiResultView => new URLSearchParams(location.search).get('result') === 'cumulative' ? 'cumulative' : 'period';
export function useKpiResultView() {
  const [view, setView] = useState<KpiResultView>(read);
  useEffect(() => {
    const restore = () => setView(read());
    window.addEventListener('popstate', restore);
    return () => window.removeEventListener('popstate', restore);
  }, []);
  function change(next: KpiResultView) {
    const params = new URLSearchParams(location.search);
    if (next === 'period') params.delete('result'); else params.set('result', next);
    history.pushState({}, '', `${location.pathname}?${params}`);
    setView(next);
  }
  return [view, change] as const;
}
export function KpiResultViewControl({ view, onChange }: {
  view: KpiResultView; onChange(view: KpiResultView): void;
}) {
  return <div className="kpi-segment kpi-result-view" role="group" aria-label="รูปแบบผลการดำเนินงาน">
    <button aria-pressed={view === 'period'} onClick={() => onChange('period')}>รายเดือน / งวด</button>
    <button aria-pressed={view === 'cumulative'} onClick={() => onChange('cumulative')}>สะสมตั้งแต่ ต.ค.</button>
  </div>;
}
