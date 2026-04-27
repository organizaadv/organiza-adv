-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 006: Tabela de clientes
-- Execute no Supabase SQL Editor — rode cada bloco em ordem
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- BLOCO 1 — Criar tabela clientes
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.clientes (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escritorio_id   UUID        NOT NULL REFERENCES public.escritorios(id) ON DELETE CASCADE,

  -- Identificação
  nome            TEXT        NOT NULL,
  cpf_cnpj        TEXT        NULL,
  rg              TEXT        NULL,
  data_nascimento DATE        NULL,
  estado_civil    TEXT        NULL,   -- solteiro, casado, divorciado, viuvo, uniao_estavel
  profissao       TEXT        NULL,

  -- Contato
  telefone        TEXT        NULL,
  email           TEXT        NULL,

  -- Endereço
  cep             TEXT        NULL,
  endereco        TEXT        NULL,   -- logradouro + número
  complemento     TEXT        NULL,
  bairro          TEXT        NULL,
  cidade          TEXT        NULL,
  estado          TEXT        NULL,   -- UF, ex: 'SP'

  obs             TEXT        NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS clientes_escritorio_idx
  ON public.clientes(escritorio_id);

CREATE INDEX IF NOT EXISTS clientes_nome_idx
  ON public.clientes(escritorio_id, nome);

CREATE UNIQUE INDEX IF NOT EXISTS clientes_unique_nome_esc
  ON public.clientes(escritorio_id, nome);   -- evita duplicatas por escritório

-- ── RLS: clientes ────────────────────────────────────────────────
-- Padrão duplo: cobre contas novas (via usuarios) e contas antigas
-- (via escritorios.user_id) — ambos os modelos de auth coexistem.

ALTER TABLE public.clientes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ver_clientes_do_escritorio" ON public.clientes;
CREATE POLICY "ver_clientes_do_escritorio" ON public.clientes
  FOR SELECT
  USING (
    escritorio_id = (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
    OR escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "criar_cliente" ON public.clientes;
CREATE POLICY "criar_cliente" ON public.clientes
  FOR INSERT
  WITH CHECK (
    escritorio_id = (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
    OR escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "atualizar_cliente" ON public.clientes;
CREATE POLICY "atualizar_cliente" ON public.clientes
  FOR UPDATE
  USING (
    escritorio_id = (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
    OR escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
  );

DROP POLICY IF EXISTS "excluir_cliente" ON public.clientes;
CREATE POLICY "excluir_cliente" ON public.clientes
  FOR DELETE
  USING (
    escritorio_id = (SELECT escritorio_id FROM public.usuarios WHERE id = auth.uid())
    OR escritorio_id IN (SELECT id FROM public.escritorios WHERE user_id = auth.uid())
  );


-- ──────────────────────────────────────────────────────────────
-- BLOCO 2 — Adicionar cliente_id nas tabelas existentes
-- ──────────────────────────────────────────────────────────────

-- demandas_escritorio
ALTER TABLE public.demandas_escritorio
  ADD COLUMN IF NOT EXISTS cliente_id UUID NULL REFERENCES public.clientes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS demandas_cliente_id_idx
  ON public.demandas_escritorio(cliente_id);

-- atendimentos
ALTER TABLE public.atendimentos
  ADD COLUMN IF NOT EXISTS cliente_id UUID NULL REFERENCES public.clientes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS atendimentos_cliente_id_idx
  ON public.atendimentos(cliente_id);

-- contratos: coluna já existe como nullable sem FK — só adiciona o vínculo
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'contratos_cliente_id_fk'
  ) THEN
    ALTER TABLE public.contratos
      ADD CONSTRAINT contratos_cliente_id_fk
      FOREIGN KEY (cliente_id) REFERENCES public.clientes(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS contratos_cliente_id_idx
  ON public.contratos(cliente_id);


-- ──────────────────────────────────────────────────────────────
-- BLOCO 3 — Migração: popular clientes a partir de demandas
--
-- Lê os dados únicos de demandas_escritorio e cria um registro
-- de cliente por (escritorio_id, nome). Em caso de múltiplas
-- demandas para o mesmo cliente, usa os dados da demanda mais
-- recente. Conflitos de nome já existente são ignorados.
-- ──────────────────────────────────────────────────────────────

INSERT INTO public.clientes (escritorio_id, nome, cpf_cnpj, telefone, email)
SELECT DISTINCT ON (d.escritorio_id, d.nome)
  d.escritorio_id,
  d.nome,
  NULLIF(trim(d.cpf),  ''),
  NULLIF(trim(d.tel),  ''),
  NULLIF(trim(d.email),'')
FROM public.demandas_escritorio d
WHERE trim(d.nome) != ''
ORDER BY d.escritorio_id, d.nome, d.created_at DESC
ON CONFLICT (escritorio_id, nome) DO NOTHING;


-- ──────────────────────────────────────────────────────────────
-- BLOCO 4 — Vincular cliente_id nas tabelas existentes
--
-- Atualiza os registros já existentes para apontar ao cliente
-- correto pelo par (escritorio_id, nome). Rode após o Bloco 3.
-- ──────────────────────────────────────────────────────────────

-- demandas_escritorio
UPDATE public.demandas_escritorio d
SET    cliente_id = c.id
FROM   public.clientes c
WHERE  d.escritorio_id = c.escritorio_id
  AND  d.nome          = c.nome
  AND  d.cliente_id IS NULL;

-- atendimentos
UPDATE public.atendimentos a
SET    cliente_id = c.id
FROM   public.clientes c
WHERE  a.escritorio_id = c.escritorio_id
  AND  a.nome_cliente  = c.nome
  AND  a.cliente_id IS NULL;

-- contratos
UPDATE public.contratos ct
SET    cliente_id = c.id
FROM   public.clientes c
WHERE  ct.escritorio_id  = c.escritorio_id
  AND  ct.cliente_nome   = c.nome
  AND  ct.cliente_id IS NULL;
