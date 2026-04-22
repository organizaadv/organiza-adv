-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 003: Tabela de pagamentos (admin)
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- Tabela de pagamentos registrados pelo painel admin
CREATE TABLE IF NOT EXISTS public.pagamentos (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  valor         NUMERIC(10,2) NOT NULL,
  metodo        TEXT        DEFAULT 'pix',   -- pix, boleto, transferencia, mercado_pago
  referencia    TEXT,                         -- Ex: Abril/2026
  observacao    TEXT,
  data_pagamento DATE       NOT NULL,
  status        TEXT        NOT NULL DEFAULT 'confirmado',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS pagamentos_escritorio_idx ON public.pagamentos(escritorio_id);
CREATE INDEX IF NOT EXISTS pagamentos_data_idx ON public.pagamentos(data_pagamento DESC);

-- RLS: apenas service role (admin.html usa anon key mas validar admin no app)
ALTER TABLE public.pagamentos ENABLE ROW LEVEL SECURITY;

-- Permite leitura irrestrita para contas autenticadas
-- (o controle de acesso ao admin.html é feito na camada de aplicação)
CREATE POLICY IF NOT EXISTS "pagamentos_leitura" ON public.pagamentos
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "pagamentos_escrita" ON public.pagamentos
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "pagamentos_atualizacao" ON public.pagamentos
  FOR UPDATE USING (auth.role() = 'authenticated');

-- Atualiza coluna plano em escritorios para suportar novos valores
-- (essencial, avancado, trial, pro — mantém pro por compatibilidade)
-- Nada a fazer: a coluna já é TEXT sem CHECK constraint
