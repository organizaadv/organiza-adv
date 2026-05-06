import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

serve(async (req) => {
  const { movimentacao, demandaNome, demandaTipo } = await req.json()

  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-5',
      max_tokens: 400,
      messages: [{
        role: 'user',
        content: `Você é um assistente jurídico. Analise esta movimentação processual e responda APENAS com JSON válido:\n{"resumo":"Resumo claro em 1-2 frases","acao":"O que o advogado deve fazer agora","prazo":"DD/MM/AAAA ou null","urgente":true|false}\n\nMovimentação: ${JSON.stringify(movimentacao)}\nDemanda: ${demandaNome} — ${demandaTipo}`
      }]
    })
  })

  if (!r.ok) return new Response(JSON.stringify(null), { status: 200 })

  const dados = await r.json()
  const txt = dados.content?.[0]?.text ?? ''
  try {
    const resultado = JSON.parse(txt.replace(/```json|```/g, '').trim())
    return new Response(JSON.stringify(resultado), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch {
    return new Response(JSON.stringify(null), { status: 200 })
  }
})
