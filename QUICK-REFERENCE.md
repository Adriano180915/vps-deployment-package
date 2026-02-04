# 🚀 Quick Reference - VPS Deployment Package

Guia de referência rápida com comandos mais usados.

## 📦 Estrutura do Pacote

```
vps-deployment-package/
├── docker/                    # Arquivos Docker
├── scripts/                   # Scripts de setup e gerenciamento
├── github-workflows/          # Workflows CI/CD
├── config/                    # Arquivos de configuração
└── docs/                      # Documentação
```

## ⚡ Setup Rápido

```bash
# 1. Upload para VPS
scp -r vps-deployment-package root@SEU_IP:/opt/

# 2. Setup completo
cd /opt/vps-deployment-package
sudo bash scripts/setup-vps-new.sh

# 3. Configurar banco
sudo bash scripts/setup-postgres.sh

# 4. Copiar arquivos Docker
cp docker/* /opt/plannerate/staging/

# 5. Configurar .env
vim /opt/plannerate/staging/.env

# 6. Deploy via GitHub Actions
git push origin dev
```

## 🐳 Comandos Docker

### Containers

```bash
# Listar containers
docker ps
docker ps -a  # incluir parados

# Ver logs
docker logs -f <container-name>
docker logs --tail 100 <container-name>

# Shell no container
docker exec -it <container-name> bash

# Restart
docker restart <container-name>

# Stop/Start
docker stop <container-name>
docker start <container-name>

# Remover
docker rm <container-name>
docker rm -f <container-name>  # forçar

# Stats
docker stats
docker stats <container-name>
```

### Images

```bash
# Listar imagens
docker images

# Pull imagem
docker pull ghcr.io/usuario/repo:tag

# Remover imagem
docker rmi <image-id>

# Remover todas não usadas
docker image prune -a
```

### Docker Compose

```bash
# Up (criar e iniciar)
docker compose up -d

# Down (parar e remover)
docker compose down

# Restart
docker compose restart

# Rebuild
docker compose build --no-cache
docker compose up -d --force-recreate

# Logs
docker compose logs -f
docker compose logs -f <service-name>

# Pull
docker compose pull

# Ver configuração
docker compose config
```

### Limpeza

```bash
# Limpar tudo não usado
docker system prune -a --volumes -f

# Limpar apenas volumes
docker volume prune -f

# Limpar apenas redes
docker network prune -f

# Ver espaço usado
docker system df
```

## 🎯 Comandos Laravel

```bash
# Prefixo para todos comandos
docker exec plannerate-app-staging php artisan <command>

# Atalho (criar alias)
alias artisan="docker exec plannerate-app-staging php artisan"
```

### Artisan Comum

```bash
# Migrations
artisan migrate
artisan migrate --force  # production
artisan migrate:fresh    # resetar
artisan migrate:rollback

# Cache
artisan optimize
artisan optimize:clear
artisan config:cache
artisan route:cache
artisan view:cache

# Queue
artisan queue:work
artisan queue:restart
artisan queue:clear

# Tinker
docker exec -it plannerate-app-staging php artisan tinker

# Horizon
artisan horizon
artisan horizon:status
artisan horizon:terminate

# Keys
artisan key:generate
```

## 🗄️ Comandos de Banco

### PostgreSQL

```bash
# Conectar
docker exec -it postgres-plannerate psql -U postgres

# Conectar em database específica
docker exec -it postgres-plannerate psql -U plannerate_staging -d plannerate_staging

# Executar comando
docker exec postgres-plannerate psql -U postgres -c "SELECT version();"

# Listar databases
docker exec postgres-plannerate psql -U postgres -c "\l"

# Listar tabelas
docker exec postgres-plannerate psql -U postgres -d plannerate_staging -c "\dt"

# Backup
docker exec postgres-plannerate pg_dump -U plannerate_staging plannerate_staging > backup.sql

# Restore
docker exec -i postgres-plannerate psql -U plannerate_staging plannerate_staging < backup.sql

# Ver conexões ativas
docker exec postgres-plannerate psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

### MySQL

```bash
# Conectar
docker exec -it mysql-plannerate mysql -u root -p

# Executar comando
docker exec mysql-plannerate mysql -u root -p -e "SHOW DATABASES;"

# Backup
docker exec mysql-plannerate mysqldump -u root -p plannerate_staging > backup.sql

# Restore
docker exec -i mysql-plannerate mysql -u root -p plannerate_staging < backup.sql
```

## 🌐 Traefik

```bash
# Logs
cd /opt/traefik
docker compose logs -f

# Restart
docker compose restart

# Ver configuração
docker compose config

# Dashboard
# https://traefik.seudominio.com.br

