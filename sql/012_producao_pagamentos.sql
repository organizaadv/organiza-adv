-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 012: Ajustes para produção (pagamentos + IA)
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- 1. stripe_subscription_id (migration 010 — idempotente)
ALTER TABLE public.escritorios
  ADD COLUMN IF NOT EXISTS stripe_subscription_id TEXT NULL;

-- 2. Créditos extras de IA (migration 009 — idempotente)
ALTER TABLE public.escritorios
  ADD COLUMN IF NOT EXISTS ia_creditos_extras INT NOT NULL DEFAULT 0;

-- 3. Novos cadastros recebem 10 créditos grátis automaticamente
ALTER TABLE public.escritorios
  ALTER COLUMN ia_creditos_extras SET DEFAULT 10;

-- 4. Retroativo: escritórios em trial que ainda têm 0 créditos recebem 10
UPDATE public.escritorios
SET ia_creditos_extras = 10
WHERE plano = 'trial'
  AND ia_creditos_extras = 0;

-- 5. Recria a função consumir_credito_ia (sem alteração de lógica — idempotente)
CREATE OR REPLACE FUNCTION public.consumir_credito_ia(p_escritorio_id UUID)
RETURNS void AS $func$
BEGIN
  UPDATE public.escritorios
  SET ia_creditos_extras = GREATEST(ia_creditos_extras - 1, 0)
  WHERE id = p_escritorio_id;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Recria adicionar_creditos_ia com novo mapeamento de pacotes
CREATE OR REPLACE FUNCTION public.adicionar_creditos_ia(p_email TEXT, p_creditos INT)
RETURNS jsonb AS $func$
DECLARE
  v_escritorio_id UUID;
  v_extras INT;
BEGIN
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
$func$ LANGUAGE plpgsql SECURITY DEFINER;
