# THIP KPI BMS — ผลพัฒนาประสิทธิภาพ 2026-10-02

หน้า monitoring โหลด JavaScript ที่จำเป็น 130,495 bytes gzip (ประมาณ 130.5 KB) จาก baseline ประมาณ 490 KB. Production lab benchmark ห้ารอบต่อ device ผ่าน budgets ที่กำหนด โดยยังมี 232 แถว/2,784 ช่องใน DOM. Cache 177 native KPI คืนผลโดยไม่เรียก SQL ซ้ำ. ผลนี้เป็นการจำลองในเครื่อง; การตรวจเครื่องโรงพยาบาล/มือถือจริงและ latency ของฐานจริงเป็นขั้นรับรองถัดไป

## วิธีวัดและผลก่อน–หลัง

Baseline ตาม audit เดิมสองรอบ: JavaScript ตอนเปิดเว็บประมาณ 3.09 MB ก่อนบีบอัด/490 KB gzip, DOM ประมาณ 12,300 จุด และ LCP มือถือประมาณ 4.7s. Baseline ไม่ใช่ชุดห้ารอบเดียวกับผลใหม่ จึงใช้เป็นจุดอ้างอิงโดยไม่อ้างความแม่นยำทางสถิติของเปอร์เซ็นต์ที่ดีขึ้น

ผลใหม่ใช้ production build ที่เสิร์ฟ `.gz` ล่วงหน้า, Chromium headless, context ใหม่ทุก cold run, ห้ารอบ/device. Desktop 1440×1000/CPU 1×; mobile 390×844/CPU 4×. Network 1.6 Mbps, latency 100ms; p75 ใช้ nearest rank (ค่าที่สี่จากห้ารอบ). Browser ห้าม external HTTPS ยกเว้น mocked session/API. ข้อมูลเป็น synthetic aggregates เท่านั้น

| Metric | Baseline | Desktop p75 | Mobile p75 | Budget / ผล |
|---|---:|---:|---:|---|
| JS ที่ใช้บน monitoring แรก (gzip) | ~490 KB | 130,495 B | 130,495 B | ≤200,000 B — ผ่าน |
| LCP | mobile ~4.7s | 1,612 ms | 2,272 ms | ≤2,000/2,500 ms — ผ่าน |
| Interaction samples | ไม่ได้บันทึก | 80 ms | 112 ms | ≤200 ms — ผ่าน |
| CLS | ไม่ได้บันทึก | 0.0276 | 0.0735 | ≤0.1 — ผ่าน |
| Cache 177 codes | ไม่ได้บันทึก | 202 ms | 1,074 ms | ≤1,000/2,000 ms — ผ่าน |
| DOM rows / month buttons | 232 / 2,784 | 232 / 2,784 | 232 / 2,784 | ครบและใช้ instance เดิม |
| DOM nodes | ~12,300 | 12,324 | 12,324 | รักษาทุกแถวตามที่เลือก |

