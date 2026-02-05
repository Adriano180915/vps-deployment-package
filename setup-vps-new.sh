#!/bin/bash

##############################################################################
# Laravel App VPS Setup Script
# 
# Este script configura uma VPS do zero para rodar aplicação Laravel com:
# - Docker & Docker Compose
# - Traefik como reverse proxy
# - MySQL instalado localmente
# - Estrutura em /opt/production
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

# ============================================
# Configuração - Solicita informações do usuário
# ============================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Configuração Inicial da VPS                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

read -p "Nome do projeto (ex: meuapp): " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-meuapp}

read -p "Domínio principal (ex: meuapp.com.br): " DOMAIN
DOMAIN=${DOMAIN:-app.local}

read -p "Email para Let's Encrypt: " ACME_EMAIL
ACME_EMAIL=${ACME_EMAIL:-admin@${DOMAIN}}

read -p "GitHub Container Registry (ex: usuario/repo): " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-myuser/myapp}

echo ""
echo "Configuração:"
echo "  - Projeto: ${PROJECT_NAME}"
echo "  - Domínio: ${DOMAIN}"
echo "  - Email: ${ACME_EMAIL}"
echo "  - GitHub: ${GITHUB_REPO}"
echo ""
read -p "Continuar com esta configuração? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Instalação cancelada"
    exit 1
fi

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
# 3. Instalar MySQL Server
##############################################################################
log_info "Instalando MySQL Server..."

# Senha root do MySQL
MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Pré-configurar senha do MySQL (para instalação não-interativa)
debconf-set-selections <<< "mysql-server mysql-server/root_password password ${MYSQL_ROOT_PASSWORD}"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${MYSQL_ROOT_PASSWORD}"

# Instalar MySQL
apt-get install -y -qq mysql-server

# Configurar MySQL para aceitar conexões de containers Docker
cat > /etc/mysql/mysql.conf.d/custom.cnf <<EOF
[mysqld]
bind-address = 0.0.0.0
default-authentication-plugin = mysql_native_password
max_connections = 200
innodb_buffer_pool_size = 1G
EOF

systemctl restart mysql

log_success "MySQL instalado e configurado"

# Criar database e usuário para a aplicação
DB_NAME="${PROJECT_NAME}_production"
DB_USER="${PROJECT_NAME}_user"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

mysql -u root -p"${MYSQL_ROOT_PASSWORD}" <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

log_success "Database criado: ${DB_NAME}"
log_success "Usuário criado: ${DB_USER}"

##############################################################################
# 4. Instalar Docker
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
# 5. Configurar usuário deploy (não-root)
##############################################################################
log_info "Configurando usuário para deploy..."

DEPLOY_USER="deploy"

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
# 6. Configurar estrutura de diretórios
##############################################################################
log_info "Criando estrutura de diretórios..."

# Diretórios principais
mkdir -p /opt/production/{backups,storage}
mkdir -p /opt/traefik/{letsencrypt,config}

# Ajustar permissões
chown -R "$DEPLOY_USER":"$DEPLOY_USER" /opt/production
chmod -R 755 /opt/production

log_success "Estrutura de diretórios criada"

##############################################################################
# 7. Configurar Traefik
##############################################################################
log_info "Configurando Traefik..."

# Criar rede global do Traefik
docker network create traefik-global 2>/dev/null || log_warning "Rede traefik-global já existe"

# Criar arquivo .env do Traefik
cat > /opt/traefik/.env <<EOF
# Email para Let's Encrypt
ACME_EMAIL=${ACME_EMAIL}

# Domínio do admin/dashboard
ADMIN_DOMAIN=${DOMAIN}
EOF

# Criar docker-compose do Traefik (versão 2.11 testada)
cat > /opt/traefik/docker-compose.yml <<'TRAEFIK_COMPOSE'
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
      - "--certificatesresolvers.letsencrypt.acme.email=\${ACME_EMAIL}"
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
      - "traefik.http.routers.dashboard.rule=Host(\`traefik.\${ADMIN_DOMAIN}\`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$8EVjn/nj$$GiLUZqcbueTFeD23SuB6x0"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth"

