-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 008: Coluna movimentacoes em clientes
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.clientes
  ADD COLUMN IF NOT EXISTS movimentacoes JSONB DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS clientes_movimentacoes_idx
  ON public.clientes USING GIN (movimentacoes);
