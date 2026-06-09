# GoCardless Open Banking with manual-first rollout

Bank connectivity is phased: manual entry and CSV import ship first (all accounts work immediately), then GoCardless Bank Account Data (free UK Open Banking) for supported institutions (Monzo, Barclays, Amex). Wise and Moneybox remain manual. Open Banking requires 90-day re-consent (PSD2). Transactions are deduped via hash to prevent overlap between manual and synced data.

**Considered options:** Open Banking first; manual/CSV only; paid aggregator (TrueLayer/Plaid).

**Consequences:** MVP is usable before any bank API integration. A Supabase Edge Function is required for GoCardless OAuth and secret handling.
