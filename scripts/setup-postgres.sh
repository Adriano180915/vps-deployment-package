#!/bin/bash

##############################################################################
# PostgreSQL Setup Script - Plannerate VPS
# 
# Este script configura um servidor PostgreSQL standalone ou em cluster
# com suporte a replicação
#
# Uso: 
#   sudo bash setup-postgres.sh
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
echo "║         Plannerate PostgreSQL Setup Script                ║"
echo "║         PostgreSQL Server Configuration                    ║"
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
echo "1) PostgreSQL Standalone (desenvolvimento/testes)"
echo "2) PostgreSQL via Docker (recomendado para produção)"
echo "3) PostgreSQL com Replicação (1 primário + 2 réplicas)"
echo "4) Configuração manual (pular instalação)"
echo ""
read -p "Escolha uma opção [1-4]: " PG_TYPE

##############################################################################
# 2. Gerar credenciais
##############################################################################
log_info "Gerando credenciais..."

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

POSTGRES_PASSWORD=$(generate_password)
REPLICATOR_PASSWORD=$(generate_password)

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

if [ "$PG_TYPE" = "1" ]; then
    ##########################################################################
    # Instalação Standalone (Sistema)
    ##########################################################################
    log_info "Instalando PostgreSQL Server..."
    
    # Adicionar repositório oficial PostgreSQL
    sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
    
    # Atualizar pacotes
    apt-get update -qq
    
    # Instalar PostgreSQL 16
    apt-get install -y postgresql-16 postgresql-client-16 postgresql-contrib-16
    
    # Iniciar serviço
    systemctl start postgresql
    systemctl enable postgresql
    
    log_success "PostgreSQL Server instalado"
    
    # Configurar senha do usuário postgres
    log_info "Configurando usuário postgres..."
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';"
    
    # Criar databases e usuários
    log_info "Criando databases e usuários..."
    
    sudo -u postgres psql <<EOF
-- Database Staging
CREATE DATABASE ${STAGING_DB_NAME} ENCODING 'UTF8';
CREATE USER ${STAGING_DB_USER} WITH PASSWORD '${STAGING_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${STAGING_DB_NAME} TO ${STAGING_DB_USER};
\c ${STAGING_DB_NAME}
GRANT ALL ON SCHEMA public TO ${STAGING_DB_USER};

-- Database Production
\c postgres
CREATE DATABASE ${PROD_DB_NAME} ENCODING 'UTF8';
CREATE USER ${PROD_DB_USER} WITH PASSWORD '${PROD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${PROD_DB_NAME} TO ${PROD_DB_USER};
\c ${PROD_DB_NAME}
GRANT ALL ON SCHEMA public TO ${PROD_DB_USER};
EOF
    
    # Configurar pg_hba.conf para aceitar conexões remotas
    log_info "Configurando acesso remoto..."
    
    PG_HBA="/etc/postgresql/16/main/pg_hba.conf"
    
    # Backup
    cp "$PG_HBA" "${PG_HBA}.backup"
    
    # Adicionar regras
    cat >> "$PG_HBA" <<EOF

# Plannerate - Acesso remoto
host    ${STAGING_DB_NAME}    ${STAGING_DB_USER}    0.0.0.0/0    scram-sha-256
host    ${PROD_DB_NAME}        ${PROD_DB_USER}       0.0.0.0/0    scram-sha-256
EOF
    
    # Configurar postgresql.conf
    PG_CONF="/etc/postgresql/16/main/postgresql.conf"
    
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"
    sed -i "s/max_connections = 100/max_connections = 200/" "$PG_CONF"
    sed -i "s/shared_buffers = 128MB/shared_buffers = 1GB/" "$PG_CONF"
    
    # Restart PostgreSQL
    systemctl restart postgresql
    
    PG_HOST="localhost"
    PG_PORT="5432"
    
    log_success "PostgreSQL Standalone configurado"

