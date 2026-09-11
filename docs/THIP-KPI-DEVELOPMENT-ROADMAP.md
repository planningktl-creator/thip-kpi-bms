# THIP KPI BMS — แผนพัฒนาต่อสู่ระบบข้อมูลจริง

สถานะเอกสาร: Development roadmap  
วันที่จัดทำ: 11 กันยายน 2026

เอกสารนี้เป็นแผนทำงานต่อจากฐานโค้ดปัจจุบัน เพื่อพาระบบ THIP KPI BMS จากหน้าตลาด/แดชบอร์ดที่มี data contract และ query foundation แล้ว ไปสู่ระบบที่อ่านข้อมูลจริงจาก HOSxP ผ่าน BMS ได้ครบ 232 ตัวชี้วัด โดยรักษาหลักการสำคัญคือ HOSxP เป็น read-only, SQL ต้องผ่าน registered query layer และห้ามส่งออก credentials, token, PHI หรือ raw patient rows

## 1. เป้าหมายปลายทาง

ระบบ release production ต้องสามารถทำงานตามลำดับนี้ได้:

    HOSxP (read-only)
      -> registered SQL / reporting view ใน BMS
      -> normalized KPI rows
      -> source-view validation
      -> THIP KPI BMS dashboard / catalogue / detail / trend

### Definition of success

ถือว่าพร้อมเปิดใช้งานข้อมูลจริงเมื่อครบทุกข้อ:

1. มีข้อมูลจาก source view ครบ 232 รหัส และครบตามรอบรายงาน 1,552 cells ต่อปีงบประมาณ
   - รายเดือน 112 ตัว × 12 เดือน
   - รายไตรมาส 19 ตัว × 4 ไตรมาส
   - ราย 6 เดือน 31 ตัว × 2 รอบ
   - รายปี 70 ตัว × 1 รอบ
2. ทุก KPI มี approved rule พร้อมหลักฐานอ้างอิงจากนิยาม THIP, code set ของโรงพยาบาล และการ sign-off ของเจ้าของงาน
3. ไม่มี unknown code, duplicate row, period ผิด cadence, metadata ไม่ตรง, ค่าที่คำนวณซ้ำแล้วไม่ตรงกับ numerator/denominator หรือ percentile นอกช่วง 0–100
4. ค่า value, numerator, denominator, target, percentile และ status ของแต่ละแถวมีความหมายเดียวกันทั้ง BMS, audit script และ frontend
5. ระบบไม่ใช้ demo/mock fallback และเมื่อ BMS หรือ session ใช้งานไม่ได้ต้อง fail closed พร้อมข้อความที่เจ้าหน้าที่เข้าใจได้
6. ผ่าน automated tests, build, visual smoke, source audit และ BMS connectivity smoke โดยใช้ session จริงที่หมดอายุ/ต่อใหม่ได้
7. ไม่มี credentials, access token, raw patient row หรือข้อมูลระบุตัวบุคคลใน repository, browser payload, log และ artifact ที่ส่งมอบ

## 2. สถานะฐานปัจจุบัน

| ส่วนงาน | สถานะปัจจุบัน | ความหมายต่อแผนถัดไป |
|---|---|---|
| KPI catalogue | 232/232 รหัส | มีรายการกลางสำหรับ navigation, metadata และ rule mapping แล้ว |
| Reporting cadence | 112 monthly, 19 quarterly, 31 semiannual, 70 annual | ใช้เป็น contract กลางของ source view และ completeness audit |
| Rule manifest | 232/232 รหัส; 16 foundation, 216 needs-local-mapping | โครงสร้างครบ แต่ 216 รหัสยังต้องทำ local definition และ SQL ให้ได้รับอนุมัติ |
| Registered foundation queries | 16/232 รหัส | ใช้เป็นฐานสำหรับทดสอบ end-to-end และเป็น pattern ให้ family อื่น |
| Normalized source-view reader | รองรับ contract ของทั้ง 232 รหัส | พร้อมรับข้อมูลจริง แต่ยังต้อง provision view และเติมข้อมูลจาก BMS |
| Data quality audit | ตรวจ code, cadence, duplicate, metadata, formula, refresh และ percentile | ใช้เป็น quality gate ก่อน deploy ทุก environment |
| Frontend | อ่าน live rows จาก BMS และแสดง no-data แบบชัดเจน | ต้องทดสอบกับ source view จริงและตรวจ UX ของ missing/zero/error ให้ครบ |
| Hospital mapping | ยังต้องยืนยัน schema, code set, business rule และ aggregate กับโรงพยาบาล | เป็น critical path ของ 216 รหัสที่เหลือ |

