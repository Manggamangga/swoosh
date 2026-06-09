# Supabase as backend

Swoosh stores all financial data in Supabase (Postgres 17, eu-west-1) with Auth, Row Level Security, and Edge Functions. An existing project (`segpgjvfwlwfqkverhso`, named "Swoosh") is reused. eu-west-1 keeps UK/EU financial data residency. Edge Functions hold GoCardless secrets and OAuth redirects — these cannot live in the Flutter app.

**Considered options:** Supabase; Cloudflare Workers + D1; local-only SQLite.

**Consequences:** App requires network for writes; lightweight read-cache covers offline dashboard viewing. Single-user MVP with user-scoped RLS; partner can be added later without schema rewrite.