elif [ "$PG_TYPE" = "2" ]; then
    ##########################################################################
    # Instalação via Docker
    ##########################################################################
    log_info "Configurando PostgreSQL via Docker..."
    
    # Verificar se Docker está instalado
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado. Execute setup-vps-new.sh primeiro."
        exit 1
    fi
    
    # Criar diretórios
    mkdir -p /opt/postgres/{data,config}
    
    # Criar arquivo de configuração
    cat > /opt/postgres/config/postgresql.conf <<'EOF'
# Configurações de performance
max_connections = 200
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 256MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 2621kB
min_wal_size = 1GB
max_wal_size = 4GB

# Logging
log_min_duration_statement = 1000
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_timezone = 'America/Sao_Paulo'

# Locale
datestyle = 'iso, dmy'
timezone = 'America/Sao_Paulo'
lc_messages = 'pt_BR.UTF-8'
lc_monetary = 'pt_BR.UTF-8'
lc_numeric = 'pt_BR.UTF-8'
lc_time = 'pt_BR.UTF-8'
default_text_search_config = 'pg_catalog.portuguese'
EOF
    
    # Criar script de inicialização
    mkdir -p /opt/postgres/docker-entrypoint-initdb.d
    
    cat > /opt/postgres/docker-entrypoint-initdb.d/01-init.sql <<EOF
-- Criar databases e usuários

-- Staging
CREATE DATABASE ${STAGING_DB_NAME} ENCODING 'UTF8';
CREATE USER ${STAGING_DB_USER} WITH PASSWORD '${STAGING_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${STAGING_DB_NAME} TO ${STAGING_DB_USER};

\c ${STAGING_DB_NAME}
GRANT ALL ON SCHEMA public TO ${STAGING_DB_USER};

-- Production
\c postgres
CREATE DATABASE ${PROD_DB_NAME} ENCODING 'UTF8';
CREATE USER ${PROD_DB_USER} WITH PASSWORD '${PROD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${PROD_DB_NAME} TO ${PROD_DB_USER};

\c ${PROD_DB_NAME}
GRANT ALL ON SCHEMA public TO ${PROD_DB_USER};
EOF
    
    # Criar docker-compose.yml
    cat > /opt/postgres/docker-compose.yml <<EOF
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres-plannerate
    restart: always
    
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: postgres
      POSTGRES_DB: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    
    volumes:
      - ./data:/var/lib/postgresql/data
      - ./config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
      - ./docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d:ro
    
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    
    ports:
      - "5432:5432"
    
    networks:
      - postgres-network
    
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
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
  postgres-network:
    driver: bridge
EOF
    
    # Subir PostgreSQL
    cd /opt/postgres
    docker compose up -d
    
    log_info "Aguardando PostgreSQL iniciar..."
    sleep 20
    
    # Get IP do host
    PG_HOST=$(hostname -I | awk '{print $1}')
    PG_PORT="5432"
    
    log_success "PostgreSQL Docker configurado"

elif [ "$PG_TYPE" = "3" ]; then
    ##########################################################################
    # Instalação com Replicação (1 primário + 2 réplicas)
    ##########################################################################
    log_info "Configurando PostgreSQL com Replicação..."
    
    # Verificar se Docker está instalado
    if ! command -v docker &> /dev/null; then
        log_error "Docker não está instalado. Execute setup-vps-new.sh primeiro."
        exit 1
    fi
    
    log_warning "⚠️  Configuração de replicação requer IPs específicos para cada servidor."
    log_warning "Este setup cria 1 primário + 2 réplicas no mesmo servidor (para testes)."
    log_warning "Para produção, configure cada réplica em servidores separados."
    
    # Criar diretórios
    mkdir -p /opt/postgres-cluster/{primary/data,replica1/data,replica2/data,config}
    
    # Criar configuração primária
    cat > /opt/postgres-cluster/config/primary.conf <<'EOF'
# Configurações do primário
max_connections = 200
shared_buffers = 1GB
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
EOF
    
    # Criar configuração de réplicas
    cat > /opt/postgres-cluster/config/replica.conf <<'EOF'
