-- OrganizaADV — Migration 015
-- Função RPC que salva etapas do escritório, bypassa RLS com segurança
-- Execute no Supabase SQL Editor

CREATE OR REPLACE FUNCTION public.fn_salvar_etapas(p_escritorio_id UUID, p_etapas TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.escritorios
  SET etapas = p_etapas
  WHERE id = p_escritorio_id
    AND (
      user_id = auth.uid()
      OR id IN (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
    );
  RETURN FOUND;
END;
$$;
