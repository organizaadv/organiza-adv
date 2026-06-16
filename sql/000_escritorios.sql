-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 000: Tabela principal de escritórios
-- Deve ser rodada ANTES de todas as outras migrations.
-- Esta tabela nunca foi versionada no projeto original — foi criada
-- manualmente. Este arquivo reconstitui o schema completo.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.escritorios (
  id                     UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Titular legado (auth direto via user_id, sem tabela usuarios)
  user_id                UUID        REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Dados do escritório
  nome                   TEXT,
  email                  TEXT,
  tel                    TEXT,
  responsavel            TEXT,
  logo_url               TEXT,
  etapas                 JSONB,
  tema                   TEXT,
  onboarding_completo    BOOLEAN     NOT NULL DEFAULT FALSE,
  ativo                  BOOLEAN     NOT NULL DEFAULT TRUE,

  -- Plano e trial
  plano                  TEXT        NOT NULL DEFAULT 'trial',
  trial_inicio           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  trial_fim              TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  trial_expira           TIMESTAMPTZ,

  -- IA
  ia_creditos_extras     INT         NOT NULL DEFAULT 10,

  -- Stripe
  stripe_subscription_id TEXT        NULL,
  stripe_customer_id     TEXT        NULL,

  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS
ALTER TABLE public.escritorios ENABLE ROW LEVEL SECURITY;

-- Qualquer autenticado pode criar um escritório (fluxo de signup)
DROP POLICY IF EXISTS "criar_escritorio" ON public.escritorios;
CREATE POLICY "criar_escritorio" ON public.escritorios
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Apenas titular legado (user_id) por enquanto — usuarios ainda não existe.
-- A policy completa (incluindo membros via usuarios) é aplicada em 000b_rls_escritorios_select.sql
-- após a tabela usuarios ser criada.
DROP POLICY IF EXISTS "ver_proprio_escritorio" ON public.escritorios;
CREATE POLICY "ver_proprio_escritorio" ON public.escritorios
  FOR SELECT
  USING (user_id = auth.uid());
