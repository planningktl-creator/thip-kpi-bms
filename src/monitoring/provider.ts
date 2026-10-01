import { executeRegisteredQuery, type RegisteredQuery } from '@/services/queryRegistry';
import type { BmsRuntimeConfig } from '@/services/bmsSession';
import type { MonitoringProvider } from './types';

export const monitoringPreviewEnabled = import.meta.env.DEV && import.meta.env.VITE_THIP_MONITORING_PREVIEW === 'true';
const columns = ['code', 'fiscal_year', 'fiscal_month', 'period_start', 'period_end', 'data_through', 'numerator', 'denominator', 'value', 'unit', 'target', 'cumulative', 'accumulation', 'formula', 'method', 'data_status', 'assessment', 'reason', 'rule_version', 'refreshed_at', 'synthetic'];
const aliases = ['code', 'fiscalYear', 'fiscalMonth', 'periodStart', 'periodEnd', 'dataThrough', 'numerator', 'denominator', 'value', 'unit', 'target', 'cumulative', 'accumulation', 'formula', 'method', 'dataStatus', 'assessment', 'reason', 'ruleVersion', 'refreshedAt', 'synthetic'];
export function buildMonitoringQuery(sourceView: string): RegisteredQuery {
  if (!/^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$/i.test(sourceView)) throw new Error('Monitoring source must be a schema-qualified registered view');
  return { key: 'thipMonthlyMonitoring', description: 'Approved monthly monitoring aggregate source, independent of THIP cadence', sql: `SELECT ${columns.map((column, index) => `${column} AS "${aliases[index]}"`).join(', ')} FROM ${sourceView} WHERE fiscal_year = :fiscal_year ORDER BY code, fiscal_month` };
}
export async function createMonitoringProvider(runtime: BmsRuntimeConfig | null): Promise<MonitoringProvider> {
  if (import.meta.env.DEV && monitoringPreviewEnabled) {
    const preview = await import('@/dev/monitoringPreview');
    return preview.createPreviewProvider();
  }
  const view = import.meta.env.VITE_BMS_MONITORING_SOURCE_VIEW?.trim();
  return {
    preview: false,
    async load(fiscalYear, signal) {
      if (!runtime || !view) return [];
      const response = await executeRegisteredQuery(buildMonitoringQuery(view), runtime, { fiscal_year: { value: fiscalYear, value_type: 'integer' } }, runtime.marketplaceToken, { signal });
      return response.data ?? response.result ?? [];
    },
  };
}
