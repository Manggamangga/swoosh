# Rules-based categorization over LLM

Smart categorization was needed for Monzo sync, CSV import, budgeting, and transaction filtering. LLM-based classification was considered.

**Decision:** Use deterministic layered rules:
1. Map Monzo-provided transaction categories at sync time
2. Apply seeded merchant keyword rules for CSV and unmatched merchants
3. Learn merchant→category mappings when the user re-categorises a transaction

Rules live in a `category_rules` table with RLS. No LLM or external inference API.

**Consequences:**
- Zero per-transaction cost and predictable results offline-friendly
- Accuracy improves with user corrections without model drift
- New merchants require rules (seeded or learned) — no semantic guessing
- Retroactive pass can re-apply rules to existing uncategorized rows

**Alternatives rejected:**
- LLM via Edge Function: cost, latency, non-determinism, privacy surface
- Monzo-only mapping: leaves CSV/manual imports uncategorized
