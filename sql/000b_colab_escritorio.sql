-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 000b: Tabela de colaboradores (modelo legado)
-- Criada manualmente no projeto original — reconstitui o schema completo.
-- Deve rodar após escritorios e antes de migrar_titulares_equipe.
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.colab_escritorio (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  nome          TEXT        NOT NULL,
  email         TEXT,
  perfil        TEXT        NOT NULL DEFAULT 'colaborador',
  oab           TEXT,
  permissoes    JSONB       NOT NULL DEFAULT '{}',
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.colab_escritorio ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver_colabs_do_escritorio" ON public.colab_escritorio;
CREATE POLICY "ver_colabs_do_escritorio" ON public.colab_escritorio
  FOR SELECT
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );

DROP POLICY IF EXISTS "gerenciar_colabs" ON public.colab_escritorio;
CREATE POLICY "gerenciar_colabs" ON public.colab_escritorio
  FOR ALL
  USING (
    escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
    OR escritorio_id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );
