# Shared SPA release — 2 ตุลาคม 2569

[Shared owner contract](THIP-SHARED-DATA.md) โหลดครั้งเดียวใช้ร่วม matrix/overview/charts/detail/catalogue/validation. Default THIP review; monthly monitoring แยก series และ 101 explicit review bridges. Certified reporting charts/export เดิมคงอยู่หลัง publication gates.

| งาน | Dependency | Acceptance |
|---|---|---|
| Root owner + cache/queue | Step/cache/performance release เดิม | เปลี่ยนหน้าระหว่าง request ได้; DH0101 ไม่ query ซ้ำ; FY/session abort และล้างทันที |
| Strict source adapters + selectors | Root owner | Source view ราย code; ไม่มี silent fallback; 1,552 cadence cells/2,784 monitoring cells; unapproved ไม่เข้าผลรับรอง |
| Shared UI + review export | Selectors | Global controls; 232 rows DOM; BE dates; URL/history; semantic keyboard/mobile; CSV label/lineage และ NULL reasons |
| Verification/performance | ทั้งหมดด้านบน | Unit/browser/generated/source/release checks และ production performance gates |
| Hospital sign-off/activation | Release + owner evidence | Cohort/cardinality/event date/denominator/local codes/target/version และ aggregate reconciliation; real source latency แยกจาก browser benchmark |

รอบนี้ใช้ fixtures/mock เท่านั้น ไม่เรียกฐานจริง ไม่เปิด Issues หรือ deploy โดยตรง. Native/external clinical readiness ยังไม่เปลี่ยน. รายงาน benchmark อยู่ [THIP-SHARED-PERFORMANCE-2026-10-02.md](THIP-SHARED-PERFORMANCE-2026-10-02.md).

---

# THIP KPI BMS — Roadmap หลัง project audit

**ปรับปรุง:** 1 ตุลาคม 2569 · **Audit evidence:** 30 กันยายน 2569
**หลักฐานราย code:** [THIP KPI development matrix (อ่านง่าย)](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.md) และ [JSON](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json)
**ข้อค้นพบ/รายละเอียด:** [Project audit](PROJECT-AUDIT-2026-09-30.md) · [remediation และ acceptance criteria](PROJECT-AUDIT-REMEDIATION-2026-09-30.md)

**แผนถัดไปจากโปรเจ็คที่ดึง BMS ได้:** [Direct HOSxP aggregate และหน้าตรวจสอบก่อนรับรอง](THIP-BMS-DIRECT-DATA-DEVELOPMENT-PLAN.md) (1 ตุลาคม 2569; ยังไม่ได้ implement). ผู้ใช้ยืนยันหน้าตรวจสอบ aggregate จริงแยกจากผลเผยแพร่. สำหรับ native queries ให้ตรวจผ่าน registered direct SELECT ได้ก่อนโดยไม่ต้อง provision reporting layer; source view เป็นทางเลือก. Dependency/acceptance ของทางเลือกนี้ใช้แผนที่ลิงก์ ส่วนกติกา publication approval และ cadence เดิมยังคงอยู่.

**ผล export ที่ใช้ปรับแผน:** [ตรวจ Excel FY2569](THIP-EXPORTED-AGGREGATE-REVIEW-2026-10-01.md): 177 codes / 1,353 cadence cells, 55 external codes ขาด, integer arithmetic discrepancies และ 0/0 provenance ต้องแก้ก่อนเปิดผลทางการ; มีผลส่งออกไม่ใช่ approval.

**Implemented เพิ่มเติม:** [Step loader](THIP-STEP-LOADING.md) โหลด native candidates ทีละหนึ่งรหัส เว้น 1 วินาที พร้อม progressive results/pause/resume/cancel/retry และหน้าสอบทานแยก. Source query manifest มี numeric arithmetic guard; source presence แยก 0/0 จาก missing facts. ยังไม่รวม direct monthly provider สำหรับ 71 additional rules หรือการรับรอง/เปิดข้อมูลจริงของแผนระยะถัดไป.

