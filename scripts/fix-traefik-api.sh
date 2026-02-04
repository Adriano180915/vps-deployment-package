#!/bin/bash

##############################################################################
# Fix Traefik Docker API Version Issue
# 
# Este script corrige o erro de versão da API do Docker no Traefik
##############################################################################

set -e

echo "🔧 Corrigindo configuração do Traefik..."

# Navegar para diretório do Traefik
cd /opt/traefik

# Parar o Traefik
echo "⏸️  Parando Traefik..."
docker compose down

# Backup da configuração atual
cp docker-compose.yml docker-compose.yml.backup

# Atualizar docker-compose.yml para usar Traefik v2.11
cat > docker-compose.yml <<'EOF'
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
      
      # Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      
      # Redirect HTTP -> HTTPS
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
      
      # Let's Encrypt
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL:-admin@plannerate.com.br}"
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
      - "traefik.http.routers.dashboard.rule=Host(`traefik.plannerate.com.br`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$8EVjn/nj$$GiLUZqcbueTFeD23SuB6x0"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth"

networks:
  traefik-global:
    external: true
EOF

echo "✅ Configuração atualizada"

# Reiniciar Traefik
echo "🚀 Reiniciando Traefik..."
docker compose up -d

# Aguardar um momento
sleep 5

# Verificar status
echo "📊 Status do Traefik:"
docker compose ps

# Verificar logs (sem erros de API)
echo ""
echo "📋 Logs recentes (verificando erros):"
docker compose logs --tail=20 traefik

echo ""
echo "✅ Traefik corrigido!"
echo "   Backup da configuração anterior: docker-compose.yml.backup"
