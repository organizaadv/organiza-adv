#!/bin/bash
# OrganizaADV — Migração para novo projeto Supabase (sa-east-1)
# Novo projeto: jixopedfltyriertssal

set -e

NOVO_REF="jixopedfltyriertssal"
NOVO_URL="https://jixopedfltyriertssal.supabase.co"
DB_HOST="aws-0-sa-east-1.pooler.supabase.com"
SQL_DIR="/home/vinicius/organiza-adv/sql"
FN_DIR="/home/vinicius/organiza-adv/supabase/functions"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  OrganizaADV — Migração para São Paulo (sa-east-1)"
echo "═══════════════════════════════════════════════════"
echo ""

# ── 1. CREDENCIAIS ──────────────────────────────────────────────
ENV_FILE="/home/vinicius/organiza-adv/.env.migration"

if [ -f "$ENV_FILE" ]; then
  echo "→ Carregando credenciais salvas de .env.migration..."
  source "$ENV_FILE"
  echo "  ✅ Carregado. (Delete .env.migration para redigitar tudo)"
else
  echo "→ Informe as credenciais do NOVO projeto Supabase:"
  echo ""

  read -s -p "  Senha do banco (database password): " DB_PASS; echo ""
  read -s -p "  anon key (eyJ...): " ANON_KEY; echo ""
  read -s -p "  service_role key (eyJ...): " SERVICE_KEY; echo ""
  read -s -p "  Supabase Access Token (dashboard → Account → Access Tokens): " SB_TOKEN; echo ""

  echo ""
  echo "→ Variáveis das Edge Functions:"
  echo ""
  read -s -p "  STRIPE_SECRET_KEY: " STRIPE_SECRET; echo ""
  read -s -p "  STRIPE_WEBHOOK_SECRET: " STRIPE_WEBHOOK; echo ""
  read -s -p "  ANTHROPIC_API_KEY: " ANTHROPIC_KEY; echo ""
  read -s -p "  RESEND_API_KEY: " RESEND_KEY; echo ""

  # Salva para próximas execuções
  cat > "$ENV_FILE" <<ENVEOF
DB_PASS='${DB_PASS}'
ANON_KEY='${ANON_KEY}'
SERVICE_KEY='${SERVICE_KEY}'
SB_TOKEN='${SB_TOKEN}'
STRIPE_SECRET='${STRIPE_SECRET}'
STRIPE_WEBHOOK='${STRIPE_WEBHOOK}'
ANTHROPIC_KEY='${ANTHROPIC_KEY}'
RESEND_KEY='${RESEND_KEY}'
ENVEOF
  chmod 600 "$ENV_FILE"
  echo ""
  echo "  ✅ Credenciais salvas em .env.migration (chmod 600)"
fi

echo ""
echo "───────────────────────────────────────────────────"
echo "  ETAPA 1/5 — Linkando Supabase CLI..."
echo "───────────────────────────────────────────────────"
echo ""

cd /home/vinicius/organiza-adv
SUPABASE_ACCESS_TOKEN="$SB_TOKEN" supabase link --project-ref "$NOVO_REF" --password "$DB_PASS"

echo ""
echo "───────────────────────────────────────────────────"
echo "  ETAPA 2/5 — Preparando e rodando migrations..."
echo "───────────────────────────────────────────────────"
echo ""

MIG_DIR="/home/vinicius/organiza-adv/supabase/migrations"
mkdir -p "$MIG_DIR"

# Copia migrations em ordem com timestamp sequencial (formato exigido pelo CLI)
declare -a ORDERED=(
  "20240101000100_escritorios:000_escritorios.sql"
  "20240101000200_usuarios:001_usuarios.sql"
  "20240101000300_rls_escritorios_select:001b_rls_escritorios_select.sql"
  "20240101000400_colab_escritorio:000b_colab_escritorio.sql"
  "20240101000500_convites:002_convites.sql"
  "20240101000600_pagamentos:003_pagamentos.sql"
  "20240101000700_recovery_codes:004_recovery_codes.sql"
  "20240101000800_financeiro:005_financeiro.sql"
  "20240101000900_migrar_titulares:005_migrar_titulares_equipe.sql"
  "20240101000950_demandas_escritorio:000c_demandas_escritorio.sql"
  "20240101000960_atendimentos:000d_atendimentos.sql"
  "20240101000970_agenda:000e_agenda.sql"
  "20240101001000_clientes:006_clientes.sql"
  "20240101001100_movimentacoes:007_movimentacoes.sql"
  "20240101001200_rls_demandas_delete:007_rls_demandas_delete.sql"
  "20240101001300_clientes_movimentacoes:008_clientes_movimentacoes.sql"
  "20240101001400_ia_uso:008_ia_uso.sql"
  "20240101001500_creditos_extras:009_creditos_extras.sql"
  "20240101001600_stripe_subscription:010_stripe_subscription.sql"
  "20240101001700_funcoes_rpc:011_funcoes_rpc.sql"
  "20240101001800_producao_pagamentos:012_producao_pagamentos.sql"
  "20240101001900_agenda_cliente_id:013_agenda_cliente_id.sql"
  "20240101002000_realtime:013_realtime.sql"
  "20240101002100_atendimentos_anotacoes:014_atendimentos_anotacoes.sql"
  "20240101002200_rls_escritorios_update:014_rls_escritorios_update.sql"
  "20240101002300_fn_salvar_etapas:015_fn_salvar_etapas.sql"
  "20240101002400_stripe_customer_id:015_stripe_customer_id.sql"
)

