# แผนแก้ข้อค้นพบและตรวจรับ

**อ้างอิง:** [รายงาน audit](PROJECT-AUDIT-2026-09-30.md) และ [mapping ราย KPI](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.md). ความรุนแรงจัดภายในแกน Standards / Spec ตาม code review; รหัส `STD-*`/`SPEC-*` ที่ชี้ซ้ำคือปัญหาเดียวกันคนละมุมตรวจ.

| งาน | ระดับ / Finding | Dependency | ผลลัพธ์และเกณฑ์รับงาน |
|---|---|---|---|
| R0.1 ตัดข้อมูลระบุตัวตนออกจาก access log | P1 · STD-01 | ยืนยันรูปแบบ launcher/session URL ที่ใช้งานจริง; ไม่ต้องใช้ข้อมูลจริงในการทดสอบ | Nginx log format บันทึก path แบบไม่ query และ Referer ที่ผ่านการ redact/ตัดออก; synthetic canary ใส่ทั้ง query, Referer และ error path แล้วไม่พบค่าใน stdout/container collector. ยืนยัน request tracing ยังใช้ correlation id ที่ไม่ใช่ credential ได้. |
| R0.2 ทำ read-only database privilege เป็น security boundary | P1 gate · STD-16 | BMS/DB owner กำหนด database role และ function allowlist | ต่อเมื่อ BMS/DB owner ให้หลักฐาน role อ่านอย่างเดียวและ deny write/DDL/side-effect functions; ทดสอบ forbidden operations ถูกปฏิเสธที่ server/DB แม้ส่งผ่าน query wrapper. SQL allowlist ต้องยึด registered keys; guard ใน client อย่างเดียวไม่ผ่าน. |
| R0.3 แยก registered SQL ออกจากสิทธิ์ publish ผลจริง | P1 · SPEC-02 | อนุมัติ evidence schema กับผู้รับผิดชอบ KPI/คุณภาพ | ใช้ approval manifest ราย code และ series ที่ต้องมี source/cohort/episode grain/date/target source/code set/rule version/evidence/owner/effective date; default block. Registered query ที่ยังไม่มี sign-off ส่ง unavailable พร้อม reason. Fixture ที่ลองเปลี่ยน status เป็น ready โดยไม่มี evidence ต้อง fail. |
| R0.4 คืนทาง external aggregates | P1 · SPEC-01 | R0.3 และสัญญา shape ของ hospital-managed staging | ใช้ aggregate row จาก external staging จริงใน source view; seeded synthetic value 95/100 ต้องได้ 95 พร้อม target NULL ถ้าไม่มี hospital target; missing staging ต้องเป็น unavailable พร้อม reason; ค่า 0 และ NULL ต้องไม่ปะปน. ห้ามส่ง raw person/event rows. |
| R0.5 แก้ query bisection ตาม grain ของผล | P1 · SPEC-03 | ระบุว่าการแบ่งช่วงมีไว้ลด runtime หรือแยก query และยืนยัน row grain ทุก query family | หาก split ช่วงเวลาแล้ว fact เป็น quarter/YTD/cohort ที่ทับกัน ให้ไม่ merge แบบ first-wins; ประเมินทั้งช่วงด้วย bounded query/แบ่ง code หรือ aggregate แบบ associativity ที่พิสูจน์แล้ว. Oct–Jan admission/discharge/observation-window fixtures ต้องเท่ากับผล full-window ทั้ง numerator, denominator และ value. |
| R0.6 กัก generated monthly/yearly SQL ที่ไม่มี rule อนุมัติ | P1 ก่อนใช้ · SPEC-04 | นิยาม monthly data contract R1.1 และ rule owner | ต่อ code ต้องระบุ sum/count, weighted ratio, fixed denominator, snapshot หรือ server-side distinct cohort พร้อมเหตุผล. HH0102 บุคคลเดียวหลายเดือนต้องนับครั้งเดียวถ้า cohort เป็นบุคคล; SH0101 สูตรรายปีคงอยู่ใน official THIP series ส่วนสูตรเดือนแยกมี acceptance/sign-off ของตน. Annual boundary fixtures ต้องไม่รวมข้าม FY ผิด. |
| R0.7 ยกเลิกการเดา target จาก `kpi_moph` | P1 ก่อนใช้ · SPEC-05 | Data owner ส่ง crosswalk ที่ระบุ field, meaning, year, unit, effective interval และ update policy | Crosswalk ที่ไม่มีความหมายยืนยันต้องให้ hospital target `NULL`; dictionary benchmark แสดงแยกเป็น reference เท่านั้น. ทดสอบป้องกัน result ถูกเลือกเป็น target, ปีเก่าถูกนำมาใช้, target เปลี่ยนกลางปี, ไม่มี target และ target 0. |
| R0.8 เคลียร์ state ปีงบและห้าม export snapshot ผิดปี | P1 · STD-02 | เลือก stale-while-revalidate หรือ pending state UX | ระหว่างรอ FY ใหม่ UI ต้องระบุปีของ snapshot เดิมชัด หรือเคลียร์ rows/coverage; disable export จน snapshot ตรงกับปีที่เลือก. เพิ่ม delayed/out-of-order response, error/timeout, back-to-old-year และ filename assertion. |
| R0.9 เติม pending reason และแก้ความหมาย completeness | P2 · STD-09/SPEC-07, STD-15 | R0.3 ยืนยัน status/coverage vocabulary | Completeness นับเฉพาะ measured reporting cells ตามนิยาม; target อย่างเดียวไม่ใช่ observation. ทุก unavailable cell มี reason code/text. ทดสอบ no-data all-NULL = 0 measured, zero cohort = measured zero cohort, partial source = incomplete, future period = future, ทั้งหมดไม่ถูกนับเป็นศูนย์โดยอัตโนมัติ. |
| R0.10 แก้ effective target rollup และเกณฑ์แบบช่วง | P2 · STD-06/SPEC-06 | R1.2 target contract ระบุวัน/งวดมีผล | Target annual rollup ต้องใช้กฎ approved ที่สัมพันธ์ effective period; ห้ามใช้ target ไตรมาสแรกกับทุกงวด. มี fixture เปลี่ยนเป้า, ไม่มีเป้า, เป้าศูนย์, direction สูง/ต่ำ และเกณฑ์ range. |
| R0.11 แก้ SPC rules และเลือก chart จาก measurement model | P2 · STD-07/08, SPEC-08 | Domain owner รับรองชนิด measure/ลำดับข้อมูล | เส้นกลางไม่ถูกนับเป็น side run เว้นแต่กฎที่รับรองระบุ; ratio/control-limit count ไม่ใช้ p-chart จน metadata ระบุ Bernoulli proportion + denominator ที่เหมาะ. Fixtures ค่าเท่ากับ CL, ties, denominator ต่างกัน, out-of-range และ missing months ต้องให้ผลตาม rule. |
| R0.12 ใช้หน่วยจริงและ range criteria | P2 · SPEC-09 | เพิ่ม dictionary metadata ที่ผ่าน review | รองรับ month, day, minute, hour/person และหน่วยที่เจ้าของยืนยัน; แปลง benchmark ได้เฉพาะเมื่อระบุ conversion/period. แยก unit, display precision, direction, threshold/range. ทดสอบ SM0201 วันเทียบเดือน, CE0102 นาที และ SH0204 ชั่วโมง/คน. |
| R0.13 ป้องกันสูตร spreadsheet ใน CSV | P2 · STD-10 | กำหนดพฤติกรรมสำหรับ text fields และตัวเลขติดลบ | Escape text cells ที่ขึ้นต้นด้วย `= + - @`, tab, CR/LF หรือ control prefix ตามแนว spreadsheet injection; numeric columns ยังคงเป็นตัวเลขที่ผู้รับเปิดใช้ต่อได้อย่างตั้งใจ. ทดสอบ round-trip delimiter/quote/unicode และไม่เปลี่ยน raw DB payload. |
| R0.14 ทำ routing catalogue ให้ refresh ได้ | P2 · STD-05 | ไม่มี | route state ต้องอยู่ใน URL; เปิด/refresh/back/forward ที่ catalog คงหน้าเดิมและ keyboard navigation ไม่เสีย. |
| R0.15 ยกเลิก request เก่าและขยาย timeout ถึง body | P2 · STD-03/04 | ปรับ loader/cancellation interface | เปลี่ยน FY/unmount ยกเลิก request เมื่อ transport รองรับ; deadline ครอบคลุม headers, body read และ parse; request เก่าไม่มีสิทธิ์เขียน state. ทดสอบ aborted signal, body stall และ error mapping/telemetry ที่ไม่มี token/SQL/rows. |
| R0.16 ซ่อน sidebar ออกจาก focus tree | P2 · STD-14 | เลือกรูปแบบ focus trap/close behavior | เมื่อปิดบน mobile sidebar เป็น inert/hidden และ focus กลับ toggle; Escape/Tab/Shift+Tab ถูกต้อง; เปิดแล้วอ่าน label/status ได้. ตรวจ keyboard และ responsive browser test. |
| R0.17 ทำ build/runtime baseline ให้สอดคล้อง | P2 · STD-11/12/13/17 | ตกลง Node LTS ที่ deploy target รองรับ (แนะนำ Node 24 หลังยืนยัน platform) | Compose ส่ง args/flags ครบและผ่านทั้ง foundation/source-view mode; CI ทุก job ใช้ Node/pnpm เดียว; lockfile อัป Vitest ไป patched compatible release แล้ว test/build ผ่าน; `.dockerignore` ยกเว้น `.env*`/private artifacts และทดสอบ build context ไม่มีไฟล์ต้องห้าม. |
| R0.18 ตรวจ generated artifacts ซ้ำได้ | P2 · STD-18, audit source-view drift | เจ้าของไฟล์ generated เดิมกำหนด canonical generator/input | สร้าง output จาก input ที่ระบุแล้วทำ diff/check ใน CI; fresh output ตรง committed bytes หรือมีการ commit การเปลี่ยนแปลงพร้อมเหตุผล. Hash ของ original SQL pack ต้องคำนวณหลัง transform และ encoding ที่ส่งมอบ. ไม่เขียนทับไฟล์ working tree ที่ผู้ใช้แก้ก่อนแล้วโดยไม่ review. |
| R0.19 ปรับ docs และ baseline inventory | P2/P3 · STD-20/21 | ผล R0.3/R0.18 | README/source notes/contracts/roadmap ระบุ 232 registered, 0 ready, 55 external staging และ dependencies ตรงกัน; link อ้างไฟล์ PDF/JSON ที่ใช้จริงหรือระบุรุ่น/hash; ยืนยัน workbook กับ JSON หากจะอ้างแทนกัน. ระบุ `reporting` schema provisioning ก่อน DDL; ห้ามเรียก fixture completeness ว่า clinical validation. |
| R0.20 ผ่าน browser/visual regression ใหม่ | P2 · STD-02/05/09/14/15, smoke failure | R0.8/R0.9/R0.14/R0.16 | แก้ assertion visual smoke ให้ตรวจ copy ปัจจุบันหรือ semantic anchor; ทดสอบ no-data, full mock, unavailable/error, mobile focus, search/filter, FY switch, drill-through, export. Run จบและทุก assertion ผ่าน ไม่ถือ screenshot อย่างเดียวเป็นผลสำเร็จ. |
| R0.21 ตั้ง performance budget และ lazy-load routes | P3 · STD-19 | หลัง data contract และ routing stable | วัด initial JS/network/CPU ใน desktop/mobile baseline; แยก detail/catalog/query registry เท่าที่ลด initial load โดยไม่กระทบ export/route; ตั้ง budget พร้อมผลเทียบก่อน/หลัง. |

