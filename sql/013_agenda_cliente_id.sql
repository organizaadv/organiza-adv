-- Adiciona cliente_id na tabela agenda para vincular eventos a clientes da Carteira
ALTER TABLE public.agenda
  ADD COLUMN IF NOT EXISTS cliente_id UUID NULL REFERENCES public.clientes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS agenda_cliente_id_idx
  ON public.agenda(cliente_id);
