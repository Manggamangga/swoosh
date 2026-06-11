# Swoosh

A personal finance tracker for daily use — accounts, transactions, budgets, recurring payments, and forward-looking planning.

## Language

### Accounts & money

**Account**:
A place where money is held or tracked (e.g. Monzo current, Wise GBP, Moneybox ISA). Its name is user-owned: a readable default is set when the account is created, and sync never changes it.
_Avoid_: Wallet, pot, bucket

**Account type**:
How an account is grouped for overview: Everyday or Savings. Everyday is spending money; Savings is a real account holding set-aside money (e.g. an ISA), not an envelope. Savings balances count in Net worth, but Savings transactions are excluded from spending analytics; moving money into a Savings account is an Excluded transaction, never spending.
_Avoid_: Category, bucket type, envelope, pot

**Balance**:
The current amount held in an account, stored in minor units (pence).
_Avoid_: Value, funds

**Balance anchor**:
A known balance on a specific date used to derive historical balance from transactions.
_Avoid_: Snapshot, checkpoint

**Transaction**:
A single movement of money into or out of an account (spend, income, or transfer leg).
_Avoid_: Payment, entry, line item

**Excluded transaction**:
A transaction flagged out of income/spend analytics (e.g. moving money to a savings account, or a one-off the user opts out). Set automatically when a provider marks a transaction as a transfer, or manually by the user. There is no pairing of transaction legs — exclusion is per-transaction.
_Avoid_: Transfer (retired term), internal payment, move

**Category**:
A label classifying a transaction for budgeting and analytics (e.g. Groceries, Bills).
_Avoid_: Tag, bucket

**Spending**:
Money leaving Everyday accounts, excluding Transfers and income. The unit of all budget and category analytics. Savings account activity is never spending.
_Avoid_: Expenses, outgoings

**Net worth**:
The sum of all account balances across Everyday and Savings types.
_Avoid_: Total wealth, portfolio value

### Banking & sync

**Connection**:
An authorised link between Swoosh and an external financial institution via a provider (Monzo direct API, or Enable Banking Open Banking). At most one Connection exists per provider per user; retrying a failed authorisation reuses it rather than creating another.
_Avoid_: Link, integration, bank link

**Source**:
How data entered Swoosh: manual entry, CSV import, or openbanking sync.
_Avoid_: Origin, provider

**Sync**:
Pulling the latest balances and transactions from a Connection into Swoosh. A dashboard sync runs across all Connections at once; previously synced data stays visible while it runs. Sync never changes user-owned data (e.g. account names).
_Avoid_: Refresh (that's re-reading already-stored data), update

**Dedupe hash**:
A fingerprint preventing the same transaction from being imported twice.
_Avoid_: Unique key, fingerprint

### Budgeting & planning

**Category rule**:
A stored mapping from a merchant or keyword to a Category, either seeded (e.g. bank-provided categories, known merchants) or learned when the user re-categorises a transaction. Applied automatically at import and sync.
_Avoid_: Auto-tag, classifier

**Budget**:
A monthly spending limit for a category.
_Avoid_: Cap, allowance, envelope

**Recurring payment**:
A transaction expected on a regular cadence (e.g. rent monthly, subscription annually). Amount may be positive — recurring income (e.g. salary) is modelled as a Recurring payment with a positive amount.
_Avoid_: Subscription, standing order, direct debit

**Expected income**:
A Recurring payment with a positive amount and a known cadence (e.g. monthly salary on a payday). Anchors Forecast and Safe to spend.
_Avoid_: Salary entry, paycheck

**Safe to spend**:
Everyday balance minus Recurring payments due before the next Expected income date, minus remaining Budget allocations for the current month. The headline forward-looking number.
_Avoid_: Disposable income, available balance

**Goal**:
A savings target with an amount and optional deadline.
_Avoid_: Target, milestone

**Forecast**:
A projected future balance based on known recurring payments and expected income.
_Avoid_: Projection, prediction, estimate

## Example dialogue

> **Sean:** I moved £500 from Monzo to Wise — why didn't my spending go up?
>
> **Expert:** That's an **Excluded transaction**, not spending. The provider flagged it as a transfer, so it's excluded from analytics. Your **Budget** for Groceries is unaffected.
>
> **Sean:** I re-imported my Barclays CSV and now I have duplicates.
>
> **Expert:** Each **Transaction** has a **Dedupe hash**. Re-importing the same rows is rejected. If amounts or dates differ slightly, those are treated as new transactions.
>
> **Sean:** What's my **Net worth**?
>
> **Expert:** Sum of **Balance** across all **Account** types — Everyday and Savings. **Forecast** looks forward from that using **Recurring payment** schedules, including **Expected income**.
