-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 017: Remove unicidade de nome em clientes
-- Dois clientes diferentes (pessoas distintas) podem ter o mesmo
-- nome — o índice único em (escritorio_id, nome), criado em
-- 006_clientes.sql, bloqueava esse caso legítimo, mostrando erro
-- "duplicate key value violates unique constraint" ao tentar salvar.
-- ═══════════════════════════════════════════════════════════════

DROP INDEX IF EXISTS public.clientes_unique_nome_esc;
