# THIP KPI BMS

THIP KPI quality intelligence frontend for BMS Marketplace. The default view is a 232×12 fiscal-month monitoring matrix; the original THIP overview, catalogue and reporting-period detail remain available. Monitoring and official THIP reporting are independent series. Production publishes only approved rule versions and never fabricates values; every real rule currently awaits hospital publication approval.

## Monthly monitoring release

### โหลดทีละ KPI เพื่อสอบทาน

เปิดเมนู **ตรวจข้อมูลทีละ KPI** (`?view=validation&fy=2026` สำหรับ FY2569). รับ launcher session หรือกรอก session ในหน้า; ตรวจ PostgreSQL แล้วโหลด DH0101, DH0112 และ native codes ที่เหลือทีละหนึ่งรหัส รวม 177 รหัส เว้น 1 วินาที พร้อมผลระหว่างทางและปุ่มพัก/ต่อ/ยกเลิก/retry เฉพาะ failed codes. External 55 รหัสยังแสดงรอ source. Candidate facts อยู่เฉพาะหน้าสอบทาน ไม่มี export และไม่เพิ่ม approved coverage. ดู [Step loading contract และการตรวจรับ](docs/THIP-STEP-LOADING.md).

Candidate page ไม่ต้องมี source view และ Docker สร้างได้โดยไม่ตั้ง source variables. ผล THIP/monitoring ที่เผยแพร่ยังต้องผ่าน source/approval gates เดิม. เปลี่ยนปี/session หรือ refresh ไม่ใช้ snapshot/credentials ของ context เก่า. `pnpm steps:build` / `pnpm steps:check` สร้างและตรวจ single-code query manifest จาก source.

Search codes/names, filter group/data state/assessment, open a cell's facts and rule, and export all twelve months of the filtered KPI rows. Filters and fiscal year persist in the URL. Mobile month columns scroll horizontally with sticky KPI identity; arrows move between cells, Enter opens details, Escape closes and restores focus. Missing facts stay NULL with a reason. Reporting retains 232 codes / 1,552 cadence cells; monitoring adds 2,784 cells without changing `Indicator.monthly`.

Run the synthetic preview in PowerShell:

```powershell
$env:VITE_THIP_MONITORING_PREVIEW = 'true'
pnpm dev
```

The page and CSV identify synthetic data; seven representative rules have simulated approval, while all other codes show their pending reason. Preview uses the same provider interface and does not connect to a hospital. Before a production build, remove the flag:

```powershell
Remove-Item Env:VITE_THIP_MONITORING_PREVIEW -ErrorAction SilentlyContinue
pnpm build
pnpm monitoring:release-check
```

Production builds reject the preview flag and omit fixture rows. Optional real monitoring configuration is `VITE_BMS_MONITORING_SOURCE_VIEW=reporting.thip_monthly_monitoring`; it reuses the in-memory BMS session and registered aggregate SELECT. No real monitoring rules are approved in this release. The generated DDL is an offline artifact; the frontend never provisions or refreshes a database.

See [monitoring contract](docs/THIP-MONITORING-CONTRACT.md), [release evidence](docs/THIP-MONITORING-RELEASE-2026-10-01.md), [development roadmap](docs/THIP-KPI-DEVELOPMENT-ROADMAP.md), and [232-code mapping](docs/THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.md). This implementation used schema, synthetic fixtures and mocked BMS only; no live HOSxP access, Issues or deployment.

## What is included

- Dashboard view with fiscal-year trend, group health signals, priority indicators, and filters.
- Indicator library containing all 232 THIP 2025 dictionary entries, with live, partial, and no-data states.
- Indicator detail view with a 12-slot fiscal-year timeline, reporting-period bar chart, line-trend toggle, annual rollup, numerator/denominator, target, status, definition, and source tables.
- Per-indicator control chart (statistical process control): p-chart with weighted center line and per-period 3-sigma limits for proportion indicators, I-MR chart for count/ratio indicators, CL/UCL/LCL reference lines, and special-cause signals (beyond-limits points and eight-point runs) marked in the chart.
- Results broken down per fiscal year as monthly (รายเดือน), weighted quarterly (รายไตรมาส Q1 ต.ค.–ธ.ค. … Q4 ก.ค.–ก.ย.) and annual (รายปี) rollups, each row carrying the approved target and status.
- Printed definitions for all 232 indicators from the THIP KPI 2025 dictionary (`src/data/thipKpiDictionary.json`): formula, a/b definitions, benchmark text/verbatim target, and interpretation direction. Dictionary benchmarks remain descriptive; numeric hospital targets require confirmed source, units and effectivity.
- Fiscal-year presentation that keeps ISO dates at the data boundary and renders Thai Buddhist Era dates/years in the frontend and CSV export.
- Keyboard-friendly navigation with skip link, labeled filters, table semantics, visible focus, reduced-motion support, and direct drill-through from group signals to the full catalogue.
- No synthetic production metrics or frontend-seeded benchmarks. Validated source rows remain withheld until separate publication/version/effective-period approval; hospital targets need their own approval.
- The dashboard's target-attainment summary is derived only from live values and approved targets; indicators without a target are excluded rather than assigned a synthetic score.
- Development handoff and the complete HOSxP query plan for all 232 indicators: [`docs/THIP-KPI-HOSXP-QUERY-GUIDE.md`](docs/THIP-KPI-HOSXP-QUERY-GUIDE.md).
- BMS session launch parsing and an in-memory `SELECT VERSION()` handshake through the registered query layer.
- Domain boundaries for session/transport, query registry, HOSxP adapter, indicator definitions, and UI.
- Export of the selected indicator's reporting-period result to CSV.

