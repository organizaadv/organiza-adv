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

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    // Verifica se quem chamou é admin
    const authHeader = req.headers.get('Authorization') ?? ''
    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    })
    const { data: { user } } = await caller.auth.getUser()
    if (!user || !ADMINS.includes(user.email ?? '')) {
      throw new Error('Não autorizado')
    }

    const { escritorio_id, user_id } = await req.json()
    if (!escritorio_id) throw new Error('escritorio_id é obrigatório')

    // Deleta dados na ordem certa (sem cascade)
    await admin.from('convites').delete().eq('escritorio_id', escritorio_id)
    await admin.from('colab_escritorio').delete().eq('escritorio_id', escritorio_id)
    await admin.from('demandas_escritorio').delete().eq('escritorio_id', escritorio_id)
    await admin.from('usuarios').delete().eq('escritorio_id', escritorio_id)
    await admin.from('escritorios').delete().eq('id', escritorio_id)

    // Remove o usuário do auth se user_id válido (permite recadastro com mesmo email)
    const uid = user_id && user_id !== 'null' && user_id !== 'undefined' ? user_id : null
    if (uid) {
      const { error: delErr } = await admin.auth.admin.deleteUser(uid)
      if (delErr) console.error('deleteUser:', delErr.message)
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...CORS, 'Content-Type': 'application/json' }
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 400, headers: { ...CORS, 'Content-Type': 'application/json' }
    })
  }
})
