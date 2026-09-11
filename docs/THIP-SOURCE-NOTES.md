# THIP KPI source notes

These notes record the source boundary for the first implementation slice.

## THIP KPI Dictionary 2025

- Source: `C:/Users/KTLho/Desktop/THIP KPI.pdf`.
- The document describes 232 benchmark indicators for the 2025 dictionary.
- The catalogue is organised into five groups: Disease (D), Care process (C), System (S), Health promotion (H), and Ambulatory care (A).
- Indicator codes use two group/category letters followed by two two-digit sequences, for example `DH0101`.
- Indicator reporting uses a numerator and denominator, commonly expressed as `(a/b) x 100`; the dictionary includes monthly, quarterly, semiannual, and annual cadences recorded in `src/data/thipReporting.ts`.
- The database boundary remains ISO and fiscal years run October through September; the frontend maps the ISO period to Thai Buddhist Era labels (for example, `2025-10-01` becomes `ต.ค. 2568`).
- HOSxP stores ICD-10 codes without the decimal point (for example `A409` instead of `A40.9`). Every registered query compares diagnosis and death-cause codes through `REPLACE(UPPER(TRIM(col)), '.', '')` against dotless literals so both dotted and dotless source values match.
- The detail page in the dashboard keeps the numerator, denominator, formula, frequency, and reference visible so a reviewer can trace the result.

## HOSxP Structure

- Source: `C:/Users/KTLho/Desktop/HOSxP Structure.xlsx`.
- The workbook is a schema inventory, not a result dataset.
- Relevant columns observed for the BMS read-only foundation include `ipt.an`, `ipt.regdate`, `ipt.dchdate`, `ipt.ward`, `ipt.drg`, `ipt.rw`, `ipt.adjrw`, `an_stat.item_money`, `iptdiag.icd10`, `iptoprt.icd9`, `iptbedmove.movedate`, `ward.name`, `opitemrece.vstdate`, `opitemrece.vsttime`, `opitemrece.icode`, and `drugitems.name`, `drugitems.antibiotic`, `drugitems.drugcategory`.
- The inventory alone does not establish local business meaning, ICD inclusion/exclusion lists, or THIP numerator/denominator logic. Those must be validated against anonymised staging data before live KPI queries are enabled.

## Current product decision

The UI ships with the full 232-entry catalogue in a no-data state and replaces indicators with live BMS results when the session is healthy. The first query implements `DH0101`, `DH0101.1`, `DH0101.2`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, `DN0109`, and `DN0302` from the PDF definitions using `ipt`, `an_stat`, `iptdiag`, `death`, `opitemrece`, and `drugitems`, returning one row per indicator and reporting period. `DH0101.1`/`DH0101.2` separate STEMI and NSTE-ACS cohorts using the printed pages 40/41; `DG0102` is a Pdx-based UGIH length-of-stay aggregate from printed page 121; `DN0302` measures head-injury mortality within 48 hours of admit using printed page 77 and the HOSxP admission/death timestamps; `CE0101`/`CI0101` use the PDF sepsis code sets (printed pages 194/199), and the `DR0102`/`DN0107` re-admission rule currently uses a documented approximation because the supplied schema inventory does not provide a signed local mapping for the THIP `status=improve`/unplanned exclusion. The app keeps the other indicators on the no-data contract until their hospital-specific numerator/denominator rules are confirmed.

For a complete hospital implementation, register a normalized read-only source view and set `VITE_BMS_KPI_SOURCE_VIEW`. The production Docker image and browser runtime both fail closed without that variable, and the frontend accepts a complete result only when the view covers every applicable reporting period for all 232 codes (1,552 cadence-aware cells per fiscal year). The view contract is recorded in `docs/THIP-DATA-CONTRACT.md`; it allows the same frontend to replace all catalogue entries without exposing raw patient rows.
