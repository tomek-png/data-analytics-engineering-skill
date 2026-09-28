# Analysis patterns

All of these belong in SQL (view, RPC or Edge Function), returning a small result set.

## Funnel
One row per stage with an ordinal, absolute count, conversion from previous stage, and conversion from the top. Count **distinct subjects**, not events, and require stage order (a subject reaching stage 3 counts in 1 and 2) — otherwise the funnel can widen, which is nonsense.

```sql
select s.ordinal, s.stage,
       count(distinct f.subject_id) as reached,
       count(distinct f.subject_id)::numeric
         / nullif(max(t.total) over (), 0) as rate_from_top
from stages s
left join facts f on f.stage_ordinal >= s.ordinal
cross join (select count(distinct subject_id) total from facts) t
group by s.ordinal, s.stage order by s.ordinal;
```

## Cohort / retention
Cohort = subject's first-activity period. Retention cell = distinct actives in cohort C at offset N ÷ cohort size. Return a long format (`cohort, offset, value`) and pivot in the component; never build a wide dynamic-column result in SQL.

## Period over period
Compute current and comparison window in one query with `filter (where ...)` so both use identical filters. Return absolute delta and percent change, and return `null` — not `0` — when the base is zero.

## Distributions
Return bucket boundaries and counts from SQL (`width_bucket` or explicit CASE ranges). Choose bucket count deliberately and label edges inclusively; unlabelled buckets are unreadable.

## Weighted scores / rollups
Weights and thresholds come from the owning module's single config source, never inlined in the query or the component. Round only at presentation time; rounding intermediate values drifts the total.

## Time series
Generate the date spine with `generate_series` and left join the facts, so gaps render as zero-or-null points instead of disappearing and distorting the trend line.

## Performance
Index the filter + group columns. If a dashboard query exceeds ~1s, precompute into a summary table refreshed on write (event-driven) or on a schedule; do not push the cost to the client.
