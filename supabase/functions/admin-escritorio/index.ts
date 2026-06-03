import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const ADMINS = ['organizaadv81@gmail.com', 'monicableg01@gmail.com']

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceKey  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const anonKey     = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    // Verifica se quem chamou é admin
    const authHeader = req.headers.get('Authorization') ?? ''
    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user } } = await caller.auth.getUser()
    if (!user || !ADMINS.includes(user.email ?? '')) {
      return new Response(JSON.stringify({ error: 'Não autorizado' }), {
        status: 403, headers: { ...CORS, 'Content-Type': 'application/json' }
      })
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const body = await req.json()
    const { acao, escritorio_id } = body
    if (!escritorio_id) throw new Error('escritorio_id é obrigatório')

    if (acao === 'estender_trial') {
      const novaData = new Date()
      novaData.setDate(novaData.getDate() + 7)
      const novoVal = novaData.toISOString()

      // Busca o registro atual para saber quais colunas de trial existem
      const { data: esc, error: fetchErr } = await admin
        .from('escritorios')
        .select('trial_fim, trial_expira')
        .eq('id', escritorio_id)
        .maybeSingle()
      if (fetchErr) throw new Error(fetchErr.message)
      if (!esc) throw new Error('Escritório não encontrado')

      const updates: Record<string, string> = {}
      if ('trial_fim' in esc) updates.trial_fim = novoVal
      if ('trial_expira' in esc) updates.trial_expira = novoVal
      if (Object.keys(updates).length === 0) updates.trial_fim = novoVal

      const { error } = await admin.from('escritorios').update(updates).eq('id', escritorio_id)
      if (error) throw new Error(error.message)

      return new Response(JSON.stringify({ ok: true, updates }), {
        headers: { ...CORS, 'Content-Type': 'application/json' }
      })
    }

    if (acao === 'converter_plano') {
      const { plano } = body
      if (!plano) throw new Error('plano é obrigatório')
      const { error } = await admin
        .from('escritorios')
        .update({ plano, ativo: true })
        .eq('id', escritorio_id)
      if (error) throw new Error(error.message)

      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...CORS, 'Content-Type': 'application/json' }
      })
    }

    if (acao === 'suspender') {
      const { error } = await admin
        .from('escritorios')
        .update({ ativo: false })
        .eq('id', escritorio_id)
      if (error) throw new Error(error.message)

      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...CORS, 'Content-Type': 'application/json' }
      })
    }

    throw new Error('Ação desconhecida: ' + acao)
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' }
    })
  }
})
