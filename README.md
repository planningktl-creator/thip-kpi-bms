# THIP KPI BMS

THIP KPI quality intelligence dashboard for a BMS Marketplace frontend. It provides a polished, responsive dashboard and monthly detail view with a safe demo fallback and a direct BMS read-only data path. The initial live slice covers three evidence-backed mortality indicators; a registered normalized source view can supply the complete hospital KPI set.

## What is included

- Dashboard view with fiscal-year trend, group health signals, priority indicators, and filters.
- Indicator library containing all 232 THIP 2025 dictionary entries, with wired/demo and pending-source states.
- Indicator detail view with 12 fiscal months, a monthly bar chart, line-trend toggle, annual rollup, numerator/denominator, target, status, definition, and source tables.
- Fiscal-year presentation that keeps ISO dates at the data boundary and renders Thai Buddhist Era dates/years in the frontend and CSV export.
- Keyboard-friendly navigation with skip link, labeled filters, table semantics, visible focus, reduced-motion support, and direct drill-through from group signals to the full catalogue.
- Demo data that is clearly labelled and safe to use without patient data. The dashboard starts with the full 232-entry catalogue in a no-data state and replaces wired indicators with live BMS results when the session is healthy.
- BMS session launch parsing and an in-memory `SELECT VERSION()` handshake through the registered query layer.
- Domain boundaries for session/transport, query registry, HOSxP adapter, indicator definitions, and UI.
- Export of the selected indicator's monthly result to CSV.

## Run locally

```bash
pnpm install
pnpm dev
```

Open the local Vite URL. Without a BMS launcher URL, the app stays in demo mode. A BMS launch URL may include `bms-session-id` and an optional `marketplace-token`; the app never writes either value to localStorage or logs them.

## Public preview

The demo frontend is also published as a public GitHub Pages preview:

https://planningktl-creator.github.io/thip-kpi-bms/

## BMS deployment

The intended BMS Marketplace deployment follows the same container contract as `IPTImprove`: a multi-stage Docker build, an unprivileged Nginx runtime on container port `8080`, SPA fallback, immutable asset caching, security headers, CSP, and a `/healthz` endpoint.

Build and run locally with Docker Compose:

```bash
docker compose build --build-arg BMS_ALLOWED_ORIGINS="https://hosxp.net https://10929-f446.tunnel.hosxp.net" --build-arg VITE_BMS_APP_IDENTIFIER="THIP.KPI.BMS" --build-arg VITE_BMS_KPI_SOURCE_VIEW=""
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

When `VITE_BMS_KPI_SOURCE_VIEW` is empty, the app runs the evidence-backed HOSxP foundation query for `DH0101`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, and `DN0109`. To expose more indicators, register a normalized read-only source view and build with `VITE_BMS_KPI_SOURCE_VIEW` set to its table/view name. The view contract is documented in `docs/THIP-DATA-CONTRACT.md`.

The repository intentionally keeps the GitHub mirror remote separate from the BMS deployment remote. The BMS remote and application identifier must be supplied by the platform owner before production registration.

## Build and test

```bash
pnpm build
pnpm test
```

The Playwright visual smoke also runs a token-free mocked BMS session through PasteJSON, the PostgreSQL version probe, and the KPI query path. It verifies that live KPI rows reach the dashboard without writing session data to browser storage.

## Data boundary

`HOSxP Structure.xlsx` is used as a schema inventory. `THIP KPI.pdf` is the 2025 KPI dictionary and defines the five THIP groups (D, C, S, H, A), monthly reporting expectation, and numerator/denominator model. The first live foundation query uses the PDF definitions for `DH0101` (PDF page 39), `DH0102` (page 42), `DN0101` (page 67), `DR0101` (page 79), `CE0101` (page 194), `CI0101` (page 199), `DG0202` (page 123), `DR0403` (page 90), `DR0102` (page 80), `DN0107` (page 73), `DH0112` (page 54), and `DN0109` (page 74), together with the HOSxP `ipt`, `an_stat`, `iptdiag`, `death`, `opitemrece`, and `drugitems` tables. The query preserves raw numerator/denominator counts and returns one row per indicator/month. Hospital-specific source views and further KPI SQL must still be validated on anonymized staging data before being enabled.

The 232-entry indicator library is intentionally complete at the catalogue/definition level. Twelve IPD indicators can now be replaced by BMS results when the session/API is healthy. The remaining catalogue entries keep their no-data state until their hospital source rules are mapped; a normalized source view can replace all catalogue entries at once.

The app follows the BMS baseline: HOSxP is read-only, SQL is allow-listed, parameters are typed, and no PHI is committed to the repository.
