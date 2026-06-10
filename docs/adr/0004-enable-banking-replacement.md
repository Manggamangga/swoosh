# Enable Banking replaces GoCardless for Open Banking

GoCardless Bank Account Data no longer accepts new personal sign-ups. Swoosh migrates Open Banking to Enable Banking, which offers free restricted-mode production access for individual non-commercial use.

**Considered options:** Keep GoCardless (blocked for new accounts); TrueLayer/Plaid (paid); direct Monzo API only (single-bank); manual/CSV only.

**Decision:** Enable Banking via Supabase Edge Functions (`enable-banking-connect`, `enable-banking-sync`). Auth uses RS256 JWT signed with the app's RSA private key. Restricted mode requires whitelisting own bank accounts in the Enable Banking portal before sync works.

**Consequences:**
- Sean must register a production app, upload certificate, activate via linked accounts, and set `ENABLE_BANKING_APP_ID` + `ENABLE_BANKING_PRIVATE_KEY` in Supabase secrets.
- OAuth callback uses `swoosh://bank-callback` deep link; session ID stored in `bank_connections.requisition_id`.
- 90-day re-consent unchanged (PSD2). Transaction dedupe via hash unchanged.
- Wise and Moneybox remain manual/CSV.

**Supersedes:** ADR 0003 (GoCardless phase).
