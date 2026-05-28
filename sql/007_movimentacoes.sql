-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 007: Coluna movimentacoes em demandas
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.demandas_escritorio
  ADD COLUMN IF NOT EXISTS movimentacoes JSONB DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS demandas_movimentacoes_idx
  ON public.demandas_escritorio USING GIN (movimentacoes);
