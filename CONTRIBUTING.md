# Contributing

## Scope

This skill covers tracking, ingest, validation, analysis, visualisation and
monitoring of analytics data. Anything outside that path belongs in a separate
skill.

## Structure rules

- `SKILL.md` stays short: phase map, non-negotiables, reporting rules. Detail
  goes into `references/`.
- YAML frontmatter must keep `name` and `description`. The description carries
  the trigger words that make the skill retrievable — extend it when you add a
  platform.
- One reference file per phase. A new reference file must be linked from the
  matching phase section in `SKILL.md`.
- No code that must be executed: the skill is instructions, not a library.

## Content rules

- Every vendor claim needs a source in the provider's official documentation.
  If behaviour is version-dependent, say which version.
- Do not weaken the non-negotiables: shared `event_id`, aggregation in SQL,
  one query owner per metric, no PII client-side, consent gating on server
  sends, a monitor per integration.
- Examples are minimal and runnable in principle — no pseudo-SQL, no invented
  table names beyond the ones already used.
- Keep it stack-honest: if a rule assumes React + TanStack Query + Recharts or
  Postgres/BigQuery, say so instead of implying it is universal.

## Before opening a pull request

1. Run `./scripts/check-structure.sh` — it must pass.
2. Confirm no PII, tokens, project IDs, or customer data appear in examples.
3. Note in the PR description which phase you touched and why.
