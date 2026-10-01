# Monthly monitoring UI handoff

This document records the implemented monthly monitoring extension. `PRODUCT.md` and `tmp/monitoring-release/design-contract.md` establish its scope: an operational matrix for hospital quality staff and KPI owners, within the existing navy/teal workspace. This is feature guidance, not a replacement design system. The CSS remains the source of truth for visual values.

## Evidence

Source reviewed: `src/styles.css`, `src/components/MonitoringPage.tsx`, and `src/components/Sidebar.tsx`. Live development browser captures reviewed:

- `tmp/monitoring-release/preview-desktop.png`: all 232 KPI rows, synthetic banner, filters, coverage and matrix in the desktop workspace.
- `tmp/monitoring-release/preview-mobile.png`: search first, paired filters, stacked actions and the horizontally scrollable matrix with KPI identity visible.
- `tmp/monitoring-release/preview-measured-desktop.png`: seven matching synthetic scenarios with numeric values, units and assessment text.
- `tmp/monitoring-release/preview-detail-desktop.png`: native details dialog, synthetic notice, aggregate facts and separate target/benchmark fields.

The release contract identifies Chromium capture viewports of 1440×1000 and 390×844. The image files include full-page content beyond the viewport. `tmp/monitoring-release/browser-checks.json` records passing matrix dimensions, keyboard/focus restoration, URL history, mobile scrolling, drawer, CSV, empty/error states and session checks, with no page errors. These are recorded checks; this documentation pass did not rerun browser automation.

## Layout and responsive behavior

The page presents its monthly-series heading and THIP-report overview action, then the synthetic notice when applicable, labelled filters, matching-row count and actions, measured coverage, keyboard/assessment help and the table. Monthly monitoring remains visibly distinct from official THIP reporting cadence.

The semantic table retains all 232 KPI identities and 2,784 month buttons in the DOM. Filters apply native `hidden` to nonmatching rows; clearing a filter reuses the same elements. Each visible row retains every month and matches when at least one month meets the selected data-state and assessment filters. Browser Find can search the full displayed table when filters are cleared. The toolbar includes fiscal year, code/name search, group, data state and assessment. Year and filters persist in the URL/history. CSV exports all twelve months of matching rows.

Desktop uses the incumbent fixed-width navy sidebar (268px), pale canvas and white work surfaces. Main content has a centered width limit of 1440px, with responsive outer padding. Monitoring sections use a 16px gap. The matrix has a minimum width of 1480px in a two-axis scroll region limited to 67vh. Its 54px month header stays at the top; the 280px KPI column stays at the left. The corner header layers above both. KPI titles occupy at most two visible lines; the row header retains its full title attribute and the details dialog shows the full title.

At 680px and below, the heading stacks, search becomes the first full-width filter, and the other filters share two columns with a 12px gap. Actions wrap. The KPI column narrows to 180px; the matrix remains at least 1380px wide and the scroll region is limited to 65vh. Months scroll horizontally while the KPI identity remains visible. The mobile shell uses 14px horizontal padding and an off-canvas navigation drawer. The dialog uses single-column facts and 18px padding instead of desktop's 175px label column, 14px column gap and 24px padding.

## Visual rules for this feature

