import { useEffect, useState } from 'react';
import type { KpiCellViewModel } from '@/services/kpiTypes';
import { runtimeMonitoringRules } from '@/data/thipRuntime';
import { monitoringUnitLabels } from '@/monitoring/rules';
import { formatThaiDate, formatThaiDateTime } from '@/utils/fiscal';
import { loadThipEvidence } from '@/data/thipEvidenceLoader';
import type { CohortDefinition } from '@/data/cohortTypes';
import { accumulationLabels } from '@/services/kpiCumulative';
const number = (value: number | null) =>
  value === null
    ? '—'
    : value.toLocaleString('th-TH', { maximumFractionDigits: 4 });
export function KpiCellDetails({ cell }: { cell: KpiCellViewModel }) {
  const rule = runtimeMonitoringRules.find((rule) => rule.code === cell.code)!;
  const [evidence, setEvidence] = useState<CohortDefinition | null>(null);
  useEffect(() => {
    let alive = true;
    setEvidence(null);
    void loadThipEvidence(cell.code)
      .then((result) => {
        if (alive) setEvidence(result?.cohort ?? null);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [cell.code]);
  return (
    <div className="kpi-cell-details">
      <p className="kpi-mode-label review">
        {cell.approval === 'approved'
          ? 'ผ่าน publication gate'
          : 'ข้อมูลสอบทาน — ยังไม่รับรอง'}
      </p>
      <dl className="monitoring-facts">
        <div>
          <dt>ช่วงงวด (สิ้นสุดไม่รวม)</dt>
          <dd>
            {formatThaiDate(cell.periodStart)} –{' '}
            {formatThaiDate(cell.periodEnd)}
          </dd>
        </div>
        <div>
          <dt>ค่าจาก source / หน่วย</dt>
          <dd>
            {number(cell.value)} {monitoringUnitLabels[cell.unit]}
          </dd>
        </div>
        <div>
          <dt>ตัวตั้ง</dt>
          <dd>{number(cell.numerator)}</dd>
        </div>
        <div>
          <dt>ตัวหาร</dt>
          <dd>{number(cell.denominator)}</dd>
        </div>
        <div>
          <dt>คำนวณเพื่อเปรียบเทียบ</dt>
          <dd>
            {number(cell.derivedValue)}
            {cell.discrepancy &&
              ' · ต่างจาก source; ไม่นำเข้าการวิเคราะห์อัตโนมัติ'}
          </dd>
        </div>
        <div>
          <dt>เป้าหมายโรงพยาบาล</dt>
          <dd>
            {cell.target
              ? `${number(cell.target.value)} ${monitoringUnitLabels[cell.unit]} · ${cell.target.source}`
              : 'ไม่มีเป้าหมายที่ยืนยัน'}
          </dd>
        </div>
        <div>
          <dt>Benchmark จากพจนานุกรม (ข้อมูลอ้างอิง)</dt>
          <dd>{rule.dictionaryBenchmark ?? '—'}</dd>
        </div>
        <div>
          <dt>ผลสะสมตั้งแต่ ต.ค.</dt>
          <dd>
            {number(cell.cumulative.value)} {cell.cumulative.value !== null && monitoringUnitLabels[cell.unit]} ·{' '}
            {cell.cumulative.complete
              ? 'ครบช่วงที่ source ยืนยัน'
              : 'ยังไม่ยืนยันความครบช่วง'}{' '}
            · {accumulationLabels[cell.accumulation] ?? cell.accumulation}
            <small>{cell.cumulativeReason}</small>
          </dd>
        </div>
        <div><dt>ตัวตั้ง / ตัวหารสะสม</dt><dd>{number(cell.cumulative.numerator)} / {number(cell.cumulative.denominator)}</dd></div>
        <div><dt>วันตัดยอดสะสม</dt><dd>{cell.cumulative.through ? formatThaiDate(cell.cumulative.through) : 'แหล่งข้อมูลยังไม่ยืนยันวันตัดยอด'}</dd></div>
        <div>
          <dt>เหตุผล / สถานะ</dt>
          <dd>{cell.reason}</dd>
        </div>
        <div>
          <dt>วันที่ source ครอบคลุมถึง</dt>
          <dd>
            {cell.dataThrough
              ? formatThaiDate(cell.dataThrough)
              : 'ยังไม่ยืนยัน'}
          </dd>
        </div>
        <div>
          <dt>Refresh ที่ source</dt>
          <dd>
            {cell.refreshedAt
              ? formatThaiDateTime(cell.refreshedAt)
              : 'ยังไม่ยืนยัน'}
          </dd>
        </div>
        <div>
          <dt>อ่านผลเมื่อ</dt>
          <dd>
            {cell.observedAt ? formatThaiDateTime(cell.observedAt) : '—'}
            {cell.origin === 'cache' && ' · จาก cache'}
            <small>เวลาอ่านผลไม่ใช่ source freshness</small>
          </dd>
        </div>
        <div>
          <dt>หมดอายุ cache</dt>
          <dd>{cell.expiresAt ? formatThaiDateTime(cell.expiresAt) : '—'}</dd>
        </div>
        <div>
          <dt>Rule version / lineage</dt>
          <dd>
            {cell.ruleVersion} · {cell.lineage}
          </dd>
        </div>
      </dl>
      <details>
        <summary>นิยามตัวตั้ง–ตัวหารและวิธีคำนวณ</summary>
        {evidence ? (
          <>
            <p>ตัวตั้ง: {evidence.numeratorDefinition}</p>
            <p>ตัวหาร: {evidence.denominatorDefinition}</p>
            <p>สูตร THIP: {evidence.formula}</p>
            <p>
              คีย์: {evidence.keyCandidates.join(', ')} · วันที่:{' '}
              {evidence.eventDateCandidates.join(', ')}
            </p>
            <p>
              หน่วยนับ: {evidence.currentGrain} · {evidence.observationWindow}
            </p>
            <p>
              PDF หน้า {evidence.pdfPage} · {evidence.ruleVersion} · หลักฐาน
              candidate ยังไม่รับรอง
            </p>
          </>
        ) : (
          <p>หลักฐานยังไม่พร้อม</p>
        )}
        <p>สูตรชุดผลที่เลือก: {cell.formula}</p>
        <p>{cell.method}</p>
      </details>
    </div>
  );
}
