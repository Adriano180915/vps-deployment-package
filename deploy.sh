#!/bin/bash

##############################################################################
# Script de Deploy - Exemplo GitHub Actions
# Use este script como referência para criar seu workflow
##############################################################################

set -e

# Variáveis (em produção, use secrets do GitHub)
VPS_HOST="${VPS_HOST}"
VPS_USER="${VPS_USER:-deploy}"
GITHUB_REPO="${GITHUB_REPO}"
DOMAIN="${DOMAIN}"
DEPLOY_PATH="/opt/production"

echo "🚀 Iniciando deploy..."
echo "  - Host: ${VPS_HOST}"
echo "  - Usuário: ${VPS_USER}"
echo "  - Repo: ${GITHUB_REPO}"
echo "  - Domínio: ${DOMAIN}"

# Conectar via SSH e fazer deploy
ssh ${VPS_USER}@${VPS_HOST} << 'DEPLOY_SCRIPT'

set -e

echo "📦 Fazendo pull da imagem..."
cd /opt/production
docker compose -f docker-compose.production.yml pull

echo "🔄 Parando containers..."
docker compose -f docker-compose.production.yml down

echo "🚀 Subindo novos containers..."
docker compose -f docker-compose.production.yml up -d

echo "⏳ Aguardando containers ficarem saudáveis..."
sleep 10

echo "🔨 Rodando migrations..."
docker compose -f docker-compose.production.yml exec -T app php artisan migrate --force

echo "🧹 Limpando cache..."
docker compose -f docker-compose.production.yml exec -T app php artisan optimize:clear
docker compose -f docker-compose.production.yml exec -T app php artisan config:cache
docker compose -f docker-compose.production.yml exec -T app php artisan route:cache
docker compose -f docker-compose.production.yml exec -T app php artisan view:cache

echo "📊 Verificando status..."
docker compose -f docker-compose.production.yml ps

echo "✅ Deploy concluído!"

# Ver últimas linhas do log
echo ""
echo "📝 Últimos logs:"
docker compose -f docker-compose.production.yml logs --tail=20 app

DEPLOY_SCRIPT

echo ""
echo "✅ Deploy concluído com sucesso!"
echo ""
echo "🌐 Acesse: https://${DOMAIN}"
echo "📊 Horizon: https://${DOMAIN}/horizon"
echo "🏥 Health: https://${DOMAIN}/up"
