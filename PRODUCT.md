# THIP KPI BMS

This product helps hospital quality staff and KPI owners inspect THIP indicators and follow monthly performance. It is a React/Vite BMS Marketplace frontend. The THIP KPI dictionary and the repository's evidence mapping govern definitions; local clinical formulas require hospital approval.

The workspace defaults to an unapproved THIP reporting matrix with an explicit monthly-monitoring tab. A single root data owner loads once and keeps the queue alive across SPA navigation; every route reads the same aggregate facts. Review mode exposes validated drafts with conspicuous labels; approved mode preserves publication gates and legacy certified charts/export. Review CSV is separately marked UNAPPROVED REVIEW. The operational matrix of 232 KPI rows and twelve fiscal months, October through September. Search by code/name, filter by group/data state/assessment, choose the fiscal year, inspect a cell's aggregate facts and rule, and export all twelve months of matching rows. Year and filters persist in the URL and browser history. Desktop month columns fit the page width; narrow screens reflow each KPI into a labeled month grid without inner scrolling. Cell buttons support arrows, Enter, and a native details dialog with Escape and restored focus.

Monthly monitoring is a separate series of 2,784 slots with its own rules, accumulation methods and versions. Official THIP reporting retains its monthly, quarterly, semiannual and annual cadences and the existing 1,552 reporting cells. A quarterly or annual result must never be repeated as twelve monthly results.

Data truth is visible. Missing facts remain NULL; zero cohorts, missing sources, unapproved rules and future months are separate states. Hospital targets require a confirmed source, unit and effective interval. Dictionary benchmarks remain separate. Assessment text accompanies colors; the system watch criterion is explicitly identified.

Development preview is conspicuously labelled synthetic on screen and in CSV. It demonstrates seven representative scenarios while preserving all 232 rows and unavailable reasons. It is development-only; production builds reject the preview flag and exclude fixture rows. All real rules begin unapproved. SQL registration alone cannot authorize publication.

The existing navy/teal workspace, Thai typography and operational components are the visual authority for this extension. No redesign or illustrative imagery is part of this release.

Keep HOSxP read-only and SQL behind registered aggregate queries. Use launcher session credentials in memory only; strip them from the URL. Never persist or export credentials, PHI, raw patient rows, or synthetic results as real hospital performance. Reporting DDL is an offline provisioning artifact, never a frontend write operation.

Real-data activation is a later phase. Hospital owners must certify cohort, joins, event dates, observation windows, denominators, local code sets, target crosswalk and rule version, and reconcile aggregates with official reports before publication. This implementation uses schema, fixtures and mocked BMS, with no Issues, deployment or actual HOSxP access.

The shared matrix and detail offer period and fiscal cumulative views. Registered accumulation governs weighted ratios, fixed denominators, snapshots and source-only distinct/custom YTD. Computed period-fact YTD retains unconfirmed source coverage. Detail provides period-based exploratory control charts with weighted p-chart limits or Individuals limits from adjacent moving ranges, visible missing periods and statistical signals. Cumulative YTD is a separate trend; it is never used as a Shewhart observation. CSV includes both period and cumulative facts with provenance.
