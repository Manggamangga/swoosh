# Monzo direct API with CSV-first for other banks

Enable Banking restricted mode showed no UK banks in Sean's portal, making it unsuitable for Monzo/Barclays/Amex. GoCardless is closed to new signups. Commercial aggregators (TrueLayer, Yapily, Plaid) require business entities for production.

**Decision:** Primary automated sync via direct Monzo developer API (OAuth, free for own account). Barclays, Amex, Wise, and Moneybox use existing manual entry and CSV import. Enable Banking code remains deployed as a dormant fallback if UK coverage improves.

**Consequences:**
- New Edge Functions: `monzo-connect`, `monzo-sync`; tokens stored in `bank_connections` (service-role only; excluded from client selects).
- OAuth redirect reuses HTTPS `bank-callback` function → `swoosh://` deep link.
- Monzo requires in-app approval after token exchange; sync immediately after connect to capture full history (90-day limit applies after ~5 minutes).
- Secrets: `MONZO_CLIENT_ID`, `MONZO_CLIENT_SECRET` in Supabase Edge Functions.

**Supersedes:** Enable Banking as primary path (ADR 0004 remains for reference).