### สิ่งที่ยังไม่ควรถือว่าเสร็จ

- การมี catalogue หรือ SQL candidate ยังไม่เท่ากับ KPI ที่ได้รับการรับรอง
- ตารางจาก HOSxP Structure.xlsx เป็น schema inventory ไม่ใช่คำสั่งให้สร้าง query โดยอัตโนมัติ
- นิยามใน THIP KPI.pdf เป็น dictionary/เกณฑ์ของตัวชี้วัด แต่หลายตัวต้อง map กับ workflow และ code set ของโรงพยาบาลก่อน
- SQL ที่พบจากเอกสารหรือ Navicat เป็นหลักฐานประกอบการวิเคราะห์เท่านั้น ต้องตรวจ dialect, version, local code และช่วงเวลาจริงก่อนเปิดใช้

## 3. หลักการพัฒนาและการควบคุมขอบเขต

1. **Read-only เป็นค่าเริ่มต้น** — query ต้องเป็น SELECT หรือ reporting view ที่อ่านข้อมูลเท่านั้น ห้าม INSERT, UPDATE, DELETE, DDL หรือเขียนกลับ HOSxP
2. **SQL อยู่หลัง registered query layer** — browser เรียก query key/endpoint ที่ลงทะเบียนไว้เท่านั้น ห้ามรับ SQL อิสระจาก client
3. **Aggregate ก่อนส่งออก** — ส่งเฉพาะ normalized KPI aggregate; ห้ามส่ง patient-level row ถ้าไม่จำเป็นต่อผลลัพธ์
4. **แยก fact ออกจาก benchmark** — target ต้องมาจาก BMS/source row หรือ benchmark registry ที่ได้รับอนุมัติ ไม่ fallback ไปใช้ metadata ใน frontend
5. **บันทึก period semantics** — เก็บปีงบประมาณ, เดือน/ไตรมาส/รอบ 6 เดือน/ปี และ timezone ให้ชัดเจน ไม่ตีความวันที่เองใน UI
6. **ไม่เดาเมื่อหลักฐานไม่พอ** — ถ้ายังไม่ยืนยัน numerator, denominator, inclusion/exclusion หรือ code set ให้คงสถานะ needs-local-mapping และไม่ publish เป็น production-ready
7. **ทุกการแก้ rule ต้องมี version** — เปลี่ยนสูตรหรือ code set ต้องเพิ่ม rule version, effective date, reason และผลกระทบย้อนหลัง

## 4. แผนพัฒนาตามระยะ

ระยะเวลาเป็น engineering estimate ไม่รวมเวลารอข้อมูลและ sign-off จากโรงพยาบาล ระยะต่าง ๆ สามารถทำคู่ขนานได้หลัง dependency ผ่าน แต่ห้ามข้าม release gate

### Phase 0 — Freeze contract และเตรียมหลักฐาน

ระยะโดยประมาณ: 1–2 วัน

| งาน | ผลลัพธ์ที่ต้องส่งมอบ | ผู้รับผิดชอบหลัก | เกณฑ์ผ่าน |
|---|---|---|---|
| ยืนยัน data contract | field, type, nullability, period และ status ที่ใช้จริง | Tech lead + BMS | contract ถูกอ้างอิงตรงกันใน frontend, audit และ BMS |
| Freeze KPI inventory | catalogue และ cadence manifest 232 รหัส | Product/domain owner | ไม่มีรหัสตกหล่นหรือซ้ำ |
| จัด evidence register | PDF page, workbook sheet/cell, local SQL reference, rule version | KPI analyst | ทุก code มี source reference และสถานะ mapping |
| ระบุ owner ต่อ KPI family | รายชื่อผู้ตรวจ clinical/quality/IT | Hospital domain owner | ทุก family มีผู้อนุมัติ ไม่ปล่อย owner ว่าง |
| ยืนยัน environment | HOSxP version, database dialect, BMS URL, auth, timezone, FY boundary | Hospital IT + BMS | มี test environment และวิธีต่อ session ที่ไม่ฝัง secret |

