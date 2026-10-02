# Monthly monitoring contract — รุ่นแรก

ผล `monthly-monitoring` เป็น series แยกจาก THIP reporting โดยสมบูรณ์ ไม่แก้ความหมาย `Indicator.monthly` ซึ่งยังเป็น reporting period ตาม cadence. THIP มี 232 รหัส / 1,552 cells; monitoring มี 232 รหัส / 2,784 cells ต่อปี. ไม่มีการนำ annual/quarter result มาทำซ้ำหรือหารเป็นเดือน.

## หลักฐานและ rule registry

ต้นฉบับคือ `C:/Users/KTLho/Desktop/02_PDF/THIP KPI.pdf` (317 หน้า) และ `C:/Users/KTLho/Desktop/HOSxP Structure with primary key.json`. ดู mapping นิยาม ตัวตั้ง/ตัวหาร สูตร หน้าจริง/หน้าพิมพ์ schema/PK/join และข้อจำกัดครบ 232 รหัสใน [human matrix](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.md) และ [machine matrix](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json).

`src/monitoring/evidence.json` สกัด code/path/unit/page จาก machine matrix; `src/monitoring/rules.ts` สร้าง registry ครบ 232 รหัส. `reporting/thip_monitoring_rules.json` เป็น artifact ที่อ่านได้ทั้งคนและเครื่อง. เส้นทางพัฒนา: 101 monthly candidates, 71 ต้องกำหนดสูตรติดตามใหม่, 55 external aggregates, 5 external population denominators. ทุก rule จริงเริ่ม `approval=unapproved` และมีเหตุผล. Candidate SQL และชื่อคอลัมน์ตรง schema ไม่ใช่การรับรองสูตรหรือ join cardinality.

`MonitoringRule` ระบุ code/group/title, version, approval/evidence/effectiveFrom/effectiveTo, unit/precision/scale, direction/watchMargin, accumulation, formula/method, capability/reason, dictionaryBenchmark และ reference. การเผยแพร่จริงต้องมี approval evidence, version ตรงกัน และช่วงวันที่ครอบเดือนนั้น. การถอน approval ทำให้ผลกลับเป็น unavailable. `synthetic` approval ใช้ได้เฉพาะ development provider.

## Rows และเวลา

Source of truth สำหรับชนิดข้อมูลคือ `src/monitoring/types.ts`. `MonthlyMonitoringResult` มี:

| Fields | Contract |
|---|---|
| code, fiscalYear, fiscalMonth | code ใน registry; ISO fiscal-year integer; เดือน 1–12 คือ ต.ค.–ก.ย.; key ต้องไม่ซ้ำ |
| periodStart, periodEnd | ISO `YYYY-MM-DD`; วันแรกเดือนและวันแรกเดือนถัดไป (exclusive end) ตรงปี/เดือน |
| dataThrough, refreshedAt | วัน cutoff ของ facts และ ISO refresh timestamp จาก source; ไม่มี source ห้ามใช้เวลาโหลดแทน |
| numerator, denominator, value, unit | finite JSON numbers หรือ NULL; หน่วยตรง rule; zero denominator ไม่สร้างค่าอัตรา |
| target | NULL หรือ approved hospital target object ตามด้านล่าง |
| cumulative | numerator/denominator/value/through/complete; distinct/custom รับ aggregate สำเร็จจาก source |
| accumulation, formula, method, ruleVersion | ต้องตรง registry; ห้าม source เปลี่ยนสูตรหรือหน่วยเอง |
| dataStatus, assessment, reason, synthetic | สถานะข้อมูลแยกจากผลเทียบเป้า; missing ต้องมีเหตุผล; source จริงห้าม synthetic |

`MonitoringLoadResult` มี fiscalYear, series, preview, rows, refreshedAt, measuredCells, totalCells, error. Loader เติมช่องที่ไม่ได้ส่งมาครบ 2,784 ช่องด้วย NULL พร้อมเหตุผล ไม่ถือ missing rows เป็นข้อมูลวัด. Target อย่างเดียวไม่นับ coverage. Reject unknown fields, unknown codes, duplicate cells, dates/unit/version/formula/status ที่ผิด แทนการรวมโดยปริยาย. ไม่รับ identifiers หรือ raw patient rows.

FY 2026 = 2025-10-01 ถึง 2026-10-01 exclusive; แสดงปี 2569. ใช้ `Asia/Bangkok` ตัดสินเดือนปัจจุบัน/อนาคต. Future months คืน NULL พร้อม `future` แม้ provider ส่งค่ามา. เปลี่ยนปีล้าง snapshot/coverage ทันที ยกเลิก request เก่า และปิด export จนผลตรงปีที่เลือก.

## สถานะและเป้าหมาย

| Data status | ความหมาย |
|---|---|
| measured | facts และ value พร้อม dataThrough/refreshedAt ตาม rule ที่เผยแพร่ได้ |
| zero-cohort | query สำเร็จและ cohort 0/0; value NULL; ประเมินเป้าไม่ได้ |
| missing-source | มีสูตรที่เผยแพร่ได้แต่ไม่มี source/facts; NULL และเหตุผล |
| rule-unapproved | ยังไม่มีสูตร/version/effectivity ที่รับรอง; ไม่เผยแพร่ candidate facts |
| future | เดือนอนาคตใน Bangkok; NULL และเหตุผล |

Assessment มี on-track/watch/action/no-target/not-assessable. หน่วยรองรับ percent/rate/count/ratio/minute/day/month/hour-per-person; precision อยู่ใน rule. High/low directions ใช้ watch margin ที่กำหนด หรือ default system margin `max(abs(target) × 0.08, 0.02)`; UI บอกว่าเป็นเกณฑ์ระบบ. Range ผ่านเมื่ออยู่ระหว่าง lower/upper inclusive; ใช้ watch เฉพาะ rule กำหนด margin. Missing/zero cohort/future ประเมินไม่ได้.

