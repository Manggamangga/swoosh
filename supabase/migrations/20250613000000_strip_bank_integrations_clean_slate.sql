-- Strip bank integrations and reset transactional data for imports-only MVP.

ALTER TYPE public.account_type ADD VALUE IF NOT EXISTS 'credit';

DELETE FROM public.account_balance_snapshots;
DELETE FROM public.transactions;
UPDATE public.recurring_payments SET account_id = NULL WHERE account_id IS NOT NULL;
UPDATE public.goals SET account_id = NULL WHERE account_id IS NOT NULL;
DELETE FROM public.accounts;

DROP TABLE IF EXISTS public.bank_connections;
