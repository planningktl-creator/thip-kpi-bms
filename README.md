# THIP KPI BMS

THIP KPI quality intelligence dashboard for a BMS Marketplace frontend. The first slice is a polished, responsive dashboard and monthly detail view backed by a demo data contract. It is designed to switch to a registered BMS read-only query once the hospital-specific THIP numerator/denominator rules are confirmed.

## What is included

- Dashboard view with fiscal-year trend, group health signals, priority indicators, and filters.
- Indicator detail view with 12 fiscal months, numerator/denominator, target, status, trend, definition, and source tables.
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

The app follows the BMS baseline: HOSxP is read-only, SQL is allow-listed, parameters are typed, and no PHI is committed to the repository.
