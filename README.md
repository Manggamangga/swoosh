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

## Supabase

Project ref: `segpgjvfwlwfqkverhso` (eu-west-1)

Edge Functions require GoCardless secrets:

- `GOCARDLESS_SECRET_ID`
- `GOCARDLESS_SECRET_KEY`

## Features

- Manual accounts and transactions
- CSV import with dedupe
- Budgets by category
- Recurring payment detection
- Cash-flow forecast and savings goals
- GoCardless Open Banking (Monzo, Barclays, Amex)

## Git commits

Use prefixes: `feat:`, `fix:`, `chore:`, etc.
