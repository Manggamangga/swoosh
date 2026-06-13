# Swoosh

Personal finance tracker for accounts, transactions, budgets, recurring payments, and planning.

## Stack

- Flutter / Dart
- Supabase (Auth, Postgres, RLS)
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

Accounts and transactions are created by importing bank statements (CSV or PDF). Supported formats include Barclays, Amex, and Wise — see the in-app import flow for guidance.

## Features

- Statement import (CSV/PDF) with smart dedupe on re-import
- Budgets by category
- Recurring payment detection
- Cash-flow forecast and savings goals

## Git commits

Use prefixes: `feat:`, `fix:`, `chore:`, etc.
