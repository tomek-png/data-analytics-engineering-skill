# Data Analytics & Engineering — Agent Skill

An agent skill covering the full path from an event firing in the browser to a
decision-ready number: **track → distribute → prepare → validate → analyse →
visualise → monitor**.

Built for AI coding agents (Lovable, Claude Code, Cursor, and any tool that reads
`SKILL.md` files). It encodes the rules that keep analytics honest: one shared
`event_id` per real-world event, aggregation in SQL rather than in the client,
one query owner per metric, no PII in client payloads, consent gating on server
sends too, and a monitor shipped with every integration.

## What is inside

| File | Covers |
| --- | --- |
| `SKILL.md` | Phase map, non-negotiables, reporting rules |
| `references/tracking-datalayer.md` | Event contract (Zod), shared `event_id`, naming taxonomy, identity, PII rules, Consent Mode v2, SPA page views |
| `references/martech-integrations.md` | GTM (web + server-side), GA4 streams & Measurement Protocol, Meta Pixel + Conversions API, TikTok Pixel + Events API, deduplication, match quality |
| `references/data-preparation.md` | CSV/XLSX/JSON ingest, staging, normalisation, idempotency, large files |
| `references/data-quality.md` | Pre-display validation checks (row multiplication, nulls, duplicates, ranges) |
| `references/analysis-patterns.md` | SQL shapes for funnels, cohorts, retention, distributions, period-over-period, weighted scores |
| `references/bi-bigquery-ecosystem.md` | GA4 BigQuery export, `UNNEST`, partitioning & cost, star-schema modelling, Power BI (DAX, incremental refresh), Tableau (relationships, LOD) |
| `references/visualization.md` | Chart selection, insight-led headlines, Recharts conventions, design-token palette |
| `references/system-drift-and-monitoring.md` | CI contract tests, volume & null-rate alerts, schema-drift diffs, platform health (dedup rate, EMQ), metric reconciliation, vendor API sunsets |

## Platform coverage

Google Tag Manager (web container and server-side container), GA4 (web/app
streams, Measurement Protocol), Meta Pixel + Conversions API, TikTok Pixel +
Events API, Google Consent Mode v2, BigQuery (GA4 export and modelled
warehouse), Power BI, Tableau.

## Install

### Lovable

1. Copy the `.agents/skills/data-analytics-engineering/` folder into your project.
2. Activate it in **Settings → Skills**.
3. It loads automatically on analytics work, or invoke it by typing `/` in the composer.

### Claude Code / Claude Desktop

```bash
mkdir -p ~/.claude/skills
cp -r .agents/skills/data-analytics-engineering ~/.claude/skills/
```

Project-scoped instead of global: copy to `.claude/skills/` inside the repository.

### Cursor / other agents that read skill folders

```bash
cp -r .agents/skills/data-analytics-engineering <your-agent-skills-dir>/
```

The skill is plain Markdown with YAML frontmatter (`name`, `description`) — no
runtime, no dependencies, no build step.

## Usage examples

Natural-language prompts that activate the skill:

- *"Add conversion tracking for the signup form — GA4 plus Meta CAPI, deduplicated."*
  → Phase 0 event contract with a shared `event_id`, Phase 1 browser tag + server send,
  Phase 6 dedup-rate monitor.

- *"Build a KPI dashboard: leads per week, conversion rate, top 5 campaigns."*
  → Phase 4 SQL aggregation (one query owner per metric), Phase 5 chart selection,
  distinct empty/loading/error states, i18n labels.

- *"This CSV of 180k orders needs importing before the report."*
  → Phase 2 staging table and idempotent upsert, Phase 3 quality checks before display.

- *"Conversions in Meta Ads Manager are roughly double what our database says."*
  → Phase 6 duplicate diagnosis: shared `event_id`, dedup rate, then metric reconciliation.

- *"Query the GA4 BigQuery export for a 4-week retention cohort."*
  → `bi-bigquery-ecosystem.md`: `events_YYYYMMDD` finalisation window, safe `UNNEST`
  via subquery, partition pruning, then the cohort SQL shape.

## Design principles

1. **Contract first.** Events are validated against a schema before they are sent anywhere.
2. **One number, one owner.** Every metric has a single definition, reused by the app and by BI.
3. **Deduplication by construction.** The shared `event_id` is created once and travels to every destination.
4. **Privacy by default.** No PII in the data layer; advanced matching hashes server-side; consent gates server sends.
5. **Silence is the enemy.** Tracking breaks quietly, so every integration ships with its monitor.

## Verify the file structure

```bash
./scripts/check-structure.sh
```

It fails if `SKILL.md`, the frontmatter fields, or any of the eight reference
files are missing.

## Sources and attribution

Patterns were derived and adapted from these open repositories, then rewritten
for this phase model and stack:

- [`nimrodfisher/data-analytics-skills`](https://github.com/nimrodfisher/data-analytics-skills) — analysis and data-preparation patterns
- [`kgraph57/mckinsey-style-visualization-skill`](https://github.com/kgraph57/mckinsey-style-visualization-skill) — insight-led headline and chart-selection discipline
- [`jiannanya/snow-d3`](https://github.com/jiannanya/snow-d3) — visualisation structure
- [`diegosouzapw/awesome-omni-skills`](https://github.com/diegosouzapw/awesome-omni-skills) (`analytics-tracking/SKILL.md`) — tracking and tag-management groundwork

Vendor behaviour (GA4, Meta, TikTok, Consent Mode, BigQuery) reflects official
provider documentation at the time of writing. Platforms change: see
`references/system-drift-and-monitoring.md` for the vendor-watch routine.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
