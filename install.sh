#!/bin/bash

# Script de instalação - Copia arquivos necessários para o projeto Laravel
# Uso: bash install.sh [diretorio-do-projeto-laravel]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Diretório de destino (raiz do projeto Laravel)
DEST_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Instalação VPS Deployment Package ===${NC}\n"

# Verifica se é um projeto Laravel
if [ ! -f "$DEST_DIR/artisan" ]; then
    echo -e "${RED}Erro: '$DEST_DIR' não parece ser um projeto Laravel (artisan não encontrado)${NC}"
    exit 1
fi

echo -e "${YELLOW}Diretório de destino: $DEST_DIR${NC}\n"

# Copia arquivos Docker para a raiz
echo "📦 Copiando arquivos Docker..."
cp "$SCRIPT_DIR/docker/Dockerfile" "$DEST_DIR/"
cp "$SCRIPT_DIR/docker/docker-compose.staging.yml" "$DEST_DIR/"
cp "$SCRIPT_DIR/docker/traefik-docker-compose.yml" "$DEST_DIR/"
echo -e "${GREEN}✓ Arquivos Docker copiados${NC}\n"

# Cria diretório .github/workflows se não existir
if [ ! -d "$DEST_DIR/.github/workflows" ]; then
    echo "📁 Criando diretório .github/workflows..."
    mkdir -p "$DEST_DIR/.github/workflows"
fi

# Copia workflows do GitHub
echo "🔧 Copiando GitHub workflows..."
cp "$SCRIPT_DIR/github-workflows/deploy-staging.yml" "$DEST_DIR/.github/workflows/"
cp "$SCRIPT_DIR/github-workflows/build-and-push.yml" "$DEST_DIR/.github/workflows/"
echo -e "${GREEN}✓ Workflows copiados${NC}\n"

# Cria diretório scripts se não existir
if [ ! -d "$DEST_DIR/scripts" ]; then
    echo "📁 Criando diretório scripts..."
    mkdir -p "$DEST_DIR/scripts"
fi

# Copia script helper (útil para desenvolvimento)
echo "🛠️  Copiando script helper..."
cp "$SCRIPT_DIR/scripts/helper.sh" "$DEST_DIR/scripts/"
chmod +x "$DEST_DIR/scripts/helper.sh"
echo -e "${GREEN}✓ Helper script copiado${NC}\n"

# Mensagem final
echo -e "${GREEN}=== Instalação concluída com sucesso! ===${NC}\n"
echo "Arquivos copiados para: $DEST_DIR"
echo ""
echo "Próximos passos:"
echo "1. Edite o docker-compose.staging.yml com seus domínios"
echo "2. Configure as secrets no GitHub (GHCR_TOKEN, VPS_HOST, VPS_USER, etc.)"
echo "3. Para configurar a VPS, copie os scripts para o servidor:"
echo "   scp $SCRIPT_DIR/scripts/setup-*.sh user@vps:/root/"
echo ""
echo "Scripts disponíveis para VPS:"
echo "  - setup-vps-new.sh  : Configura VPS completa (Docker, Traefik, usuários)"
echo "  - setup-postgres.sh : Configura banco PostgreSQL"
echo "  - setup-mysql.sh    : Configura banco MySQL"
echo ""
echo "Helper disponível no projeto:"
echo "  ./scripts/helper.sh logs        # Ver logs"
echo "  ./scripts/helper.sh restart     # Reiniciar containers"
echo "  ./scripts/helper.sh artisan ... # Executar artisan"
