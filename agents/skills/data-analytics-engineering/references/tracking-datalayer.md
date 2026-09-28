# Data layer & event contract

Contents: event contract · dataLayer transport · naming taxonomy · identity & PII · Consent Mode v2 · SPA specifics.

## Event contract first

The data layer is an API with external consumers (GTM, warehouse, ad platforms). Treat it like one: declare the schema before emitting, validate at runtime, and version it. An untyped `dataLayer.push` drifts within weeks because nothing fails when a field disappears.

```ts
// src/modules/analytics/contract.ts — single source of truth
export const AnalyticsEvent = z.object({
  event: z.enum(['view_item', 'select_item', 'lead_submitted', 'funnel_step_completed']),
  event_id: z.string().uuid(),        // dedup key shared with every server-side copy
  schema_version: z.literal(2),        // bump when a field's meaning changes
  occurred_at: z.string().datetime(),  // ISO, UTC
  page: z.object({ path: z.string(), locale: z.string() }),
  payload: z.record(z.unknown()),
});
```

Rules that matter:
- **`event_id` is generated once, client-side, and reused by every downstream copy** of that event (GA4, Meta CAPI, TikTok Events API, warehouse row). Without one shared id, deduplication is impossible and conversions double-count.
- Validate in dev and log a loud console error on failure; in production drop the malformed event and count it — a silently malformed push is worse than a missing one because it poisons the dataset.
- Never change the meaning of an existing key. Add a new key and bump `schema_version`.
- Flat, snake_case parameter names. GA4 truncates names at 40 chars and values at 100; nested objects arrive in BigQuery as unusable JSON strings.

## Transport

Emit through one module, never `window.dataLayer.push` scattered in components — a single choke point is what makes contract validation, consent gating and tests possible.

```ts
// src/modules/analytics/track.ts
export function track(e: AnalyticsEventInput) {
  const event = AnalyticsEvent.parse({ event_id: crypto.randomUUID(), schema_version: 2, ...e });
  (window.dataLayer ??= []).push(event);   // array exists before GTM loads; GTM drains it
}
```

- Declare `window.dataLayer = window.dataLayer || []` before the container snippet. The array is the buffer — events pushed pre-load are replayed, so no queue of your own is needed.
- Debounce or guard once-per-intent events (form submit, add to cart) on an idempotency key; double-fired clicks are the most common source of inflated conversion counts.
- Push a plain serialisable object. Functions, DOM nodes and class instances break GTM variables and warehouse export.

## Naming taxonomy

Use GA4's reserved names where one fits (`view_item`, `add_to_cart`, `purchase`, `generate_lead`, `login`, `sign_up`) — reserved names unlock built-in reports and platform mappings. Invent names only for domain steps, in `object_action` form: `funnel_step_completed`, `survey_answer_saved`, `workshop_submitted`.

Every funnel step carries `funnel_id`, `step_ordinal`, `step_name` so the funnel query (see `analysis-patterns.md`) needs no per-step SQL.

Never encode a value in the event name (`lead_submitted_warsaw`) — it fragments the metric across hundreds of names. Values go in parameters.

## Identity

- `user_pseudo_id` / `client_id` — device scoped, set by the platform. Do not overwrite.
- `user_id` — your stable app identifier, only after authentication, never an email or any value reversible to a person.
- `session_id` — from the platform where available; mixing your own session logic with GA4's produces two incompatible session counts.

## PII discipline

Raw email, phone, name, address, IP or free-text user input MUST NOT enter the data layer. Ad-platform advanced matching needs hashed identifiers, and hashing belongs server-side (see `martech-integrations.md`) where the salt and the raw value stay out of the browser. If a hash must be produced client-side: normalise first (trim, lowercase, E.164 for phones), then SHA-256 — an unnormalised hash silently never matches.

Query strings and page paths leak PII (`?email=`, `/reset/<token>`). Strip an allowlisted set of params before pushing `page.path`.

## Consent Mode v2

Set defaults **before** the GTM/GA4 snippet, or the first page view fires unconsented and the hit is unrecoverable.

```html
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('consent', 'default', {
    ad_storage: 'denied', analytics_storage: 'denied',
    ad_user_data: 'denied', ad_personalization: 'denied',
    wait_for_update: 500                 // ms to let the CMP answer before tags decide
  });
</script>
```

- On CMP interaction send `gtag('consent','update',{...})` with the granted keys; also persist the decision so the next page load's *default* already reflects it.
- `ad_user_data` and `ad_personalization` are v2-only and required for Google Ads; omitting them degrades bidding even when `ad_storage` is granted.
- Server-side conversions (CAPI, Measurement Protocol) are subject to the same consent. Propagate the consent state into the event payload and check it in the server handler — consent that only gates the browser tag is not compliance.
- Region-scoped defaults (`region: ['PL','DE']`) when the policy differs by market.

## SPA specifics

Route changes do not reload the page, so nothing fires by itself:
- Emit a single `page_view` per committed navigation, after the route resolves and the title is set — firing on route intent double-counts cancelled navigations.
- Reset per-page state (scroll depth, item impressions) on navigation, or impressions accumulate across pages.
- In React, emit from a router subscription or a route-level effect, not from a component that remounts on filter changes.

## Verification

An implementation is not done until the event is observed end to end: GTM Preview shows the push, GA4 DebugView shows the hit, and the row appears in the warehouse. Automate that check — see `system-drift-and-monitoring.md`.
