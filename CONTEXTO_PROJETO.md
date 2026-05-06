# OrganizaADV — Contexto Completo do Projeto

## Quem somos
- **Vinícius** (co-fundador, dev) — justa.assessoria1@gmail.com
- **Dra. Monica Bleg** (co-fundadora, advogada que usa o produto no dia a dia)
- SaaS jurídico para escritórios de advocacia brasileiros

---

## Stack
- **Frontend:** HTML/JS puro, sem framework/bundler
- **Backend:** Supabase (Auth, PostgreSQL, Edge Functions)
- **Deploy:** Vercel
- **Banco:** `https://cfoastlckbscoggiiqlr.supabase.co`

---

## Diretório do projeto
```
/home/vinicius/organiza-adv/
```

---

## Arquivos e tamanhos
| Arquivo | Linhas | Descrição |
|---|---|---|
| `app.html` | ~5610 | App principal — todo o SaaS |
| `auth.html` | ~617 | Login/signup/recovery + suporte a convite |
| `admin.html` | ~583 | Painel admin (Vinícius) — escritórios, MRR, trial, pagamentos |
| `index.html` | ~646 | Landing page (trial self-service) |
| `cadastro.html` | ~297 | Fluxo de cadastro |
| `contratar.html` | ~176 | Página de contratação de plano |
| `demo.html` | ~280 | Demo do produto |
| `sql/001_usuarios.sql` | ~86 | Tabela `usuarios` (login individual) |
| `sql/002_convites.sql` | ~59 | Tabela `convites` (invite flow) |
| `sql/003_pagamentos.sql` | ~38 | Tabela `pagamentos` (registro manual) |
| `supabase/functions/invite-member/index.ts` | ~122 | Edge Function: envia email de convite |
| `supabase/functions/resumir-ia/index.ts` | ~35 | Edge Function: resumo IA |

---

## Planos e valores
| Plano | Preço | Limite |
|---|---|---|
| `trial` | Grátis 7 dias, sem cartão | — |
| `essencial` | R$ 99/mês | 2 advogados |
| `avancado` | R$ 149/mês | 5 advogados |
| `pro` | Legado | igual essencial |

---

## Modelo de dados — arquitetura atual

### Tabela `usuarios` (novo modelo — login individual)
- Cada membro do escritório tem seu próprio email/senha
- Colunas de permissões: `perm_processos`, `perm_demandas`, `perm_agenda`, `perm_clientes`, `perm_financeiro`, `perm_relatorios`, `perm_equipe`
- Função JS central: `temPermissao()`

### Tabela `colab_escritorio` (modelo legado — ainda em uso nos seletores de responsável)
- Fallback necessário para compatibilidade com dados antigos
- **Regra:** sempre manter fallback para esse modelo ao sugerir novas funcionalidades

### Tabela `convites`
- Invite flow via Edge Function `invite-member`
- Email enviado via Supabase Admin API

### Tabela `pagamentos`
- Registro manual pelo admin

---

## O que já foi implementado

### auth.html
- Login individual email/senha
- Signup trial (auto-criação de escritório + titular em `usuarios`)
- Recovery de senha
- Suporte a token de convite na URL

### app.html
- Busca usuário por `session.user.id` na tabela `usuarios`, fallback para contas antigas
- **Permissões granulares:** `temPermissao()` usa colunas `perm_*`
- **Trial banner + bloqueio:** CSS var `--trial-offset`, painel urgentes `p<=1`
- **Onboarding:** campo OAB + titular auto-cadastrado em `colab_escritorio`
- **Logo do escritório** na sidebar; "Powered by OrganizaADV" discreto quando há logo
- **Meu Perfil (cfg view):** campos nome, WhatsApp, alterar senha
- **Modal de equipe:** invite flow com permissões por módulo, OAB obrigatório para advogados

### Aba Publicações
- Feed unificado Tribunal + Diário Oficial
- Busca automática DataJud por nome do advogado
- Filtros + badge unificado
- Funções: `renderPublicacoes()`, `buscarPorNome()`, `atualizarBadgePub()`

### Aba Processos
- Listagem alfabética
- Importação em lote `.xlsx`/`.csv` (SheetJS)
- Relatório de importação
- Funções: `renderProcessos()`, `abrirImportacao()`, `processarArquivoImport()`, `confirmarImportacao()`

### Aba Relatórios
- 4 tipos: individual, lista geral, por área, sem movimentação 30d
- PDF com logo do escritório
- Mensagem WhatsApp editável
- Funções: `renderRelatorios()`, `selecionarTipoRel()`, `gerarRelPDF()`, `cabecalhoPDF()`, `estiloPDF()`, `abrirJanelaPDF()`
- **Regra:** todo PDF usa `cabecalhoPDF()` + `estiloPDF()` + `abrirJanelaPDF()` para consistência

### Aba Demandas
- Visão accordion por cliente com badges de urgência
- Relatório de produtividade mensal da equipe em PDF
- Funções: `renderLista()`, `toggleGrupoDem()`, `abrirRelProd()`, `gerarRelProdPDF()`

### admin.html
- Painel para Vinícius monitorar escritórios, MRR, trials, pagamentos

---

## O que ainda falta fazer
1. **Deploy da Edge Function** `invite-member`:
   ```
   supabase functions deploy invite-member --project-ref cfoastlckbscoggiiqlr
   ```
2. **Configurar SMTP** no Supabase Dashboard (Auth > Settings > Email)
3. **Rodar migrations SQL** 001, 002, 003 no Supabase SQL Editor
4. **WhatsApp automático** da Agenda (webhook ou API — ex: Z-API ou Evolution API)
5. **Integração de pagamento** (Stripe ou Pagar.me) para converter trial → assinante automaticamente
6. **Módulo de atendimentos** melhorado

---

## Preferências de trabalho (Vinícius)
- Dá contexto completo e deixa Claude implementar com autonomia
- Quando diz "sim" ou "pode continuar", quer que o trabalho avance sem confirmar cada passo
- Stack sem framework — manter tudo em HTML/JS puro
- Sempre verificar compatibilidade com tabela `usuarios` ao sugerir novas funcionalidades
- Sempre manter fallback para `colab_escritorio`

---

## Por que a arquitetura foi mudada
A arquitetura antiga tinha seleção visual de colaborador (sem login individual), o que impedia escalar para SaaS multi-user real. A nova arquitetura usa login individual por email/senha para cada membro do escritório.