Dependency: ไม่มี

### Phase 1 — สร้าง BMS/source-view pipeline และ staging

ระยะโดยประมาณ: 2–4 วัน

| งาน | ผลลัพธ์ที่ต้องส่งมอบ | เกณฑ์ผ่าน |
|---|---|---|
| Provision normalized view | view หรือ endpoint ตาม contract ที่ VITE_BMS_KPI_SOURCE_VIEW อ้างถึง | query ได้โดยไม่เปิด raw patient row |
| ทำ staging export | JSON/CSV aggregate สำหรับอย่างน้อย 1 FY | thip_source_audit.py ผ่านโดยไม่มี error |
| ทำ refresh metadata | refreshed_at, source system, rule version และ batch/run id | ตรวจย้อนหลังได้ว่าแต่ละข้อมูลมาจากรอบใด |
| ทำ auth/session smoke | login, refresh, expiry, unauthorized, reconnect | ระบบไม่ค้างที่ stale session และไม่ log token |
| ตั้ง observability | query latency, row count, failure reason, audit result | log เป็น aggregate/technical metadata เท่านั้น |

Dependency: Phase 0 — contract, environment และ access

### Phase 2 — รับรอง foundation 16 ตัวแรก

ระยะโดยประมาณ: 3–5 วัน

16 รหัสที่เริ่มก่อน:

DH0101, DH0101.1, DH0101.2, DN0101, DR0101, CE0101, CI0101, DH0102, DG0102, DG0202, DR0403, DR0102, DN0107, DH0112, DN0109, DN0302

งานหลัก:

1. ตรวจ SQL กับ HOSxP version และ schema จริง
2. ตรวจความหมาย episode, admission/discharge, diagnosis position, procedure, death และ denominator
3. เปลี่ยน hardcoded local code/FY/date ให้เป็น registered parameters หรือ mapping table ที่ควบคุมได้
4. ทดสอบ aggregate ด้วยช่วงเวลาอย่างน้อย 3 เดือนที่มีข้อมูล และ 1 ช่วงที่ denominator เป็นศูนย์
5. เปรียบเทียบกับรายงานเดิมของโรงพยาบาลและให้ clinical/quality owner sign-off
6. publish เป็น ready เฉพาะตัวที่มีหลักฐานครบ

เกณฑ์ผ่าน: 16 ตัวผ่าน source audit, query test, domain review และ BMS-to-UI smoke โดยไม่มี frontend benchmark fallback

Dependency: Phase 1

### Phase 3 — IPD และ clinical outcome families

ระยะโดยประมาณ: 1–2 สัปดาห์

ลำดับแนะนำ:

1. ACS/AMI และโรคหลอดเลือดหัวใจ
2. stroke / fast track / thrombolysis
3. pneumonia, sepsis และ infection outcome
4. surgery, anesthesia และ perioperative outcome
5. pressure ulcer, fall, medication-related harm และ patient safety
6. upper GI bleeding, head injury และ readmission

ผลลัพธ์ต่อ family:

- approved inclusion/exclusion และ episode key
- code set/diagnosis/procedure crosswalk ของโรงพยาบาล
- registered query หรือ reporting view
- fixture aggregate ที่ลบข้อมูลระบุตัวบุคคลแล้ว
- rule test, denominator-zero test, cadence test และ owner sign-off

Dependency: Phase 2 และ local clinical mapping

### Phase 4 — OPD, NCD และ chronic care

ระยะโดยประมาณ: 1–2 สัปดาห์

ครอบคลุมอย่างน้อย:

- ambulatory care sensitive conditions
- diabetes และ hypertension
- CKD และ complication
- HIV/TB ตามนิยามและระบบติดตามของโรงพยาบาล
- asthma/COPD
- tobacco และ risk-factor indicators

