#!/bin/bash

# ============================================
# GUIA DE SETUP INICIAL - VPS
# Execute este script NA VPS
# ============================================

set -e  # Para em caso de erro

echo "🚀 Iniciando setup do Plannerate na VPS..."
echo ""

# ============================================
# 1. Criar estrutura de diretórios
# ============================================
echo "📁 Criando estrutura de diretórios..."
sudo mkdir -p /opt/plannerate/{production,staging,traefik/letsencrypt}
sudo chown -R $USER:$USER /opt/plannerate

# ============================================
# 2. Configurar Traefik Global
# ============================================
echo ""
echo "🌐 Configurando Traefik..."
cd /opt/plannerate/traefik

# Criar docker-compose.yml do Traefik
cat > docker-compose.yml << 'EOF'
# COLE AQUI O CONTEÚDO DO traefik-docker-compose.yml
EOF

# Criar .env do Traefik
cat > .env << 'EOF'
ACME_EMAIL=seu-email@dominio.com.br
ADMIN_DOMAIN=plannerate.com.br
EOF

echo "⚠️  EDITE o arquivo /opt/plannerate/traefik/.env com seu email!"
echo "   nano /opt/plannerate/traefik/.env"
read -p "Pressione ENTER quando terminar de editar..."

# Criar arquivo de certificados
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json

# Criar rede do Traefik
docker network create traefik-global || true

# Subir o Traefik
echo ""
echo "🚀 Iniciando Traefik..."
docker compose up -d

echo ""
echo "✅ Traefik configurado!"
docker compose ps

# ============================================
# 3. Clonar repositório - STAGING
# ============================================
echo ""
echo "📦 Configurando ambiente de STAGING..."
cd /opt/plannerate/staging

echo "Digite a URL do repositório Git:"
echo "Exemplo: git@github.com:seu-usuario/plannerate.git"
read -p "URL: " REPO_URL

git clone -b staging $REPO_URL .

# Criar .env de staging
echo ""
echo "📝 Criando arquivo .env de staging..."
cat > .env << 'EOF'
# COLE AQUI O CONTEÚDO DO env.staging.example
# E EDITE as senhas!
EOF

echo "⚠️  IMPORTANTE: Edite o arquivo .env de staging!"
echo "   nano /opt/plannerate/staging/.env"
echo ""
echo "Você precisa configurar:"
echo "  - DB_PASSWORD"
echo "  - REDIS_PASSWORD"
echo "  - APP_KEY (rode: docker compose -f docker-compose.staging.yml run --rm app php artisan key:generate)"
read -p "Pressione ENTER quando terminar..."

# ============================================
# 4. Clonar repositório - PRODUCTION
# ============================================
echo ""
echo "📦 Configurando ambiente de PRODUCTION..."
cd /opt/plannerate/production

git clone -b main $REPO_URL .

# Criar .env de production
echo ""
echo "📝 Criando arquivo .env de production..."
cat > .env << 'EOF'
# COLE AQUI O CONTEÚDO DO env.production.example
# E EDITE as senhas!
EOF

echo "⚠️  IMPORTANTE: Edite o arquivo .env de production!"
echo "   nano /opt/plannerate/production/.env"
echo ""
echo "Você precisa configurar:"
echo "  - DB_PASSWORD (DIFERENTE do staging!)"
echo "  - REDIS_PASSWORD (DIFERENTE do staging!)"
echo "  - APP_KEY (rode: docker compose -f docker-compose.prod.yml run --rm app php artisan key:generate)"
read -p "Pressione ENTER quando terminar..."

# ============================================
# 5. Configurar DNS
# ============================================
echo ""
echo "============================================"
echo "📡 CONFIGURAÇÃO DE DNS NECESSÁRIA"
echo "============================================"
echo ""
echo "Você precisa configurar os seguintes registros DNS:"
echo ""
echo "STAGING (plannerate.dev.br):"
echo "  A     plannerate.dev.br       →  $(curl -s ifconfig.me)"
echo "  A     *.plannerate.dev.br     →  $(curl -s ifconfig.me)"
echo "  CNAME reverb.plannerate.dev.br → plannerate.dev.br"
echo ""
echo "PRODUCTION (plannerate.com.br):"
echo "  A     plannerate.com.br       →  $(curl -s ifconfig.me)"
echo "  A     *.plannerate.com.br     →  $(curl -s ifconfig.me)"
echo "  CNAME reverb.plannerate.com.br → plannerate.com.br"
echo "  CNAME www.plannerate.com.br    → plannerate.com.br"
echo ""
read -p "Pressione ENTER quando terminar de configurar o DNS..."

# ============================================
# 6. Deploy inicial de staging
# ============================================
echo ""
echo "🚀 Fazendo deploy inicial de STAGING..."
cd /opt/plannerate/staging

docker compose -f docker-compose.staging.yml build --no-cache
docker compose -f docker-compose.staging.yml up -d

echo "⏳ Aguardando containers iniciarem..."
sleep 15

echo "🗄️  Rodando migrations..."
docker compose -f docker-compose.staging.yml exec app php artisan migrate --force

echo "🔑 Gerando APP_KEY..."
docker compose -f docker-compose.staging.yml exec app php artisan key:generate --force

echo "⚡ Otimizando..."
docker compose -f docker-compose.staging.yml exec app php artisan config:cache
docker compose -f docker-compose.staging.yml exec app php artisan route:cache
docker compose -f docker-compose.staging.yml exec app php artisan view:cache

echo ""
echo "📊 Status STAGING:"
docker compose -f docker-compose.staging.yml ps

# ============================================
# 7. Deploy inicial de production
# ============================================
echo ""
echo "🚀 Fazendo deploy inicial de PRODUCTION..."
cd /opt/plannerate/production

docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d

echo "⏳ Aguardando containers iniciarem..."
sleep 15

echo "🗄️  Rodando migrations..."
docker compose -f docker-compose.prod.yml exec app php artisan migrate --force

echo "🔑 Gerando APP_KEY..."
docker compose -f docker-compose.prod.yml exec app php artisan key:generate --force

echo "⚡ Otimizando..."
docker compose -f docker-compose.prod.yml exec app php artisan config:cache
docker compose -f docker-compose.prod.yml exec app php artisan route:cache
docker compose -f docker-compose.prod.yml exec app php artisan view:cache

echo ""
echo "📊 Status PRODUCTION:"
docker compose -f docker-compose.prod.yml ps

# ============================================
# 8. Resumo final
# ============================================
echo ""
echo "============================================"
echo "✅ SETUP CONCLUÍDO!"
echo "============================================"
echo ""
echo "📍 Seus ambientes:"
echo "  STAGING:    https://plannerate.dev.br"
echo "  PRODUCTION: https://plannerate.com.br"
echo ""
echo "📊 Traefik Dashboard:"
echo "  URL: https://traefik.plannerate.com.br"
echo "  User: admin"
echo "  Pass: admin123"
echo ""
echo "🔧 Comandos úteis:"
echo ""
echo "Ver logs de staging:"
echo "  cd /opt/plannerate/staging"
echo "  docker compose -f docker-compose.staging.yml logs -f"
echo ""
echo "Ver logs de production:"
echo "  cd /opt/plannerate/production"
echo "  docker compose -f docker-compose.prod.yml logs -f"
echo ""
echo "Restart de staging:"
echo "  cd /opt/plannerate/staging"
echo "  docker compose -f docker-compose.staging.yml restart"
echo ""
echo "Restart de production:"
echo "  cd /opt/plannerate/production"
echo "  docker compose -f docker-compose.prod.yml restart"
echo ""
echo "============================================"