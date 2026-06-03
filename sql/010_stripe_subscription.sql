-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 010: Stripe subscription ID em escritorios
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.escritorios
  ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT NULL;

-- Status 'expirado' para quando a assinatura é cancelada no Stripe
-- (a coluna plano já é TEXT sem CHECK constraint — nada a fazer)
