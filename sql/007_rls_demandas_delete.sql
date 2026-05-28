-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 007: Policy DELETE para demandas_escritorio
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- Cobre os dois modelos de auth que coexistem:
--   - novo: usuário na tabela `usuarios` com escritorio_id
--   - legado: escritório com user_id direto na tabela `escritorios`

DROP POLICY IF EXISTS "excluir_demanda" ON public.demandas_escritorio;
CREATE POLICY "excluir_demanda" ON public.demandas_escritorio
  FOR DELETE
  USING (
    escritorio_id = (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
    OR escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
  );
