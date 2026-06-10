WITH ranked AS (
  SELECT id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, provider
      ORDER BY
        CASE status
          WHEN 'active' THEN 0
          WHEN 'pending' THEN 1
          WHEN 'expired' THEN 2
          ELSE 3
        END,
        created_at DESC
    ) AS rn
  FROM public.bank_connections
)
DELETE FROM public.bank_connections
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

ALTER TABLE public.bank_connections
  ADD CONSTRAINT bank_connections_user_id_provider_key UNIQUE (user_id, provider);
