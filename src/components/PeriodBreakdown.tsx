import { useState } from 'react';
import type { Indicator } from '@/types/thip';
import { rollupAnnual, rollupMonths, rollupQuarters, type PeriodRollup } from '@/utils/rollup';
import { formatFiscalYear, formatFiscalYearShort } from '@/utils/fiscal';
import { formatIndicatorValue, formatNumber, formatTargetValue } from '@/utils/format';
import { StatusPill } from '@/components/StatusPill';

type PeriodView = 'monthly' | 'quarterly' | 'annual';

const viewLabels: Record<PeriodView, string> = {
  monthly: 'รายเดือน',
  quarterly: 'รายไตรมาส',
  annual: 'รายปี',
};

type Props = {
  indicator: Indicator;
};

/**
 * Results broken down by reporting horizon for one fiscal year: monthly
 * (every fiscal month), quarterly (weighted Q1-Q4) and the annual rollup.
 * Every row carries its approved target next to the measured result.
 */
export function PeriodBreakdown({ indicator }: Props) {
  const [view, setView] = useState<PeriodView>('monthly');
  const rows: PeriodRollup[] = view === 'monthly'
    ? rollupMonths(indicator)
    : view === 'quarterly'
      ? rollupQuarters(indicator)
      : [rollupAnnual(indicator)];

  return (
    <section className="panel period-breakdown-panel" data-testid="period-breakdown">
      <div className="panel-heading">
        <div>
          <span className="panel-eyebrow">RESULTS BY REPORTING HORIZON</span>
          <h3>ผลการดำเนินการรายปีงบประมาณ · {formatFiscalYear(indicator.fiscalYear)}</h3>
          <p>ค่าผลลัพธ์รวมเป็นแบบถ่วงน้ำหนักจากตัวตั้ง/ตัวหารจริงของทุกงวดในรอบเวลานั้น พร้อมเป้าหมายและสถานะของทุกช่วง</p>
        </div>
        <div className="chart-switcher" role="tablist" aria-label="มุมมองผลการดำเนินการ">
          {(Object.keys(viewLabels) as PeriodView[]).map((key) => (
            <button
              key={key}
              type="button"
              role="tab"
              aria-selected={view === key}
              className={view === key ? 'is-active' : ''}
              onClick={() => setView(key)}
            >
              {viewLabels[key]}
            </button>
          ))}
        </div>
      </div>
      <div className="monthly-table-wrap">
        <table className="monthly-table">
          <thead>
            <tr>
              <th>{view === 'monthly' ? 'เดือนงบประมาณ' : view === 'quarterly' ? 'ไตรมาส (ต.ค. – ก.ย.)' : 'ปีงบประมาณ'}</th>
              <th>ตัวตั้ง (a)</th>
              <th>ตัวหาร (b)</th>
              <th>ผลลัพธ์</th>
              <th>เป้าหมาย</th>
              {view !== 'monthly' && <th>งวดที่วัดได้</th>}
              <th>สถานะ</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row) => (
              <tr key={row.key}>
                <td><strong>{view === 'annual' ? formatFiscalYearShort(indicator.fiscalYear) : row.label}</strong><span>{row.hint}</span></td>
                <td>{formatNumber(row.numerator)}</td>
                <td>{formatNumber(row.denominator)}</td>
                <td><strong>{formatIndicatorValue(indicator, row.value)}</strong></td>
                <td>{formatTargetValue(indicator, row.target)}<span>{row.targetLabel}</span></td>
                {view !== 'monthly' && <td>{row.measuredCellCount}/{row.fiscalMonths.length}</td>}
                <td><StatusPill status={row.status} compact /></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