ประเด็นที่ต้องล็อกก่อนเขียน query:

- นิยาม visit เทียบกับ unique patient/episode
- การรวมข้อมูลจาก OPD, chronic registry, laboratory และ pharmacy
- การนับผู้ป่วยที่มีหลาย visit ในรอบเดียว
- code set version และการรองรับ ICD-10/local code
- การใช้ข้อมูล longitudinal โดยไม่ส่งออก patient-level row

Dependency: Phase 0 mapping และ Phase 1 source view

### Phase 5 — Maternal, child และ specialty services

ระยะโดยประมาณ: 1–2 สัปดาห์

ครอบคลุม family ที่เกี่ยวกับ ANC, labor/delivery, postpartum, newborn, child immunization/growth และ specialty service ตามรายการใน catalogue

ต้องกำหนดเพิ่ม:

- event date ที่ใช้จริง เช่น delivery date, admission date, discharge date หรือ service date
- การเชื่อม mother–newborn โดยใช้ surrogate/aggregate key เท่านั้น
- denominator กรณี referral, transfer, stillbirth และ out-of-area case
- รอบรายงานที่ไม่ใช่รายเดือน และการสรุปปีงบประมาณ

Dependency: local workflow review กับผู้รับผิดชอบหน่วยงาน

### Phase 6 — Operations, safety, administration และ system performance

ระยะโดยประมาณ: 1–2 สัปดาห์

ครอบคลุม family ที่เหลือ เช่น ED, mental health, infection control, medication, blood bank, CSSD, customer experience, HR, finance และ governance

แนวทาง:

- แยก KPI ที่มาจาก clinical fact ออกจาก KPI ที่ต้องรับข้อมูลจากระบบงาน/แบบสำรวจ
- ทำ source ownership ต่อ field ไม่ให้ query พยายามอนุมานข้อมูลที่ไม่มีใน HOSxP
- ระบุ manual/import source ที่ยอมรับได้ผ่าน BMS contract หากไม่มี table ใน HOSxP
- ใช้สถานะ not-applicable, not-available หรือ pending-local-source อย่างมีเหตุผล แทนการใส่ศูนย์ปลอม

Dependency: source owner ของแต่ละหน่วยงาน และการตัดสินใจเรื่อง non-HOSxP source

### Phase 7 — Production acceptance และ deploy

ระยะโดยประมาณ: 2–3 วัน

| Gate | รายการตรวจ |
|---|---|
| Data gate | 232 codes, 1,552 cells, completeness, duplicate, formula, metadata, percentile และ refresh ผ่าน |
| Security gate | ไม่พบ secret/PHI/raw row ใน repo, payload, log และ artifact; SQL เป็น read-only |
| Runtime gate | auth/session expiry/reconnect, timeout, unauthorized, BMS unavailable และ empty/zero state ผ่าน |
| Product gate | catalogue, dashboard, detail, trend, target/benchmark และ cadence แสดงตรงกับ source row |
| Operational gate | มี runbook, owner, alert, rollback, backup/export aggregate และช่องทางรับ incident |
| Sign-off gate | IT, quality/clinical, product และผู้อนุมัติข้อมูลลงนาม release note |

เกณฑ์ deploy: ทุก gate ผ่านและไม่มี P0/P1 ค้างอยู่

## 5. Workflow ต่อ KPI หนึ่งตัว

ใช้ workflow เดียวกันทั้ง 232 ตัวเพื่อไม่ให้แต่ละทีมตีความต่างกัน:

