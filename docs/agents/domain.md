# Domain Docs

This is a single-context repository. Before exploring or changing domain behaviour, read:

- `README.md` for the product boundary and local commands.
- `docs/THIP-DATA-CONTRACT.md` for the normalized indicator and reporting-period result contract.
- `docs/THIP-SOURCE-NOTES.md` for the evidence and limitations from the THIP KPI PDF and HOSxP schema workbook.
- `docs/adr/` when it exists and the change touches an architectural decision.

## Domain vocabulary

- **Indicator**: one THIP KPI code with its group, definition, formula, target, reporting cadence, and fiscal-year results.
- **Reporting-period result**: one `indicator_code × fiscal_year × fiscal_month` row preserving the ISO `periodStart`, Thai Buddhist display label, numerator, denominator, value, target, percentile, and status. The applicable fiscal months come from the indicator cadence (monthly, quarterly, semiannual, or annual).
- **Fiscal-year rollup**: one annual numerator/denominator/value/target/status summary derived from a selected October–September fiscal year.
- **Source view**: the hospital-specific BMS read-only table or view that supplies a normalized THIP reporting-period result.
- **No-data contract**: the explicit null-result state used when the app has no confirmed hospital source rows; it is never a fabricated metric.
- **Foundation query**: the twenty-four registered HOSxP IPD queries available only for local development and rule validation when no normalized source view is configured. They are assembled from per-family read-only queries that share one IPD base cohort, with an opt-in `ipt_drg_result` variant.
- **Implementation tier**: the classification of a code as `registered` (approved read-only query, measured rows) or `pending-local-source` (in the 232-code contract but still needing a hospital rule); recorded in `src/data/thipImplementation.ts`.
- **Reporting-layer artifact**: the generated `reporting/thip_kpi_monthly.sql` (DDL + per-fiscal-year refresh) that provisions the normalized source view with measured rows for registered codes and explicit `unavailable` rows for pending codes.
- **Complete live coverage**: all 232 catalogue codes present for every applicable reporting period of the selected fiscal year (1,552 cadence-aware cells for the 2025 dictionary), split into measured (`availableCellCount`) and explicit `unavailableCellCount`.
- **Rule evidence**: the traceable facts (episode grain, period field, code set version, owner, rule version, and references) that must be present before a rule can be published as `ready`; curated in `src/data/thipRuleEvidence.ts`.
- **Aggregate fixture**: a synthetic, PHI-free export of the normalized source-view contract derived from the repository manifests; used only by tests, the CI audit gate, and never by a runtime path.
- **Data freshness**: the classification of the last successful refresh as fresh, stale (past the SLA), or unavailable; the UI never renders an unavailable source as a zero result.
- **BMS data boundary**: session-scoped, read-only access to HOSxP through registered queries; no arbitrary SQL from the UI.

If a new feature needs a term not covered here, record the decision in an ADR or update the data contract before spreading the term through UI and tests.