## Monthly monitoring contract ที่ต้องสร้างในระยะพัฒนา

ใช้ object/ตารางใหม่สำหรับ `monthly-monitoring` แยกจาก `Indicator.monthly` ปัจจุบันที่เก็บ **THIP reporting periods** แม้ชื่อจะเป็น monthly ก็ตาม. คงรายงาน THIP เดิมและ gate 1,552 cells ไว้.

ตัวอย่าง contract ระดับแนวคิด:

```ts
type MonitoringDataState =
  | 'measured' | 'zero-cohort' | 'missing-source' | 'rule-unapproved' | 'future';
type MonitoringAssessment =
  | 'on-track' | 'watch' | 'action' | 'no-target' | 'not-assessable';
type Accumulation =
  | 'sum-count' | 'weighted-ratio' | 'fixed-denominator'
  | 'snapshot' | 'distinct-cohort-server-aggregate' | 'custom-approved';

type MonthlyMonitoringResult = {
  seriesKind: 'monthly-monitoring';
  code: string;
  fiscalYear: number;
  fiscalMonth: number;
  periodStart: string;
  periodEnd: string;         // exclusive end
  dataThrough: string | null;
  numerator: number | null;
  denominator: number | null;
  value: number | null;
  unit: ApprovedUnit;
  target: number | null;     // hospital target only
  targetSource: string | null;
  targetEffectiveFrom: string | null;
  targetEffectiveTo: string | null;
  direction: ApprovedDirection;
  threshold: ApprovedThreshold | null;
  accumulation: Accumulation | null;
  cumulativeNumerator: number | null;    // only when the rule declares it
  cumulativeDenominator: number | null;
  cumulativeValue: number | null;
  dataState: MonitoringDataState;
  assessment: MonitoringAssessment;
  reason: string | null;
  ruleVersion: string;
  refreshedAt: string;
};
```