1. เลือกรหัสจาก src/data/thipCatalogue.ts และอ่านนิยาม/สูตรจาก docs/THIP-KPI-HOSXP-QUERY-GUIDE.md
2. บันทึก evidence: หน้าใน PDF, sheet/cell ใน workbook, local report หรือเอกสารโรงพยาบาล
3. สร้างหรือปรับ rule ใน src/data/thipKpiRules.ts โดยระบุ family, cadence, period field, episode key, inclusion, exclusion, code set และ rule version
4. ทำ local mapping: ตาราง/ฟิลด์, diagnosis/procedure/lab/drug code, status code และ source owner
5. เขียน SQL ใน src/services/queryRegistry.ts หรือสร้าง reporting view ใน BMS; ห้ามให้ frontend ส่ง SQL อิสระ
6. ตรวจ one-to-many และ distinct grain ให้ชัดก่อน aggregate เพื่อป้องกัน numerator/denominator พอง
7. สร้าง normalized row ตาม contract พร้อม numerator, denominator, value, target, percentile, period, refreshed_at และ rule_version
8. ทดสอบอย่างน้อย: มีข้อมูล, ไม่มีข้อมูล, denominator = 0, target missing, duplicate, period boundary และ date/timezone boundary
9. เปรียบเทียบ aggregate กับรายงานเดิมของโรงพยาบาลอย่างน้อย 3 ช่วง และบันทึกผลต่างที่อธิบายได้
10. ให้ domain owner sign-off แล้วเปลี่ยนสถานะจาก needs-local-mapping เป็น ready
11. รัน source audit, automated tests, build และ visual smoke
12. เพิ่ม release note หาก rule หรือ code set เปลี่ยนจาก version เดิม

## 6. งานพัฒนาใน repository

### งานที่ควรทำใน codebase