for entry in "${ORDERED[@]}"; do
  ts="${entry%%:*}"
  src="${entry##*:}"
  dest="${MIG_DIR}/${ts}.sql"
  cp "${SQL_DIR}/${src}" "$dest"
  echo "  ▸ ${ts}.sql"
done

echo ""
echo "  Reparando histórico remoto de migrations..."

export SUPABASE_ACCESS_TOKEN="$SB_TOKEN"

# Coleta todas as versões que o Supabase reporta como órfãs e as reverte
ORPHAN_VERSIONS=$(supabase migration list --project-ref "$NOVO_REF" 2>&1 \
  | grep -oP '[0-9]{14}(?=\s)' || true)

if [ -n "$ORPHAN_VERSIONS" ]; then
  echo "  ▸ Versões a reparar: $ORPHAN_VERSIONS"
  supabase migration repair --status reverted $ORPHAN_VERSIONS \
    --project-ref "$NOVO_REF"
  echo "  ✅ Histórico reparado"
else
  echo "  ✅ Sem versões órfãs"
fi

echo ""
echo "  Rodando supabase db push..."
SUPABASE_ACCESS_TOKEN="$SB_TOKEN" supabase db push --password "$DB_PASS"

echo ""
echo "───────────────────────────────────────────────────"
echo "  ETAPA 3/6 — Configurando secrets das Edge Functions..."
echo "───────────────────────────────────────────────────"
echo ""

SUPABASE_ACCESS_TOKEN="$SB_TOKEN" supabase secrets set \
  SUPABASE_URL="$NOVO_URL" \
  SUPABASE_ANON_KEY="$ANON_KEY" \
  SUPABASE_SERVICE_ROLE_KEY="$SERVICE_KEY" \
  STRIPE_SECRET_KEY="$STRIPE_SECRET" \
  STRIPE_WEBHOOK_SECRET="$STRIPE_WEBHOOK" \
  STRIPE_PRICE_ESSENCIAL="price_1Tdrw8RyPQPsLWIWhU95zxCl" \
  STRIPE_PRICE_AVANCADO="price_1TdrxMRyPQPsLWIWKK9FxMeG" \
  ANTHROPIC_API_KEY="$ANTHROPIC_KEY" \
  RESEND_API_KEY="$RESEND_KEY" \
  SITE_URL="https://organizaadv.com.br"

echo "✅ Secrets configurados"

echo ""
echo "───────────────────────────────────────────────────"
echo "  ETAPA 4/6 — Deploy das Edge Functions..."
echo "───────────────────────────────────────────────────"
echo ""

FUNCTIONS=("resumir-ia" "criar-checkout" "stripe-webhook" "invite-member" "criar-portal" "recovery-otp" "admin-escritorio" "cancelar-conta")

for fn in "${FUNCTIONS[@]}"; do
  echo -n "  ▸ $fn ... "
  SUPABASE_ACCESS_TOKEN="$SB_TOKEN" supabase functions deploy "$fn" --no-verify-jwt 2>&1 | tail -1
  echo "✅"
done

echo ""
echo "───────────────────────────────────────────────────"
echo "  ETAPA 5/6 — Atualizando arquivos HTML..."
echo "───────────────────────────────────────────────────"
echo ""

OLD_URL="https://cfoastlckbscoggiiqlr.supabase.co"
OLD_KEY_PATTERN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmb2FzdGxja2JzY29nZ2lpcWxyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NTIwODYsImV4cCI6MjA5MTIyODA4Nn0.sJPwSXCTE8xkC8vxz69kxs_ViWDvmOZGS1UctORuZRA"

for htmlfile in app.html auth.html admin.html; do
  echo -n "  ▸ $htmlfile ... "
  sed -i "s|${OLD_URL}|${NOVO_URL}|g" "/home/vinicius/organiza-adv/${htmlfile}"
  sed -i "s|${OLD_KEY_PATTERN}|${ANON_KEY}|g" "/home/vinicius/organiza-adv/${htmlfile}"
  echo "✅"
done

echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✅ MIGRAÇÃO CONCLUÍDA!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  Próximos passos manuais:"
echo "  1. Supabase Dashboard → Auth → Email Templates"
echo "     Trocar {{ .ConfirmationURL }} por {{ .Token }}"
echo "     nos templates 'Confirm signup' e 'Magic Link'"
echo ""
echo "  2. Supabase Dashboard → Auth → Providers → Email"
echo "     Habilitar 'Enable Email OTP'"
echo ""
echo "  3. Stripe Webhook → atualizar URL para:"
echo "     ${NOVO_URL}/functions/v1/stripe-webhook"
echo ""

echo "───────────────────────────────────────────────────"
echo "  ETAPA 6/6 — Deploy na Vercel..."
echo "───────────────────────────────────────────────────"
echo ""

VERCEL_BIN="/home/vinicius/.local/node_modules/.bin/vercel"
cd /home/vinicius/organiza-adv
"$VERCEL_BIN" --prod --yes

echo ""
echo "═══════════════════════════════════════════════════"
echo "  ✅ TUDO PRONTO — app em produção!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  Passos manuais restantes:"
echo "  1. Supabase Dashboard → Auth → Email Templates"
echo "     Trocar {{ .ConfirmationURL }} por {{ .Token }}"
echo "     nos templates 'Confirm signup' e 'Magic Link'"
echo "  2. Stripe Webhook → atualizar URL para:"
echo "     ${NOVO_URL}/functions/v1/stripe-webhook"
echo ""
