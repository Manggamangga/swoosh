# Enable Banking Restricted Production for personal use

Swoosh is a personal finance app for Sean's own accounts. Full Enable Banking production requires FCA AISP registration (3–6 months) or a paid KYB contract. Restricted Production lets a single developer link and sync only their own whitelisted bank accounts for free.

**Considered options:** FCA AISP registration (too slow for MVP); paid Enable Banking contract (unnecessary for single-user); GoCardless free tier (closed to new sign-ups); TrueLayer/Yapily (enterprise sales-led); drop Open Banking and use CSV only (loses automatic sync for non-Monzo banks).

**Decision:** Activate Enable Banking in Restricted Production mode. Sean whitelists his own accounts in the Enable Banking control panel. Supabase Edge Functions store `ENABLE_BANKING_APP_ID` and `ENABLE_BANKING_PRIVATE_KEY` as secrets. The app only accesses banks Sean has explicitly linked — not a general UK bank directory for other users.

**Consequences:**
- UK ASPSPs only appear after GB market is selected and accounts are whitelisted in the portal; sandbox alone is insufficient.
- The Connect bank UI must explain this constraint so failed auth is not mistaken for a code bug.
- If Swoosh ever ships to other users, a regulated path (AISP or signed production contract) is required — Restricted Production does not scale.

**Supersedes:** Nothing. Complements ADR 0004 with the operational mode chosen for MVP.