| Priority | งาน | ไฟล์/พื้นที่ | ผลลัพธ์ |
|---|---|---|---|
| P0 | ขยาย rule metadata | src/data/thipKpiRules.ts | ทุก KPI มี episode, period field, inclusion/exclusion, code set, owner, status และ version |
| P0 | ทำ query registry ต่อ family | src/services/queryRegistry.ts | SQL มีชื่อ, parameter, source tables, read-only assertion และ test |
| P0 | คง normalized source contract | src/services/bmsData.ts, src/types/thip.ts | frontend ไม่ต้องรู้ HOSxP schema และไม่ใช้ fallback benchmark |
| P0 | ทำ fixture aggregate | src/services/*.test.ts และ test-fixtures/ ที่ไม่มี PHI | ทดสอบ rule ด้วยข้อมูลจำลองระดับ aggregate |
| P0 | เพิ่ม audit ใน CI | scripts/thip_source_audit.py และ workflow | artifact ที่ไม่ผ่าน contract ถูกปฏิเสธก่อน deploy |
| P1 | ทำ rule evidence registry | docs/ หรือ BMS metadata endpoint | ตรวจย้อนกลับได้ว่าค่าแต่ละ KPI มาจาก rule/evidence ใด |
| P1 | เพิ่ม source freshness/error panel | Dashboard/BMS status | ผู้ใช้เห็น stale, unavailable และ partial data ชัดเจน |
| P1 | เพิ่ม export aggregate | BMS endpoint/UI | export ได้เฉพาะ aggregate ตามสิทธิ์และ audit log |
| P2 | เพิ่ม query performance telemetry | BMS/observability | ติดตาม latency, timeout, row count และ failure rate ต่อ query key |

### โครงสร้าง rule ที่ควรครบก่อน publish

    {
      code: "DH0101",
      family: "ipd-outcome",
      status: "ready",
      cadence: "monthly",
      periodField: "discharge_date",
      episodeGrain: "one-row-per-admission",
      inclusion: ["..."],
      exclusion: ["..."],
      codeSetVersion: "hospital-approved-version",
      ruleVersion: "2026.1",
      owner: "clinical-quality",
      evidence: ["THIP KPI.pdf:p.xx", "HOSxP Structure.xlsx:sheet/cell"],
      queryKey: "thip.ipd.dh0101"
    }

ชื่อ field ข้างต้นเป็นโครงสร้างเป้าหมาย ต้องตรวจให้ตรงกับ type และ contract จริงก่อน implement; ห้ามเติมค่า placeholder แล้วประกาศเป็น ready

## 7. งานที่โรงพยาบาลต้องส่งมอบ

เพื่อให้ทีมพัฒนาทำต่อได้โดยไม่เดา ขอข้อมูลเป็น metadata/aggregate เท่าที่จำเป็น ไม่ต้องส่ง credentials หรือ raw patient data:

1. HOSxP version, database engine/version, schema diff จาก workbook และ timezone
2. รายชื่อ table/view ที่อนุญาตให้อ่าน และชื่อ field ที่เปลี่ยนจาก standard
3. ICD-10, procedure, drug, lab, clinic, ward, department และ local code crosswalk พร้อม version/effective date
4. นิยาม episode และ date boundary ของแต่ละ family
5. target/benchmark ที่อนุมัติแล้ว พร้อม effective period และ direction (higher, lower, neutral)
6. aggregate validation sample ต่อ KPI: period, numerator, denominator, value, target และผู้ยืนยัน
7. รายการ KPI ที่โรงพยาบาลไม่เก็บข้อมูล, ไม่เกี่ยวข้อง หรือมาจากระบบอื่น
8. BMS endpoint/source view schema, authentication flow, refresh schedule, timeout และ support contact
9. ตัวอย่าง error/empty/zero-denominator ที่คาดหวัง

ห้ามส่งเข้ามาใน repository: username/password, token, session cookie, patient name, HN, AN, CID, address, phone, raw visit row หรือไฟล์ export ที่ระบุตัวบุคคลได้

## 8. วิธีตรวจรับแต่ละรอบ

ก่อน merge หรือ deploy ทุก batch ให้รัน:

    pnpm test
    pnpm run build
    python scripts/thip_source_audit.py --input <aggregate-export.json> --fiscal-year 2026
    python scripts/visual_smoke.py

สำหรับ production image ให้ส่ง source view เป็น build argument และตั้งค่า runtime ให้ตรงกับ BMS จริง:

    docker build --build-arg VITE_BMS_KPI_SOURCE_VIEW=thip_kpi_monthly -t thip-kpi-bms .

รายละเอียด contract, endpoint, session และ failure behavior ให้ยึด:

- docs/THIP-DATA-CONTRACT.md
- docs/THIP-SOURCE-NOTES.md
- docs/THIP-KPI-HOSXP-QUERY-GUIDE.md
- README.md

ผลตรวจรับขั้นต่ำของ source export:

- รหัสต้องอยู่ใน catalogue 232 ตัว
- cadence และ period ต้องตรง manifest
- ครบ 1,552 cells ต่อ FY หรือมีสถานะ missing ที่ได้รับอนุมัติและตรวจสอบได้
- ห้าม duplicate key
- value ต้องสอดคล้องกับ numerator/denominator และ multiplier ของ KPI
- percentile ต้องอยู่ระหว่าง 0–100
- metadata เช่น definition, formula, unit, direction, source tables และ status ต้องตรงกับ rule version
- refreshed_at ต้องใหม่ตาม SLA ของรอบรายงาน

## 9. Release gate และ rollback

### P0 — ห้าม deploy

- query เขียนข้อมูลหรือเปิด raw patient row
- มี secret/PHI ใน repository, payload หรือ log
- ใช้ demo/mock data หรือ frontend fallback เป็นข้อมูล production
- numerator/denominator ผิดจนเปลี่ยนความหมาย KPI
- source view มี duplicate, unknown code หรือ cadence ผิดจำนวนมาก
- session/auth ทำให้ข้อมูลของผู้ใช้อื่นรั่วไหล

### P1 — deploy ได้เมื่อแก้และมีหลักฐาน

- KPI family สำคัญยังไม่มี owner sign-off
- target/percentile/refresh metadata ขาด
- query ช้าเกิน SLA หรือ timeout โดยไม่มี graceful error
- visual/detail/trend แสดง period หรือ target ไม่ตรง source row

### P2 — ทำหลังเปิดใช้ได้โดยต้องติด backlog

- ปรับ copy/UX ที่ไม่กระทบความถูกต้อง
- เพิ่ม performance telemetry หรือ export format
- เพิ่มคำอธิบาย/ลิงก์ evidence ใน detail view

Rollback ต้องทำโดยสลับไปยัง source-view/rule version ล่าสุดที่ผ่าน gate แล้ว ไม่ใช้การแก้ข้อมูลใน HOSxP และไม่ลบ audit artifact

## 10. ความเสี่ยงและวิธีลดความเสี่ยง

| ความเสี่ยง | ผลกระทบ | วิธีลดความเสี่ยง |
|---|---|---|
| schema ของโรงพยาบาลต่างจาก workbook | query ใช้ไม่ได้หรือได้ค่าผิด | ทำ schema diff และ mapping sign-off ก่อนเขียน family query |
| local code เปลี่ยนตามเวลา | trend ขาดช่วงหรือค่ากระโดด | version code set และ effective date; เก็บ rule version กับ row |
| one-to-many จาก diagnosis/procedure/visit | numerator/denominator พอง | กำหนด episode grain และ aggregate หลัง deduplicate |
| fiscal year/date boundary ต่างกัน | period ผิดและ audit ไม่ครบ | กำหนด timezone/FY boundary ใน BMS contract และมี boundary test |
| target อยู่คนละแหล่งกับ fact | แสดง benchmark ผิด | target ต้องอยู่ใน source row/approved registry และห้าม fallback จาก frontend |
| KPI ใน PDF แต่ไม่มี source ใน HOSxP | พยายามอนุมานข้อมูลจนผิด | ใช้สถานะ pending-local-source และระบุ owner/source อื่น |
| SQL เดิมมี hardcoded code/FY | ใช้ซ้ำแล้วผิดปีหรือผิดหน่วยงาน | parameterize และเก็บเป็น evidence ไม่เปิด production จนผ่าน review |
| BMS ล่ม/ข้อมูลค้าง | ผู้ใช้เข้าใจว่าไม่มีผู้ป่วย | แยก unavailable, stale, no-data, zero และแสดง freshness |

## 11. แผน 5 วันทำงานถัดไป

รายการนี้เป็นชุดงานที่เริ่มได้ทันทีโดยยังไม่ต้องรอทำครบ 216 ตัว:

| วัน | งาน | ผลลัพธ์ที่ต้องมี |
|---|---|---|
| Day 1 | นัด review contract กับ IT/BMS และ quality owner | ตกลง source-view schema, auth, FY, timezone, refresh และ owner matrix |
| Day 2 | เตรียม staging source view สำหรับ 16 foundation | endpoint/view ที่คืน aggregate row ตาม contract และไม่มี PHI |
| Day 3 | ตรวจ 16 foundation กับ aggregate sample 3 เดือน | discrepancy log, test fixture และรายการที่ต้องแก้ rule |
| Day 4 | ปิด sign-off foundation และทำ BMS runtime smoke | 16 รหัสเป็น ready เท่าที่หลักฐานครบ; session/error path ผ่าน |
| Day 5 | เริ่ม family ถัดไปด้วย 10–20 รหัสที่มี source ชัด | mapping sheet, evidence, query key และ acceptance test ต่อรหัส |

ถ้าต้องเลือกงานเดียวเพื่อเริ่มวันนี้ ให้เริ่มที่ **ขอ source-view contract + aggregate validation sample ของ 16 foundation จาก BMS/โรงพยาบาล** เพราะเป็น dependency ของทั้ง runtime verification และการขยาย rule ไปยัง 216 ตัวที่เหลือ

## 12. Definition of done ต่อ batch

batch หนึ่งจะปิดได้เมื่อ:

- [ ] KPI code และ cadence อยู่ใน manifest
- [ ] rule มี evidence, owner, status และ version
- [ ] local mapping ผ่านการตรวจ schema/code set
- [ ] query/view เป็น read-only และผ่าน registered layer
- [ ] normalized rows ผ่าน audit script
- [ ] มี test สำหรับ data, no-data, zero denominator, duplicate และ period boundary
- [ ] aggregate ตรงกับตัวอย่างที่เจ้าของข้อมูลรับรอง
- [ ] frontend detail/trend/target แสดงตรงกับ source row
- [ ] ไม่มี PHI/secret/raw row ใน artifact
- [ ] มี release note และ rollback version

เอกสารนี้จึงเป็นแผนพัฒนาต่อ ไม่ใช่คำรับรองว่าข้อมูลทั้ง 232 ตัวพร้อมใช้งานแล้ว สถานะ production-ready ต้องเกิดจากหลักฐานและ sign-off ตาม gate ข้างต้นเท่านั้น