**Implemented cache:** [Candidate cache](THIP-CANDIDATE-CACHE.md) เก็บ validated aggregates ใน IndexedDB 24 ชั่วโมง แยก verified context/FY/query/rule, restore หลังตรวจ session, โหลดต่อเฉพาะช่องที่ขาด และมี force reload/clear-all. Memory fallback ไม่หยุดคิว; cached candidates ยังไม่รับรองและไม่มี publication coverage เพิ่ม.

## เป้าหมาย

พัฒนา dashboard ให้ติดตามผลงานรายเดือน **232 KPI × 12 เดือน** ควบคู่กับผลรายงาน THIP ตามรอบเดิม โดยแยก series และ rule version:

1. `thip-report`: ยังคงนิยามรายเดือน/ไตรมาส/ครึ่งปี/ปี และ completeness 1,552 cells ต่อปีงบประมาณ.
2. `monthly-monitoring`: นิยามติดตามเดือน ต.ค.–ก.ย. ใหม่แยก code เมื่อ grain, cohort, target, unit และวิธีสะสมได้รับการอนุมัติ.

ห้ามคัดลอกผลไตรมาสหรือผลปีลงเป็นผลของทุกเดือน. ผลสะสม YTD แสดงแยกจากค่ารายเดือน และคำนวณเฉพาะเมื่อ rule ระบุ. ระบบอ่าน HOSxP แบบ read-only ผ่าน registered query/source view; ส่งเฉพาะ aggregate; ห้ามเก็บ session credential, PHI หรือ raw patient rows ใน repository/log/browser/export.

## สถานะฐานที่ตรวจแล้ว

| รายการ | สถานะ | ขอบเขตความหมาย |
|---|---:|---|
| THIP KPI catalog / registered SQL branch | 232 / 232 | มี SQL candidate ไม่ได้หมายถึงสูตรตรงนิยามหรือ production approved |
| Rule manifest | foundation 16; needs-local-mapping 216; ready 0 | ไม่มี code ที่ได้ owner/evidence/version sign-off ครบเพื่อเปิดข้อมูลจริง |
| THIP cadence | 112 monthly / 19 quarterly / 31 semiannual / 70 annual | สร้าง 1,552 reporting cells; คง contract นี้ |
| HOSxP inventory | 6,109 tables / 56,891 columns / 5,862 tables with PK / 0 declared FK columns | ไม่มีข้อมูลจริง; column match ไม่ยืนยัน join cardinality |
| SQL parser/schema-name audit | 232 branches ผ่าน; 696 files parse ผ่าน; qualified-column gaps 0 | syntax/name check เท่านั้น; ไม่ใช่ clinical validation หรือ run บน HOSxP |
| Automated baseline | 1,212 tests ผ่าน / build ผ่าน | เกณฑ์โค้ด; ไม่รับรอง KPI ณ โรงพยาบาล |
| Monthly-monitoring readiness | 0/232 measurable/approved; ออกแบบ 2,784 ช่อง | ประเมินราย code ใน matrix พร้อมเหตุผลและ design path |
| Pending working-tree files | query bundles และ source modules มี local edits ก่อน audit | เก็บไว้ ไม่ reset; generator/canonical source ต้องตรวจให้เสร็จก่อน overwrite |

ตรวจ PDF 317 หน้าและ HOSxP JSON โดยใช้ hash/source reference ใน matrix. ไม่ได้เปิด BMS/HOSxP จริง, เขียน GitHub issues หรือ deploy.

## Release gates และ priority

### P1 — ห้าม publish KPI/ข้อมูลจริงจนกว่าจะผ่าน

