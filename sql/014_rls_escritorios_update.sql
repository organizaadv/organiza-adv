-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 014: Policies RLS para tabela escritorios
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- Titular (user_id) pode atualizar o próprio escritório
DROP POLICY IF EXISTS "titular_atualizar_escritorio" ON public.escritorios;
CREATE POLICY "titular_atualizar_escritorio" ON public.escritorios
  FOR UPDATE
  USING (
    user_id = auth.uid()
    OR id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  )
  WITH CHECK (
    user_id = auth.uid()
    OR id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );

-- Garante que a policy de DELETE em demandas_escritorio existe
DROP POLICY IF EXISTS "excluir_demanda" ON public.demandas_escritorio;
CREATE POLICY "excluir_demanda" ON public.demandas_escritorio
  FOR DELETE
  USING (
    escritorio_id = (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
    OR escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
  );
