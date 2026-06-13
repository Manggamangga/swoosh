# Swoosh

A personal finance tracker for daily use — accounts, transactions, spending, and recurring insights.

## Language

### Accounts & money

**Account**:
A place where money is held or tracked (e.g. Barclays current, Wise GBP, Amex card). Its name is user-owned: a readable default is set when the account is created from a statement import.
_Avoid_: Wallet, pot, bucket

**Account type**:
How an account is grouped for overview: Everyday, Savings, or Credit. Everyday is spending money; Savings is set-aside money; Credit is borrowed money (e.g. a credit card) shown as a liability. Credit balances reduce Net worth.
_Avoid_: Category, bucket type, envelope, pot

**Balance**:
The current amount held in an account, stored in minor units (pence). For Credit accounts, balance is negative (amount owed).
_Avoid_: Value, funds

**Balance anchor**:
The most recent known balance on a specific date used to derive the current balance from later transactions. Only moves forward — importing an older statement backfills transactions but never moves the anchor backward.
_Avoid_: Snapshot, checkpoint

**Transaction**:
A single movement of money into or out of an account (spend, income, or transfer leg).
_Avoid_: Payment, entry, line item

**Excluded transaction**:
A transaction flagged out of income/spend analytics (e.g. moving money between own accounts, currency conversions, or a one-off the user opts out). Set automatically by import rules or manually by the user. There is no pairing of transaction legs — exclusion is per-transaction.
_Avoid_: Transfer (retired term), internal payment, move

**Category**:
A label classifying a transaction for budgeting and analytics (e.g. Groceries, Bills).
_Avoid_: Tag, bucket

**Spending**:
Money leaving Everyday accounts, excluding Excluded transactions and income. The unit of all budget and category analytics. Savings account activity is never spending. Foreign-currency rows without a GBP value are excluded from GBP spending totals.
_Avoid_: Expenses, outgoings

**Net worth**:
Everyday plus Savings balances minus Credit balances (liabilities).
_Avoid_: Total wealth, portfolio value

### Data entry

**Source**:
How data entered Swoosh: CSV/PDF statement import (the only supported entry path for new data).
_Avoid_: Origin, provider

**Transaction identity**:
The fingerprint used to decide whether an imported row is the same transaction as one already stored. Uses the bank's transaction ID when present (e.g. Wise); otherwise date, amount, normalized description, and an occurrence counter for genuinely duplicate lines in one statement.
_Avoid_: Dedupe hash (legacy term), unique key

**Statement import**:
Bringing a bank statement file into Swoosh file-first: the bank is inferred from the statement itself, the matching Account is found or created automatically, transactions are imported with transaction identity dedupe, and the Account's balance anchor advances only when a newer statement provides a running balance.
_Avoid_: CSV upload, file import

### Budgeting & insights

**Category rule**:
A stored mapping from a merchant or keyword to a Category, either seeded (known merchants) or learned when the user re-categorises a transaction. Applied automatically at import.
_Avoid_: Auto-tag, classifier

**Budget**:
A monthly spending limit for a category.
_Avoid_: Cap, allowance, envelope

**Recurring payment**:
A transaction expected on a regular cadence (e.g. rent monthly, subscription annually). Amount may be positive — recurring income (e.g. salary) is modelled as a Recurring payment with a positive amount.
_Avoid_: Subscription, standing order, direct debit

## Example dialogue

> **Sean:** I moved £500 from Monzo to Wise — why didn't my spending go up?
>
> **Expert:** That's an **Excluded transaction**, not spending. The import flagged it as a transfer between your own accounts, so it's excluded from analytics. Your **Budget** for Groceries is unaffected.

> **Sean:** I re-imported my May Wise statement after already importing June — why didn't my balance go backwards?
>
> **Expert:** **Balance anchor** only moves forward. The June import set the anchor; May just backfilled any missing transactions via **Transaction identity** dedupe.

> **Sean:** What's my **Net worth**?
>
> **Expert:** Sum of **Balance** across Everyday and Savings, minus Credit (liabilities).
