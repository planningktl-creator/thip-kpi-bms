# Shared KPI data owner — 2 ตุลาคม 2569

`KpiDataStore` เป็นเจ้าของ snapshot, repository และคิวหนึ่งชุดต่อ app/tab. Root `App` ตรวจ launcher/manual session กับ PostgreSQL ก่อน `configure(runtime, fiscalYear)`. Route ไม่มีสิทธิ์เริ่มโหลดผลใหม่: matrix, review overview/trend/detail, catalogue และหน้าตรวจสอบอ่าน facts จาก owner เดียวกัน. Approved reporting dashboard/detail เดิมยังอยู่ แต่เป็น presentation-only และรับเฉพาะ projection ผ่าน publication gate.

## Query และ cache

- Native default: 177 registered single-code SELECTs เริ่ม DH0101/DH0112; 55 external รอ source พร้อมเหตุผล. SQL สร้างเมื่อถึงคำขอ เก็บ observation window เต็ม FY ไม่แบ่งวันที่.
- เมื่อกำหนด reporting view ใช้ code-bound SELECT 232 งานแทน native; source failure ไม่ fallback แบบเงียบ. Monitoring view ที่กำหนดเพิ่ม 232 งานของอีก series; หลัง reporting สองรหัสแรก interleave สอง series เพื่อไม่ให้ monitoring รอทั้งคิว THIP.
- หนึ่ง request พร้อมกัน เว้นหนึ่งวินาทีหลังจบ; profiles ใช้ aggregate lane เดียวกัน แต่เริ่มด้วยปุ่มเฉพาะ. Pause/resume/cancel/failed-only retry/session expiry/429/สาม network failures คงกติกาเดิม.
- IndexedDB DB schema 2 เดิม: native envelope v2 ยังใช้ได้เมื่อ fingerprint ตรง. Projection envelope v3 แยก namespace `reporting-source`/`monitoring-source`; ไม่ย้าย raw HTTP response ลง cache. Fingerprint มี registered SQL, code/FY และ rule manifest. Validated contract projections เท่านั้นที่ persist.
- Cache TTL สูงสุด 24h และไม่ข้ามต้นเดือน Bangkok สำหรับปีปัจจุบัน; expiry ไม่เลื่อนจาก cache hit. Timer และ visibility handler ถอนผลที่หมดอายุ; user เริ่มคิวใหม่เพื่อโหลดที่ขาด. Repository prune/bulk read/memory fallback และ write AbortSignal คงเดิม.
- Navigation ไม่ cancel งาน. FY/session/reconnect เปลี่ยน generation, abort request/cache writes และล้าง active snapshot. Old callbacks ไม่ publish. Clear-all หยุดจนกดเริ่มโหลด; force reload ล้าง context/FY ก่อนเริ่มใหม่. Capability อยู่ใน memory; durable scope เก็บ digest เท่านั้น. Session-expiry/Retry-After lock อยู่เหนือ snapshot: clear cache หรือเปลี่ยน FY ไม่ปลด lock; reconnect ที่ตรวจ session ใหม่จึงปลด session lock.

## Selectors และ publication

`KpiCellViewModel` มี source value, comparison arithmetic, status/reason, period, source refresh/data-through, read time, cache origin/expiry, unit, target, cumulative, rule version และ lineage. Unchanged step/row/cell references ถูกใช้ซ้ำ; nested source aggregates freeze ก่อนส่งให้ consumers.

Reporting definitions มี canonical cohort formula, observation window และ hash ของ rule เต็มชุดสำหรับ fingerprint; source-refresh timestamp ต้องระบุ timezone/offset เพื่อให้ snapshot comparison และ expiry ไม่ตีความตาม timezone ของ browser.

