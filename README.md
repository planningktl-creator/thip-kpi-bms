# THIP KPI BMS

THIP KPI quality intelligence dashboard for a BMS Marketplace frontend. The first slice is a polished, responsive dashboard and monthly detail view backed by a demo data contract. It is designed to switch to a registered BMS read-only query once the hospital-specific THIP numerator/denominator rules are confirmed.

## What is included

- Dashboard view with fiscal-year trend, group health signals, priority indicators, and filters.
- Indicator library containing all 232 THIP 2025 dictionary entries, with wired/demo and pending-source states.
- Indicator detail view with 12 fiscal months, a monthly bar chart, line-trend toggle, annual rollup, numerator/denominator, target, status, definition, and source tables.
- Fiscal-year presentation that keeps ISO dates at the data boundary and renders Thai Buddhist Era dates/years in the frontend and CSV export.
- Demo data that is clearly labelled and safe to use without patient data.
- BMS session launch parsing and an in-memory `SELECT VERSION()` handshake through the registered query layer.
- Domain boundaries for session/transport, query registry, HOSxP adapter, indicator definitions, and UI.
- Export of the selected indicator's monthly result to CSV.

## Run locally

```bash
pnpm install
pnpm dev
```

Open the local Vite URL. Without a BMS launcher URL, the app stays in demo mode. A BMS launch URL may include `bms-session-id` and an optional `marketplace-token`; the app never writes either value to localStorage or logs them.

## Build and test

```bash
pnpm build
pnpm test
```

## Data boundary

`HOSxP Structure.xlsx` is used as a schema inventory. `THIP KPI.pdf` is the 2025 KPI dictionary and defines the five THIP groups (D, C, S, H, A), monthly reporting expectation, and numerator/denominator model. The supplied files do not contain hospital KPI observations, so the UI does not invent live results. Hospital-specific KPI SQL must be added to `src/services/queryRegistry.ts` only after the source table/view, grain, code list, and data-quality rules are confirmed on anonymized staging data.

The 232-entry indicator library is intentionally complete at the catalogue/definition level. The first 12 indicators have demo monthly rows to exercise the dashboard and detail interaction; other indicators open the same 12-month detail contract with an explicit `no-data` state until their hospital source view is mapped.

The app follows the BMS baseline: HOSxP is read-only, SQL is allow-listed, parameters are typed, and no PHI is committed to the repository.
