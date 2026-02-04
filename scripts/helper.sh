#!/bin/bash

# ============================================
# PLANNERATE HELPER - Comandos Úteis
# Use: ./helper.sh [comando] [ambiente]
# ============================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de help
show_help() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}       PLANNERATE HELPER${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
    echo "Uso: ./helper.sh [comando] [ambiente]"
    echo ""
    echo "Ambientes:"
    echo "  staging    - Ambiente de testes (plannerate.dev.br)"
    echo "  prod       - Ambiente de produção (plannerate.com.br)"
    echo ""
    echo "Comandos:"
    echo "  logs       - Ver logs em tempo real"
    echo "  restart    - Reiniciar containers"
    echo "  status     - Ver status dos containers"
    echo "  shell      - Acessar bash do container app"
    echo "  tinker     - Abrir Laravel Tinker"
    echo "  artisan    - Executar comando artisan"
    echo "  backup     - Criar backup do banco"
    echo "  restore    - Restaurar backup do banco"
    echo "  rebuild    - Rebuild completo (build + up)"
    echo "  update     - Git pull + rebuild"
    echo "  cache      - Limpar todos os caches"
    echo ""
    echo "Exemplos:"
    echo "  ./helper.sh logs staging"
    echo "  ./helper.sh restart prod"
    echo "  ./helper.sh artisan staging migrate"
    echo "  ./helper.sh backup prod"
    echo ""
}

# Validar ambiente
ENV=$2
if [ "$ENV" = "staging" ]; then
    DIR="/opt/plannerate/staging"
    COMPOSE_FILE="docker-compose.staging.yml"
    ENV_NAME="STAGING"
    DOMAIN="plannerate.dev.br"
elif [ "$ENV" = "prod" ]; then
    DIR="/opt/plannerate/production"
    COMPOSE_FILE="docker-compose.prod.yml"
    ENV_NAME="PRODUCTION"
    DOMAIN="plannerate.com.br"
else
    if [ ! -z "$1" ]; then
        echo -e "${RED}❌ Ambiente inválido: $ENV${NC}"
        echo ""
    fi
    show_help
    exit 1
fi

# Comando
CMD=$1

case $CMD in
    logs)
        echo -e "${GREEN}📋 Logs de ${ENV_NAME}${NC}"
        cd $DIR
        docker compose -f $COMPOSE_FILE logs -f
        ;;
    
    restart)
        echo -e "${GREEN}🔄 Reiniciando ${ENV_NAME}${NC}"
        cd $DIR
        docker compose -f $COMPOSE_FILE restart
        echo -e "${GREEN}✅ Reiniciado!${NC}"
        ;;
    
    status)
        echo -e "${GREEN}📊 Status de ${ENV_NAME}${NC}"
        cd $DIR
        docker compose -f $COMPOSE_FILE ps
        ;;
    
    shell)
        echo -e "${GREEN}🐚 Acessando shell de ${ENV_NAME}${NC}"
        cd $DIR
        docker compose -f $COMPOSE_FILE exec app bash
        ;;
    
    tinker)
        echo -e "${GREEN}🔧 Laravel Tinker - ${ENV_NAME}${NC}"
        cd $DIR
        docker compose -f $COMPOSE_FILE exec app php artisan tinker
        ;;
    
    artisan)
        shift 2  # Remove os dois primeiros argumentos
        echo -e "${GREEN}🎨 Artisan: $@ - ${ENV_NAME}${NC}"
        cd $DIR
        docker compose -f $COMPOSE_FILE exec app php artisan "$@"
        ;;
    
    backup)
        BACKUP_DIR=~/backups
        mkdir -p $BACKUP_DIR
        BACKUP_FILE="$BACKUP_DIR/${ENV}-$(date +%Y%m%d-%H%M%S).sql"
        
        echo -e "${GREEN}💾 Criando backup de ${ENV_NAME}${NC}"
        cd $DIR
        
        if [ "$ENV" = "staging" ]; then
            DB_USER="plannerate_staging_user"
            DB_NAME="plannerate_staging"
        else
            DB_USER="plannerate_prod_user"
            DB_NAME="plannerate_production"
        fi
        
        docker compose -f $COMPOSE_FILE exec -T postgres \
            pg_dump -U $DB_USER $DB_NAME > $BACKUP_FILE
        
        echo -e "${GREEN}✅ Backup salvo em: $BACKUP_FILE${NC}"
        ls -lh $BACKUP_FILE
        ;;
    
    restore)
        BACKUP_FILE=$3
        
        if [ -z "$BACKUP_FILE" ]; then
            echo -e "${RED}❌ Especifique o arquivo de backup${NC}"
            echo "Uso: ./helper.sh restore $ENV /caminho/para/backup.sql"
            exit 1
        fi
        
        if [ ! -f "$BACKUP_FILE" ]; then
            echo -e "${RED}❌ Arquivo não encontrado: $BACKUP_FILE${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}⚠️  ATENÇÃO: Isso vai SUBSTITUIR o banco de ${ENV_NAME}!${NC}"
        read -p "Tem certeza? (digite 'sim'): " confirm
        
        if [ "$confirm" != "sim" ]; then
            echo "Operação cancelada"
            exit 0
        fi
        
        echo -e "${GREEN}♻️  Restaurando backup em ${ENV_NAME}${NC}"
        cd $DIR
        
        if [ "$ENV" = "staging" ]; then
            DB_USER="plannerate_staging_user"
            DB_NAME="plannerate_staging"
        else
            DB_USER="plannerate_prod_user"
            DB_NAME="plannerate_production"
        fi
        
        docker compose -f $COMPOSE_FILE exec -T postgres \
            psql -U $DB_USER $DB_NAME < $BACKUP_FILE
        
        echo -e "${GREEN}✅ Backup restaurado!${NC}"
        ;;
    
    rebuild)
        echo -e "${GREEN}🔨 Rebuild completo de ${ENV_NAME}${NC}"
        cd $DIR
        
        echo "1. Parando e removendo containers, redes e volumes órfãos..."
        docker compose -f $COMPOSE_FILE down --remove-orphans -v || true
        
        echo "2. Removendo containers órfãos manualmente (se houver)..."
        docker ps -a --filter "name=${ENV}" --format "{{.Names}}" | xargs -r docker rm -f || true
        
        echo "3. Removendo redes órfãs (se houver)..."
        docker network ls --filter "name=${ENV}" --format "{{.Name}}" | xargs -r docker network rm || true
        
        echo "4. Rebuild de imagens..."
        docker compose -f $COMPOSE_FILE build --no-cache
        
        echo "5. Subindo containers..."
        docker compose -f $COMPOSE_FILE up -d
        
        echo "6. Aguardando inicialização..."
        sleep 10
        
        echo -e "${GREEN}✅ Rebuild concluído!${NC}"
        docker compose -f $COMPOSE_FILE ps
        ;;
    
    update)
        echo -e "${GREEN}🔄 Atualizando ${ENV_NAME}${NC}"
        cd $DIR
        
        # Verificar branch
        if [ "$ENV" = "staging" ]; then
            BRANCH="staging"
        else
            BRANCH="main"
        fi
        
        echo "1. Git pull..."
        git fetch origin
        git checkout $BRANCH
        git pull origin $BRANCH
        
        echo "2. Parando e removendo containers, redes e volumes órfãos..."
        docker compose -f $COMPOSE_FILE down --remove-orphans -v || true
        
        echo "3. Removendo containers órfãos manualmente (se houver)..."
        docker ps -a --filter "name=${ENV}" --format "{{.Names}}" | xargs -r docker rm -f || true
        
        echo "4. Rebuild..."
        docker compose -f $COMPOSE_FILE build --no-cache
        
        echo "5. Rodando migrations..."
        docker compose -f $COMPOSE_FILE run --rm app php artisan migrate --force
        
        echo "6. Otimizando caches..."
        docker compose -f $COMPOSE_FILE run --rm app php artisan config:cache
        docker compose -f $COMPOSE_FILE run --rm app php artisan route:cache
        docker compose -f $COMPOSE_FILE run --rm app php artisan view:cache
        
        echo "7. Subindo containers..."
        docker compose -f $COMPOSE_FILE up -d
        
        echo -e "${GREEN}✅ Update concluído!${NC}"
        echo -e "${BLUE}🌐 Acesse: https://$DOMAIN${NC}"
        ;;
    
    cache)
        echo -e "${GREEN}🧹 Limpando caches de ${ENV_NAME}${NC}"
        cd $DIR
        docker compose -f $COMPOSE_FILE exec app php artisan cache:clear
        docker compose -f $COMPOSE_FILE exec app php artisan config:clear
        docker compose -f $COMPOSE_FILE exec app php artisan route:clear
        docker compose -f $COMPOSE_FILE exec app php artisan view:clear
        echo -e "${GREEN}✅ Caches limpos!${NC}"
        ;;
    
    *)
        show_help
        exit 1
        ;;
esac