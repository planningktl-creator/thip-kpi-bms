# THIP KPI รุ่นแรก — หลักฐานส่งมอบ 2026-10-01

พัฒนา phase A–F: monitoring matrix 232×12, development-only synthetic preview, registered aggregate provider/contract, drill-through และ CSV พร้อมแก้ฐาน correctness/security. Official reporting ยังคง 232 codes / 1,552 cadence cells. ทุก real rule เริ่มไม่รับรองและไม่เผยแพร่ candidate facts. ไม่มี real BMS/HOSxP access, GitHub Issues หรือ deployment; เก็บงานที่ค้างเดิมไว้.

## ผลงานและหลักฐาน

- [Roadmap](THIP-KPI-DEVELOPMENT-ROADMAP.md) ระบุ dependencies/acceptance และงาน certification ถัดไป.
- [Monitoring contract](THIP-MONITORING-CONTRACT.md) ระบุ state/NULL/targets/units/period/version/accumulation/provider/preview.
- [UI handoff](THIP-MONITORING-UI.md) บันทึกพฤติกรรมจริงจาก code และ browser captures; `PRODUCT.md` เก็บขอบเขตที่ผู้ใช้อนุมัติ.
- [Human mapping](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.md) / [machine mapping](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json) ครบ 232 definitions/page pairs/schema/PK/joins/limitations. เส้นทาง 101 monthly candidates / 71 additional rules / 55 external / 5 population.
- [Generated rule registry](../reporting/thip_monitoring_rules.json), [monitoring DDL](../reporting/thip_monthly_monitoring.sql), [official source artifact](../reporting/thip_kpi_monthly.sql) เป็น artifacts ไม่ใช่ migration ที่รันจริง.

## การตรวจรับ

| Check | ผลและขอบเขต |
|---|---|
| Unit/integration | 33 files / 1,240 tests ผ่าน; period/accumulation/targets/NULL/approval/transport/CSV และ compatibility |
| Production build | TypeScript + Vite ผ่าน; bundle ยังมี warning เรื่องขนาดตาม backlog |
| Preview isolation | Production fixture canary exclusion และ build flag rejection ผ่าน |
| Generated drift | `pnpm sourceview:check` เปรียบเทียบ source SQL/monitoring DDL/rules/compact evidence ผ่าน |
| THIP fixture/source audit | 232 codes / 1,552 cells; complete fixture ผ่านและ invalid variants 6 ชุดถูกปฏิเสธ |
| Browser | 20 checks: mock BMS desktop 1440px/mobile 390px/tablet 800px; filters/search/URL refresh/history/CSV; keyboard/dialog focus; future months; slow FY switch/stale result; source error/session rejection ผ่าน ไม่มี page errors |
| Original visual smoke | Mocked legacy dashboard/catalogue/detail routes ผ่าน; ปรับ assertion ตาม publication withholding และ reporting period |
| Docker/Nginx | Local non-root image build/health/config validation ผ่าน; canaries ใน query string และ Referer ไม่ปรากฏ logs |
| Synthetic PostgreSQL 16 | Generated refresh ได้ 1,552 cells; DE1601 external facts 95/100 retained; DH0101 discharge ข้ามเดือนและ duplicate diagnosis/death rows นับ 1 episode; SH0104 full quarter ต่างจาก partial windows; monitoring DDL ผ่าน |
| UI review | Finish disposition `ship`; preserved incumbent visual system. Breakpoint sidebar ปรับให้ตรง CSS 680px และตรวจ tablet เพิ่ม |

คำสั่งหลัก:

```powershell
pnpm test
pnpm build
pnpm monitoring:release-check
pnpm sourceview:check
python scripts/check-thip-fixtures.py
python scripts/thip_source_audit.py --input test-fixtures/thip-kpi-complete-2026.json --fiscal-year 2026
python scripts/visual_smoke.py
python scripts/monitoring_browser_smoke.py
```

Browser checks ต้องเริ่ม normal/preview/source-configured Vite servers ตาม CI; ทุก external endpoint ถูก mock. Local QA captures/check outputs อยู่ใน ignored `tmp/monitoring-release/` และไม่มีข้อมูลผู้ป่วย.

## ข้อจำกัดที่ยังต้องรับรอง

Tests และ synthetic SQL execution ไม่ยืนยันสูตรระดับโรงพยาบาลครบ 232 รหัส. รุ่นนี้ให้ครบช่อง/นิยาม/mapping/เหตุผลและเส้นทางข้อมูล; การเผยแพร่จริงต้องมี owner evidence สำหรับ cohort, joins, dates, local codes, denominator, monthly/YTD rule, source targets และ version/effectivity. Production measurement coverage ยังเป็น 0 เมื่อยังไม่รับรอง. Preview approval และค่าทั้งหมดเป็นการจำลองเฉพาะ development.

Bundle size warning และ test-tool dependency advisory จาก audit เดิมยังเป็น backlog; ไม่ปรับ dependencies โดยไม่มีการตรวจผลกระทบเพิ่มเติม. การปิด HTTP error log เพื่อกัน capability leakage ต้องใช้ safe access logs และ `/healthz` สำหรับ runtime diagnostics. Reporting grants/refresh/freshness/latency rollout ต้องตรวจโดย platform owner ในระยะเปิด family.
