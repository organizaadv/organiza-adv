-- OrganizaADV — Migration 014: Coluna anotacoes em atendimentos
ALTER TABLE public.atendimentos
  ADD COLUMN IF NOT EXISTS anotacoes TEXT;