- Default `mode=review`, `series=thip-report`: แสดง source value ที่ validator รับ พร้อมป้ายยังไม่รับรองทุกหน้า/CSV. Arithmetic mismatch ไม่เปลี่ยนค่าหลักเป็นค่าคำนวณ และถูกตัดออกจากเส้นเฉลี่ยอัตโนมัติ. Review trend เป็นกราฟสอบทาน ไม่อ้างเป็น SPC ที่รับรอง.
- Approved mode ใช้ gate เดิม: readiness, evidence, source/rule version และ effective interval. Production reporting source ต้องครบ 232 รหัส/1,552 งวดและ source-refresh snapshot เดียวก่อนให้ publication projection. All current real rules remain unapproved; native cache ไม่เพิ่ม approved coverage.
- THIP grid มี 2,784 display slots แต่ 1,552 applicable cadence cells. ไตรมาส/ครึ่งปี/ปีแสดงที่เดือนเริ่มงวด พร้อม exclusive end เต็มงวด; เดือนอื่น `not-applicable` และ NULL.
- Monitoring 2,784 cells แยกอิสระ. Build manifest ประกาศ 101 monthly bridges เฉพาะ monthly candidate ที่ scale/unit/cohort hash/SQL rule hash สอดคล้อง; review-only ไม่มี clinical approval. Configured monitoring source มีสิทธิ์เหนือ bridge แม้ source ยัง pending/failed; ไม่ fallback จาก report เพื่อกลบข้อผิดพลาด. SH0101 และ additional/external rules ไม่ยืมผลปีมาแบ่งเดือน.
- Cumulative bridge ใช้ accumulation ของ rule; custom/distinct ต้องมี source YTD. Missing months หรือ arithmetic mismatch ไม่สร้าง complete YTD. Native ไม่ทราบ coverage จึงไม่อ้าง cumulative completeness. Hospital target ต้องมี approval/source/unit/effectivity; benchmark เป็นคำอ้างอิงแยก.
- Query success/cache count/มีค่า/approved coverage แยกกัน. Target-only, missing facts และ expired ไม่เป็น measured zero. Native read timestamp ไม่ใช่ source freshness.

## UI และ export

Global bar แสดงโรงพยาบาล/FY/mode/queue/cache/error state และ controls; session entry/reconnect ใช้ได้ทุกหน้า. Navy/teal/fonts เดิมคงอยู่. Search deferred, semantic table 232 rows อยู่ใน DOM, hidden filters, memo row/cell, เดือนพอดีความกว้างหน้า/จัดเป็น grid บนจอแคบ และ keyboard arrows/Enter/Escape/focus restoration. FY/mode/series/search/group/data/assessment อยู่ใน URL รองรับ back/forward.

CSV review ระบุ `UNAPPROVED REVIEW` และ filename `*-unapproved-review.csv`. ใช้ source facts ชุดเดียวกับ UI, รวม numerator/denominator/derived, reason/status, unit, version/lineage, target/source, accumulation และ read/source timestamps. THIP export เฉพาะ applicable cadence cells (ครบทุก KPI = 1,552 rows), monitoring ครบ 12 เดือน (2,784 rows). ISO เป็น machine columns คู่กับวันที่ พ.ศ.; escape formula injection. Export disabled ระหว่าง deferred filter/FY preparation. Official CSV ไม่รับ unapproved values.

## ตรวจรับ

`pnpm test`, build, generated runtime/sourceview/step/cohort checks, release isolation, synthetic source audit และ performance gates. Mocked browsers: shared SPA desktop/mobile + configured sources/cache (`scripts/shared_kpi_browser_smoke.py`), legacy approved chart smoke, development preview, step/error/cache/profile regressions. External HTTPS ถูก deny ใน shared smoke ก่อนติดตั้ง mocked routes. ไม่มี hospital calls, patient rows, Issues หรือ DB writes. SQL clinical validation/activation ยังต้องให้โรงพยาบาลรับรอง.

## ผลสะสมและ SPC

[THIP-CUMULATIVE-SPC.md](THIP-CUMULATIVE-SPC.md) เพิ่มมุมมอง `result=cumulative` ใน matrix/detail, YTD จาก explicit accumulation และ Control chart จากค่ารายงวด. Native และ reporting monthly bridge คำนวณ YTD เพื่อสอบทานโดยไม่อ้าง source coverage; distinct/custom ต้องมี source YTD. CSV เก็บทั้งรายงวด/YTD พร้อม basis/reason/cutoff. Analysis ใช้ snapshot เดิม ไม่มี query ใหม่หรือการเปลี่ยน publication gate.
