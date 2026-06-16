-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 000e: Tabela de agenda
-- Criada manualmente no projeto original — reconstitui o schema base.
-- cliente_id é adicionado em 013_agenda_cliente_id.sql
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.agenda (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  titulo        TEXT        NOT NULL,
  tipo          TEXT,
  data_evento   TEXT        NOT NULL,
  hora_evento   TEXT,
  local         TEXT,
  obs           TEXT,
  responsavel   TEXT,
  wpp_notif     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.agenda ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver_agenda_do_escritorio" ON public.agenda;
CREATE POLICY "ver_agenda_do_escritorio" ON public.agenda
  FOR SELECT
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "gerenciar_agenda" ON public.agenda;
CREATE POLICY "gerenciar_agenda" ON public.agenda
  FOR ALL
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );
