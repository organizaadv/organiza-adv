-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 000c: Tabela de demandas/processos
-- Criada manualmente no projeto original — reconstitui o schema base.
-- cliente_id é adicionado em 006_clientes.sql
-- movimentacoes é adicionado em 007_movimentacoes.sql
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.demandas_escritorio (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  nome          TEXT        NOT NULL,
  tipo          TEXT,
  tel           TEXT,
  email         TEXT,
  cpf           TEXT,
  obs           TEXT,
  processo      TEXT,
  responsavel   TEXT,
  prazo         TEXT,
  etapa_atual   INT         NOT NULL DEFAULT 0,
  status        TEXT        NOT NULL DEFAULT 'Em andamento',
  data          TEXT,
  criado_por    TEXT,
  atos          JSONB       DEFAULT '[]'::jsonb,
  hist_fases    JSONB       DEFAULT '[]'::jsonb,
  obs_etapas    JSONB       DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.demandas_escritorio ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver_demandas_do_escritorio" ON public.demandas_escritorio;
CREATE POLICY "ver_demandas_do_escritorio" ON public.demandas_escritorio
  FOR SELECT
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "gerenciar_demandas" ON public.demandas_escritorio;
CREATE POLICY "gerenciar_demandas" ON public.demandas_escritorio
  FOR ALL
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );
