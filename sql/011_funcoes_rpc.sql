-- ═══════════════════════════════════════════════════════════════
-- OrganizaADV — Migration 011: Funções RPC essenciais do app
-- Execute no Supabase SQL Editor — rode TODO o bloco de uma vez
-- ═══════════════════════════════════════════════════════════════

-- ── 1. aceitar_convite() ────────────────────────────────────────
-- Chamada em toda inicialização do app.html.
-- Retorna os dados do usuário + escritório. Lógica:
--   a) Se há convite pendente para o e-mail → aceita e cria entrada em usuarios
--   b) Se usuário já está em usuarios (novo modelo) → retorna dados
--   c) Se usuário é titular legado (escritorios.user_id) → retorna dados
--   d) Sem acesso → retorna vazio (app faz signOut)
-- SECURITY DEFINER: bypassa RLS para leitura interna de escritorios/usuarios

CREATE OR REPLACE FUNCTION public.aceitar_convite()
RETURNS TABLE(
  escritorio_id       UUID,
  nome                TEXT,
  perfil              TEXT,
  perm_admin          BOOLEAN,
  perm_financeiro     BOOLEAN,
  perm_demandas       BOOLEAN,
  perm_atendimentos   BOOLEAN,
  perm_diario_oficial BOOLEAN,
  perm_relatorios     BOOLEAN,
  escritorio          JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_email   TEXT := auth.email();
  v_usuario public.usuarios%ROWTYPE;
  v_esc     RECORD;
  v_convite public.convites%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN RETURN; END IF;

  -- a) Convite pendente para este e-mail
  SELECT * INTO v_convite
  FROM public.convites
  WHERE LOWER(email) = LOWER(v_email)
    AND status = 'pendente'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    INSERT INTO public.usuarios (
      id, escritorio_id, nome, perfil,
      perm_admin, perm_financeiro, perm_demandas,
      perm_atendimentos, perm_diario_oficial, perm_relatorios
    ) VALUES (
      v_user_id,
      v_convite.escritorio_id,
      v_convite.nome,
      v_convite.perfil,
      v_convite.perm_admin,
      v_convite.perm_financeiro,
      v_convite.perm_demandas,
      v_convite.perm_atendimentos,
      v_convite.perm_diario_oficial,
      v_convite.perm_relatorios
    )
    ON CONFLICT (id) DO UPDATE SET
      escritorio_id       = EXCLUDED.escritorio_id,
      nome                = EXCLUDED.nome,
      perfil              = EXCLUDED.perfil,
      perm_admin          = EXCLUDED.perm_admin,
      perm_financeiro     = EXCLUDED.perm_financeiro,
      perm_demandas       = EXCLUDED.perm_demandas,
      perm_atendimentos   = EXCLUDED.perm_atendimentos,
      perm_diario_oficial = EXCLUDED.perm_diario_oficial,
      perm_relatorios     = EXCLUDED.perm_relatorios;

    UPDATE public.convites
    SET status = 'aceito', aceito_em = NOW()
    WHERE id = v_convite.id;

    SELECT * INTO v_usuario FROM public.usuarios WHERE id = v_user_id;
  ELSE
    -- b) Usuário já cadastrado na tabela usuarios (novo modelo)
    SELECT * INTO v_usuario FROM public.usuarios WHERE id = v_user_id;
  END IF;

  IF v_usuario.id IS NOT NULL THEN
    SELECT * INTO v_esc FROM public.escritorios WHERE id = v_usuario.escritorio_id;
    RETURN QUERY SELECT
      v_usuario.escritorio_id,
      v_usuario.nome::TEXT,
      v_usuario.perfil::TEXT,
      v_usuario.perm_admin,
      v_usuario.perm_financeiro,
      v_usuario.perm_demandas,
      v_usuario.perm_atendimentos,
      v_usuario.perm_diario_oficial,
      v_usuario.perm_relatorios,
      row_to_json(v_esc)::jsonb;
    RETURN;
  END IF;

  -- c) Titular legado: existe em escritorios mas não em usuarios
  SELECT * INTO v_esc FROM public.escritorios WHERE user_id = v_user_id;
  IF FOUND THEN
    RETURN QUERY SELECT
      v_esc.id::UUID,
      COALESCE(v_esc.responsavel, v_esc.email, 'Titular')::TEXT,
      'titular'::TEXT,
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
      row_to_json(v_esc)::jsonb;
    RETURN;
  END IF;

  -- d) Sem acesso — retorna vazio
  RETURN;
END;
$$;


-- ── 2. sou_registrado() ─────────────────────────────────────────
-- Chamada em auth.html após OTP para saber se o usuário já tem conta.
-- Retorna TRUE se o usuário já tem escritório ou está em usuarios.

CREATE OR REPLACE FUNCTION public.sou_registrado()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_email   TEXT := auth.email();
BEGIN
  IF v_user_id IS NULL THEN RETURN FALSE; END IF;

  IF EXISTS (SELECT 1 FROM public.usuarios WHERE id = v_user_id) THEN
    RETURN TRUE;
  END IF;

  IF EXISTS (SELECT 1 FROM public.escritorios WHERE user_id = v_user_id) THEN
    RETURN TRUE;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.convites
    WHERE LOWER(email) = LOWER(v_email) AND status = 'pendente'
  ) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;


-- ── 3. buscar_meu_convite() ─────────────────────────────────────
-- Chamada em auth.html após OTP para verificar se o e-mail tem convite.
-- Retorna o convite mais recente pendente para o e-mail do usuário logado.

CREATE OR REPLACE FUNCTION public.buscar_meu_convite()
RETURNS SETOF public.convites
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.convites
  WHERE LOWER(email) = LOWER(auth.email())
    AND status = 'pendente'
  ORDER BY created_at DESC
  LIMIT 1;
$$;


-- ── 4. buscar_convites_pendentes(p_escritorio_id) ───────────────
-- Chamada em app.html para listar convites pendentes do escritório.

CREATE OR REPLACE FUNCTION public.buscar_convites_pendentes(p_escritorio_id UUID)
RETURNS SETOF public.convites
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.convites
  WHERE escritorio_id = p_escritorio_id
    AND status = 'pendente'
  ORDER BY created_at ASC;
$$;


-- ── VERIFICAÇÃO ─────────────────────────────────────────────────
-- Confirma que as 4 funções foram criadas:
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
    'aceitar_convite',
    'sou_registrado',
    'buscar_meu_convite',
    'buscar_convites_pendentes'
  )
ORDER BY routine_name;
