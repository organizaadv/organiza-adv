-- OrganizaADV — Migration 015: stripe_customer_id em escritorios
ALTER TABLE public.escritorios
  ADD COLUMN IF NOT EXISTS stripe_customer_id TEXT NULL;
