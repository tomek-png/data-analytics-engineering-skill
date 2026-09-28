---
name: data-analytics-engineering
description: Use when preparing, validating, analysing, tracking or visualising data — CSV/XLSX imports, SQL aggregations, KPI dashboards, charts, funnels, cohorts, data-quality audits, analytics tracking and warehouse/BI work. Triggers on "dashboard", "chart", "wykres", "raport", "analiza danych", "KPI", "import CSV", "funnel", "cohort", "data quality", "data layer", "dataLayer", "tracking", "GTM", "Tag Manager", "GA4", "Google Analytics", "Meta Pixel", "Conversions API", "CAPI", "TikTok Pixel", "Consent Mode", "measurement protocol", "BigQuery", "hurtownia danych", "Power BI", "DAX", "Tableau", "atrybucja", "event tracking", "schema drift".
---

# Data Analytics & Engineering

Covers the full path from an event firing in the browser to a decision-ready number: track → prepare → validate → analyse → visualise, plus the monitoring that keeps it true over time. Pick the phases the task needs; do not run all of them for one chart.

## When to use
- Building or changing a dashboard, report, KPI tile, chart, funnel or cohort view.
- Implementing or auditing analytics tracking: data layer, GTM, GA4, Meta, TikTok, consent.
- Ingesting or cleaning external data (CSV, XLSX, JSON, API pulls) before it reaches the database.
- Modelling in a warehouse or wiring Power BI / Tableau to it.
- A number looks wrong and you need to trace it back to the event or the source query.

## Non-negotiables
- **One real-world event, one `event_id`, generated once and reused by every destination** (browser tag, server API, warehouse row). This is what makes deduplication possible; without it paid-media conversions double-count.
- **Aggregate in the database, not in React.** GROUP BY / window functions in SQL, an RPC or a server function; the component receives rows ready to render. A `.reduce()` over thousands of client rows is a bug, not an optimisation.
- **One query owner per metric.** A metric is defined once (SQL view, RPC, warehouse model) and reused everywhere, including BI tools. Two surfaces computing "conversion rate" differently is a regression waiting to happen.
- **No PII in the data layer or in any client-side payload.** Advanced matching uses normalised, server-side SHA-256 hashes.
- **Consent gates server-side sends too.** A consent check that only covers the browser tag is not compliance.
- **TanStack Query for every read**, with stable query keys including all filters. No `useEffect` fetching, no metric state in a global store.
- **Never hardcode chart labels, axis titles, tooltips or empty-state copy** — they are i18n keys.
- **RLS applies to analytics too.** Aggregates are scoped by owner/role; never reach for a privileged client to make a dashboard number appear.
- **Empty, loading and error are three distinct states.** A chart with no data renders an explanatory empty state, never a blank box or `NaN`.
- **Every integration ships with its monitor** in the same change. Tracking fails silently; unmonitored tracking is undetected data loss.

## Phase 0 — Track (event contract)
Read `references/tracking-datalayer.md` before emitting or changing any analytics event: event schema and versioning, the shared `event_id`, naming taxonomy, identity, PII rules, Consent Mode v2, SPA page views.

## Phase 1 — Distribute (platforms)
Read `references/martech-integrations.md` when wiring or debugging GTM (web and server-side), GA4 streams and Measurement Protocol, Meta Pixel + Conversions API, or TikTok Pixel + Events API — including the deduplication and match-quality rules.

## Phase 2 — Prepare (ingest & clean)
Read `references/data-preparation.md` before writing an importer or transform: staging, normalisation, idempotency, large files.

## Phase 3 — Validate
Run the checks in `references/data-quality.md` before trusting any number you display. Cheap, and it catches the class of bug where a join silently multiplies rows.

## Phase 4 — Analyse
`references/analysis-patterns.md` has the SQL shapes for funnels, cohorts, retention, distributions, period-over-period and weighted scores.

For warehouse-scale work — GA4 BigQuery export, unnesting, partitioning and cost, star-schema modelling, Power BI and Tableau conventions — read `references/bi-bigquery-ecosystem.md`.

## Phase 5 — Visualise
`references/visualization.md` covers chart selection, the insight-led headline rule, Recharts conventions and the design-token palette. Read it before choosing a chart type — the most common failure is a pie chart where a sorted bar chart was needed.

## Phase 6 — Monitor
Read `references/system-drift-and-monitoring.md` whenever you add tracking, change a schema, or investigate a suspicious number: CI contract tests on the data layer, volume and null-rate alerts, schema-drift diffs, platform health checks (dedup rate, Event Match Quality), metric reconciliation across warehouse and BI, and watching vendor API sunsets.

## Reporting a result
State the number, the population it covers, the time range, and any row you excluded and why. A number without its denominator is not an answer. If a monitor or quality check failed, say what it affects before presenting the figure.

Derived from patterns in nimrodfisher/data-analytics-skills, kgraph57/mckinsey-style-visualization-skill, jiannanya/snow-d3 and diegosouzapw/awesome-omni-skills (analytics-tracking), adapted to this stack.
