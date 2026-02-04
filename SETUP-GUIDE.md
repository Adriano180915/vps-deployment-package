# 📖 Guia Completo de Setup - Plannerate VPS

Este guia detalha todo o processo de configuração de uma VPS do zero até o deploy da aplicação Plannerate.

## 📑 Índice

1. [Preparação](#1-preparação)
2. [Configuração Inicial da VPS](#2-configuração-inicial-da-vps)
3. [Instalação do Docker e Traefik](#3-instalação-do-docker-e-traefik)
4. [Configuração do Banco de Dados](#4-configuração-do-banco-de-dados)
5. [Configuração do Projeto](#5-configuração-do-projeto)
6. [Configuração do GitHub Actions](#6-configuração-do-github-actions)
7. [Configuração DNS](#7-configuração-dns)
8. [Primeiro Deploy](#8-primeiro-deploy)
9. [Verificação e Testes](#9-verificação-e-testes)
10. [Configurações Avançadas](#10-configurações-avançadas)

---

## 1. Preparação

### 1.1 Requisitos do Servidor

- **Sistema Operacional**: Ubuntu 22.04 ou 24.04 LTS
- **RAM**: Mínimo 2GB, recomendado 4GB+ para produção
- **CPU**: Mínimo 2 cores, recomendado 4+
- **Disco**: 20GB+ de espaço livre (SSD recomendado)
- **Acesso**: SSH como root ou usuário com sudo

### 1.2 Requisitos Externos

- Domínio registrado e configurável
- Conta GitHub com acesso ao repositório
- GitHub Container Registry (GHCR) habilitado
- Gerenciador de senhas (LastPass, 1Password, etc.)

### 1.3 Informações Necessárias

Antes de começar, tenha em mãos:

- ✅ IP público da VPS
- ✅ Domínio principal (ex: `plannerate.com.br`)
- ✅ Subdomain para staging (ex: `staging.plannerate.dev.br`)
- ✅ Email para Let's Encrypt
- ✅ Chave SSH para GitHub Actions

---

## 2. Configuração Inicial da VPS

### 2.1 Conectar ao Servidor

```bash
# Conectar via SSH como root
ssh root@SEU_IP_VPS

# Se usar usuário não-root com sudo
ssh usuario@SEU_IP_VPS
```

### 2.2 Atualizar Sistema

```bash
# Atualizar lista de pacotes
apt-get update

# Atualizar pacotes instalados
apt-get upgrade -y

# Instalar ferramentas básicas
apt-get install -y curl wget git vim htop
```

### 2.3 Criar Usuário Deploy (Opcional mas Recomendado)

```bash
# Criar usuário
adduser deploy

# Adicionar ao grupo sudo
usermod -aG sudo deploy

# Configurar SSH para o usuário
mkdir -p /home/deploy/.ssh
cp /root/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# Testar conexão
ssh deploy@SEU_IP_VPS
```

### 2.4 Fazer Upload do Pacote

```bash
# No seu computador local
scp -r vps-deployment-package root@SEU_IP_VPS:/opt/

# Ou usar Git
ssh root@SEU_IP_VPS
cd /opt
git clone https://github.com/seu-usuario/vps-deployment-package.git
```

---

## 3. Instalação do Docker e Traefik

### 3.1 Executar Script Principal

```bash
cd /opt/vps-deployment-package

# Tornar executável
chmod +x scripts/*.sh

# Executar setup (modo interativo)
sudo bash scripts/setup-vps-new.sh
```

### 3.2 O que o Script Faz

1. ✅ Verifica sistema operacional
2. ✅ Instala Docker e Docker Compose
3. ✅ Cria usuário `plannerate` para deploy
4. ✅ Cria estrutura de diretórios:
   ```
   /opt/
   ├── traefik/
   │   ├── letsencrypt/
   │   ├── docker-compose.yml
   │   └── .env
   └── plannerate/
       ├── staging/
       └── production/
   ```
5. ✅ Configura Traefik com SSL automático
6. ✅ Gera senhas e chaves de segurança
7. ✅ Cria templates de arquivos `.env`
8. ✅ Configura firewall (UFW)

### 3.3 Anotar Credenciais Geradas

Após o script terminar:

```bash
# Ver credenciais geradas
cat /root/.plannerate-credentials

# IMPORTANTE: Copiar para gerenciador de senhas e depois deletar
rm /root/.plannerate-credentials
```

### 3.4 Editar Configuração do Traefik

```bash
# Editar .env do Traefik
vim /opt/traefik/.env
```

Configurar:
```env
ACME_EMAIL=seu-email@dominio.com
ADMIN_DOMAIN=plannerate.com.br
```

### 3.5 Verificar Traefik

```bash
cd /opt/traefik
docker compose ps

# Ver logs
docker compose logs -f

# Acessar dashboard (após configurar DNS)
# https://traefik.plannerate.com.br
# Usuário: admin
# Senha: (verificar no docker-compose.yml)
```

---

## 4. Configuração do Banco de Dados

Escolha entre MySQL ou PostgreSQL (ou ambos se necessário).

### 4.1 PostgreSQL (Recomendado)

```bash
cd /opt/vps-deployment-package

# Executar script
sudo bash scripts/setup-postgres.sh

# Selecionar opção:
# 1 - Standalone (sistema)
# 2 - Docker (recomendado)
# 3 - Cluster com replicação (produção)
# 4 - Manual
```

#### Opção 2 - Docker (Recomendado para maioria dos casos)

Cria container PostgreSQL com:
- ✅ Configurações otimizadas
- ✅ Databases staging e production
- ✅ Usuários com permissões adequadas
- ✅ Persistência de dados
- ✅ Health checks

#### Opção 3 - Cluster com Replicação

Para alta disponibilidade:
- 1 servidor primário (read/write)
- 2 réplicas (read-only)
- Replicação streaming assíncrona
- Failover manual ou automático (com ferramenta adicional)

### 4.2 MySQL (Alternativo)

```bash
cd /opt/vps-deployment-package

# Executar script
sudo bash scripts/setup-mysql.sh

# Selecionar opção:
# 1 - Standalone (sistema)
# 2 - Docker (recomendado)
# 3 - Manual
```

### 4.3 Anotar Credenciais do Banco

```bash
# PostgreSQL
cat /root/.plannerate-postgres-credentials

# MySQL
cat /root/.plannerate-mysql-credentials

# IMPORTANTE: Salvar em gerenciador de senhas e deletar
rm /root/.plannerate-postgres-credentials
rm /root/.plannerate-mysql-credentials
```

### 4.4 Testar Conexão

```bash
# PostgreSQL Docker
docker exec postgres-plannerate psql -U plannerate_staging -d plannerate_staging -c "SELECT version();"

# MySQL Docker
docker exec mysql-plannerate mysql -u plannerate_staging -p plannerate_staging -e "SELECT version();"
```

---

## 5. Configuração do Projeto

### 5.1 Copiar Arquivos Docker

```bash
# Copiar para staging
cp /opt/vps-deployment-package/docker/docker-compose.staging.yml /opt/plannerate/staging/
cp /opt/vps-deployment-package/docker/Dockerfile /opt/plannerate/staging/

# Copiar para production (se necessário)
cp /opt/vps-deployment-package/docker/docker-compose.staging.yml /opt/plannerate/production/docker-compose.production.yml
cp /opt/vps-deployment-package/docker/Dockerfile /opt/plannerate/production/

# Ajustar permissões
chown -R plannerate:plannerate /opt/plannerate/
```

### 5.2 Criar Arquivo .env Staging

```bash
vim /opt/plannerate/staging/.env
```

Configuração mínima:

```env
# App
APP_NAME="Plannerate Staging"
APP_ENV=staging
APP_KEY=base64:WILL_BE_GENERATED_AFTER_FIRST_DEPLOY
APP_DEBUG=true
APP_URL=https://staging.plannerate.dev.br

# Domínio
DOMAIN=staging.plannerate.dev.br

# GitHub
GITHUB_REPO=seu-usuario/plannerate

# Database (usar credenciais geradas)
DB_CONNECTION=pgsql
DB_HOST=postgres-plannerate  # ou IP se externo
DB_PORT=5432
DB_DATABASE=plannerate_staging
DB_USERNAME=plannerate_staging
DB_PASSWORD=SENHA_GERADA_NO_SETUP

# Redis (usar credenciais geradas)
REDIS_HOST=redis
REDIS_PASSWORD=SENHA_GERADA_NO_SETUP
REDIS_PORT=6379

# Reverb (usar credenciais geradas)
REVERB_APP_KEY=CHAVE_GERADA_NO_SETUP
REVERB_APP_SECRET=SECRET_GERADA_NO_SETUP
VITE_REVERB_HOST=staging.plannerate.dev.br
VITE_REVERB_PORT=443
VITE_REVERB_SCHEME=wss

# DigitalOcean Spaces (configurar com suas credenciais)
DO_SPACES_KEY=sua-chave
DO_SPACES_SECRET=seu-secret
```

### 5.3 Criar Configuração PHP (Opcional)

```bash
mkdir -p /opt/plannerate/staging/php-config

cat > /opt/plannerate/staging/php-config/memory-limit.ini <<EOF
memory_limit = 512M
upload_max_filesize = 50M
post_max_size = 50M
max_execution_time = 300
EOF
```

### 5.4 Conectar Banco à Rede do Traefik

Se o banco estiver em Docker:

```bash
# PostgreSQL
docker network connect traefik-global postgres-plannerate

# MySQL
docker network connect traefik-global mysql-plannerate
```

---

## 6. Configuração do GitHub Actions

### 6.1 Copiar Workflows para o Repositório

No seu repositório local:

```bash
# Copiar workflows
cp vps-deployment-package/github-workflows/*.yml .github/workflows/

# Commit e push
git add .github/workflows/
git commit -m "Add deployment workflows"
git push origin main
```

### 6.2 Gerar Chave SSH para GitHub Actions

Na VPS:

```bash
# Como usuário plannerate
sudo -u plannerate ssh-keygen -t ed25519 -C "github-actions@plannerate" -f /home/plannerate/.ssh/github_actions -N ""

# Ver chave pública
cat /home/plannerate/.ssh/github_actions.pub

# Adicionar ao authorized_keys
cat /home/plannerate/.ssh/github_actions.pub >> /home/plannerate/.ssh/authorized_keys

# Ver chave privada (para adicionar no GitHub)
cat /home/plannerate/.ssh/github_actions
```

### 6.3 Configurar Secrets no GitHub

Ir em: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

Adicionar:

| Secret | Valor | Descrição |
|--------|-------|-----------|
| `STAGING_VPS_HOST` | IP da VPS | Endereço do servidor staging |
| `STAGING_VPS_USER` | `plannerate` | Usuário para deploy |
| `STAGING_VPS_SSH_KEY` | Chave privada | Conteúdo de `/home/plannerate/.ssh/github_actions` |
| `STAGING_VPS_PORT` | `22` | Porta SSH (padrão 22) |
| `STAGING_GITHUB_REPO` | `usuario/repo` | Nome do repositório no formato `owner/name` |
| `VITE_REVERB_APP_KEY` | Chave gerada | Do arquivo .env staging |
| `PGADMIN_PASSWORD` | Senha forte | Para acessar pgAdmin |

### 6.4 Editar Workflows (se necessário)

Verificar e ajustar em `.github/workflows/deploy-staging.yml`:

```yaml
# Verificar domínio correto
VITE_REVERB_HOST=staging.plannerate.dev.br

# Verificar nome do container
docker exec plannerate-app-staging php artisan migrate --force
```

---

## 7. Configuração DNS

### 7.1 Registros DNS Necessários

No painel do seu provedor de domínio (ex: Cloudflare, GoDaddy, etc.):

#### Staging:

| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| A | `staging` | IP_DA_VPS | 3600 |
| A | `*.staging` | IP_DA_VPS | 3600 |
| A | `pgadmin.staging` | IP_DA_VPS | 3600 |

#### Production (quando pronto):

| Tipo | Nome | Valor | TTL |
|------|------|-------|-----|
| A | `@` | IP_DA_VPS | 3600 |
| A | `*` | IP_DA_VPS | 3600 |
| A | `www` | IP_DA_VPS | 3600 |

### 7.2 Verificar DNS

```bash
# No seu computador local
dig staging.plannerate.dev.br

# Deve retornar o IP da VPS
# Aguardar propagação (pode levar até 48h, geralmente alguns minutos)
```

### 7.3 Testar Traefik

Após DNS propagar:

```bash
# Acessar dashboard do Traefik
# https://traefik.plannerate.com.br

# Ver logs de certificados
cd /opt/traefik
docker compose logs -f | grep acme
```

---

## 8. Primeiro Deploy

### 8.1 Deploy via GitHub Actions (Recomendado)

```bash
# No repositório local
git checkout dev
git add .
git commit -m "Initial deployment setup"
git push origin dev

# GitHub Actions irá:
# 1. Build da imagem Docker
# 2. Push para GHCR
# 3. Deploy na VPS
# 4. Executar migrations
```

### 8.2 Acompanhar Deploy

- Acessar GitHub → Actions
- Ver workflow `Build and Deploy Staging` em execução
- Verificar logs de cada step

### 8.3 Deploy Manual (Alternativo)

Na VPS:

```bash
cd /opt/plannerate/staging

# Login no GHCR
echo "GITHUB_TOKEN" | docker login ghcr.io -u GITHUB_USER --password-stdin

# Definir variável
export GITHUB_REPO=usuario/repositorio

# Pull e up
docker compose -f docker-compose.staging.yml pull
docker compose -f docker-compose.staging.yml up -d

# Aguardar containers iniciarem
sleep 30

# Gerar APP_KEY (APENAS NO PRIMEIRO DEPLOY)
docker exec plannerate-app-staging php artisan key:generate

# Executar migrations
docker exec plannerate-app-staging php artisan migrate --force
docker exec plannerate-app-staging php artisan tenant:migrate --force

# Otimizar
docker exec plannerate-app-staging php artisan optimize
```

### 8.4 Copiar APP_KEY Gerada

```bash
# Ver APP_KEY gerada
docker exec plannerate-app-staging php artisan tinker --execute="echo config('app.key');"

# Atualizar .env com a APP_KEY gerada
vim /opt/plannerate/staging/.env

# Rebuild containers
cd /opt/plannerate/staging
docker compose -f docker-compose.staging.yml up -d --force-recreate app
```

---

## 9. Verificação e Testes

### 9.1 Verificar Containers

```bash
cd /opt/plannerate/staging

# Ver status
docker compose -f docker-compose.staging.yml ps

# Todos devem estar "healthy" ou "running"
```

### 9.2 Verificar Logs

```bash
# App
docker logs -f plannerate-app-staging

# Queue (Horizon)
docker logs -f plannerate-queue-staging

# Redis
docker logs -f plannerate-redis-staging

# Banco
docker logs -f postgres-plannerate
```

### 9.3 Testar Aplicação

```bash
# Health check
curl https://staging.plannerate.dev.br/up

# Página inicial
curl -I https://staging.plannerate.dev.br
```

### 9.4 Testar WebSocket (Reverb)

```bash
# Ver logs do Reverb
docker logs -f plannerate-app-staging | grep reverb

# Acessar aplicação e verificar conexão WebSocket no console do browser
```

### 9.5 Acessar pgAdmin

- URL: `https://pgadmin.staging.plannerate.dev.br`
- Email: (configurado no .env - PGADMIN_EMAIL)
- Senha: (secret PGADMIN_PASSWORD)

Adicionar servidor:
- Host: `postgres-plannerate`
- Port: `5432`
- Database: `plannerate_staging`
- Username: `plannerate_staging`
- Password: (do setup)

---

## 10. Configurações Avançadas

### 10.1 Configurar Monitoring

#### Instalar Portainer (UI para Docker)

```bash
docker volume create portainer_data

docker run -d \
  -p 9000:9000 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Acessar: http://IP_VPS:9000
```

#### Logs Centralizados (Opcional)

Considerar ferramentas como:
- **Loki + Grafana** para logs
- **Prometheus** para métricas
- **Sentry** para erros da aplicação

### 10.2 Backup Automático

Criar script de backup:

```bash
cat > /opt/plannerate/staging/backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/opt/plannerate/staging/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
docker exec postgres-plannerate pg_dump -U plannerate_staging plannerate_staging > $BACKUP_DIR/db_staging_$DATE.sql

# Comprimir
gzip $BACKUP_DIR/db_staging_$DATE.sql

# Manter últimos 7 dias
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: db_staging_$DATE.sql.gz"
EOF

chmod +x /opt/plannerate/staging/backup.sh
```

Adicionar ao crontab:

```bash
# Editar crontab
crontab -e

# Adicionar (backup diário às 3am)
0 3 * * * /opt/plannerate/staging/backup.sh >> /var/log/plannerate-backup.log 2>&1
```

### 10.3 Configurar Alertas

Usar serviços como:
- **UptimeRobot** para monitorar uptime
- **StatusCake** para testes de disponibilidade
- **Pingdom** para performance

### 10.4 SSL Staging

Testar renovação de certificados:

```bash
cd /opt/traefik
docker compose logs traefik | grep acme

# Forçar renovação (se necessário)
docker compose restart traefik
```

### 10.5 Optimization

```bash
# Configurar swap (se pouca RAM)
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# Limpar Docker
docker system prune -a --volumes -f

# Configurar log rotation
vim /etc/docker/daemon.json
```

Adicionar:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

---

## ✅ Checklist Final

Antes de considerar o setup completo:

### Infraestrutura
- [ ] Docker instalado e funcionando
- [ ] Traefik rodando com SSL
- [ ] Banco de dados configurado e testado
- [ ] Estrutura de diretórios criada
- [ ] Firewall configurado

### Aplicação
- [ ] Containers subindo sem erros
- [ ] Migrations executadas
- [ ] APP_KEY gerada e configurada
- [ ] Reverb funcionando
- [ ] Health check respondendo

### DNS & SSL
- [ ] DNS propagado
- [ ] SSL certificado gerado
- [ ] HTTPS funcionando
- [ ] Wildcard funcionando para subdomínios

### CI/CD
- [ ] Workflows copiados para repositório
- [ ] Secrets configurados no GitHub
- [ ] Deploy automático funcionando
- [ ] Migrations automáticas funcionando

### Segurança
- [ ] Senhas salvas em gerenciador
- [ ] Arquivos de credenciais deletados
- [ ] SSH key configurada
- [ ] Firewall ativo

### Backup
- [ ] Script de backup criado
- [ ] Cron job configurado
- [ ] Backup testado
- [ ] Restore testado

---

## 🎉 Conclusão

Parabéns! Sua VPS está configurada e a aplicação rodando em staging.

**Próximos Passos:**

1. **Testar aplicação**: Criar usuários, testar funcionalidades
2. **Ajustar performance**: Monitorar recursos e ajustar conforme necessário
3. **Configurar monitoring**: Implementar ferramentas de monitoramento
4. **Preparar production**: Replicar setup para ambiente de produção
5. **Documentar customizações**: Anotar qualquer alteração específica do seu setup

**Lembre-se:**
- Manter backups regulares
- Monitorar logs frequentemente
- Atualizar containers regularmente
- Testar em staging antes de production

---

**Dúvidas?** Consulte [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
