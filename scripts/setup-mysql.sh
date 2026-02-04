#!/bin/bash

##############################################################################
# MySQL Setup Script - Plannerate VPS
# 
# Este script configura um servidor MySQL standalone ou em cluster
# para uso com o Plannerate
#
# Uso: 
#   sudo bash setup-mysql.sh
#
# Requisitos:
#   - Ubuntu 22.04 ou 24.04 LTS
#   - Acesso root
##############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Plannerate MySQL Setup Script                     ║"
echo "║         MySQL Server Configuration                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Verificar se está rodando como root
if [[ $EUID -ne 0 ]]; then
   log_error "Este script precisa ser executado como root ou com sudo"
   exit 1
fi

##############################################################################
# 1. Perguntar tipo de instalação
##############################################################################
echo ""
log_info "Selecione o tipo de instalação:"
echo "1) MySQL Standalone (desenvolvimento/testes)"
echo "2) MySQL via Docker (recomendado para produção)"
echo "3) Configuração manual (pular instalação)"
echo ""
read -p "Escolha uma opção [1-3]: " MYSQL_TYPE

##############################################################################
# 2. Gerar credenciais
##############################################################################
log_info "Gerando credenciais..."

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

ROOT_PASSWORD=$(generate_password)
STAGING_DB_NAME="plannerate_staging"
STAGING_DB_USER="plannerate_staging"
STAGING_DB_PASSWORD=$(generate_password)

PROD_DB_NAME="plannerate_production"
PROD_DB_USER="plannerate_prod"
PROD_DB_PASSWORD=$(generate_password)

log_success "Credenciais geradas"

##############################################################################
# 3. Instalação baseada no tipo escolhido
##############################################################################

if [ "$MYSQL_TYPE" = "1" ]; then
    ##########################################################################
    # Instalação Standalone (Sistema)
    ##########################################################################
    log_info "Instalando MySQL Server..."
    
    # Atualizar pacotes
    apt-get update -qq
    
    # Instalar MySQL
    apt-get install -y mysql-server mysql-client
    
    # Iniciar serviço
    systemctl start mysql
    systemctl enable mysql
    
    log_success "MySQL Server instalado"
    
    # Configurar root password
    log_info "Configurando senha root..."
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${ROOT_PASSWORD}';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # Criar databases e usuários
    log_info "Criando databases e usuários..."
    
    mysql -u root -p"${ROOT_PASSWORD}" <<EOF
