-- Set user_id default from auth.uid() so client inserts pass RLS without explicit user_id
ALTER TABLE public.accounts ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.transactions ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.budgets ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.goals ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.recurring_payments ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.categories ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.category_rules ALTER COLUMN user_id SET DEFAULT auth.uid();
ALTER TABLE public.bank_connections ALTER COLUMN user_id SET DEFAULT auth.uid();
