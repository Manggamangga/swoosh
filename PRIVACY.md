# Swoosh Privacy Policy

**Last updated:** 13 June 2026

Swoosh is a personal finance app for tracking accounts, transactions, budgets, and planning. This policy describes how data is handled when you use the app.

## Who operates Swoosh

Swoosh is operated for personal, non-commercial use. For data protection enquiries, contact the operator at seandarianloh@gmail.com.

## What data we collect

When you use Swoosh, the app may store and process:

- Account details you create via statement import (account names, balances, institutions)
- Transactions (dates, amounts, descriptions, categories)
- Budgets, recurring payments, and savings goals
- Authentication credentials managed through Supabase Auth (email and password if you sign up)

Statement files you choose to import are parsed on your device. Swoosh does not receive or store your bank login credentials.

## Where data is stored

Financial data is stored in a Supabase Postgres database (hosted in the EU, `eu-west-1`). Row Level Security ensures each user can only access their own data.

A local read-cache on your device may hold recent accounts and transactions so the dashboard remains visible when offline. This cache is stored on your device only.

## How data is used

Data is used solely to provide personal finance features inside the app: balances, transaction history, budgets, forecasts, and related analytics. We do not sell your data or use it for advertising.

## Third-party services

Swoosh uses:

- **Supabase** — authentication and database

These providers process data only as needed to deliver the features you use.

## Data retention and deletion

Data remains in your account until you delete it or close your account. You can remove accounts and transactions within the app. To request deletion of all stored data, contact the operator using the email above.

## Your rights

If you are in the UK or EEA, you may have rights to access, correct, or delete your personal data. Contact the operator to exercise these rights.

## Changes

This policy may be updated from time to time. The latest version is published in this repository.
