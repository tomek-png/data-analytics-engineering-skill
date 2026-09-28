# Data preparation & ingestion

## Contract first
Define the target table/columns and types before parsing anything. An importer without a declared target schema drifts into `text` columns everywhere and the analysis phase pays for it.

## Parse on the server
Run CSV/XLSX parsing in an Edge Function or server function, not the browser: files are unbounded in size, and parsing rules must be identical for a re-run. The client uploads and polls status.

## Staging → validate → promote
1. Insert raw rows into a staging table with `import_id`, `row_number`, `raw` (jsonb) and `status`.
2. Validate row by row; write failures with a reason, never abort the whole batch on row 37.
3. Promote only valid rows into the domain table, inside one transaction per batch.
4. Return a summary: rows read, promoted, rejected, top rejection reasons. The UI shows this summary — an import that reports only "done" is unusable.

Staging makes a bad import reversible, which is the whole point.

## Normalisation rules to apply explicitly
- Trim and collapse whitespace; treat `''` as NULL, never as `0`.
- Decimal separator: accept both `,` and `.`; store numeric, never text.
- Dates: parse with an explicit expected format, store `timestamptz` in UTC; reject ambiguous `03/04/2026` rather than guessing.
- Text case: normalise keys used for matching (emails lowercased), preserve display text as given.
- Deduplicate on a declared business key, keeping the newest row, and report how many collapsed.

## Idempotency
Re-running the same import must not double data. Use a natural key + `on conflict do update`, or record a file content hash and refuse a duplicate run.

## Big files
Chunk (1–5k rows per batch), report progress, and keep each batch independently retryable. Never hold the whole file in memory at once in the Worker runtime.
