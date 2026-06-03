import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const STRIPE_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const SB_URL     = Deno.env.get('SUPABASE_URL') ?? ''
const SB_KEY     = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function stripeGet(path: string) {
  const r = await fetch(`https://api.stripe.com/v1/${path}`, {
    headers: { 'Authorization': `Bearer ${STRIPE_KEY}` },
  })
  return r.json()
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
      .select('stripe_customer_id, stripe_subscription_id, plano, email')
      .eq('id', usuario.escritorio_id)
      .single()

    let customerId: string = escritorio?.stripe_customer_id ?? ''

    // Fallback: se não tem customer_id mas tem subscription_id, busca no Stripe e salva
    if (!customerId && escritorio?.stripe_subscription_id) {
      console.log('Buscando customer via subscription:', escritorio.stripe_subscription_id)
      const sub = await stripeGet(`subscriptions/${escritorio.stripe_subscription_id}`)
      if (sub.customer) {
        customerId = sub.customer
        await sbAdmin
          .from('escritorios')
          .update({ stripe_customer_id: customerId })
          .eq('id', usuario.escritorio_id)
        console.log('stripe_customer_id salvo retroativamente:', customerId)
      }
    }

    // Fallback: busca customer pelo e-mail do escritório
    if (!customerId && escritorio?.email) {
      console.log('Buscando customer por e-mail:', escritorio.email)
      const list = await stripeGet(`customers?email=${encodeURIComponent(escritorio.email)}&limit=1`)
      const found = list.data?.[0]
      if (found?.id) {
        customerId = found.id
        await sbAdmin
          .from('escritorios')
          .update({ stripe_customer_id: customerId })
          .eq('id', usuario.escritorio_id)
        console.log('stripe_customer_id salvo via e-mail:', customerId)
      }
    }

    if (!customerId) {
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
        'customer': customerId,
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