Preserve the existing CSS palette and type treatment. Navy (`--navy`, #0a2035) anchors navigation; dark ink (`--ink`, #12263a) carries primary text; softer ink (`--ink-soft`, #365166) carries supporting text. White surfaces sit on the pale canvas (`--canvas`, #f4f7f8), with fine borders (`--line`, #dfe8ed). Teal KPI codes and the aqua navigation rail continue the incumbent identity.

Thai UI text inherits IBM Plex Sans Thai with Noto Sans Thai, Tahoma and sans-serif fallbacks. The heading uses a 24–32px responsive size and 1.35 line height. Supporting copy is 12–13px. KPI codes use the inherited Space Grotesk treatment at 12px; cell values use 600-weight 15px Space Grotesk with tabular numerals. KPI titles use 11px text and 1.6 line height; cell assessment text uses 10px and units 9px. These describe this shipped dense table, rather than establish new global typography rules.

Cells remain rectangular, with a minimum height of 73px, centered value/status/unit and fine row/column separators. The table container has 12px rounded corners; fields have 8px corners and a minimum height of 42px. The preview notice uses a pale amber surface and dark amber text, with 10px corners. The native dialog has 14px corners, a dimmed navy backdrop, a maximum height of 85vh and width capped at 760px or viewport width minus 24px. Its shadow conveys modal depth; the KPI column's slight right-hand shadow marks the sticky boundary. No decorative imagery was introduced.

| Cell meaning | Text treatment | Surface treatment |
| --- | --- | --- |
| On track | Green #09685b and explicit Thai assessment | Pale green #ecf8f3 |
| Watch | Amber #76500b and explicit Thai assessment | Pale amber #fff7df |
| Action required | Red #9c342b and explicit Thai assessment | Pale red #fff0ed |
| No target | Blue-gray #385571 and explicit Thai assessment | Pale blue #f0f5fa |
| Zero cohort | Blue-gray #486474 and explicit unavailable-state text | Pale gray #f3f7f8 |
| Future month | Gray #5c6e7b and explicit unavailable-state text | Pale gray #f6f8fa |
| Missing source or unapproved rule | Default muted text and explicit unavailable-state text | Default white |

Use the text with the color. Unavailable values display an em dash, with NULL facts and reasons preserved in details. Never style them as measured zero. The help text explicitly names the system watch criterion (8% of target or 0.02; interval targets use watch only when the rule defines it). Synthetic notices remain conspicuous on the page and in synthetic details, and CSV identifies the preview truth.

## Interaction and accessibility

- Keep native table semantics: scoped column/row headers, a screen-reader caption, descriptive keyboard help and a labelled, focusable scroll region. Loading marks the table busy; coverage uses a polite live region, errors use an alert and preview uses status semantics.
- Each cell is a native button with a label identifying KPI, period and value/unit/assessment or unavailable reason. Roving tab focus provides one matrix entry point. Arrows move between visible rows/months; Home/End move to the first/last month; movement clamps at the boundary. Enter activates the cell.
- Cell keyboard focus has an inset 3px teal outline. Other controls retain the incumbent visible focus treatment. Hover feedback and selection coloring remain secondary to explicit status text and keyboard focus.
- Details use `dialog.showModal()` and an accessible title. The labelled close button receives initial focus. Escape or the close button dismisses the dialog and restores focus to the opener. Facts use a definition list and wrap long content; modal scrolling preserves access to the complete record.
- Closed mobile navigation is inert. An open drawer focuses its first button, cycles Tab between buttons, closes on Escape and restores prior focus. The current workspace item uses `aria-current="page"`.
- Empty results explain the filter mismatch and provide a reset. Typing is immediate while deferred filtering reports a pending state. Refresh disables while loading; export disables while filtering is pending, loading, on errors, without a matching year/session snapshot or with no rows. Year/session changes immediately discard old displayed facts and dialog contents. Existing reduced-motion CSS suppresses smooth scrolling and substantially shortens transitions/animations.

Rows/cells are memoized; delegated keyboard/focus/click handlers update the current cell without recreating the whole matrix. Detail contents mount only while open. Thai/Latin fonts are app-hosted WOFF2 with `font-display: swap` and existing fallbacks. Route asset failures show an explicit retry; a further failure offers a manual page reload with a notice that session verification and unfinished requests restart while stored aggregates remain in cache. There is no automatic reload loop. See [production lab measurements](THIP-PERFORMANCE-2026-10-02.md).

## Inherited drift and limits

The detector's inherited Space Grotesk font warnings remain acknowledged. Preserving incumbent typography was expressly required; the warning is not converted into a new design-system rule or a recommendation for unrelated future surfaces.

The final `Sidebar.tsx` and CSS both use 680px for the drawer/mobile boundary. At wider tablet widths, the visible sidebar remains interactive. The additional live capture `tmp/monitoring-release/preview-tablet.png` shows the 800px layout with the incumbent sidebar, wrapped filters and horizontally scrollable matrix. The updated browser evidence records twenty passing checks, including the 800px sidebar being visible, not inert, and navigable while the mobile trigger remains hidden. No unresolved sidebar breakpoint mismatch is carried into this handoff.

No new global token system, creative workshop, `DESIGN.md` or design sidecar is warranted by this ordinary extension. Real-data publication remains dependent on approved hospital rules and targets; the demonstrated scenarios are development-only synthetic aggregates.
