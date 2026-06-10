ALTER TABLE public.accounts
  ADD CONSTRAINT accounts_user_id_external_ref_key UNIQUE (user_id, external_ref);
