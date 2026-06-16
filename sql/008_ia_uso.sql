-- OrganizaADV — Migration 008: Controle de uso de IA por escritório
-- Execute no Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.ia_uso (
  escritorio_id UUID NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,
  mes           TEXT NOT NULL, -- formato 'YYYY-MM'
  contagem      INT  NOT NULL DEFAULT 0,
  PRIMARY KEY (escritorio_id, mes)
);

ALTER TABLE public.ia_uso ENABLE ROW LEVEL SECURITY;

-- Escritório só vê o próprio uso
DROP POLICY IF EXISTS "ver_proprio_uso_ia" ON public.ia_uso;
CREATE POLICY "ver_proprio_uso_ia" ON public.ia_uso
  FOR SELECT
  USING (
    escritorio_id = (
      SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid()
    )
  );

-- Função de incremento atômico (chamada pela Edge Function com service role)
CREATE OR REPLACE FUNCTION public.incrementar_ia_uso(p_escritorio_id UUID, p_mes TEXT)
RETURNS void AS $$
BEGIN
  INSERT INTO public.ia_uso (escritorio_id, mes, contagem)
  VALUES (p_escritorio_id, p_mes, 1)
  ON CONFLICT (escritorio_id, mes)
  DO UPDATE SET contagem = ia_uso.contagem + 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
