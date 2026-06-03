import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const STRIPE_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? ''
const SB_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SB_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const PRICES: Record<string, string> = {
  essencial: Deno.env.get('STRIPE_PRICE_ESSENCIAL') ?? '',
  avancado:  Deno.env.get('STRIPE_PRICE_AVANCADO') ?? '',
}

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const sbAdmin = createClient(SB_URL, SB_SERVICE_KEY)

    const { data: { user }, error: authError } = await sbAdmin.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Não autorizado' }), {
        status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    const { plano } = await req.json()
    const priceId = PRICES[plano]
    if (!priceId) {
      return new Response(JSON.stringify({ error: 'Plano inválido' }), {
        status: 400, headers: { ...CORS, 'Content-Type': 'application/json' },
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

    const origin = req.headers.get('origin') ?? 'https://organizaadv.com.br'

    const body = new URLSearchParams({
      'mode': 'subscription',
      'line_items[0][price]': priceId,
      'line_items[0][quantity]': '1',
      'customer_email': user.email ?? '',
      'success_url': `${origin}/app.html?assinatura=ok`,
      'cancel_url': `${origin}/app.html`,
      'metadata[tipo]': 'assinatura',
      'metadata[plano]': plano,
      'metadata[escritorio_id]': usuario.escritorio_id,
      'subscription_data[metadata][tipo]': 'assinatura',
      'subscription_data[metadata][plano]': plano,
      'subscription_data[metadata][escritorio_id]': usuario.escritorio_id,
      'payment_method_types[]': 'card',
      'locale': 'pt-BR',
    })

    const stripeRes = await fetch('https://api.stripe.com/v1/checkout/sessions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${STRIPE_KEY}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body.toString(),
    })

    const session = await stripeRes.json()
    if (!session.url) {
      console.error('Erro Stripe:', JSON.stringify(session))
      return new Response(JSON.stringify({ error: 'Erro ao criar sessão de pagamento' }), {
        status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ url: session.url }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error('Erro interno:', e)
    return new Response(JSON.stringify({ error: 'Erro interno' }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})