Interaction sample ใช้ Event Timing สำหรับพิมพ์คำค้น, ล้างคำค้น, ลูกศร, Enter และ Escape: รวม duration ต่อ interactionId แล้วใช้ p75 ต่อรอบและ p75 ห้ารอบ. ค่าต่ำกว่า event threshold 16ms ไม่ถูกสังเกต; รอบที่ไม่มี sample ใช้ upper bound 16ms. นี่เป็น lab proxy ของ input-to-next-paint ไม่ใช่ INP จากผู้ใช้จริง. CLS ใน harness รวม layout shifts ที่ไม่มี recent input จึงเป็น conservative lab check แทน field session-window score. เกณฑ์พื้นฐานและความต่าง lab/field อ้างอิง [Web Vitals](https://web.dev/articles/vitals)

Cache benchmark โหลด validation modules ก่อน, seed รายงวดครบของ 177 รหัสใน IndexedDB แล้วเริ่มจับเวลาตั้งแต่กดเชื่อมต่อ จน cacheHits=177 และตรวจว่า native query count=0. เวลานี้รวม mocked session/probe และ UI จึงกว้างกว่า budget ที่เริ่มหลังตรวจ session/module พร้อม. ช่วงเว้นคิวและการโหลดฐานจริงไม่ถูกรวมในเวลาคืน cache. Warm snapshot มี 232 แถว/177 cached successes/55 external placeholders และไม่เพิ่ม approved coverage

ผลรายรอบอยู่ใน [frontend benchmark JSON](performance/frontend-2026-10-02.json). มือถือรอบหนึ่งมี interaction p75 216ms ขณะที่ aggregate p75 ห้ารอบเป็น 112ms; จึงยังต้องตรวจบนอุปกรณ์จริง. งาน mount ตารางทั้งหมดมี main-thread blocking p75 ประมาณ 1.05s บน CPU จำลอง 4×; ไม่ได้อ้างว่าทุก interaction หรือทุกเครื่องผ่านจากชุดเล็กนี้

## โค้ดที่เปลี่ยน

| ระยะ | Dependency | ผลที่ส่งมอบ / acceptance |
|---|---|---|
| A Measurement | Production build/baseline | `performance_smoke.py`, production gzip fixture server, bounded in-memory query/cache/lane diagnostics; CI budgets และ artifacts |
| B Startup | A | แยก transport/probe จาก registry, lazy monitoring/dashboard/catalog/detail/validation, runtime metadata ขนาดเล็กและ 29 family evidence imports. SQL/พจนานุกรมเต็มไม่อยู่ใน monitoring startup |
| C Rendering | B | Memoized matrix/rows/cells, delegated events, hidden filtersคง instance, cached periods/search/formatters, deferred search + pending export guard, dialog body เมื่อเปิด, FY/session snapshot guards, หยุด countdown เมื่อครบเวลา |
| D Queue/cache | B–C | SQL/rule hashesตอน build, SQL planเมื่อถึง code, IndexedDB v2 `readMany` transaction เดียว/context+expiry index, readonly frozen progressพร้อม reference เดิม; expiry/fallback/cancel/publication gates เดิม |
| E SQL/delivery | A–D | CTE dependencies 177 codes, synthetic PG equivalence/EXPLAIN, `.gz` build/Nginx gzip_static, immutable assets/no-store HTML, Thai/Latin WOFF2 ที่ hostในแอป, explicit failed-chunk retry |

Canonical rule/dictionary ยังอยู่ครบสำหรับ audit/build/official reporting adapter. Generated family evidence เก็บนิยามและ cohort ครบ 232 รหัส; compact runtime readiness ได้ผลเท่ากับ full rule และ cache rule hash รวม cohort evidence. ขนาด JavaScript ทั้งหมดใน build ไม่ใช่ startup budget: evidence/reporting/chart chunks ยังโหลดเมื่อใช้งาน และ Vite ยังแจ้งบาง chunk เกิน 500 KB ก่อนบีบอัด. ไม่มีการซ่อน warning หรือเอาหลักฐานทิ้งเพื่อลดตัวเลข

Browser จดจำ failed dynamic-import URL ได้ จึงใช้ URL ใหม่สำหรับ same-origin JS asset เมื่อผู้ใช้กด retry. ไม่มีการ reload อัตโนมัติ. กรณีไฟล์รุ่นเดิมหมดอายุ/โหลดซ้ำไม่ได้ มีปุ่ม reload พร้อมอธิบายการตรวจ session ใหม่และงานที่ยังไม่สำเร็จ; cached aggregates คงอยู่. Browser smoke ยืนยัน retry ได้, session inputคงอยู่และไม่มี document reload

## SQL equivalence และข้อเสนอ DBA

CTE planner สร้างเฉพาะ dependency closure จาก registered branch; ไม่แก้ cohort/formula/outer cadence grid และไม่แบ่งวันที่. SQL 177 คำขอรวมลดจาก baseline 2,582,250 เป็น 1,538,312 bytes (ลดประมาณ 40%). แต่ละคำขอยังคง observation window ต.ค.–ก.ย., concurrency 1 และ gap 1s

ทดสอบ PostgreSQL 16 ใน disposable container ที่ปิด network ไม่มี host mount/port/credential ของโรงพยาบาล. ใช้ fixture คนซ้ำ/หลาย episode/diagnosis ซ้ำ/ข้ามงวดและ synthetic episodes เพิ่ม 10,000 + diagnosis 20,000. ก่อน–หลังคืน aggregate ตรงกันครบหกรหัส. `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)` ห้ารอบ/รูปแบบ; ตารางแสดง median execution ไม่รวม API หรือ queue wait. วิธีอ่านแผนและผลวัดอ้างอิง [PostgreSQL EXPLAIN](https://www.postgresql.org/docs/16/using-explain.html)

| Code | SQL bytes ก่อน → หลัง | Execution median ms ก่อน → หลัง | Aggregate |
|---|---:|---:|---|
| DH0101 | 13,201 → 9,877 | 111.640 → 109.099 | ตรงกัน 12 cells |
| DH0112 | 12,937 → 9,613 | 13.675 → 13.675 | ตรงกัน 12 cells |
| CE0102 | 13,321 → 4,059 | 0.377 → 0.384 | ตรงกัน 12 cells |
| HH0102 | 15,810 → 6,548 | 0.772 → 1.234 | ตรงกัน 12 cells |
| HE0101 | 13,784 → 3,581 | 0.491 → 0.513 | ตรงกัน 12 cells |
| SH0101 | 15,502 → 5,299 | 0.607 → 0.587 | ตรงกัน 1 annual cell |

เวลาของบาง query เพิ่มขึ้นเล็กน้อย; ผลนี้ยืนยันการลด payload/การประกอบ query และความเท่ากันบน fixtures ไม่ยืนยันความเร็วของฐานโรงพยาบาล. SH0101 ยังคง annual turnover ตามสูตรเดิม ไม่หารเป็นรายเดือน. ดู [SQL benchmark JSON](performance/sql-2026-10-02.json) สำหรับ planning median และ dependency list

Fixture มี indices `iptdiag(an)` และ `an_stat(an)` เพื่อจำลอง episode lookup; ไม่ได้พิสูจน์ว่าฐานจริงขาด index เหล่านี้ และไม่มี hospital index ถูกสร้าง. ข้อเสนอก่อนเปลี่ยน index คือให้ DBA ตรวจ existing index/primary key, row cardinality, statistics และ EXPLAIN บน approved aggregate staging: เริ่มจาก episode predicates ใน iptdiag/an_stat และ regdate/dchdate window ของ ipt. ต้องเปรียบเทียบ plans/buffers/latency กับ workload จริงก่อนเลือก composite/partial index หรือ materialized aggregate; ตอนนี้ยังไม่เสนอ DDL ให้รัน

## การตรวจรับ

- Unit/integration: 1,300 tests / 39 files ผ่าน รวม hash/readiness equivalence, frozen/shared snapshots, cancellationก่อน attachment, fiscal/date memoization และ cache validator/fallback/expiry
- Generated checks: runtime 232/177/29, Step 177 native/55 external, cohort evidence 232/6 profiles, THIP 1,552 และ monitoring 2,784 cells ผ่าน
- Synthetic source audit และ complete/invalid fixture audit ผ่าน; production fixture exclusion และ preview flag rejection ผ่าน
- Browser: monitoring 20 checks, Step 13 checks, profile 18 checks, persistent cache/migration 14 checks, visual smoke และ production chunk recovery. Filters/URL/CSV/keyboard/mobile/stale-year/session/error coverage ไม่เรียกฐานจริง
- Synthetic cohort SQL 16 checks และหกรหัส original/pruned aggregate equivalence ผ่าน
- TypeScript/Vite/Docker build ผ่าน; Nginxตรวจ gzip file/response, immutable hashed assets, no-store HTML และ credential canary ไม่ปรากฏใน logs

ตรวจ source/fixtures ด้วย publication gates เดิม; registered SQL/cache successes ไม่กลายเป็น approved measurements. ไม่แก้ BMS HTTP payload และไม่มี patient identifiers ออกจาก SQL/cache. รอบนี้ไม่มี live BMS/HOSxP calls, Issues, deployment หรือ commit/push

## ทำซ้ำและเกณฑ์ CI

```text
pnpm test
pnpm runtime:check
pnpm steps:check
pnpm cohorts:check
pnpm sourceview:check
pnpm fixture:export
python scripts/check-thip-fixtures.py
python scripts/thip_source_audit.py --input test-fixtures/thip-kpi-complete-2026.json --fiscal-year 2026
python scripts/cohort_sql_smoke.py
python scripts/query_performance_smoke.py
pnpm build
pnpm monitoring:release-check
pnpm perf:check
python scripts/chunk_browser_smoke.py
```

Performance scripts ต้องมี Python Playwright/Chromium และ Docker สำหรับ synthetic SQL. รัน performance แยกจาก CPU-heavy suites; port 5186 ต้องว่าง. Runtime generation อิง canonical code; หลังแก้สูตร regenerate cohort/runtime/Step/reporting ตาม README. Build splitting ใช้ [Vite dynamic import](https://vite.dev/guide/build.html). CI ใช้ budgets เดียวกันและอัปโหลด numeric results ใน `tmp/performance`/`tmp/sql-performance`; ผลวัดใหม่อาจต่างตาม runner

การเปิดทั้งคิวมีช่องเว้นอย่างน้อย 176s ยังไม่รวม latency ของ 177 คำขอ. การรับรองเครื่องจริงและ hospital query latency/index ต้องดำเนินการกับเจ้าของระบบในระยะถัดไป โดยรักษา full observation windows, read-only access และการรับรองสูตรแยกจากความเร็ว
