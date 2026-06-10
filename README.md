# Swoosh

Personal finance tracker for accounts, transactions, budgets, recurring payments, and planning.

## Stack

- Flutter / Dart
- Supabase (Auth, Postgres, RLS, Edge Functions)
- Riverpod, go_router, fl_chart

## Setup

1. Install Flutter 3.35+
2. `flutter pub get`
3. Copy `.env.example` values or use defaults in `lib/core/config/env.dart`
4. `flutter run`

Auth is skipped by default (`SKIP_AUTH=true`) — the app auto-signs into a dev account so you can try features immediately. Re-enable with:

`flutter run --dart-define=SKIP_AUTH=false`

## Supabase

Project ref: `segpgjvfwlwfqkverhso` (eu-west-1)

### Monzo (recommended — automatic sync)

1. Sign in at [developers.monzo.com](https://developers.monzo.com) and approve access in the Monzo app.
2. Create a **Confidential** OAuth client with redirect URI:
   `https://segpgjvfwlwfqkverhso.supabase.co/functions/v1/bank-callback`
3. Set Supabase Edge Function secrets:
   - `MONZO_CLIENT_ID`
   - `MONZO_CLIENT_SECRET`
4. In the app: Accounts → Connect bank → **Monzo** → approve in Monzo app → sync runs automatically.

### Other banks (CSV / manual)

Barclays, Amex, Wise, and Moneybox: add an account manually, then import CSV from the account detail screen.

### Enable Banking (optional — limited UK coverage)

Kept as fallback if UK banks become available in restricted mode. Requires `ENABLE_BANKING_APP_ID` and `ENABLE_BANKING_PRIVATE_KEY` in Supabase secrets.

## Features

- Monzo direct API sync (balances + transactions)
- Manual accounts and CSV import with dedupe
- Budgets by category
- Recurring payment detection
- Cash-flow forecast and savings goals

## Git commits

Use prefixes: `feat:`, `fix:`, `chore:`, etc.