`value`, zero cohort, missing source, unapproved formula and future month are different states. A zero denominator never fabricates a ratio. `dataThrough` describes source coverage. Distinct person/episode aggregation happens in the approved database query; patient keys never cross the browser boundary. Unit/criterion metadata supports numeric, time and range targets. A default watch band such as 8%/0.02 is system policy only and must be labeled as such; it is not a THIP rule.

## Matrix/UI acceptance for a later implementation

The dashboard will offer a fiscal-year selector and a horizontally scrollable 232-row × 12-column table (2,784 slots), with KPI code frozen while scrolling. It will filter group and status, search code/name, navigate cells by keyboard, and open details with period, data-through date, numerator/denominator, hospital target, measured and cumulative results, unit, accumulation method, reason, and rule version. Future months remain future; they do not get zero-filled. CSV carries series kind, fiscal period, unit, target provenance/effective interval, rule version, data state, assessment and missing reason; spreadsheet-safe escaping is required. Mobile shows horizontal scrolling with the KPI key pinned.

## Tests that close the plan

1. Fiscal year Oct–Sep boundaries; admission, discharge and event-window crossing months/year.
2. Duplicate joins and one-to-many fan-out; distinct cohort spanning several months; exact full-window vs bisection output.
3. `sum-count`, weighted ratio, fixed denominator, month-end snapshot and server-side distinct cohort; monthly result differs from cumulative where expected.
4. Zero cohort, `NULL`, missing source, pending rule and future month remain distinct; THIP result series and its 1,552-cell completeness cannot change when monitoring rows exist.
5. Target changes within year, no target, target zero, direction high/low, range thresholds and unit conversion.
6. Browser with mocked BMS: desktop/mobile, filters/search, keyboard grid/drill-through, CSV contents/filename/formula-safe escaping, slow/out-of-order FY response, timeout, unavailable session and no-data state.
7. Source audit, clean generated artifact check, dependency advisory status, build and full tests before opening any approved KPI family.

## งานที่ต้องทำกับโรงพยาบาลก่อนเปิดข้อมูลจริง

โรงพยาบาลต้องรับรอง schema/version, primary and foreign-key behavior หรือ join cardinality evidence, local code sets, episode/date rules, catchment denominators, employee inventory snapshots, source owners, hospital target crosswalk และ aggregate comparison against official reports. เปิดใช้งานทีละ KPI family หลัง evidence ถูกแนบและมี owner sign-off; monitoring rules กับ official THIP rules มี version/effective dates แยกกัน. งานรอบนี้ไม่ติดต่อฐานหรือออกผลรับรองแทนโรงพยาบาล.
