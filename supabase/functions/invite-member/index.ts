import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const anonKey     = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    const siteUrl     = Deno.env.get('SITE_URL') ?? 'https://organiza-adv.vercel.app'

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const authHeader = req.headers.get('Authorization') ?? ''
    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    const { data: { user } } = await caller.auth.getUser()
    if (!user) throw new Error('Não autorizado')

    // Tenta encontrar o usuário na tabela usuarios (novo modelo)
    let escritorioId: string | null = null
    let nomeRemetente = 'Titular'

    const { data: meuUsuario } = await admin
      .from('usuarios')
      .select('perfil, escritorio_id, nome')
      .eq('id', user.id)
      .maybeSingle()

    if (meuUsuario) {
      if (meuUsuario.perfil !== 'titular') {
        throw new Error('Apenas o titular pode convidar membros')
      }
      escritorioId = meuUsuario.escritorio_id
      nomeRemetente = meuUsuario.nome
    } else {
      // Fallback: modelo antigo — verifica se é titular pelo escritorios.user_id
      const { data: esc } = await admin
        .from('escritorios')
        .select('id, responsavel')
        .eq('user_id', user.id)
        .maybeSingle()

      if (!esc) throw new Error('Apenas o titular pode convidar membros')
      escritorioId = esc.id
      nomeRemetente = esc.responsavel || 'Titular'
    }

    const body = await req.json()
    const {
      email, nome, perfil = 'colaborador',
      perm_admin = false, perm_financeiro = false,
      perm_demandas = true, perm_atendimentos = false,
      perm_diario_oficial = false, perm_relatorios = false
    } = body

    if (!email || !nome) throw new Error('Email e nome são obrigatórios')

    const emailNorm = email.toLowerCase().trim()

    // Cancela convites anteriores pendentes para o mesmo email/escritório
    await admin
      .from('convites')
      .update({ status: 'cancelado' })
      .eq('escritorio_id', escritorioId)
      .eq('email', emailNorm)
      .eq('status', 'pendente')

    // Cria registro de convite
    const { data: convite, error: conviteErr } = await admin
      .from('convites')
      .insert([{
        escritorio_id: escritorioId,
        email: emailNorm, nome, perfil,
        perm_admin, perm_financeiro, perm_demandas,
        perm_atendimentos, perm_diario_oficial, perm_relatorios,
        enviado_por: user.id,
        status: 'pendente'
      }])
      .select()
      .single()

    if (conviteErr) throw conviteErr

    // Envia convite via Supabase Auth Admin
    const { error: inviteErr } = await admin.auth.admin.inviteUserByEmail(emailNorm, {
      redirectTo: `${siteUrl}/auth.html`,
      data: {
        nome,
        escritorio_id: escritorioId,
        convite_id: convite.id,
        convidado_por: nomeRemetente,
      }
    })

    if (inviteErr) {
      await admin.from('convites').delete().eq('id', convite.id)
      throw inviteErr
    }

    return new Response(JSON.stringify({ ok: true, convite_id: convite.id }), {
      headers: { ...CORS, 'Content-Type': 'application/json' }
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' }
    })
  }
})