- แก้ Nginx access-log credential/Referer leak และยืนยัน role อ่านอย่างเดียวจาก BMS/DB server.
- แยก registered SQL ออกจาก publish approval; เริ่มที่ 0 ready และเปิดทีละ code เมื่อหลักฐานครบ.
- แก้ external facts ที่ query ทิ้ง, bisection ที่เสียข้อมูล และ state ปีงบ/CSV ที่แสดงข้อมูลเก่าเป็นปีใหม่.
- ระงับการใช้ monthly/yearly query packs และ target crosswalk ที่ยังเดา field/year/cohort.
- เพิ่มการเทียบ numerator/denominator/value กับรายงานที่ผู้รับผิดชอบโรงพยาบาลรับรอง.

### P2 — ต้องผ่านก่อนยอมรับ matrix เป็นเครื่องมือคุณภาพ

- แยก measured, zero cohort, missing source, unapproved rule และ future; completeness ไม่นับ target เป็นข้อมูลวัด.
- กำหนดหน่วย, target source/effective interval, direction, range, accumulation และ SPC measurement model.
- แก้ route refresh, request cancellation/timeout/body, hidden-sidebar focus, CSV spreadsheet escaping, generated artifact checks และ Node/dependency/build alignment.
- เติม report visual/browser tests และ contract invariants.

### P3 — หลัง correctness gate

วัดและลด initial bundle (~1.75 MB JS raw) ด้วย route-level lazy loading; ตั้ง budget จากการทดสอบอุปกรณ์/network ที่ตกลงกัน. ยังไม่มีผล latency จากผู้ใช้จริง.

## แผนงานตามลำดับ dependency