networks:
  traefik-global:
    external: true
TRAEFIK_COMPOSE

# Criar arquivo para certificados Let's Encrypt
touch /opt/traefik/letsencrypt/acme.json
chmod 600 /opt/traefik/letsencrypt/acme.json

log_success "Traefik configurado"

##############################################################################
# 8. Gerar senhas e chaves
##############################################################################
log_info "Gerando senhas e chaves de segurança..."

# Função para gerar senha aleatória
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Gerar senhas
REDIS_PASSWORD=$(generate_password)

# APP_KEY será gerado depois que a imagem estiver disponível
log_success "Senhas e chaves geradas"

##############################################################################
# 9. Criar arquivo .env
##############################################################################
log_info "Criando arquivo .env com senhas geradas..."

# Obter IP da máquina para conexão MySQL
MACHINE_IP=$(hostname -I | awk '{print $1}')

cat > /opt/production/.env <<EOF
# ============================================
# ${PROJECT_NAME} - Production Environment
# ============================================

APP_NAME="${PROJECT_NAME}"
APP_ENV=production
APP_KEY=base64:TODO_GENERATE_AFTER_FIRST_DEPLOY
APP_DEBUG=false
APP_TIMEZONE=America/Sao_Paulo
APP_URL=https://${DOMAIN}
APP_LOCALE=pt_BR
APP_FALLBACK_LOCALE=pt_BR

# ============================================
# Domínio
# ============================================
DOMAIN=${DOMAIN}

# ============================================
# GitHub Container Registry
# ============================================
GITHUB_REPO=${GITHUB_REPO}

# ============================================
# Database (MySQL local)
# ============================================
DB_CONNECTION=mysql
DB_HOST=${MACHINE_IP}
DB_PORT=3306
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

# ============================================
# Redis
# ============================================
REDIS_HOST=redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_PORT=6379
REDIS_DB=0
REDIS_CACHE_DB=1

# ============================================
# Cache & Session & Queue
# ============================================
CACHE_STORE=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

# ============================================
# Broadcasting (Pusher)
# ============================================
BROADCAST_CONNECTION=pusher

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1

VITE_PUSHER_APP_KEY=\${PUSHER_APP_KEY}
VITE_PUSHER_APP_CLUSTER=\${PUSHER_APP_CLUSTER}
VITE_PUSHER_PORT=443
VITE_PUSHER_SCHEME=https

# ============================================
# Multi-Tenancy (se usar Raptor)
# ============================================
LANDLORD_SUBDOMAIN=landlord
TENANT_SUBDOMAIN=tenant

# ============================================
# Storage (configure conforme necessário)
# ============================================
FILESYSTEM_DISK=local

# ============================================
# Mail
# ============================================
MAIL_MAILER=smtp
MAIL_HOST=
MAIL_PORT=587
MAIL_USERNAME=
MAIL_PASSWORD=
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@${DOMAIN}"
MAIL_FROM_NAME="\${APP_NAME}"

# ============================================
# Horizon
# ============================================
HORIZON_PREFIX=${PROJECT_NAME}:horizon:
EOF

# Salvar senhas em arquivo seguro para referência
cat > /root/.credentials <<EOF
# ${PROJECT_NAME} - Credenciais Geradas
# Gerado em: $(date)
# IMPORTANTE: Guarde este arquivo em local seguro e delete da VPS após backup

========================================
MYSQL ROOT
========================================
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}

========================================
DATABASE
========================================
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=${MACHINE_IP}

========================================
REDIS
========================================
REDIS_PASSWORD=${REDIS_PASSWORD}

========================================
PRÓXIMOS PASSOS
========================================
1. Copie estas credenciais para um local seguro (gerenciador de senhas)
2. Delete este arquivo: rm /root/.credentials
3. Configure as credenciais do Pusher (PUSHER_APP_ID, PUSHER_APP_KEY, PUSHER_APP_SECRET)
4. Configure as credenciais de email (MAIL_*)
5. Configure storage se necessário (S3, DO Spaces, etc)
6. Após primeiro deploy, gere APP_KEY com:
   cd /opt/production
   docker compose exec app php artisan key:generate
