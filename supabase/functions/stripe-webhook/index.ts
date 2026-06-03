import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { crypto } from 'https://deno.land/std@0.168.0/crypto/mod.ts'

// Mapeia valor em centavos → créditos de IA (pacotes avulsos)
const CREDITOS_POR_VALOR: Record<number, number> = {
  1990: 20,  // Starter
  4990: 60,  // Pro
  12990: 200, // Max
}

async function verificarAssinatura(payload: string, header: string, secret: string): Promise<boolean> {
  const parts = Object.fromEntries(header.split(',').map(p => p.split('=')))
  const timestamp = parts['t']
  const assinatura = parts['v1']
  if (!timestamp || !assinatura) return false
  const signed = `${timestamp}.${payload}`
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']
  )
  const mac = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signed))
  const computed = Array.from(new Uint8Array(mac)).map(b => b.toString(16).padStart(2, '0')).join('')
  return computed === assinatura
}

const SB_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SB_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

async function patchEscritorio(escritorioId: string, updates: Record<string, unknown>) {
  const res = await fetch(`${SB_URL}/rest/v1/escritorios?id=eq.${escritorioId}`, {
    method: 'PATCH',
    headers: {
      apikey: SB_KEY,
      Authorization: `Bearer ${SB_KEY}`,
      'Content-Type': 'application/json',
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(updates),
  })
  if (!res.ok) console.error('patchEscritorio falhou:', await res.text())
}

serve(async (req) => {
  if (req.method !== 'POST') return new Response('ok', { status: 200 })

  const payload = await req.text()
  const stripeHeader = req.headers.get('stripe-signature') ?? ''
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''

  if (!await verificarAssinatura(payload, stripeHeader, webhookSecret)) {
    console.error('Assinatura Stripe inválida')
    return new Response('Unauthorized', { status: 401 })
  }

  const evento = JSON.parse(payload)
  console.log('Stripe evento:', evento.type)

  // ── 1. checkout.session.completed ────────────────────────────
  // Dispara para: assinatura nova (criar-checkout) e compra de créditos (payment link)
  if (evento.type === 'checkout.session.completed') {
    const session = evento.data.object
    const tipo = session.metadata?.tipo

    if (tipo === 'assinatura') {
      const plano: string        = session.metadata?.plano ?? ''
      const escritorioId: string = session.metadata?.escritorio_id ?? ''
      const subId: string        = session.subscription ?? ''
      if (escritorioId && plano) {
        await patchEscritorio(escritorioId, {
          plano,
          ativo: true,
          stripe_subscription_id: subId || null,
        })
        console.log(`✅ Plano ${plano} ativado — escritório ${escritorioId}`)
      }
    } else {
      // Compra de créditos avulsos via payment link
      const email: string        = session.customer_details?.email ?? session.customer_email ?? ''
      const valorCentavos: number = session.amount_total ?? 0
      const creditos              = CREDITOS_POR_VALOR[valorCentavos]

      if (!email) { console.error('Email ausente no evento', session.id); return new Response('ok', { status: 200 }) }
      if (!creditos) { console.log(`Valor ${valorCentavos}¢ não mapeado para créditos — ignorado`); return new Response('ok', { status: 200 }) }

      const res = await fetch(`${SB_URL}/rest/v1/rpc/adicionar_creditos_ia`, {
        method: 'POST',
        headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_email: email, p_creditos: creditos }),
      })
      const resultado = await res.json()
      if (!resultado.ok) console.error('Erro ao adicionar créditos:', resultado.erro, '— email:', email)
      else console.log(`✅ ${creditos} créditos adicionados para ${email}`)
    }
  }

  // ── 2. invoice.paid ───────────────────────────────────────────
  // Dispara a cada renovação mensal — garante que o plano continua ativo
  if (evento.type === 'invoice.paid') {
    const invoice = evento.data.object
    if (invoice.billing_reason === 'subscription_create') {
      // Primeira cobrança já tratada pelo checkout.session.completed — ignora
      return new Response('ok', { status: 200 })
    }
    const meta = invoice.subscription_details?.metadata ?? {}
    const escritorioId: string = meta.escritorio_id ?? ''
    const plano: string        = meta.plano ?? ''
    if (escritorioId && plano) {
      await patchEscritorio(escritorioId, { plano, ativo: true })
      console.log(`✅ Renovação confirmada: plano ${plano} — escritório ${escritorioId}`)
    }
  }

  // ── 3. customer.subscription.deleted ─────────────────────────
  // Dispara quando assinatura é cancelada no Stripe
  if (evento.type === 'customer.subscription.deleted') {
    const sub = evento.data.object
    const escritorioId: string = sub.metadata?.escritorio_id ?? ''
    if (escritorioId) {
      await patchEscritorio(escritorioId, {
        plano: 'expirado',
        ativo: false,
        stripe_subscription_id: null,
      })
      console.log(`✅ Assinatura cancelada — escritório ${escritorioId} marcado como expirado`)
    }
  }

  return new Response('ok', { status: 200 })
})
