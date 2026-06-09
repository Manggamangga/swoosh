# Swoosh

A personal finance tracker for daily use — accounts, transactions, budgets, recurring payments, and forward-looking planning.

## Language

### Accounts & money

**Account**:
A place where money is held or tracked (e.g. Monzo current, Wise GBP, Moneybox ISA).
_Avoid_: Wallet, pot, bucket

**Account type**:
How an account is grouped for overview: Everyday, Savings, or Investment.
_Avoid_: Category, bucket type

**Balance**:
The current amount held in an account, stored in minor units (pence).
_Avoid_: Value, funds

**Balance anchor**:
A known balance on a specific date used to derive historical balance from transactions.
_Avoid_: Snapshot, checkpoint

**Transaction**:
A single movement of money into or out of an account (spend, income, or transfer leg).
_Avoid_: Payment, entry, line item

**Transfer**:
A pair of linked transactions moving money between the user's own accounts; excluded from income/spend analytics.
_Avoid_: Internal payment, move

**Category**:
A label classifying a transaction for budgeting and analytics (e.g. Groceries, Bills).
_Avoid_: Tag, bucket

**Net worth**:
The sum of all account balances across Everyday, Savings, and Investment types.
_Avoid_: Total wealth, portfolio value

### Banking & sync

**Connection**:
An authorised link between Swoosh and an external financial institution via Open Banking.
_Avoid_: Link, integration, bank link

**Source**:
How data entered Swoosh: manual entry, CSV import, or openbanking sync.
_Avoid_: Origin, provider

**Dedupe hash**:
A fingerprint preventing the same transaction from being imported twice.
_Avoid_: Unique key, fingerprint

### Budgeting & planning

**Budget**:
A monthly spending limit for a category.
_Avoid_: Cap, allowance, envelope

**Recurring payment**:
A transaction expected on a regular cadence (e.g. rent monthly, subscription annually).
_Avoid_: Subscription, standing order, direct debit

**Goal**:
A savings target with an amount and optional deadline.
_Avoid_: Target, milestone

**Forecast**:
A projected future balance based on known recurring payments and expected income.
_Avoid_: Projection, prediction, estimate

## Example dialogue

> **Sean:** I moved £500 from Monzo to Wise — why didn't my spending go up?
>
> **Expert:** That's a **Transfer**, not spending. Swoosh links both **Transaction** legs and excludes them from analytics. Your **Budget** for Groceries is unaffected.
>
> **Sean:** I re-imported my Barclays CSV and now I have duplicates.
>
> **Expert:** Each **Transaction** has a **Dedupe hash**. Re-importing the same rows is rejected. If amounts or dates differ slightly, those are treated as new transactions.
>
> **Sean:** What's my **Net worth**?
>
> **Expert:** Sum of **Balance** across all **Account** types — Everyday, Savings, and Investment. **Forecast** looks forward from that using **Recurring payment** schedules.
