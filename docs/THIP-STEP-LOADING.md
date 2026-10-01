# โหลด THIP ทีละ KPI เพื่อสอบทาน

เพิ่มเมื่อ 1 ตุลาคม 2569. เปิดเมนู **ตรวจข้อมูลทีละ KPI** หรือ `?view=validation&fy=2026` สำหรับ FY2569. ใช้ session จาก BMS launcher หรือช่องกรอก session บนหน้านี้; Step 1 ตรวจ PasteJSON และ SELECT VERSION() ว่าเป็น PostgreSQL ก่อนสร้างคิว. การ refresh หน้าไม่เก็บ credentials; ต้องเปิด launcher/กรอก session ใหม่

## วิธีโหลด

- Step 2 สร้างคิวจาก manifest: DH0101, DH0112 แล้ว native codes ที่เหลือเรียงรหัส รวม 177; 55 external codes แสดงรอ source พร้อมเหตุผล ไม่เรียก external staging โดยอัตโนมัติ.
- Step 3 ส่ง registered SELECT ครั้งละหนึ่งรหัส เว้นอย่างน้อย 1 วินาทีหลัง request/body/validation จบ. ใช้ observation window เต็ม FY และ reporting cadence เดิม; ไม่มี time bisection หรือ annual/12.
- แต่ละผลผ่าน validator แล้วแสดงทันทีในตารางตามลำดับคิว ทั้ง source value, อัตราคำนวณสอบทาน, ตัวตั้ง/ตัวหาร, หน่วย, candidate version, latency และเวลาที่อ่านผล. ฟิลเตอร์ไม่เปลี่ยนคิว; ตารางไม่รอครบทั้งปี/ทั้งชุด.
- พักรอ active request จบแล้วหยุด; ต่อทำเฉพาะงานที่เหลือและรักษาเวลารอเดิม. ยกเลิก abort request/เวลารอ เก็บผลสำเร็จที่เห็นอยู่จนเริ่มใหม่หรือเปลี่ยน context.
- Retry เป็นคำสั่งจากผู้ใช้เท่านั้น เลือกเฉพาะ failed codes; ไม่เรียก successful codes ซ้ำ. เปลี่ยน FY/session, ออกจากหน้า หรือ reconnect ยกเลิกคิวเดิม; กลับเข้าหน้าเริ่มคิวใหม่. ไม่มี durable result cache.

## การจำแนกข้อมูลและข้อผิดพลาด

`ThipStepLoader` ส่ง `StepSnapshot` ผ่าน progress callback; มี state idle/running/pausing/paused/cancelled/complete และ step pending/running/success/failed/skipped. Snapshot เป็นสำเนาของ aggregate objects และไม่มี runtime/session config. Query success, non-NULL value cells และ approved coverage เป็นคนละตัวเลข

Candidate validator รับเจ็ดคอลัมน์ `indicator_code, period_start, fiscal_month, fiscal_year, numerator, denominator, value` และ optional `fact_present` เท่านั้น. ตรวจ code/FY/cadence/date, duplicate periods, numeric facts และ positive denominator สำหรับ non-NULL rates. Registered per-code SELECT เพิ่ม fact-presence flag เพื่อให้ absent facts ที่ outer grid เติม 0 ไม่ถูกตีความเป็น cohort ว่าง. Seven-column exports ที่ไม่มี flag ยังคง unknown เมื่อเป็น 0/0

`CandidateAggregate` เป็น series `thip-report`, approval `unapproved`; sourceValue กับ derivedValue แยกกัน. Dictionary-derived display unit ไม่รับรองสูตร. เดือนอนาคตตาม Asia/Bangkok มี NULL facts; dataThrough/refreshedAt เป็น NULL จน source ให้หลักฐาน. observedAt คือเวลาอ่าน query ไม่ใช่ source freshness. แถวรายไตรมาส/ครึ่งปี/ปีคง anchor เดิม

- Single-code failure/timeout เก็บ sanitized reason แล้วไปต่อ; HTTP404 ไม่ถูกเหมารวมว่าเป็น budget refusal. Single-code timeout ไม่แบ่ง observation window.
- HTTP401/403 หรือ JSON MessageCode401/403 แม้ HTTP501 พักและล็อกคิวเพื่อ reconnect.
- HTTP429/MessageCode429 พักตาม Retry-After (seconds หรือ HTTP date; default 1 วินาทีเมื่อ header ใช้ไม่ได้), แล้วรอผู้ใช้กดต่อ/ลองใหม่ ไม่ restart อัตโนมัติ.
- Network/HTTP server errors ติดต่อกัน 3 ครั้งพักคิว. Query-specific JSON database errors ไม่ถูกเหมาเป็น network outage. ผลสำเร็จไม่ถูกล้างโดยความล้มเหลวของรหัสอื่น.

