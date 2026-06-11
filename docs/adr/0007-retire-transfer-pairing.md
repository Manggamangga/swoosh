# ADR 0007: Retire transfer pairing in favour of per-transaction exclusion

## Status

Accepted

## Context

The schema includes `transfer_pair_id` on transactions, implying paired legs between accounts. In practice the field was never populated, and Swoosh users do not record transfers manually — the app only tracks money via sync and CSV.

Users still need savings top-ups and bank-flagged transfers excluded from spending analytics.

## Decision

- Retire the **Transfer** domain term; use **Excluded transaction** instead.
- Keep `exclude_from_analytics` on each transaction.
- Do not implement `transfer_pair_id` pairing.
- Allow manual exclude/include toggles on transactions in the UI.

## Consequences

- Spending analytics stay correct without complex leg-matching logic.
- `transfer_pair_id` remains in the schema but unused — a future migration may drop it.
- Multi-leg movements between accounts may appear as separate rows until excluded manually or flagged by the provider.
