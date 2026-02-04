#!/bin/bash

##############################################################################
# Plannerate VPS Setup Script
# 
# Este script configura uma VPS do zero para rodar o Plannerate com:
# - Docker & Docker Compose
# - Traefik como reverse proxy
# - Ambientes de staging e production separados
# - Estrutura de diretórios e permissões
#
# Uso: 
#   bash setup-vps-new.sh
#
# Requisitos:
#   - Ubuntu 22.04 ou 24.04 LTS
#   - Acesso root ou sudo
#   - Porta 80 e 443 abertas no firewall
##############################################################################

set -e  # Parar em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções de log
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Banner
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Plannerate VPS Setup Script                        ║"
echo "║         Automated Docker + Traefik Installation            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se está rodando como root ou com sudo
if [[ $EUID -ne 0 ]]; then
   log_error "Este script precisa ser executado como root ou com sudo"
   exit 1
fi

# Verificar sistema operacional
if ! grep -qi ubuntu /etc/os-release; then
    log_warning "Este script foi testado no Ubuntu. Pode não funcionar em outras distribuições."
fi

log_info "Sistema operacional detectado:"
cat /etc/os-release | grep PRETTY_NAME

echo ""
read -p "Continuar com a instalação? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Instalação cancelada pelo usuário"
    exit 1
fi

##############################################################################
# 1. Atualizar sistema
##############################################################################
log_info "Atualizando sistema..."
apt-get update -qq
apt-get upgrade -y -qq
log_success "Sistema atualizado"

##############################################################################
# 2. Instalar dependências básicas
##############################################################################
log_info "Instalando dependências básicas..."
apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    vim \
    htop \
    ufw
log_success "Dependências instaladas"

##############################################################################
# 3. Instalar Docker
##############################################################################
log_info "Verificando instalação do Docker..."

# Verificar se Docker já está instalado
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    log_warning "Docker já está instalado: $DOCKER_VERSION"
    echo ""
    read -p "Deseja reinstalar o Docker? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Pulando instalação do Docker"
    else
        log_info "Reinstalando Docker..."
        
        # Remover versões antigas
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Adicionar repositório oficial do Docker
        install -m 0755 -d /etc/apt/keyrings
        
        # Remover arquivo antigo se existir
        rm -f /etc/apt/keyrings/docker.gpg
        
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Instalar Docker Engine
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        log_success "Docker reinstalado com sucesso"
    fi
else
    log_info "Instalando Docker..."
    
    # Remover versões antigas
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Adicionar repositório oficial do Docker
    install -m 0755 -d /etc/apt/keyrings
    
    # Remover arquivo antigo se existir
    rm -f /etc/apt/keyrings/docker.gpg
    
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker Engine
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    log_success "Docker instalado com sucesso"
fi

# Verificar instalação
docker --version
docker compose version

##############################################################################
# 4. Configurar usuário deploy (não-root)
##############################################################################
log_info "Configurando usuário para deploy..."

DEPLOY_USER="plannerate"

# Criar usuário se não existir
if ! id "$DEPLOY_USER" &>/dev/null; then
    useradd -m -s /bin/bash "$DEPLOY_USER"
    log_success "Usuário $DEPLOY_USER criado"
else
    log_warning "Usuário $DEPLOY_USER já existe"
fi

# Adicionar ao grupo docker
usermod -aG docker "$DEPLOY_USER"
log_success "Usuário adicionado ao grupo docker"

##############################################################################
# 5. Configurar estrutura de diretórios
##############################################################################
log_info "Criando estrutura de diretórios..."

# Diretórios principais
mkdir -p /opt/plannerate/staging/{backups,storage}
mkdir -p /opt/plannerate/production/{backups,storage}
mkdir -p /opt/traefik/{letsencrypt,config}

# Ajustar permissões
chown -R "$DEPLOY_USER":"$DEPLOY_USER" /opt/plannerate
chmod -R 755 /opt/plannerate

log_success "Estrutura de diretórios criada"

##############################################################################
# 6. Configurar Traefik
##############################################################################
log_info "Configurando Traefik..."

# Criar rede global do Traefik
docker network create traefik-global 2>/dev/null || log_warning "Rede traefik-global já existe"

# Criar arquivo .env do Traefik
cat > /opt/traefik/.env <<'EOF'
# Email para Let's Encrypt
ACME_EMAIL=admin@plannerate.com.br

# Domínio do admin/dashboard
ADMIN_DOMAIN=plannerate.com.br
EOF

