# Data quality checks

Run these before publishing a number. Each maps to a bug class that is invisible in the UI.

## Six dimensions, one query each
| Dimension | Check | Why |
| --- | --- | --- |
| Completeness | NULL / empty share per column | a 40% NULL column silently skews every average |
| Uniqueness | count vs count(distinct business_key) | duplicates inflate totals |
| Validity | values outside allowed enum/range | scores > max, negative durations |
| Consistency | cross-field rules (end >= start, sum of parts = total) | catches broken transforms |
| Referential integrity | orphan FKs on both sides | joins drop rows nobody notices |
| Freshness | max(updated_at) vs now | a stale pipeline looks like a business decline |

## Row-count invariant
Before and after any join, compare row counts against the expected grain. If a left join changes the row count of the driving table, the join key is not unique — fix the key, do not paper over it with `distinct`.

## Denominator check
For every rate, verify numerator ⊆ denominator population and that both use the same filters and time window. Mismatched filters are the most common cause of >100% conversion.

## Outliers
Report them; do not silently drop. Use median + IQR or p95 for skewed data and say which you used. An average that includes one 10-year-old session is not wrong data, it is a wrong statistic.

## Timezones
Aggregate by day in a single declared timezone. Mixing UTC storage with local-day grouping shifts totals by the first and last day of every range.

## When a check fails
Say what failed, how many rows, and the impact on the reported number — then propose the fix. Do not quietly exclude the rows and present a clean chart.
