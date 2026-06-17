-- Suporte a arquivamento automático de demandas concluídas há 10+ dias

ALTER TABLE public.demandas_escritorio
  ADD COLUMN IF NOT EXISTS arquivado   BOOLEAN    NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS concluido_em TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_demandas_arquivado
  ON public.demandas_escritorio(escritorio_id, arquivado);