EOF

chmod 600 /root/.credentials
chown root:root /root/.credentials

chown "$DEPLOY_USER":"$DEPLOY_USER" /opt/production/.env
chmod 600 /opt/production/.env

log_success "Arquivo .env criado com senhas geradas"
log_warning "Credenciais salvas em: /root/.credentials"

##############################################################################
# 10. Copiar docker-compose file
##############################################################################
log_info "IMPORTANTE: Você precisa copiar o arquivo docker-compose.production.yml"
log_warning "Copie para: /opt/production/docker-compose.production.yml"

##############################################################################
# 11. Configurar firewall (UFW)
##############################################################################
log_info "Configurando firewall..."

ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS
ufw allow 3306/tcp # MySQL (para conexão de containers)

ufw status

log_success "Firewall configurado"

##############################################################################
# 12. Iniciar Traefik
##############################################################################
log_info "Iniciando Traefik..."

cd /opt/traefik
docker compose up -d

sleep 5
docker compose ps

log_success "Traefik iniciado"

##############################################################################
# 13. Configurar SSH para GitHub Actions
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
# 14. Resumo Final
##############################################################################
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Instalação Concluída com Sucesso! 🎉            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

log_success "MySQL instalado e configurado"
log_success "Docker instalado e funcionando"
log_success "Traefik rodando na rede traefik-global"
log_success "Usuário $DEPLOY_USER criado e configurado"
log_success "Estrutura de diretórios criada em /opt/production"
log_success "Firewall configurado"

echo ""
log_warning "CREDENCIAIS GERADAS:"
echo ""
echo "📄 Arquivo com todas as senhas: /root/.credentials"
echo "⚠️  IMPORTANTE: Salve essas credenciais em local seguro e depois delete o arquivo!"
echo "   cat /root/.credentials"
echo "   # Copie o conteúdo para seu gerenciador de senhas"
echo "   rm /root/.credentials"
echo ""
log_warning "PRÓXIMOS PASSOS:"
echo ""
echo "1️⃣  Copiar docker-compose.production.yml do repositório para a VPS:"
echo "    scp docker-compose.production.yml $DEPLOY_USER@\$(hostname -I | awk '{print \$1}'):/opt/production/docker-compose.production.yml"
echo ""
echo "2️⃣  Configurar credenciais externas no arquivo .env:"
echo "    vim /opt/production/.env"
echo "    # Preencha: PUSHER_*, MAIL_*, etc"
echo ""
echo "3️⃣  Após primeiro deploy, gerar APP_KEY:"
echo "    cd /opt/production"
echo "    docker compose exec app php artisan key:generate"
echo ""
echo "4️⃣  Configurar GitHub Secrets no repositório:"
echo "    - VPS_HOST: $(hostname -I | awk '{print $1}')"
echo "    - VPS_USER: $DEPLOY_USER"
echo "    - SSH_PRIVATE_KEY: (chave privada SSH)"
echo "    - DOMAIN: ${DOMAIN}"
echo ""
echo "5️⃣  Configurar DNS:"
echo "    - A record: ${DOMAIN} → $(hostname -I | awk '{print $1}')"
echo "    - A record: *.${DOMAIN} → $(hostname -I | awk '{print $1}')"
echo "    - A record: traefik.${DOMAIN} → $(hostname -I | awk '{print $1}')"
echo ""
echo "6️⃣  Fazer primeiro deploy via GitHub Actions"
echo ""

log_info "Para verificar status do Traefik:"
echo "  cd /opt/traefik && docker compose logs -f"
echo ""

log_info "Para acessar como usuário deploy:"
echo "  sudo -u $DEPLOY_USER -i"
echo ""

log_info "Para conectar no MySQL:"
echo "  mysql -u root -p"
echo "  # Senha: veja em /root/.credentials"
echo ""

log_success "Setup concluído! ✨"
