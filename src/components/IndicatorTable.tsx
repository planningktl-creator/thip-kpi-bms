import { ChevronRight, ClipboardCheck, Minus, TrendingDown, TrendingUp } from 'lucide-react';
import type { Indicator } from '@/types/thip';
import { groupMeta } from '@/data/thipData';
import { formatDelta, formatIndicatorValue } from '@/utils/format';
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
        <thead>
          <tr>
            <th>ตัวชี้วัด</th>
            <th>ผลงานล่าสุด</th>
            <th>เป้าหมาย</th>
            <th>เทียบเดือนก่อน</th>
            <th>สถานะ</th>
            <th aria-label="เปิดรายละเอียด" />
          </tr>
        </thead>
        <tbody>
          {indicators.map((indicator) => {
            const latest = indicator.monthly[visibleMonthIndex] ?? indicator.monthly[indicator.monthly.length - 1];
            const previous = indicator.monthly[visibleMonthIndex - 1] ?? indicator.monthly[Math.max(0, visibleMonthIndex - 1)];
            const delta = latest.value !== null && previous.value !== null ? latest.value - previous.value : null;
            const improvement = delta === null ? null : indicator.direction === 'lower-is-better' ? delta < 0 : delta > 0;
            return (
              <tr key={indicator.code} onClick={() => onOpen(indicator.code)} tabIndex={0} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') onOpen(indicator.code); }}>
                <td>
                  <div className="indicator-name-cell">
                    <span className="table-group-letter" style={{ backgroundColor: groupMeta[indicator.group].color }}>{indicator.group}</span>
                    <div>
                      <strong>{indicator.code} <span className="row-category">· {groupMeta[indicator.group].shortLabel}</span></strong>
                      <span>{indicator.titleTh}</span>
                    </div>
                  </div>
                </td>
                <td><strong className="table-value">{formatIndicatorValue(indicator, latest.value)}</strong><span className="table-subvalue">{latest.label} 2569</span></td>
                <td><span className="target-value">{formatIndicatorValue(indicator, indicator.target)}</span></td>
                <td>
                  <div className={`table-delta ${improvement === true ? 'delta-good' : improvement === false ? 'delta-bad' : ''}`}>
                    {improvement === null ? <Minus size={15} /> : improvement ? <TrendingUp size={15} /> : <TrendingDown size={15} />}
                    <span>{formatDelta(latest.value, previous.value, indicator)}</span>
                  </div>
                </td>
                <td><StatusPill status={latest.status} compact /></td>
                <td><button className="table-arrow" aria-label={`เปิด ${indicator.code}`}><ChevronRight size={17} /></button></td>
              </tr>
            );
          })}
        </tbody>
      </table>
      {!indicators.length && <div className="table-empty"><ClipboardCheck size={22} /><strong>ไม่พบตัวชี้วัดตามตัวกรอง</strong><span>ลองเปลี่ยนกลุ่มหรือคำค้นหา</span></div>}
    </div>
  );
}
