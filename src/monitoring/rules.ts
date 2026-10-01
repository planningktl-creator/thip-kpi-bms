import { runtimeMonitoringRules } from '@/data/thipRuntime';
import type { MonitoringRule, MonitoringUnit } from './types';
export const monitoringRules: readonly MonitoringRule[] = runtimeMonitoringRules;
export const monitoringRulesByCode: ReadonlyMap<string, MonitoringRule> = new Map(monitoringRules.map((rule) => [rule.code, rule]));
export const monitoringUnitLabels: Record<MonitoringUnit, string> = {
  percent: '%', rate: 'อัตรา', count: 'จำนวน', ratio: 'อัตราส่วน', minute: 'นาที', day: 'วัน', month: 'เดือน', 'hour-per-person': 'ชั่วโมง/คน',
};