## Run locally

```bash
pnpm install
pnpm dev
```

Open the local Vite URL. Without a BMS launcher URL, the app stays in no-data mode. A BMS launch URL may include `bms-session-id` and an optional `marketplace-token`; the app removes both from the address bar before the request and keeps them only in memory for the current page so a transient connection failure can be retried. It never writes either value to localStorage or logs them.

## Public preview

The frontend is also published as a public GitHub Pages preview. It shows no-data unless it is opened inside an approved BMS live session:

https://planningktl-creator.github.io/thip-kpi-bms/

## BMS deployment

The intended BMS Marketplace deployment follows the same container contract as `IPTImprove`: a multi-stage Docker build, an unprivileged Nginx runtime on container port `8080`, SPA fallback, immutable asset caching, security headers, CSP, and a `/healthz` endpoint.

Build and run locally with Docker Compose:

```bash
docker compose build --build-arg BMS_ALLOWED_ORIGINS="https://hosxp.net https://10929-f446.tunnel.hosxp.net" --build-arg VITE_BMS_APP_IDENTIFIER="THIP.KPI.BMS" --build-arg VITE_BMS_KPI_SOURCE_VIEW="thip_kpi_monthly"
docker compose up -d
```

The local container is available at `http://127.0.0.1:3082/`. Replace the origins with the approved BMS/HOSxP origins for staging or production; the value is validated as a space-separated list of `http(s)` origins and is used only to render the Nginx CSP. `VITE_BMS_APP_IDENTIFIER` must match the identifier registered by the BMS platform.

Before testing a live session, the BMS API must allow the deployed app origin `https://thip-kpi-10929.kube.bmscloud.in.th` on `OPTIONS` and `POST /api/sql` for `Authorization` and `Content-Type`. `OPTIONS /api/sql` must return `200` or `204` with `Access-Control-Allow-Methods: POST, OPTIONS`, `Access-Control-Allow-Headers: Authorization, Content-Type`, the exact `Access-Control-Allow-Origin` value (not `*`), and `Vary: Origin`. The tunnel must return a healthy response rather than `502 Bad Gateway`.

Run the read-only connectivity smoke with a fresh session ID supplied through the environment; the script never prints the session token or query result:

```powershell
$env:THIP_BMS_SESSION_ID = '<fresh-session-id>'
$env:THIP_APP_ORIGIN = 'https://thip-kpi-10929.kube.bmscloud.in.th'
python scripts/bms-connectivity-smoke.py
```

The smoke verifies PasteJSON, CORS preflight, authenticated `SELECT VERSION()`, the app identifier, and CORS headers on the actual API response.

Production builds fail closed when neither data path is configured: the Docker image rejects the build and the browser runtime also refuses an incomplete configuration. There are two ways to serve the 232-indicator contract:

1. **Normalized source view (recommended)** — `VITE_BMS_KPI_SOURCE_VIEW=thip_kpi_monthly`. Small and fast, one read for all 232 codes, but requires a hospital-approved read-only reporting source. `reporting/thip_kpi_monthly.sql` is an offline provisioning/refresh artifact for a separate approved reporting database; the app never runs it or writes to HOSxP. A complete hospital release must provide the normalized read-only view; its contract is documented in `docs/THIP-DATA-CONTRACT.md`.
2. **Registered HOSxP foundation queries** — `VITE_BMS_KPI_LIVE_FOUNDATION=true` is a development validation path. Requests retain the full fiscal-year observation window and partition by code only. A refused single-code request becomes unavailable with `query-budget-exceeded`; it is never split by date without proof of equivalence. Concurrency defaults to sequential and is capped at 12. This candidate SQL path does not grant publication approval.

In local Vite development only, an empty value runs the evidence-backed HOSxP foundation query for `DH0101`, `DH0101.1`, `DH0101.2`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, `DN0109`, and `DN0302` for query validation.

The repository intentionally keeps the GitHub mirror remote separate from the BMS deployment remote. The BMS remote and application identifier must be supplied by the platform owner before production registration.

## Build and test

