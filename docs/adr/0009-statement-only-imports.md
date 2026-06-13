# ADR 0009: Statement-only imports

## Status

Accepted — 2026-06-13

## Context

Swoosh removed bank API integrations (Monzo, Enable Banking) in favour of CSV/PDF statement imports. Users re-import overlapping statements (e.g. May then June), use multiple Wise export formats, and need reliable balances without manual prompts for every credit-card CSV.

## Decision

1. **Statement-only entry** — Accounts and transactions are created only via statement import. Manual account creation and manual transaction entry are removed.

2. **Hybrid transaction identity** — When a bank provides a stable transaction ID (Wise), dedupe uses `accountId + providerTxnId` stored in `external_ref`. Otherwise dedupe uses `accountId + date + amount + normalized description + occurrence ordinal` within the import batch so genuinely duplicate lines (two identical Tesco purchases same day) are preserved while re-imports still skip known rows.

3. **Forward-only balance anchor** — The balance anchor (known balance + date) advances only when an imported statement is newer than the current anchor. Older statements backfill gaps without moving the displayed balance backward. Transactions on the anchor date are not double-counted when deriving balance.

4. **GBP-only foreign handling for Wise CSV** — Wise PDF is the preferred Wise source (GBP value on every line). Wise activity CSV converts GBP-leg rows; foreign-only rows are stored in original currency but excluded from GBP spending analytics rather than approximated with FX tables.

5. **No balance prompt on import** — Files without a running balance (e.g. Amex activity CSV) never block import. Users can set balance manually on the account detail screen.

## Consequences

- Re-importing the same statement is safe: duplicates skipped, newer anchor preserved.
- Wise CSV and Wise PDF dedupe across formats via shared numeric transaction IDs.
- Foreign card spend from Wise CSV appears on the account but not in GBP spending totals unless imported via PDF.
- Users must export full statements; live/pending PDF views are rejected with guidance.

## Alternatives considered

- **Always overwrite anchor with latest import** — Rejected; breaks balance when backfilling older months.
- **Built-in FX rate table for foreign CSV rows** — Rejected; inaccurate for spending analytics; PDF preferred instead.
- **Prompt for credit balance on every import** — Rejected; friction; optional manual set is sufficient.
