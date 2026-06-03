import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const LIMITES: Record<string, number> = {
  trial: 10,
  essencial: 50,
  avancado: 150,
  pro: 150,
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { movimentacao, demandaNome, demandaTipo, pdfBase64, escritorioId } = await req.json()

  const sbUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const sbKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const mes = new Date().toISOString().slice(0, 7) // 'YYYY-MM'

  // ── Verificar limite de uso ──────────────────────────────────
  let usandoCredito = false
  if (escritorioId) {
    const escRes = await fetch(
      `${sbUrl}/rest/v1/escritorios?id=eq.${escritorioId}&select=plano,ia_creditos_extras`,
      { headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}` } }
    )
    const [esc] = await escRes.json()
    const plano: string = esc?.plano ?? 'trial'
    const limite = LIMITES[plano] ?? 10
    const creditosExtras: number = esc?.ia_creditos_extras ?? 0

    const usoRes = await fetch(
      `${sbUrl}/rest/v1/ia_uso?escritorio_id=eq.${escritorioId}&mes=eq.${mes}&select=contagem`,
      { headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}` } }
    )
    const [usoRow] = await usoRes.json()
    const uso: number = usoRow?.contagem ?? 0

    if (uso >= limite) {
      if (creditosExtras <= 0) {
        return new Response(
          JSON.stringify({ _limite: true, uso, limite, plano, creditos_extras: 0 }),
          { status: 200, headers: { 'Content-Type': 'application/json', ...CORS } }
        )
      }
      usandoCredito = true
    }
  }

  // ── Chamar a IA ──────────────────────────────────────────────
  const messages: { role: string; content: unknown[] }[] = []

  const promptText = `Você é um assistente jurídico especializado em direito brasileiro. Analise a movimentação processual e responda APENAS com JSON válido, sem markdown, sem explicações fora do JSON:
{
  "resumo": "Resumo claro em 1-2 frases do que ocorreu",
  "situacao": "Situação atual do processo em uma frase",
  "proximos_passos": ["passo 1", "passo 2"],
  "prazo": "DD/MM/AAAA ou null",
  "urgente": true ou false,
  "alerta_prazo": "Descrição breve do risco de prazo ou null"
}

Demanda: ${demandaNome} — ${demandaTipo}`

  if (pdfBase64) {
    messages.push({
      role: 'user',
      content: [
        { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: pdfBase64 } },
        { type: 'text', text: promptText },
      ],
    })
  } else {
    messages.push({
      role: 'user',
      content: [{ type: 'text', text: `${promptText}\n\nMovimentação: ${JSON.stringify(movimentacao)}` }],
    })
  }

  const apiHeaders: Record<string, string> = {
    'Content-Type': 'application/json',
    'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
    'anthropic-version': '2023-06-01',
  }
  if (pdfBase64) apiHeaders['anthropic-beta'] = 'pdfs-2024-09-25'

  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: apiHeaders,
    body: JSON.stringify({ model: 'claude-sonnet-4-6', max_tokens: 600, messages }),
  })

  if (!r.ok) {
    const errBody = await r.text()
    console.error('Anthropic error', r.status, errBody)
    return new Response(JSON.stringify({ _erro: errBody }), { status: 200, headers: CORS })
  }

  const dados = await r.json()
  const txt = dados.content?.[0]?.text ?? ''
  let resultado: unknown
  try {
    resultado = JSON.parse(txt.replace(/```json|```/g, '').trim())
  } catch {
    console.error('JSON parse falhou. Resposta da IA:', txt)
    return new Response(
      JSON.stringify({ _erro: `IA retornou formato inválido: ${txt.slice(0, 200)}` }),
      { status: 200, headers: CORS }
    )
  }

  // ── Incrementar contador de uso ──────────────────────────────
  if (escritorioId) {
    if (usandoCredito) {
      await fetch(`${sbUrl}/rest/v1/rpc/consumir_credito_ia`, {
        method: 'POST',
        headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_escritorio_id: escritorioId }),
      }).catch(() => {})
    } else {
      await fetch(`${sbUrl}/rest/v1/rpc/incrementar_ia_uso`, {
        method: 'POST',
        headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_escritorio_id: escritorioId, p_mes: mes }),
      }).catch(() => {})
    }
  }

  return new Response(JSON.stringify(resultado), {
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
})
