# THIP KPI BMS

THIP KPI quality intelligence dashboard for a BMS Marketplace frontend. It provides a polished, responsive dashboard and reporting-period detail view backed by a direct BMS read-only data path. Production never fabricates KPI values: without a live session or a source row, the UI stays explicitly no-data.

## What is included

- Dashboard view with fiscal-year trend, group health signals, priority indicators, and filters.
- Indicator library containing all 232 THIP 2025 dictionary entries, with live, partial, and no-data states.
- Indicator detail view with a 12-slot fiscal-year timeline, reporting-period bar chart, line-trend toggle, annual rollup, numerator/denominator, target, status, definition, and source tables.
- Fiscal-year presentation that keeps ISO dates at the data boundary and renders Thai Buddhist Era dates/years in the frontend and CSV export.
- Keyboard-friendly navigation with skip link, labeled filters, table semantics, visible focus, reduced-motion support, and direct drill-through from group signals to the full catalogue.
- No synthetic production metrics or frontend-seeded benchmarks. The dashboard starts with the full 232-entry catalogue in a no-data state and replaces indicators with live BMS results only when the session and registered query return rows; targets are accepted only from the approved source view.
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

Production builds fail closed when `VITE_BMS_KPI_SOURCE_VIEW` is empty: the Docker image rejects the build and the browser runtime also refuses the incomplete configuration. A complete hospital release must provide all 232 indicators through the normalized read-only source view. In local Vite development only, an empty value runs the evidence-backed HOSxP foundation query for `DH0101`, `DH0101.1`, `DH0101.2`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, `DN0109`, and `DN0302` for query validation. The view contract is documented in `docs/THIP-DATA-CONTRACT.md`.

The repository intentionally keeps the GitHub mirror remote separate from the BMS deployment remote. The BMS remote and application identifier must be supplied by the platform owner before production registration.

## Build and test

```bash
pnpm build
pnpm test
```

`pnpm fixture:export` regenerates the synthetic aggregate fixtures from the repository manifests (232 codes, 1,552 cadence-aware cells, plus six deliberately invalid variants). `python scripts/check-thip-fixtures.py` asserts the complete fixture passes the source audit and every invalid fixture fails it; CI runs both before the build. `pnpm sourceview:build` regenerates `reporting/thip_kpi_monthly.sql`. The fixtures contain no patient data and are never imported from a runtime path.

The Playwright visual smoke also runs a token-free mocked BMS session through PasteJSON, the PostgreSQL version probe, and the KPI query path. Run it while the repository Vite server is available (or set `THIP_SMOKE_BASE_URL`); it verifies that live KPI rows reach the dashboard without writing session data to browser storage.

## Data boundary

`HOSxP Structure.xlsx` is used as a schema inventory. `THIP KPI.pdf` is the 2025 KPI dictionary and defines the five THIP groups (D, C, S, H, A), the reporting cadence (112 monthly, 19 quarterly, 31 semiannual, and 70 annual indicators), and the numerator/denominator model. The first live foundation query uses the PDF definitions for `DH0101` (PDF page 39), `DH0101.1` (page 40), `DH0101.2` (page 41), `DH0102` (page 42), `DG0102` (page 121), `DN0101` (page 67), `DR0101` (page 79), `CE0101` (page 194), `CI0101` (page 199), `DG0202` (page 123), `DR0403` (page 90), `DR0102` (page 80), `DN0107` (page 73), `DH0112` (page 54), `DN0109` (page 74), and `DN0302` (page 77), together with the HOSxP `ipt`, `an_stat`, `iptdiag`, `death`, `opitemrece`, and `drugitems` tables. The query preserves raw numerator/denominator counts and returns one row per indicator/reporting period. Hospital-specific source views and further KPI SQL must still be validated on anonymized staging data before being enabled.

The 232-entry indicator library is complete at the catalogue/rule level. The THIP 2025 dictionary contains 112 monthly, 19 quarterly, 31 semiannual, and 70 annual indicators. Twenty-four IPD indicators now have registered foundation SQL for local validation. The foundation SQL is assembled from per-family read-only queries (`thipAcsFoundation`, `thipStrokeFoundation`, and so on) that share one IPD base cohort (`src/services/thipIpdBase.ts`), so a family can be extended without touching the frontend contract; `queryRegistry.thipIpdDrgResultFoundation` is an opt-in variant for sites whose coded diagnosis lives in the local `ipt_drg_result` relation. A production normalized source view must return one row per indicator and reporting period (1,552 expected cells per fiscal year); incomplete responses fail closed in production and never become a complete live release. Local development can opt into a visible partial state while the source view is assembled. The cadence registry is in `src/data/thipReporting.ts`.

Every code is classified in `src/data/thipImplementation.ts` as `registered` (approved read-only query, measured rows) or `pending-local-source` (in the 232-code contract but still needing a hospital rule, with a documented reason). `pnpm sourceview:build` generates `reporting/thip_kpi_monthly.sql`, the read-only reporting table plus a per-fiscal-year refresh that emits measured rows for registered codes and explicit `unavailable` rows (`denominator = NULL`, `value = NULL`, `pending_reason`) for the rest — never a fabricated zero. The dashboard's coverage summary separates measured from unavailable cells.

Rule evidence (episode grain, period field, code set, owner, rule version, and traceable references) is curated in `src/data/thipRuleEvidence.ts` and merged into the manifest. A rule may only be published as `ready` when every evidence field is present; `getRuleReadiness()` and `assertRuleReadiness()` enforce that, and the dashboard shows a freshness/coverage panel that distinguishes unavailable, stale, partial, and complete live data instead of rendering a missing source as zero.

The app follows the BMS baseline: HOSxP is read-only, SQL is allow-listed, parameters are typed, and no PHI is committed to the repository.

Before promoting a hospital reporting view, export only its normalized KPI rows and run the contract audit. The audit never prints row values or accepts raw HOSxP extracts:

```powershell
python scripts/thip_source_audit.py --input .\thip-kpi-export.json --fiscal-year 2026
```

It exits successfully only when the repository's 232-code/cadence manifest is covered by all 1,552 expected cells with unique periods, valid metadata, registered formula multipliers, value consistency, and safe denominator semantics.