# Criar docker-compose do Traefik (versão 2.11 testada)
cat > /opt/traefik/docker-compose.yml <<'EOF'
services:
  traefik:
    image: traefik:v2.11
    container_name: traefik-global
    restart: unless-stopped
    
    command:
      # Dashboard
      - "--api.dashboard=true"
      - "--api.insecure=false"
      
      # Providers
      - "--providers.docker=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.watch=true"
      
      # Entrypoints (portas de entrada)
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      
      # Redirect HTTP -> HTTPS automático
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      
      # Let's Encrypt (SSL Automático)
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      
      # Logs
      - "--log.level=INFO"
      - "--accesslog=true"
    
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    
    networks:
      - traefik-global
    
    labels:
      - "traefik.enable=true"
      # Dashboard
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${ADMIN_DOMAIN}`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$8EVjn/nj$$GiLUZqcbueTFeD23SuB6x0"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth"

networks:
  traefik-global:
    external: true
EOF

# Criar arquivo para certificados Let's Encrypt
touch /opt/traefik/letsencrypt/acme.json
chmod 600 /opt/traefik/letsencrypt/acme.json

log_success "Traefik configurado"

##############################################################################
# 7. Gerar senhas e chaves
##############################################################################
log_info "Gerando senhas e chaves de segurança..."

# Função para gerar senha aleatória
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Gerar senhas únicas para cada ambiente
STAGING_DB_PASSWORD=$(generate_password)
STAGING_REDIS_PASSWORD=$(generate_password)
STAGING_REVERB_KEY=$(openssl rand -hex 16)
STAGING_REVERB_SECRET=$(openssl rand -hex 32)

PROD_DB_PASSWORD=$(generate_password)
PROD_REDIS_PASSWORD=$(generate_password)
PROD_REVERB_KEY=$(openssl rand -hex 16)
PROD_REVERB_SECRET=$(openssl rand -hex 32)

# APP_KEY será gerado depois que a imagem estiver disponível
log_success "Senhas e chaves geradas"

##############################################################################
# 8. Criar templates de .env
##############################################################################
log_info "Criando arquivos .env com senhas geradas..."

# Template staging
cat > /opt/plannerate/staging/.env.staging <<EOF
# ============================================
# Plannerate - Staging Environment
# ============================================

APP_NAME="Plannerate Staging"
APP_ENV=staging
APP_KEY=base64:TODO_GENERATE_AFTER_FIRST_DEPLOY
APP_DEBUG=true
APP_TIMEZONE=America/Sao_Paulo
APP_URL=https://staging.plannerate.dev.br
APP_LOCALE=pt_BR
APP_FALLBACK_LOCALE=pt_BR

# ============================================
# Domínio
# ============================================
DOMAIN=staging.plannerate.dev.br

# ============================================
# GitHub Container Registry
# ============================================
GITHUB_REPO=callcocam/plannerate

# ============================================
# Database (PostgreSQL)
# ============================================
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=plannerate_staging
DB_USERNAME=plannerate_staging
DB_PASSWORD=${STAGING_DB_PASSWORD}

# ============================================
# Redis
# ============================================
REDIS_HOST=redis
REDIS_PASSWORD=${STAGING_REDIS_PASSWORD}
REDIS_PORT=6379
REDIS_DB=0
REDIS_CACHE_DB=1

# ============================================
# Cache & Session
# ============================================
CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# ============================================
# Reverb (WebSockets)
# ============================================
REVERB_APP_ID=plannerate-staging
REVERB_APP_KEY=${STAGING_REVERB_KEY}
REVERB_APP_SECRET=${STAGING_REVERB_SECRET}
REVERB_HOST=reverb.staging.plannerate.dev.br
REVERB_PORT=8080
REVERB_SCHEME=https

VITE_REVERB_APP_KEY=\${REVERB_APP_KEY}
VITE_REVERB_HOST=\${REVERB_HOST}
VITE_REVERB_PORT=443
VITE_REVERB_SCHEME=https

# ============================================
# Multi-Tenancy (Raptor)
# ============================================
LANDLORD_SUBDOMAIN=landlord
TENANT_SUBDOMAIN=tenant

# ============================================
# Storage (DigitalOcean Spaces)
# ============================================
FILESYSTEM_DISK=do
DO_SPACES_KEY=
DO_SPACES_SECRET=
DO_SPACES_ENDPOINT=https://nyc3.digitaloceanspaces.com
DO_SPACES_REGION=nyc3
DO_SPACES_BUCKET=repositorioimagens

# ============================================
# Mail
# ============================================
MAIL_MAILER=smtp
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@plannerate.dev.br"
MAIL_FROM_NAME=\${APP_NAME}
EOF

# Template production
cat > /opt/plannerate/production/.env.production <<EOF
# ============================================
# Plannerate - Production Environment
# ============================================

APP_NAME="Plannerate"
APP_ENV=production
APP_KEY=base64:TODO_GENERATE_AFTER_FIRST_DEPLOY
APP_DEBUG=false
APP_TIMEZONE=America/Sao_Paulo
APP_URL=https://plannerate.com.br
APP_LOCALE=pt_BR
APP_FALLBACK_LOCALE=pt_BR

# ============================================
# Domínio
# ============================================
DOMAIN=plannerate.com.br

# ============================================
# GitHub Container Registry
# ============================================
GITHUB_REPO=callcocam/plannerate

# ============================================
# Database (PostgreSQL)
# ============================================
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=plannerate_production
DB_USERNAME=plannerate_prod
DB_PASSWORD=${PROD_DB_PASSWORD}

# ============================================
# Redis
# ============================================
REDIS_HOST=redis
REDIS_PASSWORD=${PROD_REDIS_PASSWORD}
REDIS_PORT=6379
REDIS_DB=0
REDIS_CACHE_DB=1

# ============================================
# Cache & Session
# ============================================
CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# ============================================
# Reverb (WebSockets)
# ============================================
REVERB_APP_ID=plannerate-prod
REVERB_APP_KEY=${PROD_REVERB_KEY}
REVERB_APP_SECRET=${PROD_REVERB_SECRET}
REVERB_HOST=reverb.plannerate.com.br
REVERB_PORT=8080
REVERB_SCHEME=https

VITE_REVERB_APP_KEY=\${REVERB_APP_KEY}
VITE_REVERB_HOST=\${REVERB_HOST}
VITE_REVERB_PORT=443
VITE_REVERB_SCHEME=https

# ============================================
# Multi-Tenancy (Raptor)
# ============================================
LANDLORD_SUBDOMAIN=landlord
TENANT_SUBDOMAIN=tenant

# ============================================
# Storage (DigitalOcean Spaces)
# ============================================
FILESYSTEM_DISK=do
DO_SPACES_KEY=
DO_SPACES_SECRET=
DO_SPACES_ENDPOINT=https://nyc3.digitaloceanspaces.com
DO_SPACES_REGION=nyc3
DO_SPACES_BUCKET=repositorioimagens

# ============================================
# Mail
# ============================================
MAIL_MAILER=smtp
MAIL_HOST=smtp.sendgrid.net
MAIL_PORT=587
MAIL_USERNAME=apikey
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@plannerate.com.br"
MAIL_FROM_NAME=\${APP_NAME}
EOF

# Salvar senhas em arquivo seguro para referência
cat > /root/.plannerate-credentials <<EOF
# Plannerate - Credenciais Geradas
# Gerado em: $(date)
# IMPORTANTE: Guarde este arquivo em local seguro e delete da VPS após backup

==9=====================================
STAGING CREDENTIALS
========================================
DB_PASSWORD=${STAGING_DB_PASSWORD}
REDIS_PASSWORD=${STAGING_REDIS_PASSWORD}
REVERB_APP_KEY=${STAGING_REVERB_KEY}
REVERB_APP_SECRET=${STAGING_REVERB_SECRET}

========================================
PRODUCTION CREDENTIALS
========================================
DB_PASSWORD=${PROD_DB_PASSWORD}
REDIS_PASSWORD=${PROD_REDIS_PASSWORD}
REVERB_APP_KEY=${PROD_REVERB_KEY}
REVERB_APP_SECRET=${PROD_REVERB_SECRET}

========================================
PRÓXIMOS PASSOS
========================================
1. Copie estas credenciais para um local seguro (gerenciador de senhas)
2. Delete este arquivo: rm /root/.plannerate-credentials
3. Configure as credenciais do DigitalOcean Spaces (DO_SPACES_KEY, DO_SPACES_SECRET)
4. Configure as credenciais de email (MAIL_*)
5. Após primeiro deploy, gere APP_KEY com:
   docker compose exec app php artisan key:generate
EOF

chmod 600 /root/.plannerate-credentials
chown root:root /root/.plannerate-credentials

chown "$DEPLOY_USER":"$DEPLOY_USER" /opt/plannerate/staging/.env.staging
chown "$DEPLOY_USER":"$DEPLOY_USER" /opt/plannerate/production/.env.production
chmod 600 /opt/plannerate/staging/.env.staging
chmod 600 /opt/plannerate/production/.env.production

log_success "Arquivos .env criados com senhas geradas"
log_warning "Credenciais salvas em: /root/.plannerate-credentials"

##############################################################################
# 8. Copiar docker-compose files
##############################################################################
log_info "Criando arquivos docker-compose..."

# Nota: Os arquivos docker-compose.staging.yml e docker-compose.production.yml
# devem ser copiados do repositório para /opt/plannerate/staging e /opt/plannerate/production

log_warning "IMPORTANTE: Você precisa copiar os arquivos docker-compose do repositório:"
echo "  - docker-compose.staging.new.yml → /opt/plannerate/staging/docker-compose.staging.yml"
echo "  - docker-compose.production.yml → /opt/plannerate/production/docker-compose.production.yml"

##############################################################################
# 10. Configurar firewall (UFW)
##############################################################################
log_info "Configurando firewall..."

ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS

ufw status

log_success "Firewall configurado"

##############################################################################
# 11. Iniciar Traefik
##############################################################################
log_info "Iniciando Traefik..."

cd /opt/traefik
docker compose up -d

sleep 5
docker compose ps

log_success "Traefik iniciado"

##############################################################################
# 12. Configurar SSH para GitHub Actions
##############################################################################
log_info "Configurando acesso SSH para GitHub Actions..."

# Criar diretório .ssh para o usuário deploy
sudo -u "$DEPLOY_USER" mkdir -p /home/"$DEPLOY_USER"/.ssh
sudo -u "$DEPLOY_USER" chmod 700 /home/"$DEPLOY_USER"/.ssh

log_warning "AÇÃO NECESSÁRIA: Adicione a chave pública do GitHub Actions ao arquivo:"
echo "  /home/$DEPLOY_USER/.ssh/authorized_keys"
echo ""
echo "Exemplo de comando (execute como root):"
echo "  echo 'sua-chave-publica-aqui' >> /home/$DEPLOY_USER/.ssh/authorized_keys"
echo "  chown $DEPLOY_USER:$DEPLOY_USER /home/$DEPLOY_USER/.ssh/authorized_keys"
echo "  chmod 600 /home/$DEPLOY_USER/.ssh/authorized_keys"

##############################################################################
# 13. Resumo Final
##############################################################################
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Instalação Concluída com Sucesso! 🎉            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

log_success "Docker instalado e funcionando"
log_success "Traefik rodando na rede traefik-global"
log_success "Usuário $DEPLOY_USER criado e configurado"
log_success "Estrutura de diretórios criada"
log_success "Firewall configurado"

echo ""
log_warning "CREDENCIAIS GERADAS:"
echo ""
echo "📄 Arquivo com todas as senhas: /root/.plannerate-credentials"
echo "⚠️  IMPORTANTE: Salve essas credenciais em local seguro e depois delete o arquivo!"
echo "   cat /root/.plannerate-credentials"
echo "   # Copie o conteúdo para seu gerenciador de senhas"
echo "   rm /root/.plannerate-credentials"
echo ""
log_warning "PRÓXIMOS PASSOS:"
echo ""
echo "1️⃣  Copiar docker-compose files do repositório para a VPS"
echo ""
echo "2️⃣  Configurar credenciais externas nos arquivos .env:"
echo "    vim /opt/plannerate/staging/.env.staging"
echo "    vim /opt/plannerate/production/.env.production"
echo "    # Preencha: DO_SPACES_KEY, DO_SPACES_SECRET, MAIL_*"
echo ""
echo "3️⃣  Após primeiro deploy, gerar APP_KEY:"
echo "    cd /opt/plannerate/staging"
echo "    docker compose exec app php artisan key:generate"
echo ""
echo "4️⃣  Copiar APP_KEY gerada para production também"
echo ""
echo "5️⃣  Configurar GitHub Secrets no repositório:"
echo "    - VPS_HOST: $(hostname -I | awk '{print $1}')"
echo "    - VPS_USER: $DEPLOY_USER"
echo "    - SSH_PRIVATE_KEY: (chave privada SSH)"
echo "    - STAGING_DOMAIN: staging.plannerate.dev.br"
echo "    - PRODUCTION_DOMAIN: plannerate.com.br"
echo ""
echo "6️⃣  Configurar DNS:"
echo "    - A record: plannerate.com.br → $(hostname -I | awk '{print $1}')"
echo "    - A record: *.plannerate.com.br → $(hostname -I | awk '{print $1}')"
echo "    - A record: staging.plannerate.dev.br → $(hostname -I | awk '{print $1}')"
echo "    - A record: *.staging.plannerate.dev.br → $(hostname -I | awk '{print $1}')"
echo ""
echo "7️⃣  Fazer primeiro deploy via GitHub Actions (push na branch dev)"
echo ""
echo "📚 Documentação completa: /opt/plannerate/README.md"
echo ""

log_info "Para verificar status do Traefik:"
echo "  cd /opt/traefik && docker compose logs -f"
echo ""

log_info "Para acessar como usuário deploy:"
echo "  sudo -u $DEPLOY_USER -i"
echo ""

log_success "Setup concluído! ✨"
