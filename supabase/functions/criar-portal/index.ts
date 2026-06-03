import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const STRIPE_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const SB_URL     = Deno.env.get('SUPABASE_URL') ?? ''
const SB_KEY     = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const sbAdmin = createClient(SB_URL, SB_KEY)

    const { data: { user }, error: authError } = await sbAdmin.auth.getUser(
      (req.headers.get('Authorization') ?? '').replace('Bearer ', '')
    )
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Não autorizado' }), {
        status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    // Busca escritório do usuário
    const { data: usuario } = await sbAdmin
      .from('usuarios')
      .select('escritorio_id')
      .eq('id', user.id)
      .single()

    if (!usuario?.escritorio_id) {
      return new Response(JSON.stringify({ error: 'Escritório não encontrado' }), {
        status: 404, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const { data: escritorio } = await sbAdmin
      .from('escritorios')
      .select('stripe_customer_id, plano')
      .eq('id', usuario.escritorio_id)
      .single()

    if (!escritorio?.stripe_customer_id) {
      return new Response(JSON.stringify({ error: 'sem_assinatura' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const origin = req.headers.get('origin') ?? 'https://organizaadv.com.br'

    const stripeRes = await fetch('https://api.stripe.com/v1/billing_portal/sessions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${STRIPE_KEY}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        'customer': escritorio.stripe_customer_id,
        'return_url': `${origin}/app.html`,
      }).toString(),
    })

    const session = await stripeRes.json()
    if (!session.url) {
      console.error('Erro Stripe portal:', JSON.stringify(session))
      return new Response(JSON.stringify({ error: 'Erro ao criar sessão do portal' }), {
        status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ url: session.url }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('Erro interno criar-portal:', e)
    return new Response(JSON.stringify({ error: 'Erro interno' }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})