## Publication และ build

หน้านี้มีป้ายยังไม่รับรองและไม่มี CSV/export API. ไม่ส่ง candidate facts เข้า `publishApprovedThip()` หรือ production monitoring contract; approved coverage จากหน้านี้เป็น 0. Official THIP 232 codes/1,552 cadence cells และ monitoring 2,784 cells พร้อม gates เดิมยังอยู่. การจบคิวไม่ใช่ clinical sign-off

Docker build ไม่ต้องตั้ง source view เพื่อสร้าง candidate page แล้ว; official runtime source/approval gates ยังคงอยู่. Compose ส่ง monitoring source/foundation/concurrency variables ด้วย แต่ candidate queue ไม่ใช้ concurrency override: คงหนึ่งคำขอเสมอ. Session/token ไม่อยู่ใน build variables/logs/storage

สูตร runtime ปัจจุบันใช้ numeric scale ก่อนหารอยู่แล้ว ขณะที่ Navicat/legacy SQL exports ที่ผู้ใช้ส่งมี integer division. New Step path ใช้ runtime registered branches; regression gate ปฏิเสธ integer multiplier-before-division. ไฟล์ Navicat และ Excel เดิมไม่ถูกแก้หรือรัน. SQL รวมเก่ามี provisioning/sample INSERT/refresh DELETE; ห้ามส่งทั้งไฟล์เข้า API หรือใช้ sample rows เป็นผลจริง

## ตรวจรับซ้ำ

```powershell
pnpm test
pnpm build
pnpm steps:check
pnpm sourceview:check
pnpm monitoring:release-check
python scripts/thip_source_audit.py --input test-fixtures/thip-kpi-complete-2026.json --fiscal-year 2026
```

`pnpm steps:build` สร้าง `reporting/thip_step_queries.manifest.json` จาก source (key/code/cadence/full-window/query bytes/SHA256) ไม่มีข้อมูลคน/credentials. `steps:check` ตรวจ 177 native/55 external, one-code SELECT, numeric ratio และ generated drift. Manifest ใช้ FY2026 เป็น canonical validation window ไม่ล็อก UI ให้โหลดเฉพาะปีนี้

เปิด dev server ที่ port5183 แล้วรัน `python scripts/step_browser_smoke.py` (หรือกำหนด `THIP_STEP_SMOKE_URL`). Script mock BMS ทั้งหมด: desktop/mobile, progress-before-complete, gap/controls/retry, filtering, manual session/reload, FY/stale responses, auth/429, keyboard details และ console canary. Screenshots/results อยู่ใน ignored `tmp/step-browser/`

การตรวจรับโรงพยาบาลจริงยังไม่ทำ: ต้องยืนยัน cohort/join/date/population/targets/version และเทียบกับรายงาน aggregate ก่อนเปิดผลเผยแพร่. รอบนี้ไม่ deploy ไม่เปิด Issues และไม่เรียก BMS/HOSxP สด

## ผลตรวจรับ implementation — 1 ตุลาคม 2569

- Unit/integration suite ผ่าน 1,261 tests ใน 34 files รวม fake-timer queue, session/429, failed-only retry และ arithmetic regression.
- Mocked browser ผ่าน 13 checks บน desktop/mobile: ผลแรกก่อนจบคิว, หนึ่ง request พร้อมกัน, ช่วงรอ, controls, retry, filters, session refresh, เปลี่ยนปี/ผลเก่าที่มาช้า และ keyboard details; ไม่มี JavaScript errors หรือการเรียก BMS จริง.
- TypeScript/Vite build ผ่าน. Docker build ที่ไม่กำหนด source view และ `nginx -t` ใน local container ที่ปิด network ผ่าน; ไม่ได้ deploy.
- Generated step manifest ผ่าน 177 native/55 external; reporting artifact ผ่าน 232 codes/1,552 THIP cells/2,784 monitoring cells. Synthetic source audit ผ่าน และ production fixture exclusion/preview-flag rejection ผ่าน.
- ยังมี Vite warning เรื่องขนาด bundle เกิน 500 kB; ไม่ใช่ข้อยืนยัน latency ของ query จริง. ความถูกต้องทางคลินิก, schema โรงพยาบาล และความเร็วบน BMS จริงยังต้องตรวจรับแยก.
