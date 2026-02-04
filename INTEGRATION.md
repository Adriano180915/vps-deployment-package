# 🔗 Integração com Projeto Laravel

Guia para integrar o VPS Deployment Package em seu projeto Laravel.

## 📥 Instalação no Projeto

### Opção 1: Git Submodule (Recomendado)

```bash
cd seu-projeto-laravel

# Adicionar como submodule
git submodule add https://github.com/callcocam/vps-deployment-package.git deployment

# Atualizar
git submodule update --init --recursive

# Commit
git add .gitmodules deployment
git commit -m "Add VPS deployment package"
```

**Atualizar o submodule no futuro:**
```bash
cd deployment
git pull origin main
cd ..
git add deployment
git commit -m "Update deployment package"
```

### Opção 2: Clonar Diretamente

```bash
cd seu-projeto-laravel

# Clonar para subpasta
git clone https://github.com/callcocam/vps-deployment-package.git deployment

# Remover git do clone (para não ter repo dentro de repo)
rm -rf deployment/.git

# Adicionar ao git do projeto
git add deployment
git commit -m "Add VPS deployment scripts"
```

### Opção 3: Copiar Arquivos Necessários

```bash
cd seu-projeto-laravel

# Criar estrutura
mkdir -p deployment/{scripts,config}

# Baixar e copiar apenas os arquivos necessários
curl -o deployment/scripts/setup-vps-new.sh https://raw.githubusercontent.com/callcocam/vps-deployment-package/main/scripts/setup-vps-new.sh
curl -o deployment/scripts/setup-postgres.sh https://raw.githubusercontent.com/callcocam/vps-deployment-package/main/scripts/setup-postgres.sh
curl -o deployment/scripts/helper.sh https://raw.githubusercontent.com/callcocam/vps-deployment-package/main/scripts/helper.sh

# Tornar executáveis
chmod +x deployment/scripts/*.sh

# Commit
git add deployment
git commit -m "Add deployment scripts"
```

## 📁 Estrutura Final do Projeto

```
seu-projeto-laravel/
├── app/
├── config/
├── database/
├── resources/
├── routes/
├── .github/
│   └── workflows/
│       ├── deploy-staging.yml     # ← Do pacote
│       └── build-and-push.yml     # ← Do pacote
├── deployment/                     # ← Pacote VPS
│   ├── scripts/
│   │   ├── setup-vps-new.sh
│   │   ├── setup-postgres.sh
│   │   ├── setup-mysql.sh
│   │   └── helper.sh
│   ├── docs/
│   │   ├── SETUP-GUIDE.md
│   │   └── TROUBLESHOOTING.md
│   └── README.md
├── docker-compose.staging.yml      # ← Adaptar do pacote
├── docker-compose.production.yml   # ← Adaptar do pacote
├── Dockerfile                      # ← Do pacote
└── .env.example
```

## 🔧 Configuração no Projeto

### 1. Copiar Arquivos Docker

```bash
cd seu-projeto-laravel

# Copiar Dockerfile (se não tiver)
cp deployment/docker/Dockerfile .

# Copiar docker-compose files
cp deployment/docker/docker-compose.staging.yml .

# Ajustar se necessário
vim docker-compose.staging.yml
```

### 2. Copiar GitHub Workflows

```bash
# Copiar workflows
mkdir -p .github/workflows
cp deployment/github-workflows/*.yml .github/workflows/

# Editar e ajustar para seu projeto
vim .github/workflows/deploy-staging.yml
# Alterar: nomes de containers, domínios, etc.
```

### 3. Atualizar .gitignore

Adicionar ao `.gitignore` do projeto:

```gitignore
# Deployment - arquivos locais
deployment/.env*
deployment/*.credentials
deployment/backups/
```

### 4. Criar Configuração Local

```bash
# Copiar exemplo de .env
cp deployment/config/.env.example .env.staging

# Editar com suas configurações
vim .env.staging
```

## 🚀 Workflow de Uso

### 1️⃣ Desenvolvimento Local

```bash
# Trabalhar normalmente no projeto
./vendor/bin/sail up
./vendor/bin/sail artisan migrate
```

### 2️⃣ Preparar VPS

**Uma única vez por servidor:**

```bash
# SSH na VPS
ssh root@seu-servidor.com

# Fazer upload do deployment
scp -r deployment root@seu-servidor.com:/opt/vps-deployment

# Executar setup
cd /opt/vps-deployment
chmod +x scripts/*.sh
sudo bash scripts/setup-vps-new.sh

# Configurar banco
sudo bash scripts/setup-postgres.sh
```

