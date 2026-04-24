import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const ok  = (d: unknown) => new Response(JSON.stringify(d), { headers: { ...CORS, 'Content-Type': 'application/json' } })
const err = (msg: string, s = 400) => new Response(JSON.stringify({ error: msg }), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } })

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { action, email, code } = await req.json()

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // ── ENVIAR CÓDIGO ──────────────────────────────────────────────
    if (action === 'send') {
      if (!email) return err('E-mail obrigatório')

      const otp       = Math.floor(100000 + Math.random() * 900000).toString()
      const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString()

      // Gera recovery token do Supabase (não envia e-mail, só gera o token)
      const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
        type: 'recovery',
        email,
      })

      // Usuário não existe → retorna sucesso silencioso (não revela se o e-mail está cadastrado)
      if (linkErr || !linkData?.properties?.hashed_token) {
        console.log('generateLink skipped:', linkErr?.message)
        return ok({ ok: true })
      }

      const hashedToken = linkData.properties.hashed_token

      // Invalida códigos anteriores pendentes
      await admin.from('recovery_codes').update({ used: true }).eq('email', email).eq('used', false)

      // Salva novo código
      const { error: insertErr } = await admin.from('recovery_codes').insert({
        email,
        code: otp,
        hashed_token: hashedToken,
        expires_at: expiresAt,
      })
      if (insertErr) throw insertErr

      // Envia e-mail via Resend API
      const resendKey = Deno.env.get('RESEND_API_KEY')!
      const emailRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: 'noreply@organizaadv.com.br',
          to: email,
          subject: 'Recuperação de senha — OrganizaADV',
          html: `
            <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:32px;background:#fff">
              <p style="font-weight:700;font-size:18px;color:#0D1321;margin:0 0 24px">OrganizaADV</p>
              <h2 style="color:#0D1321;margin:0 0 12px;font-size:22px">Recuperação de senha</h2>
              <p style="color:#48556A;line-height:1.6;margin:0 0 24px">
                Use o código abaixo para criar uma nova senha.<br>
                Ele é válido por <strong>30 minutos</strong>.
              </p>
              <div style="font-size:42px;font-weight:700;letter-spacing:12px;color:#0D1321;text-align:center;padding:28px 16px;background:#F5F7FA;border-radius:12px;margin-bottom:28px">
                ${otp}
              </div>
              <p style="color:#96A3B5;font-size:13px;line-height:1.6;margin:0">
                Se você não solicitou a recuperação de senha, ignore este e-mail.<br>
                Nenhuma alteração foi feita na sua conta.
              </p>
            </div>
          `,
        }),
      })

      if (!emailRes.ok) {
        const body = await emailRes.text()
        throw new Error(`Resend: ${body}`)
      }

      return ok({ ok: true })
    }

    // ── VERIFICAR CÓDIGO ───────────────────────────────────────────
    if (action === 'verify') {
      if (!email || !code) return err('Dados incompletos')

      const { data, error: selErr } = await admin
        .from('recovery_codes')
        .select()
        .eq('email', email)
        .eq('code', code)
        .eq('used', false)
        .gt('expires_at', new Date().toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

      if (selErr || !data) return err('Código incorreto ou expirado. Verifique e tente novamente.')

      // Marca como usado e retorna o hashed_token para o cliente criar a sessão
      await admin.from('recovery_codes').update({ used: true }).eq('id', data.id)

      return ok({ hashed_token: data.hashed_token })
    }

    return err('Ação inválida')

  } catch (e) {
    console.error(e)
    return err((e as Error).message || 'Erro interno', 500)
  }
})
