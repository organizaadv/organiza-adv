-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 005: Financeiro (contratos + parcelas)
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- ── TABELA: contratos ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contratos (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id    UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,

  -- Dados do cliente (cliente_id será populado na Etapa 2 — tabela clientes)
  cliente_nome     TEXT        NOT NULL,
  cliente_id       UUID        NULL,   -- FK para clientes (adicionada na Etapa 2)

  -- Dados do contrato
  servico          TEXT        NOT NULL,
  valor_total      NUMERIC(10,2) NOT NULL DEFAULT 0,
  forma_pagamento  TEXT        NOT NULL DEFAULT 'avista',  -- 'avista' | 'parcelado'
  entrada          NUMERIC(10,2) NOT NULL DEFAULT 0,
  num_parcelas     INT         NOT NULL DEFAULT 1,
  data_contrato    DATE        NULL,
  responsavel      TEXT        NULL,   -- nome do advogado responsável (Etapa 4)
  obs              TEXT        NULL,

  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices de busca
CREATE INDEX IF NOT EXISTS contratos_escritorio_idx
  ON public.contratos(escritorio_id);

CREATE INDEX IF NOT EXISTS contratos_cliente_nome_idx
  ON public.contratos(escritorio_id, cliente_nome);

CREATE INDEX IF NOT EXISTS contratos_data_idx
  ON public.contratos(data_contrato DESC);

-- ── TABELA: contratos_parcelas ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contratos_parcelas (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  contrato_id   UUID        NOT NULL REFERENCES public.contratos(id) ON DELETE CASCADE,
  escritorio_id UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,

  numero        INT         NOT NULL,          -- ordem da parcela (0 = entrada)
  label         TEXT        NOT NULL,          -- ex: 'Entrada', 'Parcela 1/3', 'À vista'
  valor         NUMERIC(10,2) NOT NULL DEFAULT 0,
  pago          BOOLEAN     NOT NULL DEFAULT FALSE,
  data_pagamento DATE       NULL,              -- preenchida ao marcar como paga

  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice principal: todas as parcelas de um contrato, em ordem
CREATE INDEX IF NOT EXISTS parcelas_contrato_idx
  ON public.contratos_parcelas(contrato_id, numero);

-- Índice para buscar todas as parcelas de um escritório (relatórios)
CREATE INDEX IF NOT EXISTS parcelas_escritorio_idx
  ON public.contratos_parcelas(escritorio_id);

-- ── RLS: contratos ───────────────────────────────────────────────
ALTER TABLE public.contratos ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "ver_contratos_do_escritorio" ON public.contratos
  FOR SELECT
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

CREATE POLICY IF NOT EXISTS "criar_contrato" ON public.contratos
  FOR INSERT
  WITH CHECK (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

CREATE POLICY IF NOT EXISTS "atualizar_contrato" ON public.contratos
  FOR UPDATE
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

CREATE POLICY IF NOT EXISTS "excluir_contrato" ON public.contratos
  FOR DELETE
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

-- ── RLS: contratos_parcelas ──────────────────────────────────────
ALTER TABLE public.contratos_parcelas ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "ver_parcelas_do_escritorio" ON public.contratos_parcelas
  FOR SELECT
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

CREATE POLICY IF NOT EXISTS "criar_parcela" ON public.contratos_parcelas
  FOR INSERT
  WITH CHECK (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

CREATE POLICY IF NOT EXISTS "atualizar_parcela" ON public.contratos_parcelas
  FOR UPDATE
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

CREATE POLICY IF NOT EXISTS "excluir_parcela" ON public.contratos_parcelas
  FOR DELETE
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );
