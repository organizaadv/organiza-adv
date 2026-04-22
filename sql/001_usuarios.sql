-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 001: Tabela de usuários individuais
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- Tabela de usuários (um por membro da equipe, com login próprio)
CREATE TABLE IF NOT EXISTS public.usuarios (
  id            UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  escritorio_id UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  nome          TEXT        NOT NULL,
  perfil        TEXT        NOT NULL DEFAULT 'colaborador',
  whatsapp      TEXT,
  -- Permissões granulares por módulo
  perm_admin          BOOLEAN NOT NULL DEFAULT FALSE,
  perm_financeiro     BOOLEAN NOT NULL DEFAULT FALSE,
  perm_demandas       BOOLEAN NOT NULL DEFAULT TRUE,
  perm_atendimentos   BOOLEAN NOT NULL DEFAULT FALSE,
  perm_diario_oficial BOOLEAN NOT NULL DEFAULT FALSE,
  perm_relatorios     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Titular sempre tem tudo habilitado
-- (controlado na lógica da aplicação, não em colunas separadas)

-- Colunas extras na tabela escritorios (se ainda não existirem)
ALTER TABLE public.escritorios
  ADD COLUMN IF NOT EXISTS plano         TEXT        DEFAULT 'trial',
  ADD COLUMN IF NOT EXISTS trial_inicio  TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS trial_fim     TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '7 days');

-- RLS
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

-- Usuário pode inserir o próprio registro (no momento do signup)
CREATE POLICY IF NOT EXISTS "inserir_proprio_usuario" ON public.usuarios
  FOR INSERT
  WITH CHECK (id = auth.uid());

-- Qualquer usuário vê todos os membros do mesmo escritório
CREATE POLICY IF NOT EXISTS "ver_membros_do_escritorio" ON public.usuarios
  FOR SELECT
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

-- Titular pode atualizar membros do seu escritório
CREATE POLICY IF NOT EXISTS "atualizar_membros" ON public.usuarios
  FOR UPDATE
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

-- Titular pode remover membros (exceto si mesmo)
CREATE POLICY IF NOT EXISTS "remover_membros" ON public.usuarios
  FOR DELETE
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
    AND id != auth.uid()
  );

-- ── MIGRAÇÃO DE CONTAS ANTIGAS ────────────────────────────────
-- Para cada escritório existente que ainda não tem usuário na
-- tabela usuarios, insira um registro de titular.
-- Rode isso APENAS UMA VEZ após criar a tabela:
--
-- INSERT INTO public.usuarios (id, escritorio_id, nome, perfil,
--   perm_admin, perm_financeiro, perm_demandas, perm_atendimentos,
--   perm_diario_oficial, perm_relatorios)
-- SELECT
--   e.user_id,
--   e.id,
--   COALESCE(e.responsavel, e.email),
--   'titular',
--   TRUE, TRUE, TRUE, TRUE, TRUE, TRUE
-- FROM public.escritorios e
-- WHERE NOT EXISTS (
--   SELECT 1 FROM public.usuarios u WHERE u.escritorio_id = e.id
-- )
-- ON CONFLICT (id) DO NOTHING;
