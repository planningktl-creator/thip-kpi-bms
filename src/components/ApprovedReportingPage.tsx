import { useMemo, useState } from 'react';
import { useKpiData } from './KpiDataContext';
import { DashboardPage } from './DashboardPage';
import { DetailView } from './DetailView';
import { createNoDataIndicator } from '@/data/thipCatalogue';
import { runtimeCatalogue } from '@/data/thipRuntime';
import type { BmsConnection, IndicatorGroup } from '@/types/thip';
/** Legacy approved charts/export are retained, but have no loading effect. */
export function ApprovedReportingPage({
  code,
  group,
  search,
  onGroup,
  onSearch,
  onYear,
  onOpen,
  onCatalog,
  onBack,
  connection,
}: {
  code: string | null;
  group: IndicatorGroup | 'all';
  search: string;
  onGroup(group: IndicatorGroup | 'all'): void;
  onSearch(value: string): void;
  onYear(year: number): void;
  onOpen(code: string): void;
  onCatalog(): void;
  onBack(): void;
  connection: BmsConnection;
}) {
  const { store, snapshot } = useKpiData();
  const [month, setMonth] = useState(11);
  const defaults = useMemo(
    () =>
      runtimeCatalogue.map((entry) =>
        createNoDataIndicator(entry, snapshot.fiscalYear)
      ),
    [snapshot.fiscalYear]
  );
  const indicators = defaults.map(
    (indicator) => store.officialIndicator(indicator.code) ?? indicator
  );
  if (code) {
    const indicator = indicators.find((indicator) => indicator.code === code);
    return indicator ? (
      <DetailView indicator={indicator} onBack={onBack} />
    ) : (
      <p>ไม่พบรหัส</p>
    );
  }
  const steps = store
    .reportingSteps()
    .filter((step) => step.status === 'success');
  const covered = steps.reduce((sum, step) => sum + step.rows.length, 0),
    available = indicators
      .flatMap((indicator) => indicator.monthly)
      .filter(
        (month) => month.value !== null || month.denominator !== null
      ).length;
  const coverage = {
    expectedIndicatorCount: 232,
    liveIndicatorCount: steps.length,
    measuredIndicatorCount: indicators.filter(
      (indicator) => indicator.dataSource === 'bms'
    ).length,
    expectedCellCount: 1552,
    coveredCellCount: covered,
    availableCellCount: available,
    unavailableCellCount: covered - available,
    unexpectedCellCount: 0,
    complete: covered === 1552,
    liveCodes: steps.map((step) => step.code),
  };
  const filtered = indicators.filter(
    (indicator) =>
      (group === 'all' || indicator.group === group) &&
      `${indicator.code} ${indicator.title} ${indicator.titleTh}`
        .toLowerCase()
        .includes(search.trim().toLowerCase())
  );
  return (
    <DashboardPage
      indicators={filtered}
      allIndicators={indicators}
      activeGroup={group}
      onGroupChange={onGroup}
      search={search}
      onSearchChange={onSearch}
      monthIndex={month}
      onMonthChange={setMonth}
      fiscalYear={snapshot.fiscalYear}
      onFiscalYearChange={onYear}
      onOpenIndicator={onOpen}
      onOpenCatalog={onCatalog}
      connection={connection}
      dataSource={
        snapshot.preparing ? 'loading' : available ? 'partial' : 'unavailable'
      }
      refreshedAt={null}
      coverage={coverage}
      globalYearControl
    />
  );
}
