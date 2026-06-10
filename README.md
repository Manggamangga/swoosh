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

Edge Functions require Enable Banking secrets (set in Supabase Dashboard, not in the Flutter app):

- `ENABLE_BANKING_APP_ID` — application ID from Enable Banking portal (JWT `kid`)
- `ENABLE_BANKING_PRIVATE_KEY` — RSA private key PEM (PKCS#8)

### Enable Banking setup (one-time)

1. Sign up at [enablebanking.com](https://enablebanking.com) and create a **production** application.
2. Upload your certificate and note the application ID.
3. Activate via **Activate by linking accounts** — whitelist Monzo, Barclays, Amex, etc.
4. Add the secrets above to Supabase Edge Functions.
5. In the app, go to Accounts → Connect bank and authorise each institution.

## Features

- Manual accounts and transactions
- CSV import with dedupe
- Budgets by category
- Recurring payment detection
- Cash-flow forecast and savings goals
- Enable Banking Open Banking (Monzo, Barclays, Amex — restricted mode)

## Git commits

Use prefixes: `feat:`, `fix:`, `chore:`, etc.
