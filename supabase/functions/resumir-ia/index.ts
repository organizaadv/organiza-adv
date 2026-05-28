import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { movimentacao, demandaNome, demandaTipo, pdfBase64 } = await req.json()

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
        {
          type: 'document',
          source: { type: 'base64', media_type: 'application/pdf', data: pdfBase64 },
        },
        { type: 'text', text: promptText },
      ],
    })
  } else {
    messages.push({
      role: 'user',
      content: [
        { type: 'text', text: `${promptText}\n\nMovimentação: ${JSON.stringify(movimentacao)}` },
      ],
    })
  }

  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 600,
      messages,
    }),
  })

  if (!r.ok) {
    const errBody = await r.text()
    console.error('Anthropic error', r.status, errBody)
    return new Response(JSON.stringify({ _erro: errBody }), { status: 200, headers: CORS })
  }

  const dados = await r.json()
  const txt = dados.content?.[0]?.text ?? ''
  try {
    const resultado = JSON.parse(txt.replace(/```json|```/g, '').trim())
    return new Response(JSON.stringify(resultado), {
      headers: { 'Content-Type': 'application/json', ...CORS },
    })
  } catch {
    return new Response(JSON.stringify(null), { status: 200, headers: CORS })
  }
})
