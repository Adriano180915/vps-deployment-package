# 🚀 Plannerate VPS Deployment Package

Pacote completo para configuração e deploy de aplicações Laravel em VPS com Docker, Traefik e CI/CD via GitHub Actions.

## 📦 Conteúdo do Pacote

```
vps-deployment-package/
├── docker/
│   ├── Dockerfile                          # Imagem Docker production-ready
│   ├── docker-compose.staging.yml          # Compose para ambiente de staging
│   └── traefik-docker-compose.yml          # Traefik reverse proxy
├── scripts/
│   ├── setup-vps-new.sh                    # Script principal de setup da VPS
│   ├── setup-vps.sh                        # Script alternativo de setup
│   ├── setup-mysql.sh                      # Configuração de MySQL
│   ├── setup-postgres.sh                   # Configuração de PostgreSQL
│   ├── helper.sh                           # Comandos úteis para gerenciamento
│   └── fix-traefik-api.sh                  # Fix para problemas do Traefik
├── github-workflows/
│   ├── build-and-push.yml                  # Workflow para build de imagens
│   └── deploy-staging.yml                  # Workflow para deploy automático
├── config/
│   └── (arquivos de configuração adicionais)
├── README.md                               # Este arquivo
├── SETUP-GUIDE.md                          # Guia completo de setup
├── TROUBLESHOOTING.md                      # Guia de resolução de problemas
└── .gitignore                              # Arquivos a serem ignorados
```

## ✨ Recursos

### 🐳 Docker & Containers
- **Dockerfile otimizado** com multi-stage build
- **PHP 8.4 + Nginx** em container único
- **Supervisor** para gerenciar múltiplos processos
- **Laravel Reverb** integrado para WebSockets
- **Health checks** configurados
- **Resource limits** apropriados

### 🌐 Traefik Reverse Proxy
- **SSL automático** via Let's Encrypt
- **HTTP → HTTPS redirect** automático
- **Multi-domain support** (wildcards)
- **Dashboard** com autenticação
- **Docker provider** com auto-discovery

### 🗄️ Banco de Dados
- Scripts para **MySQL** (standalone ou Docker)
- Scripts para **PostgreSQL** (standalone, Docker ou cluster com replicação)
- **Credenciais geradas automaticamente**
- **Backups e restore** facilitados

### 🚀 CI/CD
- **GitHub Actions** workflows prontos
- **Build automático** de imagens Docker
- **Deploy automático** em staging/production
- **Migrations** automáticas após deploy
- **Cache optimization** para builds rápidos

### 🛠️ Ferramentas de Gerenciamento
- Script **helper.sh** com comandos úteis
- **Logs** em tempo real
- **Shell** interativo nos containers
- **Artisan** commands remotos
- **Backup e restore** de databases

## 🎯 Casos de Uso

Este pacote é ideal para:

✅ Deploy de aplicações Laravel em VPS
✅ Ambientes staging + production separados
✅ Multi-tenancy com subdomínios
✅ WebSockets com Laravel Reverb
✅ Alta disponibilidade com replicação de banco
✅ CI/CD automatizado via GitHub Actions
✅ SSL automático e gerenciamento de domínios

## 📋 Requisitos

### Servidor VPS
- **SO**: Ubuntu 22.04 ou 24.04 LTS (recomendado)
- **RAM**: Mínimo 2GB, recomendado 4GB+
- **CPU**: Mínimo 2 cores
- **Disco**: 20GB+ de espaço livre
- **Portas**: 80, 443, 22 abertas

### Conhecimentos Necessários
- Básico de Linux/bash
- Básico de Docker
- Acesso SSH à VPS
- Conhecimento de DNS para configurar domínios

### Ferramentas Externas
- Conta no **GitHub** (para workflows)
- **GitHub Container Registry** (GHCR) configurado
- Domínio próprio configurável
- Gerenciador de senhas (recomendado)

## 🚀 Quick Start

### 1. Preparar a VPS

```bash
# Conectar via SSH
ssh root@seu-servidor.com

# Fazer upload do pacote
scp -r vps-deployment-package root@seu-servidor.com:/opt/

# Acessar o servidor
cd /opt/vps-deployment-package
```

### 2. Executar Setup Completo

```bash
# Tornar scripts executáveis
chmod +x scripts/*.sh

# Executar setup principal (instala Docker, Traefik, estrutura, etc.)
sudo bash scripts/setup-vps-new.sh
```

Este script irá:
- ✅ Instalar Docker e Docker Compose
- ✅ Criar usuário não-root para deploy
- ✅ Configurar Traefik com SSL automático
- ✅ Criar estrutura de diretórios
- ✅ Gerar senhas e chaves de segurança
- ✅ Configurar firewall (UFW)
- ✅ Criar templates de .env

### 3. Configurar Banco de Dados

Escolha MySQL ou PostgreSQL (ou ambos):

```bash
# Para MySQL
sudo bash scripts/setup-mysql.sh

# Para PostgreSQL (recomendado)
sudo bash scripts/setup-postgres.sh
```

### 4. Copiar Arquivos Docker para Projeto

```bash
# Copiar para o diretório do projeto
cp docker/docker-compose.staging.yml /opt/plannerate/staging/
cp docker/Dockerfile /opt/plannerate/staging/

# Ajustar permissões
chown -R plannerate:plannerate /opt/plannerate/staging/
```

### 5. Configurar GitHub Workflows

```bash
# Copiar workflows para o repositório
cp github-workflows/*.yml /caminho/do/seu/repo/.github/workflows/

# Configurar secrets no GitHub:
# - VPS_HOST
# - VPS_USER  
# - VPS_SSH_KEY
# - GITHUB_TOKEN (gerado automaticamente)
```

