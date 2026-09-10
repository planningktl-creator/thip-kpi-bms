# THIP KPI source notes

These notes record the source boundary for the first implementation slice.

## THIP KPI Dictionary 2025

- Source: `C:/Users/KTLho/Desktop/THIP KPI.pdf`.
- The document describes 232 benchmark indicators for the 2025 dictionary.
- The catalogue is organised into five groups: Disease (D), Care process (C), System (S), Health promotion (H), and Ambulatory care (A).
- Indicator codes use two group/category letters followed by two two-digit sequences, for example `DH0101`.
- Monthly indicator reporting uses a numerator and denominator, commonly expressed as `(a/b) x 100`.
- The detail page in the dashboard keeps the numerator, denominator, formula, frequency, and reference visible so a reviewer can trace the result.

## HOSxP Structure

- Source: `C:/Users/KTLho/Desktop/HOSxP Structure.xlsx`.
- The workbook is a schema inventory, not a result dataset.
- Relevant columns observed for the BMS read-only foundation include `ipt.an`, `ipt.regdate`, `ipt.dchdate`, `ipt.ward`, `ipt.drg`, `ipt.rw`, `ipt.adjrw`, `an_stat.item_money`, `iptdiag.icd10`, `iptoprt.icd9`, `iptbedmove.movedate`, and `ward.name`.
- The inventory alone does not establish local business meaning, ICD inclusion/exclusion lists, or THIP numerator/denominator logic. Those must be validated against anonymised staging data before live KPI queries are enabled.

## Current product decision

The UI ships with a clearly labelled demo data contract. The live BMS handshake is implemented, but the app deliberately does not pretend that a generic HOSxP schema is a complete THIP calculation engine. The next data task is to confirm the hospital-specific THIP source view or submission table and then add one registered query per use case.