Target object: `{value, lower, upper, unit, source, kind:'hospital', validFrom, validTo, mappingConfirmed:true}`. ต้องมี source, หน่วยตรงค่า และ effective interval ครอบเดือน. วันที่ validTo เป็น exclusive. Target 0 เป็นเป้าจริง ไม่ใช่ missing. Dictionary benchmark เป็นข้อความอ้างอิงแยกจาก hospital target; `kpi_moph` crosswalk ที่ยังไม่ยืนยันต้อง NULL. ไม่ carry เป้าระหว่างเดือน. Official THIP target ต้องผ่าน `hospitalTargetApproval` แยกจาก `publicationApproval` ด้วย.

## การสะสม

| Method | กฎ |
|---|---|
| sum/count | รวม facts ที่ additive และไม่ซ้ำตาม cohort ที่รับรอง |
| weighted-ratio | Σ numerator / Σ denominator × scale; ห้ามเฉลี่ย percentages |
| fixed-denominator | รวม numerator ใช้ denominator คงที่ครั้งเดียว; denominator เปลี่ยน/หายทำให้สะสมไม่สมบูรณ์ |
| snapshot | ใช้ snapshot ล่าสุดตาม cutoff; ไม่ sum snapshots |
| distinct-cohort | source ส่ง YTD aggregate ที่ distinct คน/episode แล้ว; ไม่รวมรายเดือนใน browser |
| custom | source ส่งสูตรเฉพาะพร้อม evidence/version และ YTD สำเร็จ; ไม่เดาสูตรจาก cadence |

เดือนที่ facts ขาดทำให้ client-computed YTD ไม่สมบูรณ์และ NULL; ห้ามข้ามเดือนแล้วอ้างเป็นผลครบ. SH0101 official annual turnover ยังคงสูตร dictionary; preview monthly headcount/YTD ใช้สูตรจำลองแยกและไม่ใช่สูตรโรงพยาบาลที่รับรอง.

## Provider และ reporting layer

Production ใช้ `MonitoringProvider.load(fiscalYear, signal)` ผ่าน session เดิม และ `executeRegisteredQuery`. ตั้ง `VITE_BMS_MONITORING_SOURCE_VIEW=reporting.thip_monthly_monitoring` หรือชื่อ qualified view ที่ลงทะเบียน; query รับ fiscal_year integer และ SELECT 21 aggregate columns พร้อม camelCase aliases. SQL อยู่หลัง registered layer; ต้องลงทะเบียน server-side และใช้ DB role SELECT เท่านั้น. การตรวจ SQL ฝั่ง browser ไม่ใช่ authorization boundary.

`reporting/thip_monthly_monitoring.sql` เป็น offline DDL artifact มี period/unique/state/unit constraints, JSONB target/cumulative และห้าม synthetic rows. Frontend ไม่รัน DDL/refresh. DBA ต้องตรวจและ provision reporting layer ตามกระบวนการโรงพยาบาลภายหลัง. ยังไม่มี approved refresh query สำหรับทุก monitoring code; ตารางที่ provision แล้วก็ยังไม่ทำให้ rule ผ่านรับรองเอง. ไม่มี session/source config หรือไม่มี approved rule จะเห็น matrix ครบพร้อมเหตุผล.

## Development preview และ export

ตั้ง `VITE_THIP_MONITORING_PREVIEW=true` เฉพาะ `pnpm dev`. Provider ใช้ interface เดียวกัน แต่ import fixture แบบ DEV dynamic import; production build ปฏิเสธ flag และ bundle check ห้าม fixture canary/version. ป้าย “ข้อมูลสังเคราะห์” อยู่ทั้งหน้าและ CSV. DH0101, DH0112, CE0102, HH0102, SH0101, SM0201, DE1601 เป็นตัวอย่างสูตร/สถานะจำลอง; อีก 225 รหัสแสดงเหตุผลรอรับรองครบ. Preview ไม่เริ่ม real connection.

CSV ส่งทุก 12 เดือนของแถวที่ผ่าน filter รวม NULL/reasons, series/preview label, BE year, periods, cutoff, facts/unit, target/source/interval, YTD, accumulation/formula/method, statuses, rule version/refresh. Filename ระบุ monitoring/FY/preview; text ที่ขึ้นต้นสูตรถูก escape โดยคง typed numbers. Filter status เก็บ KPI ที่พบสถานะนั้นอย่างน้อยหนึ่งเดือน; ไม่ตัดเดือนอื่นออก.

## ก่อนเปิดข้อมูลจริง

เจ้าของ KPI family ต้องรับรอง cohort, event date/observation window, join cardinality, local code sets, denominator, accumulation, source/target effectivity และ rule version แล้วเทียบ aggregate กับรายงานทางการ. เพิ่ม evidence ใน registry จึงเปิด publication. ติดตาม coverage/freshness/query latency และถอน approval ได้. การตรวจด้วย schema/fixtures/mock BMS ในรุ่นนี้ไม่ใช่ clinical certification.

## Shared SPA owner — 2 ตุลาคม 2569

[THIP-SHARED-DATA.md](THIP-SHARED-DATA.md) กำหนด root-owned queue/cache, strict draft projection, review/approved selectors และ explicit monthly bridge. Route ไม่โหลดข้อมูลซ้ำ; publication/completeness/cadence เดิมคงอยู่. ใช้ mocked BMS เท่านั้นสำหรับรอบนี้.