# Ver certificados
cat letsencrypt/acme.json | jq
```

## 🔧 Helper Script

```bash
# Uso: ./scripts/helper.sh [comando] [ambiente]

# Logs
./scripts/helper.sh logs staging

# Restart
./scripts/helper.sh restart staging

# Status
./scripts/helper.sh status staging

# Shell
./scripts/helper.sh shell staging

# Tinker
./scripts/helper.sh tinker staging

# Artisan
./scripts/helper.sh artisan staging migrate

# Backup
./scripts/helper.sh backup staging

# Restore
./scripts/helper.sh restore staging backup.sql
```

## 🔍 Diagnóstico

### Ver Recursos

```bash
# CPU e Memória
free -h
top
htop

# Disco
df -h
du -sh /opt/*
du -sh /var/lib/docker/*

# Docker stats
docker stats
```

### Ver Logs

```bash
# Sistema
journalctl -xe
journalctl -u docker -f

# Aplicação
docker logs -f plannerate-app-staging

# Traefik
cd /opt/traefik && docker compose logs -f

# Banco
docker logs -f postgres-plannerate

# Redis
docker logs -f plannerate-redis-staging
```

### Testar Conectividade

```bash
# Teste HTTP
curl -I http://staging.seudominio.com.br

# Teste HTTPS
curl -I https://staging.seudominio.com.br

# Health check
curl https://staging.seudominio.com.br/up

# DNS
dig staging.seudominio.com.br

# Porta aberta
netstat -tulpn | grep 443
```

## 🔒 Segurança

### Firewall

```bash
# Status
ufw status

# Habilitar
ufw enable

# Regras
ufw allow 22/tcp   # SSH
ufw allow 80/tcp   # HTTP
ufw allow 443/tcp  # HTTPS

# Ver logs
tail -f /var/log/ufw.log
```

### SSL

```bash
# Ver certificados
cd /opt/traefik
cat letsencrypt/acme.json | jq '.letsencrypt.Certificates'

# Forçar renovação
docker compose restart traefik

# Ver expiração
openssl s_client -connect staging.seudominio.com.br:443 -servername staging.seudominio.com.br 2>/dev/null | openssl x509 -noout -dates
```

## 💾 Backup & Restore

### Banco de Dados

```bash
# Backup manual
cd /opt/plannerate/staging
docker exec postgres-plannerate pg_dump -U plannerate_staging plannerate_staging > backups/db_$(date +%Y%m%d_%H%M%S).sql

# Comprimir
gzip backups/db_*.sql

# Restore
gunzip -c backups/db_20260204_150000.sql.gz | docker exec -i postgres-plannerate psql -U plannerate_staging plannerate_staging
```

### Arquivos

```bash
# Backup storage
cd /opt/plannerate/staging
tar -czf backups/storage_$(date +%Y%m%d_%H%M%S).tar.gz storage/

# Restore storage
tar -xzf backups/storage_20260204_150000.tar.gz
```

## 📊 Monitoramento

### Health Checks

```bash
# Container health
docker inspect --format='{{.State.Health.Status}}' plannerate-app-staging

# App health
curl https://staging.seudominio.com.br/up

# Horizon status
docker exec plannerate-app-staging php artisan horizon:status
```

### Performance

```bash
# Queries lentas (PostgreSQL)
docker exec postgres-plannerate psql -U postgres -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# Tamanho das databases
docker exec postgres-plannerate psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;"

# Redis info
docker exec plannerate-redis-staging redis-cli INFO
```

## 🚨 Problemas Comuns

### Container não inicia

```bash
# Ver erro
docker logs <container-name>

# Verificar recursos
docker stats
free -h
df -h

# Rebuild
docker compose build --no-cache <service>
docker compose up -d <service>
```

### SSL não funciona

```bash
# Ver logs do Traefik
cd /opt/traefik
docker compose logs | grep acme

# Verificar DNS
dig staging.seudominio.com.br

# Resetar certificados
docker compose down
rm letsencrypt/acme.json
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json
docker compose up -d
```

### Banco não conecta

```bash
# Verificar se está rodando
docker ps | grep postgres

# Ver logs
docker logs postgres-plannerate

# Testar conexão
docker exec postgres-plannerate psql -U postgres -c "SELECT 1"

# Verificar credenciais
cat /opt/plannerate/staging/.env | grep DB_
```

## 📚 Links Úteis

- [Docker Docs](https://docs.docker.com/)
- [Traefik Docs](https://doc.traefik.io/traefik/)
- [Laravel Docs](https://laravel.com/docs)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)

---

**Para guia completo, veja [SETUP-GUIDE.md](SETUP-GUIDE.md)**

**Para troubleshooting, veja [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**
