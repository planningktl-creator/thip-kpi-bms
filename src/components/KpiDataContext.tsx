import { createContext, useContext, useSyncExternalStore } from 'react';
import type { KpiDataStore } from '@/services/kpiDataStore';
export const KpiDataContext = createContext<KpiDataStore | null>(null);
export function useKpiData() {
  const store = useContext(KpiDataContext);
  if (!store) throw new Error('KPI data owner is required');
  const snapshot = useSyncExternalStore(store.subscribe, store.snapshot);
  return { store, snapshot };
}