### 3️⃣ Configurar Projeto na VPS

```bash
# Na VPS
mkdir -p /opt/seu-projeto/staging

# Do seu computador, copiar arquivos
scp docker-compose.staging.yml root@seu-servidor.com:/opt/seu-projeto/staging/
scp .env.staging root@seu-servidor.com:/opt/seu-projeto/staging/.env
```

### 4️⃣ Deploy via GitHub Actions

```bash
# Configurar secrets no GitHub (uma vez)
# - VPS_HOST
# - VPS_USER
# - VPS_SSH_KEY
# etc.

# Deploy automático ao fazer push
git push origin dev  # Staging
git push origin main # Production
```

### 5️⃣ Gerenciar com Helper Script

```bash
# Copiar helper para VPS
scp deployment/scripts/helper.sh seu-usuario@seu-servidor.com:/usr/local/bin/

# Usar na VPS
helper.sh logs staging
helper.sh restart staging
helper.sh artisan staging migrate
```

## 📝 Customização

### Ajustar Dockerfile

Se seu projeto precisa de extensões específicas:

```dockerfile
# No Dockerfile do projeto
# Adicionar após as instalações padrão

# Sua extensão customizada
RUN pecl install mongodb \
    && docker-php-ext-enable mongodb
```

### Ajustar docker-compose.yml

Personalizar para seu projeto:

```yaml
services:
  app:
    image: ghcr.io/seu-usuario/seu-projeto:dev
    container_name: seu-projeto-app-staging
    
    labels:
      - "traefik.http.routers.staging-app.rule=Host(`seu-dominio.com`)"
      # ...
```

### Variáveis de Ambiente

Criar `.env.staging` com suas configurações:

```env
APP_NAME="Seu Projeto Staging"
APP_URL=https://staging.seu-dominio.com
DB_DATABASE=seu_projeto_staging
# ...
```

## 🔄 Atualização do Pacote

### Se usar Git Submodule:

```bash
cd seu-projeto-laravel/deployment
git pull origin main
cd ..
git add deployment
git commit -m "Update deployment package to latest version"
```

### Se copiar arquivos:

```bash
# Baixar nova versão
cd /tmp
git clone https://github.com/callcocam/vps-deployment-package.git
cd vps-deployment-package

# Copiar atualizações
cp scripts/* /caminho/seu-projeto/deployment/scripts/
cp docs/* /caminho/seu-projeto/deployment/docs/

# Commit no projeto
cd /caminho/seu-projeto
git add deployment
git commit -m "Update deployment scripts"
```

## 📚 Documentação no Projeto

Criar `README.md` ou `docs/DEPLOYMENT.md` no seu projeto:

```markdown
# Deployment

Este projeto usa o [VPS Deployment Package](https://github.com/callcocam/vps-deployment-package).

## Setup Rápido

1. Configurar VPS:
   ```bash
   cd deployment
   ./scripts/setup-vps-new.sh
   ```

2. Deploy:
   ```bash
   git push origin dev
   ```

Ver documentação completa em `deployment/docs/`.
```

## ✅ Checklist de Integração

- [ ] Pacote adicionado ao projeto (submodule ou cópia)
- [ ] Dockerfile copiado e ajustado
- [ ] docker-compose files copiados e personalizados
- [ ] GitHub workflows copiados e configurados
- [ ] .env.staging criado com configurações
- [ ] .gitignore atualizado
- [ ] VPS configurada com scripts do pacote
- [ ] GitHub secrets configurados
- [ ] Deploy testado e funcionando
- [ ] Documentação de deployment criada no projeto

## 💡 Dicas

### Multi-Projeto

Se gerenciar múltiplos projetos Laravel:

```bash
# Cada projeto tem sua cópia do pacote
projetos/
├── projeto-a/
│   └── deployment/
├── projeto-b/
│   └── deployment/
└── projeto-c/
    └── deployment/
```

### Mesma VPS, Múltiplos Projetos

```bash
# Na VPS
/opt/
├── traefik/              # Compartilhado
├── postgres/             # Compartilhado
├── projeto-a/
│   ├── staging/
│   └── production/
└── projeto-b/
    ├── staging/
    └── production/
```

Cada projeto usa as mesmas ferramentas (Traefik, banco) mas tem seus próprios containers.

## 🆘 Suporte

- Documentação completa: `deployment/docs/`
- Troubleshooting: `deployment/docs/TROUBLESHOOTING.md`
- Issues: https://github.com/callcocam/vps-deployment-package/issues

---

**Agora seu projeto Laravel está pronto para deploy automatizado!** 🚀