| Phase | Dependency | งาน / deliverable | Acceptance criteria |
|---|---|---|---|
| 0. ปิด release blockers | เริ่มได้; ห้ามอาศัยข้อมูลคนไข้จริงในการทดสอบ | R0.1–R0.8 ใน [remediation](PROJECT-AUDIT-REMEDIATION-2026-09-30.md): log redaction, server read-only gate, publication manifest, external-source behavior, time bisection, quarantine monthly packs, target crosswalk และ FY consistency | Synthetic canary ไม่อยู่ใน logs; DB ปฏิเสธ write/side effects; external 95/100 คงค่า; full-vs-split window ตรงกัน; no guessed target; CSV ไม่ผูก snapshot ผิด FY. ทุกข้อ P1 มีหลักฐาน run เก็บโดยไม่มี secret/PHI. |
| 1. รับรอง evidence และนิยามรหัส | Phase 0; domain owner และ HOSxP/BMS representative | ใช้ mapping 232 รายการตรวจ parser fields กับ PDF ด้วยคน; ยืนยัน printed page, numerator/denominator, inclusion/exclusion, event grain/date, local code-set version, table key/cardinality, owner และ benchmark/target scope | ไม่มี code ตกหล่น; corrections ลง matrix พร้อม source; unresolved FK/one-to-many มี evidence; owner sign-off ต่อ rule/effective date; คง 0 ready จนเอกสารครบ. |
| 2. แก้ data accuracy และ release gate | Phase 1 สำหรับแต่ละ family; R0.3–R0.7 | แยก SQL presence / schema mapping / THIP definition / local confirmation / publication approval; แก้ numerator-denominator grain, join fan-out, period semantics, source refresh, external 55 codes, AA0101–5 catchment denominator และ target crosswalk | ฐานสังเคราะห์ adversarial ผ่าน; query full period เท่ากับ partitioned; exact monthly/THIP official benchmark reconciliation พร้อมลายเซ็นเจ้าของ; system block ถ้า evidence ยังขาด. |
| 3. Monthly-monitoring contract | Phase 1 metadata; R0.9–R0.12 | สร้าง model/query key แยก `monthly-monitoring`; field ช่วงเริ่ม/สิ้นสุด, data-through, numerator, denominator, value, unit, target provenance/effective dates, criterion, data status, accumulation, cumulative fields, reason, rule version, refresh time | แยก data status จาก performance assessment; `Indicator.monthly` และ THIP 1,552 cells ไม่เปลี่ยน; exact approved rule per code; NULL/zero/future/unapproved แยก; unique person/episode aggregate ทำใน DB; target unverified= NULL. |
| 4. Monitoring query/source view | Phase 3; registered read-only layer และ schema provisioning | สร้าง adapter/DDL/view/query สำหรับ monthly facts; ตั้งแต่ครอบคลุม 232 codes ทุก cell มีสถานะ ถึงแม้ value ยังไม่มี; YTD ทำ server-side ตาม accumulation | ทุก row unique code×FY×month×series/version; coverage/freshness/latency telemetry ไม่มี row/raw identifier; fiscal boundary and effective dates ตรง; source view deterministically generated; schema `reporting` preflight/provision ชัด. |
| 5. Matrix UI และ export | Phase 3 contract, Phase 4 mocked source | ปีงบประมาณ selector, group/status filters, code/name search, 232 rows×12 columns ต.ค.–ก.ย., sticky KPI key, horizontal scroll, keyboard navigation, detail drill-through, separate series toggle, CSV. สถานะผ่านเป้า/เฝ้าระวัง/ต้องดำเนินการ/ไม่มีเป้าหมาย; watch policy ระบุว่าเป็นเกณฑ์ระบบ | Desktop/mobile browser tests ผ่าน; FY request เก่าห้ามแสดง/ส่งออกผิดปี; cell เปิด numerator/denominator/target/YTD/method/data window/rule; months future ไม่ autofill zero; export มี series/time/unit/target/rule/reason และ CSV injection safe. |
| 6. ตรวจรับโรงพยาบาล | Phases 1–5; signed aggregates และ data owner | เทียบผล summary กับรายงานทางการย้อนหลังแบบ anonymized/aggregate; ตรวจ freshness, missingness, latency, target version และ per-family rule approvals | เจ้าของ data/clinical/quality sign off; threshold/error tolerance ถูกกำหนดก่อนเทียบ; no unapproved family in live mode; reconciliation ปิดประเด็นได้และมี audit trail/version. |
| 7. เปิดใช้ตาม family และติดตาม | Phase 6 ต่อ family | เปิดเฉพาะ approved codes; คง THIP reporting และ monitoring เป็นคนละ series; ปิด family หาก freshness/coverage/query latency เกิน threshold | Alerts อ้าง code/rule version และ reason โดยไม่มี PHI/token; verify rollback ปิด family กลับ unavailable; dashboard แสดง source period/freshness/coverage ตรงตาม query. |
| 8. Polish / operational hardening | Phase 5 stable; วัด baseline | dependency upgrade, generated artifacts drift gate, route loading and performance budget | CI run ทุก audit/build/test/visual/browser check; update เอกสารตรง implementation; baseline/perf budgets วัดซ้ำได้. |

Owners ระบุเป็นบทบาท (KPI owner, quality/clinical reviewer, HOSxP data owner, BMS/platform owner, frontend/QA) จนโรงพยาบาลกำหนดผู้รับผิดชอบจริง. ไม่ใส่วันเสร็จแบบเดา; dependency คือข้อมูลและการอนุมัติของผู้ดูแล.

## กติกาผล monthly monitoring

### Period และ cohort

- Fiscal year ต.ค.–ก.ย.; `periodStart` คือวันแรกของเดือนและ `periodEnd` เป็น exclusive end. เดือนอนาคตเป็น `future`.
- ระบุ event date ที่ใช้ (admit, discharge, visit, transaction, snapshot หรือ service time) แยกราย rule. Admit/discharge ข้ามเดือนต้องลงงวดตามนิยามที่อนุมัติ; observation window ต้องอ่านข้อมูลครบถึง `dataThrough`.
- One-to-many joins ต้องลดเหลือ episode/cohort ที่ถูกต้องก่อน aggregate. การนับ distinct คน/episode สะสมต้องคำนวณในฐานข้อมูลและห้ามส่ง identifiers มาหน้าเว็บ.
- Monthly facts ของ KPI ราย quarter/semiannual/annual เป็น measure ที่ออกแบบใหม่พร้อม version/approval; ห้ามนำค่ารอบ THIP เดิมไปหารหรือทำซ้ำเป็น monthly.

