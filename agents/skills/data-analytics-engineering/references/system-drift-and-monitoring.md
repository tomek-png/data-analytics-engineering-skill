# Drift detection & monitoring

Contents: failure classes · contract tests in CI · volume & null monitors · schema drift · platform health · metric reconciliation · vendor change watch · runbook.

Tracking breaks silently. Nothing errors, dashboards keep rendering, and the loss is discovered weeks later when a budget decision has already been made on wrong numbers. Every integration you add needs a monitor, added in the same change.

## The five failure classes

| Class | What happens | Detected by |
| --- | --- | --- |
| Lost event | a refactor removes a push; UI works fine | contract test in CI + volume monitor |
| Malformed payload | a param is renamed or becomes NULL | schema drift + null-rate monitor |
| Broken dedup | server copy regenerates `event_id`; conversions double | dedup-rate monitor |
| Degraded matching | consent, hashing or click-id regression | EMQ / match-rate monitor |
| Semantic drift | warehouse and BI define a metric differently | metric reconciliation |

## Contract tests in CI

The cheapest and highest-value monitor: assert the data layer from an end-to-end test, so a UI refactor that drops an event fails the build instead of the quarter's reporting.

```ts
// e2e/analytics.spec.ts
const pushes: unknown[] = [];
await page.exposeBinding('__capture', (_, e) => pushes.push(e));
await page.addInitScript(() => {
  window.dataLayer = { push: (e: unknown) => (window as any).__capture(e) } as never;
});
await submitLeadForm(page);
const lead = pushes.find(e => e.event === 'lead_submitted');
expect(AnalyticsEvent.safeParse(lead).success).toBe(true);   // same Zod schema as production
expect(lead.event_id).toMatch(UUID_RE);
```

Cover every revenue-relevant event and both device layouts. Validate with the production schema — a hand-written assertion drifts from the contract it is supposed to guard.

Also assert consent behaviour: with consent denied, no vendor request leaves the page (`page.route` on vendor hosts). A consent regression is a legal exposure, not just a data one.

## Volume & null-rate monitors (warehouse)

Run daily against the curated facts. Compare to the same weekday four weeks back, not to yesterday — weekly seasonality otherwise fires alerts every Monday.

```sql
-- per event: yesterday vs trailing same-weekday median
select event_name, yesterday, baseline,
       safe_divide(yesterday - baseline, nullif(baseline,0)) as pct_change
from (...)
where abs(safe_divide(yesterday - baseline, nullif(baseline,0))) > 0.3   -- tune per event volume
   or yesterday = 0;                                                    -- zero is always an alert
```

- Zero events for a previously-active event name is a hard alert; it almost always means a removed push or a broken tag.
- Null-rate spike per required parameter: a param that was 1% NULL and is now 40% NULL means a partial deployment. Alert on the *change*, not an absolute threshold.
- New unexpected `event_name` values: a sign of ad-hoc tagging outside the contract. Report, do not auto-accept.

## Schema drift

Detect structural change in the sources you do not control (GA4 export, vendor feeds, uploads) before a query breaks or, worse, silently returns NULL.

```sql
select column_name, data_type
from `proj.analytics_123.INFORMATION_SCHEMA.COLUMNS`
where table_name = 'events_20260101';
```

Store the expected column/type set as a fixture and diff on a schedule. Alert on: removed column, changed type, and new column (new is informational but often marks a vendor feature you now need to map).

For parameter-level drift, snapshot the distinct `event_params.key` set per event name weekly and diff it — a dropped key is invisible at column level because `event_params` itself never changes shape.

## Platform health

Check weekly, and after every tagging change:
- **Meta:** deduplication rate (browser+server pairs matched) should hold above ~95%; Event Match Quality above ~7/10. A sudden EMQ drop means hashing, consent or click-id capture broke.
- **TikTok:** Events API diagnostics for rejected events and missing `ttclid`.
- **GA4:** DebugView for the current build; unregistered custom dimensions; the 500-event-name and 25-param ceilings.
- **Your own log:** the outbound conversion table from `martech-integrations.md` — alert on non-2xx rate and on dead-letter depth. Vendor UIs lag and are not queryable history.
- **GTM:** every container publish gets a version note. When a monitor fires, diff container versions first.

## Metric reconciliation

For each headline KPI, compare the warehouse fact against every BI surface that reports it, on a schedule:
- Warehouse vs Power BI measure, warehouse vs Tableau published source: expect exact match. Any delta is a filter, a relationship, or a duplicated definition — fix the definition, do not add a fudge factor.
- Warehouse vs GA4 UI: expect small, explainable differences (thresholding, modelling, sampling). Document the expected band; alert only outside it.
- Store each run (date, metric, source, value, delta) so drift is visible as a trend rather than a single surprising day.

## Watching for vendor change

The platforms change under you; the contract must be re-verified, not assumed:
- Subscribe to the release notes that matter: GA4 / Tag Manager, Meta Graph API changelog and version deprecations, TikTok Business API changelog, BigQuery release notes, Power BI monthly, Tableau release notes.
- Meta and TikTok APIs are versioned with hard sunsets — pin the version in code, record the sunset date, and treat the upgrade as scheduled work. An unpinned version upgrades itself and breaks in production.
- Re-run the full verification suite (CI contract tests + a manual DebugView / Events Manager pass) after any vendor version bump, CMP change, CSP change, or GTM container publish.

## When a monitor fires

Report in this order, then fix: which monitor, which event or metric, the size of the gap, the window affected, and what downstream numbers are wrong. State whether historical data can be backfilled — for ad-platform conversions and unsent Measurement Protocol events past 72h it cannot, and that changes the decision about what to do next.
