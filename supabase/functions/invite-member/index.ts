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
    const resendKey   = Deno.env.get('RESEND_API_KEY') ?? ''
    const siteUrl     = Deno.env.get('SITE_URL') ?? 'https://organizaadv.com.br'

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const authHeader = req.headers.get('Authorization') ?? ''
    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    })

    const { data: { user } } = await caller.auth.getUser()
    if (!user) throw new Error('Não autorizado')

    let escritorioId: string | null = null
    let nomeRemetente = 'Titular'
    let nomeEscritorio = 'o escritório'

    const { data: meuUsuario } = await admin
      .from('usuarios')
      .select('perfil, escritorio_id, nome')
      .eq('id', user.id)
      .maybeSingle()

    if (meuUsuario) {
      if (meuUsuario.perfil !== 'titular') throw new Error('Apenas o titular pode convidar membros')
      escritorioId = meuUsuario.escritorio_id
      nomeRemetente = meuUsuario.nome
    } else {
      const { data: esc } = await admin
        .from('escritorios')
        .select('id, nome, responsavel')
        .eq('user_id', user.id)
        .maybeSingle()
      if (!esc) throw new Error('Apenas o titular pode convidar membros')
      escritorioId = esc.id
      nomeRemetente = esc.responsavel || 'Titular'
      nomeEscritorio = esc.nome || nomeEscritorio
    }

    // Busca nome do escritório se ainda não temos
    if (nomeEscritorio === 'o escritório' && escritorioId) {
      const { data: escInfo } = await admin.from('escritorios').select('nome').eq('id', escritorioId).maybeSingle()
      if (escInfo?.nome) nomeEscritorio = escInfo.nome
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

    // Cancela convites anteriores pendentes
    await admin.from('convites').update({ status: 'cancelado' })
      .eq('escritorio_id', escritorioId).eq('email', emailNorm).eq('status', 'pendente')

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
      .select().single()

    if (conviteErr) throw conviteErr

    // Gera o link de convite (não envia email — controlamos via Resend)
    let inviteLink: string

    const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
      type: 'invite',
      email: emailNorm,
      options: {
        redirectTo: `${siteUrl}/auth.html`,
        data: { nome, escritorio_id: escritorioId, convite_id: convite.id, convidado_por: nomeRemetente }
      }
    })

    if (linkErr) {
      // Usuário já existe no Auth — gera magic link para ele entrar diretamente
      const jaExiste = linkErr.message?.toLowerCase().includes('already')
      if (!jaExiste) {
        await admin.from('convites').delete().eq('id', convite.id)
        throw linkErr
      }
      const { data: mlData, error: mlErr } = await admin.auth.admin.generateLink({
        type: 'magiclink',
        email: emailNorm,
        options: { redirectTo: `${siteUrl}/auth.html` }
      })
      if (mlErr) {
        await admin.from('convites').delete().eq('id', convite.id)
        throw mlErr
      }
      inviteLink = mlData.properties.action_link
    } else {
      inviteLink = linkData.properties.action_link
    }

    // Envia email via Resend
    const emailRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: 'noreply@organizaadv.com.br',
        to: emailNorm,
        subject: `${nomeRemetente} te convidou para o OrganizaADV`,
        html: `
          <div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;padding:32px;background:#fff">
            <p style="font-weight:700;font-size:18px;color:#0D1321;margin:0 0 24px">OrganizaADV</p>
            <h2 style="color:#0D1321;margin:0 0 12px;font-size:22px">Você foi convidado!</h2>
            <p style="color:#48556A;line-height:1.6;margin:0 0 8px">
              <strong>${nomeRemetente}</strong> te convidou para fazer parte de <strong>${nomeEscritorio}</strong> no OrganizaADV.
            </p>
            <p style="color:#48556A;line-height:1.6;margin:0 0 28px">
              Clique no botão abaixo para criar sua senha e acessar o sistema.
            </p>
            <a href="${inviteLink}"
               style="display:inline-block;background:#0D1321;color:#fff;text-decoration:none;padding:14px 32px;border-radius:8px;font-weight:700;font-size:15px">
              Acessar o OrganizaADV →
            </a>
            <p style="color:#96A3B5;font-size:12px;line-height:1.6;margin:32px 0 0">
              Se você não esperava este convite, ignore este e-mail.
            </p>
          </div>
        `,
      }),
    })

    if (!emailRes.ok) {
      const body = await emailRes.text()
      await admin.from('convites').delete().eq('id', convite.id)
      throw new Error(`Resend: ${body}`)
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