```bash
pnpm build
pnpm test
```

`pnpm fixture:export` regenerates synthetic THIP aggregate fixtures (232 codes, 1,552 cadence cells plus six invalid variants). `python scripts/check-thip-fixtures.py` checks all variants. `pnpm sourceview:build` generates THIP SQL, monitoring DDL/rule registry and compact PDF evidence; `pnpm sourceview:check` checks exact drift. `pnpm monitoring:release-check` checks the production bundle and preview build rejection. Test fixtures contain no patient data; the development preview module is omitted from production.

`python scripts/visual_smoke.py` exercises the original THIP screens and mocked BMS publication withholding. `python scripts/monitoring_browser_smoke.py` exercises matrix/filters/CSV/desktop/mobile/tablet, future periods, URL history, slow year switching and session errors. It uses normal/preview/source Vite servers on 5173/5174/5175 (overridable environment variables). CI starts these mocked-only servers. `python scripts/check-nginx-security.py --image <local-image>` tests credential canaries against a disposable local container.

## Data boundary

`HOSxP Structure.xlsx` is used as a schema inventory. `THIP KPI.pdf` is the 2025 KPI dictionary and defines the five THIP groups (D, C, S, H, A), the reporting cadence (112 monthly, 19 quarterly, 31 semiannual, and 70 annual indicators), and the numerator/denominator model. The first live foundation query uses the PDF definitions for `DH0101` (PDF page 39), `DH0101.1` (page 40), `DH0101.2` (page 41), `DH0102` (page 42), `DG0102` (page 121), `DN0101` (page 67), `DR0101` (page 79), `CE0101` (page 194), `CI0101` (page 199), `DG0202` (page 123), `DR0403` (page 90), `DR0102` (page 80), `DN0107` (page 73), `DH0112` (page 54), `DN0109` (page 74), and `DN0302` (page 77), together with the HOSxP `ipt`, `an_stat`, `iptdiag`, `death`, `opitemrece`, and `drugitems` tables. The query preserves raw numerator/denominator counts and returns one row per indicator/reporting period. Hospital-specific source views and further KPI SQL must still be validated on anonymized staging data before being enabled.

The 232-entry indicator library is complete at the catalogue/rule level and now also at the query level. The THIP 2025 dictionary contains 112 monthly, 19 quarterly, 31 semiannual, and 70 annual indicators, and every code resolves to exactly one registered read-only fact branch: the in-registry family queries cover the original core and the batch modules in `src/services/thipFamilies/` cover the remaining 171 codes (one aggregate branch per code, cadence-aware period bucketing so quarterly facts cover their quarter and annual facts cover the fiscal year). Codes whose denominator or source lives outside HOSxP (population registers, audited finance, survey instruments, device-days, custom registries — 55 codes) read `reporting.thip_external_facts`, a hospital-loaded aggregate staging table that `pnpm sourceview:build` provisions alongside the reporting view; until the hospital loads those staging rows the reporting layer emits explicit `unavailable` rows for them, never a fabricated zero. Per-code measurement notes and approximation gaps are documented in `src/services/thipFamilies/*_APPROXIMATIONS` and still need clinical/quality owner sign-off before any code is called `ready`.

Every code is classified in `src/data/thipImplementation.ts` and now resolves to exactly one registered fact branch (`registered`); the `pending-local-source` tier remains available for codes whose hospital rule is withdrawn pending review. `pnpm sourceview:build` generates `reporting/thip_kpi_monthly.sql`, the read-only reporting table plus a per-fiscal-year refresh that emits measured rows — a registered HOSxP query over an empty cohort yields a measured zero cohort (0 facts, NULL value), while a missing source row or an unloaded external staging row yields an explicit `unavailable` row (`denominator = NULL`, `value = NULL`, `pending_reason`) — never a fabricated zero. The dashboard's coverage summary separates measured from unavailable cells.

Rule evidence (episode grain, period field, code set, owner, rule version, traceable references) is curated in `src/data/thipRuleEvidence.ts`. Evidence readiness, SQL registration and publication approval are separate gates. `publishApprovedThip()` requires evidence readiness plus matching source/rule approval version and fiscal-year effectivity; targets additionally require hospital-target approval. All current real rules are unapproved. Structural completeness still requires 1,552 cells, while published measurement coverage is zero until certification.

The app follows the BMS baseline: HOSxP is read-only, SQL is allow-listed, parameters are typed, and no PHI is committed to the repository.

Before promoting a hospital reporting view, export only its normalized KPI rows and run the contract audit. The audit never prints row values or accepts raw HOSxP extracts:

```powershell
python scripts/thip_source_audit.py --input .\thip-kpi-export.json --fiscal-year 2026
```

It exits successfully only when the repository's 232-code/cadence manifest is covered by all 1,552 expected cells with unique periods, valid metadata, registered formula multipliers, value consistency, and safe denominator semantics.
