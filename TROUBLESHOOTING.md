# 🔧 Troubleshooting Guide - Plannerate VPS

Guia de resolução de problemas comuns durante setup e operação.

## 📑 Índice

1. [Problemas na Instalação](#problemas-na-instalação)
2. [Problemas com Docker](#problemas-com-docker)
3. [Problemas com Traefik e SSL](#problemas-com-traefik-e-ssl)
4. [Problemas com Banco de Dados](#problemas-com-banco-de-dados)
5. [Problemas com a Aplicação](#problemas-com-a-aplicação)
6. [Problemas com GitHub Actions](#problemas-com-github-actions)
7. [Problemas de Performance](#problemas-de-performance)
8. [Comandos Úteis](#comandos-úteis)

---

## Problemas na Instalação

### Script setup-vps-new.sh falha

**Sintomas:**
- Script para com erro
- Docker não instala
- Permissões negadas

**Soluções:**

```bash
# 1. Verificar se está rodando como root
whoami  # Deve retornar "root"

# Se não for root
sudo -i
cd /opt/vps-deployment-package
bash scripts/setup-vps-new.sh

# 2. Verificar sistema operacional
cat /etc/os-release
# Deve ser Ubuntu 22.04 ou 24.04

# 3. Limpar instalação anterior do Docker
apt-get remove docker docker-engine docker.io containerd runc
rm -rf /var/lib/docker
rm -rf /var/lib/containerd

# 4. Rodar script novamente
bash scripts/setup-vps-new.sh
```

### "Network traefik-global already exists"

**Solução:**

```bash
# Remover rede existente
docker network rm traefik-global

# Criar novamente
docker network create traefik-global

# Ou ignorar o erro - a rede já existe e está OK
```

---

## Problemas com Docker

### "Cannot connect to Docker daemon"

**Sintomas:**
- Comandos docker falham
- "Is the docker daemon running?"

**Soluções:**

```bash
# 1. Verificar status do Docker
systemctl status docker

# 2. Iniciar Docker
systemctl start docker
systemctl enable docker

# 3. Verificar se usuário está no grupo docker
groups $USER

# 4. Adicionar ao grupo (se necessário)
usermod -aG docker $USER

# 5. Logout e login novamente, ou
newgrp docker

# 6. Testar
docker ps
```

### Containers não iniciam

**Sintomas:**
- `docker compose up` falha
- Containers em estado "Restarting"
- Health check failing

**Diagnóstico:**

```bash
# Ver status
docker compose ps

# Ver logs
docker logs <container-name>

# Ver logs em tempo real
docker logs -f <container-name>

# Verificar recursos
docker stats

# Verificar espaço em disco
df -h
```

**Soluções Comuns:**

```bash
# 1. Memória insuficiente
# Adicionar swap
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# 2. Porta já em uso
# Verificar portas
netstat -tulpn | grep LISTEN

# Matar processo usando a porta
kill -9 <PID>

# 3. Permissões incorretas
# Fixar permissões de volumes
chown -R www-data:www-data /opt/plannerate/staging/storage

# 4. Rebuild completo
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### "No space left on device"

**Solução:**

```bash
# Verificar espaço
df -h

# Limpar Docker
docker system prune -a --volumes -f

# Limpar logs antigos
journalctl --vacuum-time=3d

# Remover imagens não utilizadas
docker image prune -a

# Verificar volumes grandes
docker system df -v
```

---

## Problemas com Traefik e SSL

### Traefik não gera certificados SSL

**Sintomas:**
- Site acessível via HTTP mas não HTTPS
- Erro de certificado no navegador
- acme.json vazio

**Diagnóstico:**

```bash
cd /opt/traefik

# Ver logs do Traefik
docker compose logs traefik | grep acme

# Verificar arquivo acme.json
ls -la letsencrypt/acme.json
cat letsencrypt/acme.json

# Verificar DNS
dig staging.plannerate.dev.br +short
```

**Soluções:**

```bash
# 1. Verificar permissões do acme.json
chmod 600 letsencrypt/acme.json

# 2. Verificar email no .env
cat .env
# ACME_EMAIL deve ser email válido

# 3. Verificar se domínio está acessível externamente
curl -I http://staging.plannerate.dev.br

# 4. Resetar certificados
docker compose down
rm letsencrypt/acme.json
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json
docker compose up -d

# 5. Aguardar e verificar logs
docker compose logs -f traefik

# 6. Testar rate limit do Let's Encrypt
# Se muitos pedidos em pouco tempo, aguardar 1 hora
```

### "ERR_TOO_MANY_REDIRECTS"

**Sintomas:**
- Loop de redirecionamento
- Site não carrega

**Solução:**

```bash
# Verificar configuração do Traefik
cd /opt/traefik
vim docker-compose.yml

# Garantir que redirect está correto:
# - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
# - "--entrypoints.web.http.redirections.entrypoint.scheme=https"

# Restart Traefik
docker compose restart traefik
```

### Traefik não detecta containers

**Sintomas:**
- Site retorna 404
- Dashboard do Traefik não mostra routers

**Solução:**

```bash
# 1. Verificar se container está na rede correta
docker inspect plannerate-app-staging | grep traefik-global

# 2. Conectar à rede se necessário
docker network connect traefik-global plannerate-app-staging

# 3. Verificar labels do container
docker inspect plannerate-app-staging | grep -A 20 Labels

# 4. Verificar configuração do Traefik
cd /opt/traefik
docker compose config

# 5. Restart Traefik
docker compose restart traefik
```

---

## Problemas com Banco de Dados

### PostgreSQL não aceita conexões

**Sintomas:**
- "could not connect to server"
- "password authentication failed"

**Solução:**

```bash
# 1. Verificar se está rodando
docker ps | grep postgres

# 2. Ver logs
docker logs postgres-plannerate

# 3. Testar conexão local
docker exec postgres-plannerate psql -U postgres -c "SELECT 1"

# 4. Verificar pg_hba.conf (se standalone)
cat /etc/postgresql/16/main/pg_hba.conf

# 5. Verificar credenciais
cat /opt/plannerate/staging/.env | grep DB_

# 6. Conectar à rede correta
docker network connect plannerate-staging postgres-plannerate

# 7. Restart PostgreSQL
docker restart postgres-plannerate
```

### Migrations falham

**Sintomas:**
- "SQLSTATE[HY000] [2002] Connection refused"
- "Base table or view not found"

**Solução:**

```bash
# 1. Verificar se banco existe
docker exec postgres-plannerate psql -U postgres -c "\l"

# 2. Criar banco manualmente se necessário
docker exec postgres-plannerate psql -U postgres -c "CREATE DATABASE plannerate_staging"

# 3. Verificar permissões do usuário
docker exec postgres-plannerate psql -U postgres -d plannerate_staging -c "GRANT ALL ON SCHEMA public TO plannerate_staging"

# 4. Executar migrations manualmente
docker exec plannerate-app-staging php artisan migrate --force

# 5. Ver erro detalhado
docker exec plannerate-app-staging php artisan migrate --force -vvv

# 6. Resetar banco (CUIDADO - apaga dados)
docker exec plannerate-app-staging php artisan migrate:fresh --force
```

### Replicação PostgreSQL não funciona

**Sintomas:**
- Réplicas não sincronizam
- Lag alto na replicação

**Diagnóstico:**

```bash
# Verificar status da replicação
docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Verificar lag
docker exec postgres-primary psql -U postgres -c "SELECT pg_current_wal_lsn() - replay_lsn AS lag FROM pg_stat_replication;"

# Ver logs das réplicas
docker logs postgres-replica1
docker logs postgres-replica2
```

**Solução:**

```bash
# 1. Verificar se primário está configurado corretamente
docker exec postgres-primary cat /var/lib/postgresql/data/pgdata/pg_hba.conf

# 2. Resetar réplica
docker compose down postgres-replica1
docker volume rm postgres-cluster_replica1-data
docker compose up -d postgres-replica1

# 3. Verificar rede
docker network inspect postgres-cluster
```

---

## Problemas com a Aplicação

### "Class 'Intervention\Image\Drivers\Gd\Driver' not found"

**Sintomas:**
- Erro ao processar imagens
- Upload de produtos falha

**Solução:**

```bash
# Verificar se GD está instalado
docker exec plannerate-app-staging php -m | grep gd

# Se não estiver, rebuild da imagem
cd /opt/plannerate/staging
docker compose build --no-cache app
docker compose up -d app
```

### Reverb (WebSocket) não conecta

**Sintomas:**
- Erro de conexão no console do browser
- "WebSocket connection failed"

**Diagnóstico:**

```bash
# Ver logs do Reverb
docker logs plannerate-app-staging | grep -i reverb

# Testar conexão WebSocket
curl -I https://staging.plannerate.dev.br/app

# Verificar configuração Nginx
docker exec plannerate-app-staging cat /etc/nginx/http.d/laravel.conf
```

**Solução:**

```bash
# 1. Verificar variáveis de ambiente
docker exec plannerate-app-staging env | grep REVERB

# 2. Verificar se Reverb está rodando
docker exec plannerate-app-staging ps aux | grep reverb

# 3. Restart do container
docker restart plannerate-app-staging

# 4. Verificar configuração no frontend
# No browser console, verificar:
# window.Echo.connector.pusher.connection
```

### Horizon não processa jobs

**Sintomas:**
- Jobs ficam pendentes
- Horizon status: inactive

**Solução:**

```bash
# 1. Ver logs do Horizon
docker logs plannerate-queue-staging

# 2. Verificar Redis
docker exec plannerate-redis-staging redis-cli ping

# 3. Limpar filas
docker exec plannerate-app-staging php artisan queue:clear

# 4. Restart Horizon
docker exec plannerate-app-staging php artisan horizon:terminate
docker restart plannerate-queue-staging

# 5. Verificar configuração
docker exec plannerate-app-staging php artisan horizon:status
```

### "419 Page Expired" (CSRF)

**Sintomas:**
- Formulários retornam erro 419
- Sessões expiram rapidamente

**Solução:**

```bash
# 1. Verificar APP_KEY
docker exec plannerate-app-staging php artisan key:generate --show

# 2. Limpar cache de sessão
docker exec plannerate-app-staging php artisan session:flush
docker exec plannerate-app-staging php artisan cache:clear

# 3. Verificar configuração de sessão
docker exec plannerate-app-staging cat .env | grep SESSION

# 4. Verificar se HTTPS está configurado
# No .env, garantir:
# SESSION_SECURE_COOKIE=true
# SESSION_SAME_SITE=lax
```

### Performance ruim / lentidão

**Diagnóstico:**

```bash
# Verificar recursos
docker stats

# Ver queries lentas (PostgreSQL)
docker exec postgres-plannerate psql -U postgres -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"

# Ver logs de queries lentas
docker exec plannerate-app-staging cat storage/logs/laravel.log | grep -i "query took"
```

**Soluções:**

```bash
# 1. Otimizar caches
docker exec plannerate-app-staging php artisan optimize
docker exec plannerate-app-staging php artisan config:cache
docker exec plannerate-app-staging php artisan route:cache
docker exec plannerate-app-staging php artisan view:cache

# 2. Aumentar recursos do container
vim docker-compose.staging.yml
# Aumentar memory e cpus

# 3. Configurar OpCache
# Já está configurado no Dockerfile

# 4. Adicionar índices no banco
# Analisar queries e criar índices necessários

# 5. Usar queue para operações pesadas
docker exec plannerate-app-staging php artisan queue:work
```

---

## Problemas com GitHub Actions

### Build falha no GitHub Actions

**Sintomas:**
- Workflow com erro vermelho
- "Error: buildx failed"

**Solução:**

```bash
# Ver logs detalhados no GitHub Actions

# Problemas comuns:
# 1. Variáveis de ambiente faltando
# Verificar secrets no GitHub

# 2. Dockerfile com erro
# Testar build local:
docker build -t test .

# 3. Dependências faltando
# Verificar package.json e composer.json

# 4. Build args faltando
# Verificar se VITE_* args estão passados no workflow
```

### Deploy falha no GitHub Actions

**Sintomas:**
- Build passa mas deploy falha
- "Connection refused"
- "Permission denied"

**Solução:**

```bash
# 1. Verificar SSH key
# No servidor:
cat /home/plannerate/.ssh/authorized_keys

# Deve conter a chave pública correspondente ao secret SSH_PRIVATE_KEY

# 2. Testar conexão SSH
ssh plannerate@IP_VPS

# 3. Verificar secrets
# GitHub → Settings → Secrets
# Todos secrets necessários devem estar configurados

# 4. Verificar permissões
ls -la /opt/plannerate/staging
# Deve ser owner plannerate:plannerate

# 5. Ver logs detalhados no GitHub Actions
```

### Migrations não executam no deploy

**Sintomas:**
- Deploy completa mas banco não atualiza
- Tabelas faltando

**Solução:**

```bash
# 1. Verificar workflow
# deploy-staging.yml deve ter:
# docker exec plannerate-app-staging php artisan migrate --force

# 2. Executar manualmente
ssh plannerate@VPS
cd /opt/plannerate/staging
docker exec plannerate-app-staging php artisan migrate --force

# 3. Verificar se container está rodando
docker ps | grep plannerate-app-staging

# 4. Ver logs
docker logs plannerate-app-staging
```

---

## Problemas de Performance

### Alto uso de memória

**Diagnóstico:**

```bash
# Ver uso de memória
free -h
docker stats

# Ver processos
top
htop
```

**Soluções:**

```bash
# 1. Reduzir memory limits
vim docker-compose.staging.yml
# Ajustar valores de memory

# 2. Adicionar swap
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# 3. Limpar cache do Redis
docker exec plannerate-redis-staging redis-cli FLUSHDB

# 4. Otimizar PHP-FPM
# Ajustar pm.max_children no Dockerfile
```

### Alto uso de CPU

**Diagnóstico:**

```bash
# Ver processos
docker top plannerate-app-staging

# Ver queries ativas no banco
docker exec postgres-plannerate psql -U postgres -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

**Soluções:**

```bash
# 1. Verificar loops infinitos
docker logs plannerate-app-staging | tail -100

# 2. Otimizar queries
# Adicionar índices, usar eager loading

# 3. Usar queue para processos pesados
docker exec plannerate-app-staging php artisan queue:work

# 4. Limitar CPU no container
vim docker-compose.staging.yml
# Ajustar cpus
```

### Disco cheio

**Diagnóstico:**

```bash
# Ver uso de disco
df -h

# Ver maiores diretórios
du -sh /var/lib/docker/*
du -sh /opt/*
```

**Soluções:**

```bash
# 1. Limpar Docker
docker system prune -a --volumes -f

# 2. Limpar logs antigos
journalctl --vacuum-time=3d
find /var/log -name "*.log" -mtime +7 -delete

# 3. Limpar backups antigos
find /opt/plannerate/staging/backups -name "*.gz" -mtime +30 -delete

# 4. Verificar volumes grandes
docker volume ls
docker volume inspect <volume-name>
```

---

## Comandos Úteis

### Docker

```bash
# Ver todos containers
docker ps -a

# Ver logs
docker logs -f <container-name>

# Shell no container
docker exec -it <container-name> bash

# Restart container
docker restart <container-name>

# Stop all containers
docker stop $(docker ps -q)

# Remove all stopped containers
docker container prune -f

# Ver recursos usados
docker stats

# Ver redes
docker network ls

# Inspecionar container
docker inspect <container-name>
```

### Laravel (dentro do container)

```bash
# Artisan commands
docker exec plannerate-app-staging php artisan <command>

# Tinker
docker exec -it plannerate-app-staging php artisan tinker

# Clear cache
docker exec plannerate-app-staging php artisan optimize:clear

# Ver rotas
docker exec plannerate-app-staging php artisan route:list

# Ver jobs da fila
docker exec plannerate-app-staging php artisan queue:work --once

# Horizon status
docker exec plannerate-app-staging php artisan horizon:status
```

### Banco de Dados

```bash
# PostgreSQL
docker exec postgres-plannerate psql -U postgres

# Conectar a database específica
docker exec -it postgres-plannerate psql -U plannerate_staging -d plannerate_staging

# MySQL
docker exec -it mysql-plannerate mysql -u root -p

# Backup
docker exec postgres-plannerate pg_dump -U plannerate_staging plannerate_staging > backup.sql

# Restore
docker exec -i postgres-plannerate psql -U plannerate_staging plannerate_staging < backup.sql
```

### Sistema

```bash
# Ver espaço em disco
df -h

# Ver uso de memória
free -h

# Ver processos
top
htop

# Ver portas em uso
netstat -tulpn

# Ver logs do sistema
journalctl -xe

# Reiniciar serviços
systemctl restart docker
```

---

## 🆘 Ainda com Problemas?

Se nenhuma das soluções acima resolver:

1. **Coletar informações:**
   ```bash
   # Criar arquivo com informações do sistema
   {
     echo "=== Sistema ==="
     uname -a
     cat /etc/os-release
     
     echo "=== Docker ==="
     docker version
     docker compose version
     
     echo "=== Containers ==="
     docker ps -a
     
     echo "=== Logs recentes ==="
     docker logs plannerate-app-staging --tail 50
     
     echo "=== Recursos ==="
     free -h
     df -h
   } > debug-info.txt
   ```

2. **Verificar documentação oficial:**
   - [Docker Docs](https://docs.docker.com/)
   - [Traefik Docs](https://doc.traefik.io/traefik/)
   - [Laravel Docs](https://laravel.com/docs)

3. **Consultar comunidade:**
   - Stack Overflow
   - GitHub Issues
   - Discord/Slack communities

4. **Contatar suporte:**
   - Abrir issue no repositório
   - Anexar arquivo `debug-info.txt`
   - Descrever passos para reproduzir

---

**Última atualização:** 2026-02-04
