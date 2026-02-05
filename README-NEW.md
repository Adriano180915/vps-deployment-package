# Setup VPS - Laravel com Docker, Traefik e MySQL Local

Este script configura uma VPS Ubuntu para rodar uma aplicação Laravel com:
- ✅ Docker & Docker Compose
- ✅ Traefik como reverse proxy com SSL automático (Let's Encrypt)
- ✅ MySQL instalado localmente na VPS (não via Docker)
- ✅ Redis para cache e filas
- ✅ Laravel Horizon para gerenciar filas
- ✅ Pusher para broadcasting (Reverb removido)
- ✅ Estrutura em `/opt/production`

## 🚀 Como usar

### 1. Executar o script na VPS

```bash
# Baixar e executar como root
curl -O https://raw.githubusercontent.com/seu-repo/main/scripts/simple-deploy-vps/setup-vps-new.sh
sudo bash setup-vps-new.sh
```

O script irá solicitar:
- **Nome do projeto**: ex: `meuapp`
- **Domínio principal**: ex: `meuapp.com.br`
- **Email para Let's Encrypt**: ex: `admin@meuapp.com.br`
- **GitHub Container Registry**: ex: `usuario/repo`

### 2. O que o script faz

1. Atualiza o sistema
2. Instala dependências básicas
3. **Instala MySQL localmente** (não via Docker)
4. Instala Docker e Docker Compose
5. Cria usuário `deploy` (não-root)
6. Cria estrutura de diretórios em `/opt/production`
7. Configura Traefik com SSL automático
8. Gera senhas seguras e cria arquivo `.env`
9. Configura firewall (UFW)
10. Inicia Traefik

### 3. Credenciais Geradas

Ao final, o script salva todas as credenciais em `/root/.credentials`:

```bash
# Ver credenciais
cat /root/.credentials

# Copie para seu gerenciador de senhas
# DEPOIS DELETE:
rm /root/.credentials
```

### 4. Copiar docker-compose para VPS

```bash
# Da sua máquina local
scp scripts/simple-deploy-vps/docker-compose.production.new.yml \
    deploy@SEU_IP:/opt/production/docker-compose.yml
```

### 5. Configurar .env

Edite o arquivo `/opt/production/.env` e configure:

```bash
# Na VPS
vim /opt/production/.env
```

Adicione credenciais do Pusher e email:
```env
PUSHER_APP_ID=seu_app_id
PUSHER_APP_KEY=sua_key
PUSHER_APP_SECRET=seu_secret
PUSHER_APP_CLUSTER=mt1

MAIL_MAILER=smtp
MAIL_HOST=smtp.seuservidor.com
MAIL_PORT=587
MAIL_USERNAME=seu_usuario
MAIL_PASSWORD=sua_senha
```

### 6. Fazer primeiro deploy

#### Via GitHub Actions (recomendado)

Configure os secrets no repositório:
- `VPS_HOST`: IP da VPS
- `VPS_USER`: deploy
- `SSH_PRIVATE_KEY`: chave SSH privada
- `DOMAIN`: seu domínio

Faça push para branch `main` para disparar deploy.

#### Deploy manual

```bash
# Logar no GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Subir aplicação
cd /opt/production
docker compose pull
docker compose up -d

# Gerar APP_KEY
docker compose exec app php artisan key:generate

# Rodar migrations
docker compose exec app php artisan migrate --force
```

### 7. Configurar DNS

Adicione os registros no seu provedor de DNS:

| Tipo | Nome | Valor |
|------|------|-------|
| A | @ | IP_DA_VPS |
| A | * | IP_DA_VPS |
| A | traefik | IP_DA_VPS |

Aguarde propagação (pode levar até 24h).

## 📁 Estrutura de Diretórios

```
/opt/
├── production/
│   ├── .env                    # Arquivo de ambiente
│   ├── docker-compose.yml      # Docker Compose
│   ├── backups/                # Backups automáticos
│   └── storage/                # Storage local (se necessário)
└── traefik/
    ├── docker-compose.yml      # Traefik
    ├── .env                    # Configuração Traefik
    └── letsencrypt/
        └── acme.json           # Certificados SSL
```

## 🔧 Comandos Úteis

### Ver status dos containers
```bash
cd /opt/production
docker compose ps
docker compose logs -f app
docker compose logs -f queue
```

### Reiniciar aplicação
```bash
cd /opt/production
docker compose restart app
```

### Rodar comando no container
```bash
cd /opt/production
docker compose exec app php artisan tinker
docker compose exec app php artisan migrate
```

### Ver logs do Traefik
```bash
cd /opt/traefik
docker compose logs -f
```

### Acessar MySQL local
```bash
mysql -u root -p
# Senha está em /root/.credentials
```

### Backup do banco
```bash
# Ver credenciais primeiro
cat /opt/production/.env | grep DB_

# Fazer backup
mysqldump -u DB_USER -p DB_NAME > /opt/production/backups/backup-$(date +%Y%m%d).sql
```

### Limpar containers antigos
```bash
cd /opt/production
docker compose down
docker system prune -a
docker compose up -d
```

## 🔐 Segurança

### Usuários
- **root**: Usar apenas para setup inicial
- **deploy**: Usar para deployments e operações diárias
- MySQL: Usuário específico criado para a aplicação

### Firewall (UFW)
Portas abertas:
- 22 (SSH)
- 80 (HTTP - redireciona para HTTPS)
- 443 (HTTPS)
- 3306 (MySQL - apenas localhost)

### SSL/TLS
- Certificados gerados automaticamente via Let's Encrypt
- Renovação automática pelo Traefik
- Redirecionamento HTTP → HTTPS forçado

## 🎯 Traefik Dashboard

Acesse: `https://traefik.seudominio.com.br`

Credenciais:
- **Usuário**: admin
- **Senha**: admin123 (altere gerando novo hash)

Para gerar novo hash de senha:
```bash
echo $(htpasswd -nb admin nova_senha) | sed -e s/\\$/\\$\\$/g
```

Substitua no `/opt/traefik/docker-compose.yml` na linha:
```yaml
- "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:HASH_AQUI"
```

## 🐛 Troubleshooting

### Container não inicia
```bash
docker compose logs app
docker compose logs queue
```

### Erro de conexão com MySQL
Verifique se está usando o IP correto no `.env`:
```bash
# Ver IP da máquina
hostname -I

# No .env deve ter:
DB_HOST=IP_DA_MAQUINA
# ou
DB_HOST=host.docker.internal
```

### SSL não funciona
```bash
# Ver logs do Traefik
cd /opt/traefik
docker compose logs traefik | grep -i error

# Verificar se DNS está propagado
dig seudominio.com.br
```

### Filas não processam
```bash
# Ver status do Horizon
docker compose exec app php artisan horizon:status

# Reiniciar worker
docker compose restart queue
```

## 📚 Mais Informações

### Horizon
Acesse: `https://seudominio.com.br/horizon`

### Health Check
Acesse: `https://seudominio.com.br/up`

### Logs da aplicação
```bash
docker compose exec app tail -f storage/logs/laravel.log
```

## 🔄 Atualização da Aplicação

Novo código via GitHub Actions (automático) ou manual:

```bash
cd /opt/production
docker compose pull
docker compose up -d
docker compose exec app php artisan migrate --force
docker compose exec app php artisan optimize:clear
```

## 📞 Suporte

Se tiver problemas, verifique:
1. Logs dos containers: `docker compose logs`
2. Status dos containers: `docker compose ps`
3. Logs do Traefik: `cd /opt/traefik && docker compose logs`
4. Status do MySQL: `systemctl status mysql`
5. Firewall: `ufw status`
