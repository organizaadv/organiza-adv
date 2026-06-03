-- OrganizaADV — Migration 009: Créditos extras de IA por escritório
-- Execute no Supabase SQL Editor

ALTER TABLE public.escritorios
  ADD COLUMN IF NOT EXISTS ia_creditos_extras INT NOT NULL DEFAULT 0;

-- Função para consumir um crédito extra (chamada pela Edge Function resumir-ia)
CREATE OR REPLACE FUNCTION public.consumir_credito_ia(p_escritorio_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.escritorios
  SET ia_creditos_extras = GREATEST(ia_creditos_extras - 1, 0)
  WHERE id = p_escritorio_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para adicionar créditos extras (chamada pelo webhook do Stripe)
CREATE OR REPLACE FUNCTION public.adicionar_creditos_ia(p_email TEXT, p_creditos INT)
RETURNS jsonb AS $$
DECLARE
  v_escritorio_id UUID;
  v_extras INT;
BEGIN
  -- Encontra o escritório pelo email do titular
  SELECT e.id INTO v_escritorio_id
  FROM public.escritorios e
  WHERE LOWER(e.email) = LOWER(p_email)
  LIMIT 1;

  IF v_escritorio_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'escritorio_nao_encontrado');
  END IF;

  UPDATE public.escritorios
  SET ia_creditos_extras = ia_creditos_extras + p_creditos
  WHERE id = v_escritorio_id
  RETURNING ia_creditos_extras INTO v_extras;

  RETURN jsonb_build_object('ok', true, 'escritorio_id', v_escritorio_id, 'creditos_extras', v_extras);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
