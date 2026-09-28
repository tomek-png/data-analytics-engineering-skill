# MarTech integrations (GTM, GA4, Meta, TikTok)

Contents: architecture choice · GTM web · server-side GTM · GA4 · Measurement Protocol · Meta Pixel + CAPI · TikTok · dedup rules · secrets.

Read `tracking-datalayer.md` first — every integration here consumes that contract and its shared `event_id`.

## Architecture: browser, server, or both

| Signal source | Use | Why |
| --- | --- | --- |
| UI interaction | browser tag | needs cookies, click ids, viewport context |
| Money / truth events (paid order, signed contract, qualified lead) | server | browser events are lost to blockers, ITP and abandoned tabs |
| Paid-media conversions | **both**, deduplicated | browser adds match signals, server adds reliability |

Default for conversions: dual-send with a shared `event_id`. Single-source browser-only conversion tracking loses 10–30% of events and the loss is invisible.

## GTM (web container)

- Tags read **data-layer variables only**. A tag that reads the DOM (CSS selector, auto-event) breaks on the next UI refactor and nobody notices — this is the single biggest source of tracking rot.
- One trigger per contract event name. Lookup tables map event → destination config; avoid a tag per campaign.
- Container versions: name and annotate every publish. When a metric jumps, the first question is "what changed in the container".
- CSP: the container and its vendor endpoints need explicit `script-src`/`connect-src` entries. A CSP violation shows as "tag fired" in preview and zero data in the platform.

## Server-side GTM

Run the server container on a **first-party subdomain** (`gtm.example.com`) pointing at the tagging server. This is what keeps cookies first-party (longer `_ga` lifetime under ITP) and moves vendor endpoints off the client.

- The client sends one request to your own domain; the server container fans out to GA4, Meta, TikTok. Fewer browser requests, vendor keys never shipped to the client.
- Enrich server-side (order value from the database, lead quality from CRM) rather than trusting client-declared money values — client payloads are user-editable.
- Forward the shared `event_id`, the consent state, the client ip/user-agent (needed for ad-platform matching), and the platform click ids.

## GA4

Streams: one web stream per domain, separate streams per app platform. Do not split staging and production into one stream — filter by `debug_mode` is not isolation; a test purchase then lands in reported revenue.

- Mark conversions in the GA4 UI, not by inventing `*_conversion` event names.
- Register custom dimensions for any parameter you want in reports; unregistered parameters exist in BigQuery export but are invisible in the UI, which reads as "data missing".
- Respect the limits: 50 event-scoped custom dimensions, 25 params per event, 500 distinct event names. Exceeding them drops data silently.
- Enable BigQuery export on day one — it is the only complete, unsampled copy and it cannot be backfilled.

### Measurement Protocol (offline / backend events)

For events with no browser (CRM stage change, refund, delayed payment):

```
POST https://www.google-analytics.com/mp/collect?measurement_id=G-XXX&api_secret=$GA4_API_SECRET
{ "client_id": "<same client_id as the web session>",
  "events": [{ "name": "lead_qualified", "params": { "event_id": "<shared uuid>", "value": 1200, "currency": "PLN" } }] }
```

- Without the original `client_id`, the event cannot be attributed and appears as a new direct user — store `client_id` with the lead record at capture time.
- Validate against `/debug/mp/collect` in development; the production endpoint returns 2xx even for a rejected payload.
- MP events older than 72h are dropped for attribution purposes.

## Meta (Pixel + Conversions API)

Send both copies and let Meta deduplicate:

| Requirement | Browser (Pixel) | Server (CAPI) |
| --- | --- | --- |
| `event_name` | identical | identical |
| `event_id` | shared uuid | same uuid |
| match data | `fbp`, `fbc` cookies | `fbp`, `fbc` forwarded + hashed `em`, `ph`, `fn`, `ln`, `ct`, `zp` |
| `action_source` | `website` | `website` (or `system_generated` for offline) |

- Deduplication is keyed on `event_name` + `event_id`. Different names or a regenerated id on the server = double-counted conversions and a wrecked ROAS.
- Hash PII server-side: normalise (trim, lowercase; phone to E.164 digits, no `+`), then SHA-256 hex. Unnormalised input hashes to a value that matches nothing while reporting "sent successfully".
- Always forward `client_ip_address` and `client_user_agent` from the original request — without them Event Match Quality collapses.
- `fbc` must be built from `fbclid` at landing (`fb.1.<timestamp>.<fbclid>`) and persisted; reconstructing it later loses the click.
- Track EMQ and dedup rate as health metrics (see `system-drift-and-monitoring.md`).

## TikTok (Pixel + Events API)

Same dual-send shape:
- Shared `event_id` for Pixel and Events API; TikTok deduplicates on `event_id` + `event_name` within a 48h window.
- Persist `ttclid` from the landing URL and send it as `ttclid` plus `ttp` (the `_ttp` cookie) — these carry the click attribution.
- Identifiers (`email`, `phone_number`, `external_id`) must be normalised then SHA-256 hashed; TikTok rejects plaintext.
- Use TikTok's standard event names (`CompletePayment`, `SubmitForm`, `ViewContent`); custom names are not optimisable by the ad algorithm.

## Cross-platform invariants

1. One `event_id` per real-world event, generated once, reused by every destination. This is the load-bearing rule of the whole setup.
2. Currency and value in minor-unit-free decimal with explicit `currency` on every monetary event; a value without currency is treated as account currency and quietly misreports.
3. Serve server-side calls from a server function or the tagging server — never from the browser with a vendor access token.
4. All tokens (`GA4_API_SECRET`, `META_CAPI_TOKEN`, `TIKTOK_ACCESS_TOKEN`) are server secrets, read inside the handler. Only the measurement/pixel *ids* may appear in client code.
5. Retry server-side sends with backoff and a dead-letter record. A dropped conversion cannot be reconstructed after the attribution window closes.
6. Log every outbound conversion (event name, event_id, destination, response status) to your own table — vendor dashboards are not an audit trail.
