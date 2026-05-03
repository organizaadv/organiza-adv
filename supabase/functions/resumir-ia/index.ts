import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, content-type' }

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const { texto, pdfBase64, demandaNome, demandaTipo, etapaAtual, histFases } = await req.json()

  const histTxt = (histFases || [])
    .map((h: { etapa: string; data: string }) => `• ${h.etapa} em ${h.data}`)
    .join('\n') || 'Nenhuma fase concluída ainda'

  const msgContent: unknown[] = []

  if (pdfBase64) {
    msgContent.push({
      type: 'document',
      source: { type: 'base64', media_type: 'application/pdf', data: pdfBase64 }
    })
  }

  msgContent.push({
    type: 'text',
    text: `Você é um assistente jurídico especializado em direito brasileiro. Analise ${pdfBase64 ? 'o documento PDF da movimentação processual acima' : 'a movimentação processual abaixo'} no contexto da demanda indicada e responda APENAS com JSON válido (sem markdown, sem texto fora do JSON):

{"resumo":"Resumo claro em 2-3 frases sobre o que aconteceu na movimentação","situacao":"Avaliação estratégica da situação atual do processo — o que isso significa para o cliente","proximos_passos":["Ação concreta e específica 1","Ação concreta e específica 2","Ação concreta e específica 3"],"prazo":"DD/MM/AAAA ou null se não houver prazo identificado","urgente":true,"alerta_prazo":"Descrição do prazo crítico e consequências de perder, ou null"}

Onde urgente=true apenas se houver prazo processual em menos de 10 dias ou risco imediato de prejuízo ao cliente.

Demanda: ${demandaNome} — ${demandaTipo}
Etapa atual no escritório: ${etapaAtual || 'Não informada'}
Histórico de fases já concluídas:
${histTxt}
${!pdfBase64 && texto ? `\nMovimentação:\n${texto}` : ''}`
  })

  const r = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
      'anthropic-version': '2023-06-01',
      'anthropic-beta': 'pdfs-2024-09-25',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 1500,
      messages: [{ role: 'user', content: msgContent }]
    })
  })

  if (!r.ok) {
    const err = await r.text()
    return new Response(JSON.stringify({ erro: 'Falha na API: ' + r.status, detalhe: err }), {
      status: 200, headers: { 'Content-Type': 'application/json', ...CORS }
    })
  }

  const dados = await r.json()
  const txt = dados.content?.[0]?.text ?? ''
  try {
    const resultado = JSON.parse(txt.replace(/```json|```/g, '').trim())
    return new Response(JSON.stringify(resultado), {
      headers: { 'Content-Type': 'application/json', ...CORS }
    })
  } catch {
    return new Response(JSON.stringify({ erro: 'Resposta inválida da IA', raw: txt.substring(0, 500) }), {
      status: 200, headers: { 'Content-Type': 'application/json', ...CORS }
    })
  }
})
