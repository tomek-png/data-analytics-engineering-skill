# Warehouse & BI ecosystem (BigQuery, Power BI, Tableau)

Contents: GA4 export shape · UNNEST · dedup · sessions · cost control · modelling layer · Power BI · Tableau · reconciliation.

## GA4 BigQuery export: what you actually get

- `analytics_<property>.events_YYYYMMDD` — daily, finalised ~72h after the day closes and **can be restated**; `events_intraday_*` is incremental and incomplete. Never report finals from intraday.
- One row per event. `event_params` and `user_properties` are `ARRAY<STRUCT<key, value STRUCT<string_value, int_value, float_value, double_value>>>` — the value lives in exactly one typed field, so pick the right one or get NULL.
- There is no session table and no `session_id` column; sessions are derived from `event_params.ga_session_id` + `user_pseudo_id`.
- Export is not backfilled. Enabling it late means that history does not exist.

## Unnesting without exploding rows

Subquery per parameter keeps one row per event. `CROSS JOIN UNNEST` in the main FROM multiplies rows by parameter count — the classic cause of "impossible" totals.

```sql
select
  timestamp_micros(event_timestamp)                                          as occurred_at,
  user_pseudo_id, event_name,
  (select value.string_value from unnest(event_params) where key = 'event_id')      as event_id,
  (select value.int_value    from unnest(event_params) where key = 'ga_session_id') as ga_session_id,
  (select coalesce(value.double_value, value.float_value, cast(value.int_value as float64))
     from unnest(event_params) where key = 'value')                                as value
from `proj.analytics_123.events_*`
where _table_suffix between format_date('%Y%m%d', @from) and format_date('%Y%m%d', @to);
```

Always constrain `_table_suffix` — a wildcard scan without it reads the whole property history and bills for it.

## Deduplication

The export can contain duplicates (retries, dual-send, intraday overlap). Deduplicate on your contract `event_id`, and where absent on the GA4 tuple:

```sql
qualify row_number() over (
  partition by coalesce(event_id, concat(user_pseudo_id, event_name, cast(event_timestamp as string)))
  order by event_timestamp
) = 1
```

## Storage & cost

- Target tables: partition by `date(occurred_at)` (or ingestion time), cluster by the columns you filter most (`event_name`, `user_pseudo_id`, `tenant_id`). Clustering is what makes per-user lookups cheap.
- BigQuery bills scanned *columns*, not rows: `select *` on an event table is the most expensive query you can write. Never use it in a model or a BI connection.
- Materialise a curated layer (staging → facts/dims) on a schedule instead of letting BI tools query raw export directly. Raw-export dashboards are slow, expensive, and re-derive business logic in every tool.
- Set partition expiration on staging; keep curated facts long-lived.

## Modelling layer (the contract with BI)

Build a star schema in the warehouse, not in the BI tool:

- `fact_events` (event grain), `fact_sessions`, `fact_leads`, `fact_orders` — narrow, additive measures plus foreign keys.
- `dim_date`, `dim_user`, `dim_campaign` (channel grouping resolved **once**, here — not in DAX and again in Tableau), `dim_product`.
- Resolve attribution, channel grouping, currency conversion and business-rule filters in the model. Every rule left to the BI layer will be implemented differently in each tool and the two dashboards will disagree.
- One dimension table per concept, surrogate keys, no snowflaking unless a dimension is genuinely huge.

## Power BI

- **Import** for curated star schemas (fast, DAX-complete); **DirectQuery** only when near-real-time is a stated requirement — it pushes every visual interaction to BigQuery and the cost is per-click.
- Incremental refresh: partition on a `RangeStart`/`RangeEnd` datetime parameter over the fact's date column, and let query folding push the filter into BigQuery. Without folding the "incremental" refresh reads everything.
- Single-direction relationships from dim to fact; avoid bidirectional cross-filtering, which creates ambiguous paths and wrong totals.
- Mark `dim_date` as the date table; time intelligence (`SAMEPERIODLASTYEAR`, `DATESYTD`) silently misbehaves without it.
- DAX: `DIVIDE(num, den)` never `/` (handles zero denominators); aggregate with measures, not calculated columns on facts; avoid row-by-row iterators (`SUMX` over a large fact) where a plain aggregation works.
- One measure per metric, named as the business names it. Duplicated near-identical measures are how two pages start disagreeing.

## Tableau

- Use the logical layer's **relationships** (noodles) rather than physical joins — relationships keep the fact grain intact instead of fanning out measures.
- Extracts (Hyper) for curated models; live connection only with the same justification as DirectQuery.
- LOD expressions to fix the grain: `{FIXED [user_id] : MIN([first_seen])}` for cohorts, `INCLUDE`/`EXCLUDE` for per-segment averages. Computing these client-side over raw rows is what makes Tableau workbooks crawl.
- Context filters before LOD-sensitive filters, or the LOD ignores the filter and the number is wrong.
- Published data source per model, one owner. Ad-hoc workbook-local connections re-implement logic and drift.

## Reconciliation

A metric that exists in GA4, BigQuery, Power BI and Tableau must be reconciled explicitly, because small differences are expected and large ones are bugs:
- GA4 UI vs BigQuery export: the UI applies thresholding, sampling and modelled conversions; the export does not. Differences of a few percent on user counts are normal, identical event counts are expected.
- BigQuery facts vs BI measures: must match to the row. Any gap is a filter or a join, not "rounding".
- Automate the comparison and alert on drift — see `system-drift-and-monitoring.md`.