-- Database Staging
CREATE DATABASE IF NOT EXISTS ${STAGING_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${STAGING_DB_USER}'@'%' IDENTIFIED BY '${STAGING_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${STAGING_DB_NAME}.* TO '${STAGING_DB_USER}'@'%';

-- Database Production
CREATE DATABASE IF NOT EXISTS ${PROD_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${PROD_DB_USER}'@'%' IDENTIFIED BY '${PROD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${PROD_DB_NAME}.* TO '${PROD_DB_USER}'@'%';

FLUSH PRIVILEGES;
EOF
    
    # Configurar para aceitar conexões remotas
    log_info "Configurando acesso remoto..."
    
    sed -i 's/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
    
    # Restart MySQL
    systemctl restart mysql
    
    MYSQL_HOST="localhost"
    MYSQL_PORT="3306"
    
    log_success "MySQL Standalone configurado"

elif [ "$MYSQL_TYPE" = "2" ]; then
    ##########################################################################
    # Instalação via Docker
    ##########################################################################
    log_info "Configurando MySQL via Docker..."
    
    # Verificar se Docker está instalado
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado. Execute setup-vps-new.sh primeiro."
        exit 1
    fi
    
    # Criar diretórios
    mkdir -p /opt/mysql/{data,config}
    
    # Criar arquivo de configuração MySQL
    cat > /opt/mysql/config/my.cnf <<'EOF'
[mysqld]
# Configurações de performance
max_connections = 200
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# Charset
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Binlog (para replicação futura)
server-id = 1
log-bin = mysql-bin
binlog_format = ROW
expire_logs_days = 7

# Slow query log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow-query.log
long_query_time = 2
EOF
    
    # Criar docker-compose.yml
    cat > /opt/mysql/docker-compose.yml <<EOF
services:
  mysql:
    image: mysql:8.0
    container_name: mysql-plannerate
    restart: always
    
    environment:
      MYSQL_ROOT_PASSWORD: ${ROOT_PASSWORD}
      MYSQL_DATABASE: ${STAGING_DB_NAME}
      MYSQL_USER: ${STAGING_DB_USER}
      MYSQL_PASSWORD: ${STAGING_DB_PASSWORD}
    
    volumes:
      - ./data:/var/lib/mysql
      - ./config/my.cnf:/etc/mysql/conf.d/custom.cnf:ro
    
    ports:
      - "3306:3306"
    
    networks:
      - mysql-network
    
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${ROOT_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2'
        reservations:
          memory: 512M

networks:
  mysql-network:
    driver: bridge
EOF
    
    # Subir MySQL
    cd /opt/mysql
    docker compose up -d
    
    log_info "Aguardando MySQL iniciar..."
    sleep 20
    
    # Criar database de produção
    docker exec mysql-plannerate mysql -u root -p"${ROOT_PASSWORD}" <<EOF
CREATE DATABASE IF NOT EXISTS ${PROD_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${PROD_DB_USER}'@'%' IDENTIFIED BY '${PROD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${PROD_DB_NAME}.* TO '${PROD_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    
    # Get IP do host
    MYSQL_HOST=$(hostname -I | awk '{print $1}')
    MYSQL_PORT="3306"
    
    log_success "MySQL Docker configurado"

else
    ##########################################################################
    # Configuração Manual
    ##########################################################################
    log_warning "Pular instalação automática"
    
    read -p "Digite o host do MySQL: " MYSQL_HOST
    read -p "Digite a porta do MySQL [3306]: " MYSQL_PORT
    MYSQL_PORT=${MYSQL_PORT:-3306}
    
    log_info "Você precisará criar manualmente:"
    echo "  - Database: ${STAGING_DB_NAME}"
    echo "  - Usuário: ${STAGING_DB_USER}"
    echo "  - Database: ${PROD_DB_NAME}"
    echo "  - Usuário: ${PROD_DB_USER}"
fi

##############################################################################
# 4. Salvar credenciais
##############################################################################
log_info "Salvando credenciais..."

cat > /root/.plannerate-mysql-credentials <<EOF
# Plannerate MySQL Credentials
# Gerado em: $(date)
# IMPORTANTE: Guarde em local seguro e delete após backup

========================================
MYSQL ROOT
========================================
Host: ${MYSQL_HOST}
Port: ${MYSQL_PORT}
User: root
Password: ${ROOT_PASSWORD}

========================================
STAGING DATABASE
========================================
Database: ${STAGING_DB_NAME}
User: ${STAGING_DB_USER}
Password: ${STAGING_DB_PASSWORD}
Connection String: mysql://${STAGING_DB_USER}:${STAGING_DB_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${STAGING_DB_NAME}

========================================
PRODUCTION DATABASE
========================================
Database: ${PROD_DB_NAME}
User: ${PROD_DB_USER}
Password: ${PROD_DB_PASSWORD}
Connection String: mysql://${PROD_DB_USER}:${PROD_DB_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${PROD_DB_NAME}

========================================
CONFIGURAÇÃO .ENV
========================================

# Para staging (.env.staging):
DB_CONNECTION=mysql
DB_HOST=${MYSQL_HOST}
DB_PORT=${MYSQL_PORT}
DB_DATABASE=${STAGING_DB_NAME}
DB_USERNAME=${STAGING_DB_USER}
DB_PASSWORD=${STAGING_DB_PASSWORD}

# Para production (.env.production):
DB_CONNECTION=mysql
DB_HOST=${MYSQL_HOST}
DB_PORT=${MYSQL_PORT}
DB_DATABASE=${PROD_DB_NAME}
DB_USERNAME=${PROD_DB_USER}
DB_PASSWORD=${PROD_DB_PASSWORD}

========================================
COMANDOS ÚTEIS
========================================

# Conectar ao MySQL:
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${STAGING_DB_USER} -p${STAGING_DB_PASSWORD} ${STAGING_DB_NAME}

# Backup staging:
mysqldump -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${STAGING_DB_USER} -p${STAGING_DB_PASSWORD} ${STAGING_DB_NAME} > staging_backup.sql

# Restore staging:
mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${STAGING_DB_USER} -p${STAGING_DB_PASSWORD} ${STAGING_DB_NAME} < staging_backup.sql

# Logs (se Docker):
docker logs -f mysql-plannerate

# Status (se Docker):
docker exec mysql-plannerate mysqladmin -u root -p${ROOT_PASSWORD} status
EOF

chmod 600 /root/.plannerate-mysql-credentials
chown root:root /root/.plannerate-mysql-credentials

log_success "Credenciais salvas em /root/.plannerate-mysql-credentials"

##############################################################################
# 5. Testar conexões
##############################################################################
if [ "$MYSQL_TYPE" != "3" ]; then
    log_info "Testando conexões..."
    
    if [ "$MYSQL_TYPE" = "2" ]; then
        # Docker
        if docker exec mysql-plannerate mysql -u "${STAGING_DB_USER}" -p"${STAGING_DB_PASSWORD}" -e "SELECT 1" ${STAGING_DB_NAME} &>/dev/null; then
            log_success "Conexão staging OK"
        else
            log_error "Falha ao conectar staging"
        fi
        
        if docker exec mysql-plannerate mysql -u "${PROD_DB_USER}" -p"${PROD_DB_PASSWORD}" -e "SELECT 1" ${PROD_DB_NAME} &>/dev/null; then
            log_success "Conexão production OK"
        else
            log_error "Falha ao conectar production"
        fi
    else
        # Standalone
        if mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${STAGING_DB_USER}" -p"${STAGING_DB_PASSWORD}" -e "SELECT 1" ${STAGING_DB_NAME} &>/dev/null; then
            log_success "Conexão staging OK"
        else
            log_error "Falha ao conectar staging"
        fi
        
        if mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${PROD_DB_USER}" -p"${PROD_DB_PASSWORD}" -e "SELECT 1" ${PROD_DB_NAME} &>/dev/null; then
            log_success "Conexão production OK"
        else
            log_error "Falha ao conectar production"
        fi
    fi
fi

##############################################################################
# 6. Resumo Final
##############################################################################
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           MySQL Configurado com Sucesso! 🎉               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

log_success "MySQL instalado e configurado"
log_success "Databases criadas: ${STAGING_DB_NAME}, ${PROD_DB_NAME}"
log_success "Usuários criados com permissões adequadas"

echo ""
log_warning "CREDENCIAIS:"
echo ""
echo "📄 Arquivo: /root/.plannerate-mysql-credentials"
echo ""
echo "⚠️  IMPORTANTE: "
echo "   1. Leia o arquivo com: cat /root/.plannerate-mysql-credentials"
echo "   2. Salve as credenciais em local seguro (gerenciador de senhas)"
echo "   3. Delete o arquivo: rm /root/.plannerate-mysql-credentials"
echo ""
log_warning "PRÓXIMOS PASSOS:"
echo ""
echo "1️⃣  Atualizar arquivos .env com as credenciais geradas"
echo "   vim /opt/plannerate/staging/.env"
echo "   vim /opt/plannerate/production/.env"
echo ""
echo "2️⃣  Se usar MySQL Docker, conectar à rede do Traefik:"
echo "   docker network connect traefik-global mysql-plannerate"
echo ""
echo "3️⃣  Configurar firewall para porta 3306 (se necessário):"
echo "   ufw allow from SEU_IP_APLICACAO to any port 3306"
echo ""

log_success "Setup MySQL concluído! ✨"