# Configurações das réplicas
max_connections = 200
shared_buffers = 512MB
hot_standby = on
hot_standby_feedback = on
EOF
    
    # Criar usuário de replicação
    cat > /opt/postgres-cluster/config/01-replication.sql <<EOF
-- Criar usuário de replicação
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '${REPLICATOR_PASSWORD}';

-- Criar databases
CREATE DATABASE ${STAGING_DB_NAME} ENCODING 'UTF8';
CREATE USER ${STAGING_DB_USER} WITH PASSWORD '${STAGING_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${STAGING_DB_NAME} TO ${STAGING_DB_USER};

CREATE DATABASE ${PROD_DB_NAME} ENCODING 'UTF8';
CREATE USER ${PROD_DB_USER} WITH PASSWORD '${PROD_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE ${PROD_DB_NAME} TO ${PROD_DB_USER};
EOF
    
    # Criar docker-compose.yml para cluster
    cat > /opt/postgres-cluster/docker-compose.yml <<EOF
services:
  # Servidor Primário (Read/Write)
  postgres-primary:
    image: postgres:16-alpine
    container_name: postgres-primary
    restart: always
    
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    
    volumes:
      - ./primary/data:/var/lib/postgresql/data
      - ./config/primary.conf:/etc/postgresql/postgresql.conf:ro
      - ./config/01-replication.sql:/docker-entrypoint-initdb.d/01-replication.sql:ro
    
    command: |
      postgres
      -c config_file=/etc/postgresql/postgresql.conf
      -c hba_file=/var/lib/postgresql/data/pgdata/pg_hba.conf
    
    ports:
      - "5432:5432"
    
    networks:
      - postgres-cluster
    
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Réplica 1 (Read Only)
  postgres-replica1:
    image: postgres:16-alpine
    container_name: postgres-replica1
    restart: always
    
    environment:
      PGUSER: replicator
      PGPASSWORD: ${REPLICATOR_PASSWORD}
    
    volumes:
      - ./replica1/data:/var/lib/postgresql/data
      - ./config/replica.conf:/etc/postgresql/postgresql.conf:ro
    
    command: |
      bash -c "
      until pg_basebackup --pgdata=/var/lib/postgresql/data -R --slot=replication_slot_1 --host=postgres-primary --port=5432 -U replicator -W; do
        echo 'Aguardando primário...'
        sleep 5
      done
      postgres -c config_file=/etc/postgresql/postgresql.conf
      "
    
    ports:
      - "5433:5432"
    
    networks:
      - postgres-cluster
    
    depends_on:
      - postgres-primary

  # Réplica 2 (Read Only)
  postgres-replica2:
    image: postgres:16-alpine
    container_name: postgres-replica2
    restart: always
    
    environment:
      PGUSER: replicator
      PGPASSWORD: ${REPLICATOR_PASSWORD}
    
    volumes:
      - ./replica2/data:/var/lib/postgresql/data
      - ./config/replica.conf:/etc/postgresql/postgresql.conf:ro
    
    command: |
      bash -c "
      until pg_basebackup --pgdata=/var/lib/postgresql/data -R --slot=replication_slot_2 --host=postgres-primary --port=5432 -U replicator -W; do
        echo 'Aguardando primário...'
        sleep 5
      done
      postgres -c config_file=/etc/postgresql/postgresql.conf
      "
    
    ports:
      - "5434:5432"
    
    networks:
      - postgres-cluster
    
    depends_on:
      - postgres-primary

networks:
  postgres-cluster:
    driver: bridge
EOF
    
    log_info "Subindo cluster PostgreSQL..."
    cd /opt/postgres-cluster
    docker compose up -d postgres-primary
    
    log_info "Aguardando primário iniciar..."
    sleep 30
    
    # Configurar pg_hba.conf no primário para aceitar replicação
    docker exec postgres-primary bash -c "cat >> /var/lib/postgresql/data/pgdata/pg_hba.conf <<'PGEOF'