### 6. Configurar DNS

Adicionar registros DNS:

```
A     @                        -> IP_DA_VPS
A     *                        -> IP_DA_VPS
A     staging.seudominio.com   -> IP_DA_VPS
A     *.staging.seudominio.com -> IP_DA_VPS
```

### 7. Deploy Inicial

```bash
# Push para branch dev (staging) ou main (production)
git push origin dev

# O GitHub Actions fará:
# 1. Build da imagem Docker
# 2. Push para GHCR
# 3. Deploy na VPS
# 4. Run migrations
# 5. Clear cache
```

## 📚 Documentação Completa

- [**SETUP-GUIDE.md**](SETUP-GUIDE.md) - Guia completo passo a passo
- [**TROUBLESHOOTING.md**](TROUBLESHOOTING.md) - Resolução de problemas comuns
- **Scripts individuais** - Cada script tem documentação inline

## 🛠️ Comandos Úteis

O script `helper.sh` fornece atalhos para operações comuns:

```bash
# Ver logs em tempo real
./scripts/helper.sh logs staging

# Reiniciar containers
./scripts/helper.sh restart staging

# Acessar shell do container
./scripts/helper.sh shell staging

# Executar comando artisan
./scripts/helper.sh artisan staging migrate

# Backup do banco
./scripts/helper.sh backup staging

# Ver status dos containers
./scripts/helper.sh status staging
```

## 🔒 Segurança

### Credenciais
- ✅ Senhas geradas automaticamente com alta entropia
- ✅ Arquivos de credenciais com permissões 600 (root only)
- ✅ Recomendação para usar gerenciador de senhas
- ✅ Instruções para deletar arquivos sensíveis após backup

### Firewall
- ✅ UFW configurado automaticamente
- ✅ Apenas portas necessárias abertas (22, 80, 443)
- ✅ Regras específicas para banco de dados (opcional)

### SSL
- ✅ Let's Encrypt automático via Traefik
- ✅ HTTP → HTTPS redirect forçado
- ✅ Certificados renovados automaticamente

### Docker
- ✅ Usuário não-root dentro dos containers
- ✅ Networks isoladas
- ✅ Resource limits configurados
- ✅ Health checks para monitoria

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                    Internet                          │
└────────────────┬────────────────────────────────────┘
                 │ HTTP/HTTPS
                 ▼
┌─────────────────────────────────────────────────────┐
│              Traefik (Reverse Proxy)                 │
│  - SSL/TLS Termination                              │
│  - Routing por domínio                              │
│  - Let's Encrypt automático                         │
└────────────┬──────────────────┬─────────────────────┘
             │                  │
             │                  │
    ┌────────▼─────────┐ ┌─────▼──────────┐
    │   App Staging    │ │ App Production │
    │ (Laravel+Nginx)  │ │ (Laravel+Nginx)│
    │   + Reverb       │ │   + Reverb     │
    └────────┬─────────┘ └─────┬──────────┘
             │                  │
    ┌────────▼─────────┐ ┌─────▼──────────┐
    │  Redis Staging   │ │ Redis Production│
    └──────────────────┘ └─────────────────┘
             │                  │
    ┌────────▼─────────┐ ┌─────▼──────────┐
    │PostgreSQL/MySQL  │ │PostgreSQL/MySQL│
    │   (Staging DB)   │ │  (Production)  │
    └──────────────────┘ └─────────────────┘
```

## 🤝 Suporte Multi-Tenancy

O setup suporta **Laravel Raptor** multi-tenancy out-of-the-box:

- ✅ Subdomínios dinâmicos via wildcard SSL
- ✅ Landlord + Tenant contexts separados
- ✅ Database multi-tenant ou separado
- ✅ Storage isolado por tenant

## 📊 Monitoramento

### Container Health
```bash
# Ver status de todos os containers
docker ps

# Health check de um container específico
docker inspect --format='{{.State.Health.Status}}' plannerate-app-staging
```

### Logs
```bash
# Logs da aplicação
docker logs -f plannerate-app-staging

# Logs do Traefik
cd /opt/traefik && docker compose logs -f

# Logs do banco
docker logs -f postgres-plannerate
```

### Recursos
```bash
# Uso de recursos dos containers
docker stats

# Espaço em disco
df -h
```

## 🔄 Atualizações

### Atualizar a Aplicação
```bash
# Via GitHub Actions (recomendado)
git push origin dev  # Staging
git push origin main # Production

# Manual
cd /opt/plannerate/staging
docker compose pull
docker compose up -d
```

### Atualizar o Traefik
```bash
cd /opt/traefik
docker compose pull
docker compose up -d
```

## 🐛 Troubleshooting

Consulte [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para resolver problemas comuns:

- Erro de SSL/certificado
- Containers não iniciam
- Problemas de conectividade
- Erro de permissões
- Build falha no GitHub Actions
- Migrations não executam

## 📝 Licença

Este pacote é open-source e pode ser usado livremente em projetos pessoais e comerciais.

## 🤝 Contribuições

Contribuições são bem-vindas! Sinta-se à vontade para:
- Reportar bugs
- Sugerir melhorias
- Enviar pull requests
- Compartilhar suas experiências

## 📞 Suporte

Para suporte e dúvidas:
- Abra uma issue no repositório
- Consulte a documentação completa
- Verifique o guia de troubleshooting

---

**Desenvolvido para Plannerate - Planogram Editor Application**

Versão: 1.0.0
Última atualização: 2026-02-04
