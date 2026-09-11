import { ChevronRight, ClipboardCheck, Minus, TrendingDown, TrendingUp } from 'lucide-react';
import type { Indicator } from '@/types/thip';
import { groupMeta } from '@/data/thipMeta';
import { getLatestApplicableFiscalMonth, getPreviousApplicableFiscalMonth } from '@/data/thipReporting';
import { formatDelta, formatIndicatorValue, formatTargetValue } from '@/utils/format';
import { StatusPill } from '@/components/StatusPill';

type Props = {
  indicators: Indicator[];
  onOpen: (code: string) => void;
  monthIndex?: number;
};

export function IndicatorTable({ indicators, onOpen, monthIndex }: Props) {
  const visibleMonthIndex = monthIndex ?? 11;
  return (
    <div className="indicator-table-wrap">
      <table className="indicator-table">
        <caption className="sr-only">รายการสัญญาณตัวชี้วัดตามงวดที่เลือก</caption>
        <thead>
          <tr>
            <th scope="col">ตัวชี้วัด</th>
            <th scope="col">ผลงานล่าสุด</th>
            <th scope="col">เป้าหมาย</th>
            <th scope="col">เทียบรอบก่อน</th>
            <th scope="col">สถานะ</th>
            <th scope="col" aria-label="เปิดรายละเอียด" />
          </tr>
        </thead>
        <tbody>
          {indicators.map((indicator) => {
            const latestFiscalMonth = getLatestApplicableFiscalMonth(indicator.code, visibleMonthIndex + 1);
            const previousFiscalMonth = getPreviousApplicableFiscalMonth(indicator.code, latestFiscalMonth);
            const latest = indicator.monthly[latestFiscalMonth - 1] ?? indicator.monthly[indicator.monthly.length - 1];
            const previous = previousFiscalMonth === null
              ? null
              : indicator.monthly[previousFiscalMonth - 1] ?? null;
            const delta = latest.value !== null && previous?.value !== null && previous?.value !== undefined
              ? latest.value - previous.value
              : null;
            const improvement = delta === null || indicator.direction === 'neutral'
              ? null
              : indicator.direction === 'lower-is-better' ? delta < 0 : delta > 0;
            const target = indicator.targetScope === 'annual' ? indicator.annual.target : latest.target;
            return (
              <tr key={indicator.code} aria-label={`เปิดรายละเอียด ${indicator.code} ${indicator.titleTh}`} onClick={() => onOpen(indicator.code)} tabIndex={0} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); onOpen(indicator.code); } }}>
                <td>
                  <div className="indicator-name-cell">
                    <span className="table-group-letter" aria-hidden="true" style={{ backgroundColor: groupMeta[indicator.group].color }}>{indicator.group}</span>
                    <div>
                      <strong>{indicator.code} <span className="row-category">· {groupMeta[indicator.group].shortLabel}</span></strong>
                      <span>{indicator.titleTh}</span>
                    </div>
                  </div>
                </td>
                <td><strong className="table-value">{formatIndicatorValue(indicator, latest.value)}</strong><span className="table-subvalue">{latest.label}</span></td>
                <td><span className="target-value">{formatTargetValue(indicator, target)}</span></td>
                <td>
                  <div className={`table-delta ${improvement === true ? 'delta-good' : improvement === false ? 'delta-bad' : ''}`}>
                    {improvement === null ? <Minus size={15} /> : improvement ? <TrendingUp size={15} /> : <TrendingDown size={15} />}
                    <span>{formatDelta(latest.value, previous?.value ?? null, indicator)}</span>
                  </div>
                </td>
                <td><StatusPill status={latest.status} compact /></td>
                <td><button className="table-arrow" type="button" aria-label={`เปิด ${indicator.code}`}><ChevronRight size={17} /></button></td>
              </tr>
            );
          })}
        </tbody>
      </table>
      {!indicators.length && <div className="table-empty"><ClipboardCheck size={22} /><strong>ไม่พบตัวชี้วัดตามตัวกรอง</strong><span>ลองเปลี่ยนกลุ่มหรือคำค้นหา</span></div>}
    </div>
  );
}
