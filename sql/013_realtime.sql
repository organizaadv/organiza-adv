-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 013: Habilitar Supabase Realtime
-- Execute no Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════

-- 1. Adicionar tabelas à publicação do Realtime
--    (necessário para receber postgres_changes via supabase.channel())
ALTER PUBLICATION supabase_realtime ADD TABLE public.demandas_escritorio;
ALTER PUBLICATION supabase_realtime ADD TABLE public.clientes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.colab_escritorio;

-- 2. REPLICA IDENTITY FULL — necessário para receber dados da linha
--    deletada nos eventos DELETE (sem isso, o payload de DELETE
--    só retorna a primary key, não os campos como id)
ALTER TABLE public.demandas_escritorio REPLICA IDENTITY FULL;
ALTER TABLE public.clientes REPLICA IDENTITY FULL;
ALTER TABLE public.colab_escritorio REPLICA IDENTITY FULL;
