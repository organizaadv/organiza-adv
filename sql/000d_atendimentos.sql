-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 000d: Tabela de atendimentos
-- Criada manualmente no projeto original — reconstitui o schema base.
-- cliente_id é adicionado em 006_clientes.sql
-- anotacoes é adicionado em 014_atendimentos_anotacoes.sql
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.atendimentos (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id     UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  nome_cliente      TEXT        NOT NULL,
  tel               TEXT,
  email             TEXT,
  cpf               TEXT,
  tipo              TEXT,
  assunto           TEXT,
  obs               TEXT,
  data_atendimento  TEXT,
  hora_atendimento  TEXT,
  responsavel       TEXT,
  status            TEXT        NOT NULL DEFAULT 'Agendado',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.atendimentos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver_atendimentos_do_escritorio" ON public.atendimentos;
CREATE POLICY "ver_atendimentos_do_escritorio" ON public.atendimentos
  FOR SELECT
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "gerenciar_atendimentos" ON public.atendimentos;
CREATE POLICY "gerenciar_atendimentos" ON public.atendimentos
  FOR ALL
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );
