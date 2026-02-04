#!/bin/bash

##############################################################################
# Script para inicializar repositório Git do pacote VPS
# 
# Este script:
# 1. Inicializa repositório Git
# 2. Adiciona todos os arquivos
# 3. Faz commit inicial
# 4. Configura remote (opcional)
# 5. Push inicial (opcional)
##############################################################################

set -e

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     VPS Deployment Package - Git Initialization           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar se já é um repositório Git
if [ -d ".git" ]; then
    echo -e "${YELLOW}⚠️  Este diretório já é um repositório Git${NC}"
    read -p "Deseja reinicializar? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf .git
        echo -e "${GREEN}✅ Repositório removido${NC}"
    else
        echo "Abortado."
        exit 0
    fi
fi

# Inicializar repositório
echo -e "${BLUE}📦 Inicializando repositório Git...${NC}"
git init
echo -e "${GREEN}✅ Repositório inicializado${NC}"

# Adicionar todos os arquivos
echo ""
echo -e "${BLUE}📝 Adicionando arquivos...${NC}"
git add .
echo -e "${GREEN}✅ Arquivos adicionados${NC}"

# Commit inicial
echo ""
echo -e "${BLUE}💾 Fazendo commit inicial...${NC}"
git commit -m "Initial commit: VPS Deployment Package

- Docker & Traefik setup
- PostgreSQL & MySQL setup scripts
- GitHub Actions workflows
- Complete documentation
- Helper scripts for management"

echo -e "${GREEN}✅ Commit realizado${NC}"

# Configurar remote (opcional)
echo ""
read -p "Deseja configurar um remote (GitHub/GitLab)? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Exemplos de URL:"
    echo "  GitHub: git@github.com:usuario/vps-deployment-package.git"
    echo "  GitLab: git@gitlab.com:usuario/vps-deployment-package.git"
    echo ""
    read -p "URL do repositório remoto: " REMOTE_URL
    
    if [ ! -z "$REMOTE_URL" ]; then
        git remote add origin "$REMOTE_URL"
        echo -e "${GREEN}✅ Remote 'origin' configurado${NC}"
        
        # Perguntar se quer fazer push
        echo ""
        read -p "Deseja fazer push agora? (y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Perguntar branch
            read -p "Nome da branch [main]: " BRANCH
            BRANCH=${BRANCH:-main}
            
            # Renomear branch se necessário
            CURRENT_BRANCH=$(git branch --show-current)
            if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
                git branch -M "$BRANCH"
            fi
            
            echo ""
            echo -e "${BLUE}🚀 Fazendo push para $REMOTE_URL...${NC}"
            git push -u origin "$BRANCH"
            echo -e "${GREEN}✅ Push realizado com sucesso${NC}"
        fi
    fi
fi

# Resumo
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Repositório Git Configurado! 🎉               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Repositório Git inicializado${NC}"
echo -e "${GREEN}✅ Commit inicial realizado${NC}"

if git remote get-url origin &>/dev/null; then
    echo -e "${GREEN}✅ Remote configurado: $(git remote get-url origin)${NC}"
fi

echo ""
echo -e "${YELLOW}📚 Próximos passos:${NC}"
echo ""
echo "1. Compartilhar o repositório com sua equipe"
echo "2. Configurar proteção de branches (se GitHub/GitLab)"
echo "3. Adicionar colaboradores"
echo "4. Criar releases/tags quando necessário"
echo ""
echo -e "${YELLOW}💡 Comandos úteis:${NC}"
echo ""
echo "  git status              # Ver status do repositório"
echo "  git log --oneline       # Ver histórico de commits"
echo "  git remote -v           # Ver remotes configurados"
echo "  git tag v1.0.0          # Criar tag de versão"
echo "  git push origin --tags  # Push de tags"
echo ""

echo -e "${GREEN}✨ Setup concluído!${NC}"
