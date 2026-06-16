-- Atualiza policy de SELECT em escritorios para incluir membros via tabela usuarios,
-- que agora já existe. Substitui a versão provisória criada em 000_escritorios.sql.
DROP POLICY IF EXISTS "ver_proprio_escritorio" ON public.escritorios;
CREATE POLICY "ver_proprio_escritorio" ON public.escritorios
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
  );
