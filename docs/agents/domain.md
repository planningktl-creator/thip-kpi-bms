# Domain Docs

This is a single-context repository. Before exploring or changing domain behaviour, read:

- `README.md` for the product boundary and local commands.
- `docs/THIP-DATA-CONTRACT.md` for the normalized indicator and monthly-result contract.
- `docs/THIP-SOURCE-NOTES.md` for the evidence and limitations from the THIP KPI PDF and HOSxP schema workbook.
- `docs/adr/` when it exists and the change touches an architectural decision.

## Domain vocabulary

- **Indicator**: one THIP KPI code with its group, definition, formula, target, and monthly results.
- **Monthly result**: one `indicator_code × fiscal_year × fiscal_month` row preserving the ISO `periodStart`, Thai Buddhist display label, numerator, denominator, value, target, percentile, and status.
- **Fiscal-year rollup**: one annual numerator/denominator/value/target/status summary derived from a selected October–September fiscal year.
- **Source view**: the hospital-specific BMS read-only table or view that supplies a normalized THIP monthly result.
- **Demo contract**: the safe local sample data used when the app has no confirmed hospital source view.
- **BMS data boundary**: session-scoped, read-only access to HOSxP through registered queries; no arbitrary SQL from the UI.

If a new feature needs a term not covered here, record the decision in an ADR or update the data contract before spreading the term through UI and tests.