# Replicação
host    replication    replicator    postgres-replica1    scram-sha-256
host    replication    replicator    postgres-replica2    scram-sha-256
host    replication    replicator    0.0.0.0/0           scram-sha-256
PGEOF"
    
    # Criar slots de replicação
    docker exec postgres-primary psql -U postgres -c "SELECT pg_create_physical_replication_slot('replication_slot_1');"
    docker exec postgres-primary psql -U postgres -c "SELECT pg_create_physical_replication_slot('replication_slot_2');"
    
    # Restart primário
    docker restart postgres-primary
    sleep 10
    
    # Subir réplicas
    docker compose up -d
    
    PG_HOST=$(hostname -I | awk '{print $1}')
    PG_PORT="5432"
    PG_REPLICA1_PORT="5433"
    PG_REPLICA2_PORT="5434"
    
    log_success "PostgreSQL Cluster com Replicação configurado"

else
    ##########################################################################
    # Configuração Manual
    ##########################################################################
    log_warning "Pular instalação automática"
    
    read -p "Digite o host do PostgreSQL: " PG_HOST
    read -p "Digite a porta do PostgreSQL [5432]: " PG_PORT
    PG_PORT=${PG_PORT:-5432}
    
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

CRED_FILE="/root/.plannerate-postgres-credentials"

cat > "$CRED_FILE" <<EOF
# Plannerate PostgreSQL Credentials
# Gerado em: $(date)
# IMPORTANTE: Guarde em local seguro e delete após backup

========================================
POSTGRESQL ADMIN
========================================
Host: ${PG_HOST}
Port: ${PG_PORT}
User: postgres
Password: ${POSTGRES_PASSWORD}
EOF

if [ "$PG_TYPE" = "3" ]; then
    cat >> "$CRED_FILE" <<EOF

Usuário de Replicação: replicator
Senha de Replicação: ${REPLICATOR_PASSWORD}

Réplica 1: ${PG_HOST}:${PG_REPLICA1_PORT}
Réplica 2: ${PG_HOST}:${PG_REPLICA2_PORT}
EOF
fi

cat >> "$CRED_FILE" <<EOF

========================================
STAGING DATABASE
========================================
Database: ${STAGING_DB_NAME}
User: ${STAGING_DB_USER}
Password: ${STAGING_DB_PASSWORD}
Connection String: postgresql://${STAGING_DB_USER}:${STAGING_DB_PASSWORD}@${PG_HOST}:${PG_PORT}/${STAGING_DB_NAME}

========================================
PRODUCTION DATABASE
========================================
Database: ${PROD_DB_NAME}
User: ${PROD_DB_USER}
Password: ${PROD_DB_PASSWORD}
Connection String: postgresql://${PROD_DB_USER}:${PROD_DB_PASSWORD}@${PG_HOST}:${PG_PORT}/${PROD_DB_NAME}

========================================
CONFIGURAÇÃO .ENV
========================================

# Para staging (.env.staging):
DB_CONNECTION=pgsql
DB_HOST=${PG_HOST}
DB_PORT=${PG_PORT}
DB_DATABASE=${STAGING_DB_NAME}
DB_USERNAME=${STAGING_DB_USER}
DB_PASSWORD=${STAGING_DB_PASSWORD}

# Para production (.env.production):
DB_CONNECTION=pgsql
DB_HOST=${PG_HOST}
DB_PORT=${PG_PORT}
DB_DATABASE=${PROD_DB_NAME}
DB_USERNAME=${PROD_DB_USER}
DB_PASSWORD=${PROD_DB_PASSWORD}

========================================
COMANDOS ÚTEIS
========================================

# Conectar ao PostgreSQL:
psql -h ${PG_HOST} -p ${PG_PORT} -U ${STAGING_DB_USER} -d ${STAGING_DB_NAME}

# Backup staging:
pg_dump -h ${PG_HOST} -p ${PG_PORT} -U ${STAGING_DB_USER} ${STAGING_DB_NAME} > staging_backup.sql

# Restore staging:
psql -h ${PG_HOST} -p ${PG_PORT} -U ${STAGING_DB_USER} ${STAGING_DB_NAME} < staging_backup.sql

# Logs (se Docker):
docker logs -f postgres-plannerate

# Status de replicação (se cluster):
docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Verificar lag de replicação:
docker exec postgres-primary psql -U postgres -c "SELECT pg_current_wal_lsn() - replay_lsn AS lag FROM pg_stat_replication;"
EOF

chmod 600 "$CRED_FILE"
chown root:root "$CRED_FILE"

log_success "Credenciais salvas em $CRED_FILE"

##############################################################################
# 5. Testar conexões
##############################################################################
if [ "$PG_TYPE" != "4" ]; then
    log_info "Testando conexões..."
    
    if [ "$PG_TYPE" = "2" ]; then
        # Docker single
        if docker exec postgres-plannerate psql -U "${STAGING_DB_USER}" -d "${STAGING_DB_NAME}" -c "SELECT 1" &>/dev/null; then
            log_success "Conexão staging OK"
        else
            log_error "Falha ao conectar staging"
        fi
        
        if docker exec postgres-plannerate psql -U "${PROD_DB_USER}" -d "${PROD_DB_NAME}" -c "SELECT 1" &>/dev/null; then
            log_success "Conexão production OK"
        else
            log_error "Falha ao conectar production"
        fi
    elif [ "$PG_TYPE" = "3" ]; then
        # Cluster
        if docker exec postgres-primary psql -U "${STAGING_DB_USER}" -d "${STAGING_DB_NAME}" -c "SELECT 1" &>/dev/null; then
            log_success "Conexão staging OK"
        else
            log_error "Falha ao conectar staging"
        fi
        
        if docker exec postgres-primary psql -U "${PROD_DB_USER}" -d "${PROD_DB_NAME}" -c "SELECT 1" &>/dev/null; then
            log_success "Conexão production OK"
        else
            log_error "Falha ao conectar production"
        fi
        
        log_info "Verificando replicação..."
        docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"
    fi
fi

##############################################################################
# 6. Resumo Final
##############################################################################
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         PostgreSQL Configurado com Sucesso! 🎉            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

log_success "PostgreSQL instalado e configurado"
log_success "Databases criadas: ${STAGING_DB_NAME}, ${PROD_DB_NAME}"
log_success "Usuários criados com permissões adequadas"

if [ "$PG_TYPE" = "3" ]; then
    log_success "Cluster com replicação configurado (1 primário + 2 réplicas)"
fi

echo ""
log_warning "CREDENCIAIS:"
echo ""
echo "📄 Arquivo: $CRED_FILE"
echo ""
echo "⚠️  IMPORTANTE: "
echo "   1. Leia o arquivo com: cat $CRED_FILE"
echo "   2. Salve as credenciais em local seguro (gerenciador de senhas)"
echo "   3. Delete o arquivo: rm $CRED_FILE"
echo ""
log_warning "PRÓXIMOS PASSOS:"
echo ""
echo "1️⃣  Atualizar arquivos .env com as credenciais geradas"
echo "   vim /opt/plannerate/staging/.env"
echo "   vim /opt/plannerate/production/.env"
echo ""
echo "2️⃣  Se usar PostgreSQL Docker, conectar à rede do Traefik:"
echo "   docker network connect traefik-global postgres-plannerate"
echo ""
echo "3️⃣  Configurar firewall para porta 5432 (se necessário):"
echo "   ufw allow from SEU_IP_APLICACAO to any port 5432"
echo ""

if [ "$PG_TYPE" = "3" ]; then
    echo "4️⃣  Monitorar status da replicação:"
    echo "   docker exec postgres-primary psql -U postgres -c \"SELECT * FROM pg_stat_replication;\""
    echo ""
fi

log_success "Setup PostgreSQL concluído! ✨"