### Accumulation และสูตร

ต้องเลือกอย่างชัดเจนต่อ code และ series:

| Strategy | กฎ |
|---|---|
| sum/count | รวม count ได้เมื่อ events disjoint และ denominator เป็น additive ตาม cohort ที่อนุมัติ |
| weighted ratio | คำนวณจาก `Σ numerator / Σ denominator` × multiplier; ห้ามเฉลี่ยค่าเปอร์เซ็นต์รายเดือน |
| fixed denominator | เก็บ denominator/effective period และห้าม sum ซ้ำทุกเดือน |
| snapshot | อ่านยอด ณ cutoff ที่อนุมัติ เช่น employee/headcount หรือ inventory month-end |
| distinct cohort | distinct episode/person ฝั่ง SQL; dashboard รับเฉพาะ aggregate |
| custom | แนบ derivation, date logic, zero/NULL behavior, target semantics และ owner approval |

SH0101 official annual turnover ยังคงสูตรตาม PDF โดยใช้ค่าเฉลี่ย headcount ต้น/ปลายปี. สูตรติดตามรายเดือนต้องกำหนดแยกและตรวจรับต่างหาก; ห้ามแบ่ง annual result ด้วย 12 โดยปริยาย. หากไม่มี denominator/source snapshot ที่เชื่อถือได้ให้ status `missing-source` หรือ `rule-unapproved`.

### เป้าหมาย หน่วย และสถานะ

- เก็บ target โรงพยาบาล, dictionary benchmark, source, unit และ effective interval แยก fields; `kpi_moph` ที่ crosswalk ไม่ยืนยันต้องคืน NULL. Benchmark ระดับ dictionary ไม่ได้แปลว่าเป็น hospital target.
- Unit รองรับ percent, rate, ratio, count และหน่วยเวลา/stock/per-person ที่ได้รับอนุมัติ. เกณฑ์แบบ range มี lower/upper/inclusivity/direction ชัด.
- สถานะข้อมูล: `measured`, `zero-cohort`, `missing-source`, `rule-unapproved`, `future`. สถานะประเมิน: `on-track`, `watch`, `action`, `no-target`, `not-assessable`.
- `watch` default เป็น system policy และต้องแสดง label เช่น 8%/minimum 0.02; ไม่เรียกว่าเกณฑ์ THIP.
- Missing ไม่กลายเป็นศูนย์; zero cohort เป็นข้อมูลที่ query รันสำเร็จแต่ไม่มี cohortและ value อาจคำนวณไม่ได้; zero denominator มี data state แยกจาก missing source.

## UI, export, security และ operability

ตารางหลักมี 232 rows × 12 fiscal months. Filter/search คงค่าที่แชร์ URL ได้; cell เปิด accessible details/drawer และ keyboard focus ไปช่องถัดไป. Mobile ใช้ horizontal scroll และตรึงคอลัมน์ code/name. สีไม่ใช่สัญญาณเดียว; label/icon ชัด. การเปลี่ยน FY ยกเลิก query เก่าหรือ mark snapshot period; ห้าม export mixed-year.

CSV แยกไฟล์หรือมี `series_kind` ชัดเจน; เพิ่ม period start/end, data-through, value, numerator/denominator, unit, target, target source/effective dates, assessment/data state, method, cumulative result, reason และ rule version. ป้องกัน spreadsheet formula injection โดยรักษาตัวเลขที่ typed ไว้. ห้าม export raw rows หรือ client session metadata.

Read-only DB role, server-side registered query, aggregate limit, timeout ครอบ body, credential-free log, least-privilege container, sanitized error/telemetry, CSP/referrer checks และ deterministic source view เป็น release controls. Client-side SQL regex ไม่ใช่ security boundary.

## Test matrix ก่อนเปิด KPI family

