CREATE TABLE public.category_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  matcher text NOT NULL,
  matcher_type text NOT NULL CHECK (matcher_type IN ('merchant', 'monzo_category', 'keyword')),
  category_id uuid NOT NULL REFERENCES public.categories(id) ON DELETE CASCADE,
  source text NOT NULL CHECK (source IN ('seeded', 'learned')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, matcher_type, matcher)
);

ALTER TABLE public.category_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY category_rules_all ON public.category_rules
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX category_rules_user_id_idx ON public.category_rules (user_id);
