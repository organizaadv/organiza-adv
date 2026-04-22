-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 002: Tabela de convites de membros
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.convites (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  email         TEXT        NOT NULL,
  nome          TEXT        NOT NULL,
  perfil        TEXT        NOT NULL DEFAULT 'colaborador',
  -- Permissões que serão aplicadas quando o convidado aceitar
  perm_admin          BOOLEAN NOT NULL DEFAULT FALSE,
  perm_financeiro     BOOLEAN NOT NULL DEFAULT FALSE,
  perm_demandas       BOOLEAN NOT NULL DEFAULT TRUE,
  perm_atendimentos   BOOLEAN NOT NULL DEFAULT FALSE,
  perm_diario_oficial BOOLEAN NOT NULL DEFAULT FALSE,
  perm_relatorios     BOOLEAN NOT NULL DEFAULT FALSE,
  -- Controle
  status        TEXT        NOT NULL DEFAULT 'pendente', -- pendente, aceito, cancelado
  enviado_por   UUID        REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  aceito_em     TIMESTAMPTZ
);

-- Índice para lookup por email (usado no init do app)
CREATE INDEX IF NOT EXISTS convites_email_idx ON public.convites(email, status);

-- RLS
ALTER TABLE public.convites ENABLE ROW LEVEL SECURITY;

-- Membros do escritório podem ver convites do seu escritório
CREATE POLICY IF NOT EXISTS "ver_convites_do_escritorio" ON public.convites
  FOR SELECT
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
    OR email = auth.email()  -- o convidado pode ver o próprio convite
  );

-- Titular pode criar convites
CREATE POLICY IF NOT EXISTS "criar_convite" ON public.convites
  FOR INSERT
  WITH CHECK (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

-- Titular pode cancelar convites do seu escritório
CREATE POLICY IF NOT EXISTS "cancelar_convite" ON public.convites
  FOR UPDATE
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
    OR email = auth.email()  -- o convidado pode marcar como aceito
  );