| ด้าน | ตัวอย่าง acceptance |
|---|---|
| FY/date | FY 2026 = ต.ค. 2025–ก.ย. 2026; event windows ข้ามเดือน/ปี; timezone/midnight boundary |
| Join/cohort | 1:M detail fan-out; duplicates; person/episode ข้ามเดือน; numerator/denominator distinct rule |
| Query slicing | Full period เท่ากับ bisection สำหรับ numerator/denominator/value; partial quarter ห้ามกลายเป็น 0 หรือหาย |
| Missing/zero | zero cohort, zero denominator, SQL NULL, external source missing, unapproved rule, future month |
| Accumulation | sum/count vs weighted ratio; fixed denominator; snapshots; distinct server aggregate; monthly กับ YTD ที่ต่างกัน |
| Target | target เปลี่ยนในปี, NULL, 0, high/low-is-better, target interval, range, system watch policy |
| Series isolation | เติม/แก้ monthly-monitoring ต้องไม่เปลี่ยน THIP `Indicator.monthly`, target/formula หรือ 1,552 completeness |
| Browser/export | 232×12, filters, search, keyboard, drill-through, no-data/session failure/loading, old responses, CSV metadata/escaping, desktop/mobile |
| Ops | read-only privilege, source freshness/coverage/query latency, audit trail/version, clean generated output, dependencies, CI/build/test |

## Workflow อนุมัติ KPI ทีละตัว

1. ตรวจนิยาม/เลขหน้าและ rule source; บันทึก PDF page และเวอร์ชัน.
2. เจ้าของ HOSxP ยืนยัน local table/column/code-set, join cardinality, event/period date และ snapshot grain.
3. ระบุ numerator/denominator, inclusion/exclusion, unit, target provenance, missing/zero/suppression และ formula.
4. ออก version/effective dates แยก THIP report กับ monitoring series; บันทึก accumulation rule.
5. รันทดสอบ synthetic adversarial แล้วเทียบผล aggregate ย้อนหลังกับรายงานโรงพยาบาล; เจ้าของงาน sign off.
6. เปลี่ยน family approval manifest แล้ว deploy; monitor coverage/freshness/latency; rollback โดยเปลี่ยนกลับ unavailable หากผิด.

สถานะ `SQL registered`, `schema names match`, `definition mapped`, `aggregate reconciled` และ `approved for publication` ต้องมี field แยกกัน; ห้ามอนุมานขั้นท้ายจากขั้นต้น.

## งาน audit ที่ค้างกับ runtime

ส่วนนี้เป็นสถานะเมื่อ audit วันที่ 2026-09-30; การแก้รุ่นแรกและหลักฐานวันที่ 2026-10-01 บันทึกด้านล่าง. การเปิด family จริงยังต้องทำโดย hospital owner พร้อม evidence และการอนุมัติแยก.

## รุ่นแรกที่พัฒนาแล้ว — 2026-10-01

ส่งมอบ matrix 232×12 พร้อม development preview, search/filter/URL history, accessible drill-through และ CSV โดยรักษา official THIP 232 codes / 1,552 cells. ข้อมูลจริงทุก rule ยัง `unapproved`; deployment และการเชื่อมต่อโรงพยาบาลอยู่นอกงานรอบนี้. ดู [release evidence](THIP-MONITORING-RELEASE-2026-10-01.md), [monitoring contract](THIP-MONITORING-CONTRACT.md), [UI handoff](THIP-MONITORING-UI.md) และ [machine rule registry](../reporting/thip_monitoring_rules.json).

| ระยะ | Dependency | ผลที่พัฒนาและ acceptance |
|---|---|---|
| A correctness/security | Audit/remediation เดิม | Logs ไม่เก็บ query/Referer; external facts ไม่ถูกทิ้ง; publication/target approval แยกจาก registered SQL; available coverage 0 เมื่อไม่มี facts; reasons ครบ; FY ล้าง snapshot และ cancel; response-body deadline; CSV formula text escape. Unit/mock browser และ local Nginx credential canary ผ่าน |
| B period/aggregation | A | Full observation window + partition by code เท่านั้น; single-code timeout unavailable; duplicate merged cells rejected; quarterly targets ไม่ carry เป้าเปลี่ยน/annual; SPC centerline ไม่เตือน run. Unit และ synthetic PG full/partial-window counterexample ผ่าน |
| C monitoring contract | A–B | Types/rules/validator/provider/query แยกจาก THIP; ISO/Bangkok; 8 units; state/assessment/version/targets/YTD; registry 232 รหัส พร้อมเหตุผลตามเส้นทาง 101/71/55/5; generated DDL/rules/evidence drift check และ 1,552-cell compatibility ผ่าน |
| D development preview | C | Provider interface เดียวกัน; fixtures ตัวแทน 7 รหัส, remaining rows unapproved; synthetic label หน้า/CSV; production rejects flag และ bundle ไม่รวม fixture rows |
| E matrix/drill-through | C–D | 232×12 semantic table, year/search/group/data/assessment URL state; any-month row filters; sticky identity/mobile scroll; arrows/Enter/dialog Escape/focusrestore; FY/export stale guards. Desktop/mobile/tablet mocked browser ผ่าน |
| F export/release checks | A–E | Export 12 เดือนทุก filtered row รวม NULL/reasons/series/units/target/version; filename year/preview; tests/build/source audit/fixtures/generated check/visual smoke และ mock browser ผ่าน; เอกสารตรง implementation |

## ระยะถัดไป: certification และเปิดทีละ family

| งาน | Dependency | Acceptance ก่อนเปิดข้อมูลจริง |
|---|---|---|
| รับรอง cohort/joins/event dates | A–C และ evidence matrix | เจ้าของโรงพยาบาลยืนยัน grain, cardinality, local codes, inclusion/exclusion, admit/discharge/observation window; fixtures adversarial และ aggregate ย้อนหลังตรงรายงานทางการ |
| สูตรเพิ่มเติม 71 รหัส | นิยามและ owner ของแต่ละ code | Monthly formula/denominator/accumulation/unit/version/effectivity แยกจาก official THIP; SH0101 ไม่ใช้ annual/12; signed evidence พร้อม |
| External 55 + population 5 | Source owner/ทะเบียนภายนอก | Aggregate-only source มี completeness/freshness/date/source provenance; ไม่มี patient identifiers; missing stays NULL |
| Hospital targets | Formula/units ที่รับรอง | Confirm mapping/source/effective interval; แยก dictionary benchmark; เป้าเปลี่ยนระหว่างเดือน/0/range/units ผ่าน checks |
| Reporting provisioning | DBA approval + contract C | ตรวจ offline DDL/refresh, SELECT-only role และ server-side query registration; frontend ไม่รัน mutation; source JSON types ตรง strict contract |
| Publication rollout/withdrawal | งานรับรองและ target ข้างต้น | เพิ่ม approval evidence/version/date ทีละ family; compare official aggregates; coverage/freshness/latency monitoring; ถอน approval แล้วผลกลับ unavailable ได้ |
| Performance/dependency backlog | หลัง correctness + baseline evidence | ประเมิน bundle warning และ test-tool advisory ที่ audit เดิมระบุ; ปรับโดยไม่ลด registered boundary หรือเปลี่ยนสูตร; dependency review/build/browser ผ่าน |

ไม่มีการเปิด GitHub Issues, deploy หรือรัน source/DDL กับ HOSxP จริงในรุ่นนี้. งานค้างเดิมและ SQL family edits ที่ผู้ใช้มีอยู่ถูกเก็บไว้.
## ยอดฐานและ cohort evidence — 2026-10-01

ส่วนสอบทานเพิ่มยอดฐานหกชุดและหลักฐานตัวตั้ง/ตัวหารครบ 232 รหัสตาม [cohort contract](THIP-COHORT-PROFILES.md). งาน cache ที่ค้างเดิมถูกเก็บไว้; profile ใช้ namespace แยก. ไม่เปลี่ยน THIP 1,552 หรือ monitoring 2,784 ช่อง และทุก cohort evidence ยังรอรับรอง.

| งาน | Dependency | Acceptance / สถานะ |
|---|---|---|
| ยอดฐานและ linkage quality | Session + schema JSON + Step/cache | Six aggregate SELECTs; registry snapshot/current-time, monthly VN/HN/AN dates, person conflict/fan-out, emp incomplete dates/CID; no identifiers in outer output/cache; manual load; synthetic SQL/browser checks |
| Queue/cache isolation | Shared lane + validated aggregate repository | One request/1000ms gap across KPI/profile; auth/429/global failure hold; context/month abort + NULL snapshot; namespaces/FY/month/query/rule isolation; clear-all covers both |
| Cohort mapping 232 | Dictionary + registered SQL + audit matrix | Definition/a/b/unit/population/grain/key/date/source/window/limits/status for every code; missing structured evidence explicit; generated drift gate; never fills hospital approval |
| Evidence-based fixes | Representative fixture execution | CE0102/3 sampled days 5/15/25; invalid employee date ordering excluded from employee-month; SH0101 numeric annual average retained; generated reporting/step fingerprints updated |
| Hospital certification (pending) | Mapping + aggregate comparison with owners | Confirm patient/ER cardinality, local codes, event dates, full observation windows, HR completeness and external population; compare official aggregates; sign rule/version/approval separately before publishing |

## ประสิทธิภาพ — 2026-10-02

พัฒนาการแยก module, ตารางที่รักษา 232 แถว, cache v2, SQL dependency closure, precompressed gzip และ local fonts แล้ว. ดู [benchmark และหลักฐานตรวจรับ](THIP-PERFORMANCE-2026-10-02.md). THIP 1,552 และ monitoring 2,784 cells พร้อม publication gates เดิมยังคงอยู่

| ระยะ | Dependency | Implementation / acceptance |
|---|---|---|
| A วัดผล | Baseline + production build | Production gzip benchmark 5 รอบ/device; cold monitoring 232×12, interactions และ warm cache 177; numeric diagnostics แยก queue wait/request และไม่บันทึกข้อมูลหรือ capability |
| B Startup graph | A | Lightweight transport/probe; lazy routes/charts/reporting/validation; compact readiness manifest และ detail evidence แยก 29 family; initial JS ≤200 KB gzip; generated runtime/rule equivalence |
| C Rendering | B | Stable memoized rows/cells, hidden filters, cached periods/search/formatters; deferred search + pending export guard; arrows/dialog/FY/session checks; LCP/CLS/interaction budgets ใน CI |
| D Queue/cache | B–C | Build-time SQL/rule hashes, query planning เมื่อถึง code, one-transaction readMany + context/expiry indices, readonly shared progress; v1 invalidation, 24h/Bangkok expiry, memory fallback และ stale-response/write cancellation |
| E SQL/static delivery | A–D | CTE manifest ครบ 177; exact aggregate comparison + 5 EXPLAIN runs ของหกรหัสตัวแทนใน PG16 จำลอง; gzip_static/immutable assets/no-store HTML/local fonts; explicit chunk retry โดยไม่มี reload loop |
| F Hospital acceptance (pending) | A–E + เจ้าของระบบ | ทดสอบเครื่องโรงพยาบาล/มือถือจริง, latency/EXPLAIN กับ aggregate staging ที่อนุมัติ, ประเมิน indices ที่มีและ cardinality ก่อนเสนอ DBA; รับรอง family/rule แยกจาก performance |

CI เพิ่ม performance gates และ artifacts, source audit, runtime drift, SQL equivalence และ mocked browser cache/Step/profile regressions. รอบนี้ไม่มี live BMS/HOSxP calls, Issues, deployment หรือ commit/push
