import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const LIMITES: Record<string, number> = {
  trial: 0,      // trial não tem cota mensal — usa apenas ia_creditos_extras
  essencial: 50,
  avancado: 150,
  pro: 150,
}

function jsonOk(data: unknown) {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { movimentacao, demandaNome, demandaTipo, pdfBase64, escritorioId } = await req.json()

    const sbUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const sbKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const mes = new Date().toISOString().slice(0, 7)

    // ── Verificar limite de uso ──────────────────────────────────
    let usandoCredito = false
    if (escritorioId) {
      let plano = 'trial'
      let creditosExtras = 0
      let uso = 0

      // Busca plano e créditos extras — tolera coluna inexistente (migration pendente)
      const escRes = await fetch(
        `${sbUrl}/rest/v1/escritorios?id=eq.${escritorioId}&select=plano,ia_creditos_extras`,
        { headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}` } }
      )
      if (escRes.ok) {
        const escBody = await escRes.json()
        const esc = Array.isArray(escBody) ? escBody[0] : null
        plano = esc?.plano ?? 'trial'
        creditosExtras = esc?.ia_creditos_extras ?? 0
      } else {
        console.warn('escritorios query falhou (migration pendente?):', escRes.status)
      }

      // Busca uso do mês — tolera tabela inexistente (migration pendente)
      const usoRes = await fetch(
        `${sbUrl}/rest/v1/ia_uso?escritorio_id=eq.${escritorioId}&mes=eq.${mes}&select=contagem`,
        { headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}` } }
      )
      if (usoRes.ok) {
        const usoBody = await usoRes.json()
        const usoRow = Array.isArray(usoBody) ? usoBody[0] : null
        uso = usoRow?.contagem ?? 0
      } else {
        console.warn('ia_uso query falhou (migration pendente?):', usoRes.status)
      }

      const limite = LIMITES[plano] ?? 10
      if (uso >= limite) {
        if (creditosExtras <= 0) {
          return jsonOk({ _limite: true, uso, limite, plano, creditos_extras: 0 })
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

    const apiKey = Deno.env.get('ANTHROPIC_API_KEY') ?? ''
    if (!apiKey) {
      console.error('ANTHROPIC_API_KEY não configurada')
      return jsonOk({ _erro: 'Chave da API não configurada no servidor.' })
    }

    const apiHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
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
      return jsonOk({ _erro: `Anthropic ${r.status}: ${errBody.slice(0, 300)}` })
    }

    const dados = await r.json()
    const txt = dados.content?.[0]?.text ?? ''
    let resultado: unknown
    try {
      resultado = JSON.parse(txt.replace(/```json|```/g, '').trim())
    } catch {
      console.error('JSON parse falhou. Resposta da IA:', txt)
      return jsonOk({ _erro: `IA retornou formato inválido: ${txt.slice(0, 200)}` })
    }

    // ── Incrementar contador de uso ──────────────────────────────
    if (escritorioId) {
      const rpcEndpoint = usandoCredito
        ? `${sbUrl}/rest/v1/rpc/consumir_credito_ia`
        : `${sbUrl}/rest/v1/rpc/incrementar_ia_uso`
      const rpcBody = usandoCredito
        ? { p_escritorio_id: escritorioId }
        : { p_escritorio_id: escritorioId, p_mes: mes }

      await fetch(rpcEndpoint, {
        method: 'POST',
        headers: { apikey: sbKey, Authorization: `Bearer ${sbKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(rpcBody),
      }).catch((e) => console.warn('Falha ao registrar uso IA:', e))
    }

    return jsonOk(resultado)

  } catch (e) {
    console.error('Erro inesperado na Edge Function resumir-ia:', e)
    return new Response(
      JSON.stringify({ _erro: `Erro interno: ${(e as Error).message}` }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...CORS } }
    )
  }
})
