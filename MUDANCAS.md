# Mudanças Implementadas - Setup VPS Simplificado

## 📋 Resumo das Alterações

Transformamos o setup multi-ambiente (staging + production) em um setup **simplificado para produção única** com as seguintes mudanças:

## ✅ O que foi ajustado

### 1. **Configuração Dinâmica**
- ❌ Removido: Referências hardcoded a "plannerate"
- ✅ Adicionado: Script solicita nome do projeto, domínio, email e repositório no início
- 📍 Caminho fixo: `/opt/production` (não mais `/opt/plannerate`)

### 2. **Banco de Dados**
- ❌ Removido: PostgreSQL via Docker Compose
- ✅ Adicionado: **MySQL instalado localmente na VPS**
- 🔧 Configuração automática: database, usuário e senhas geradas
- 🌐 Containers conectam via `host.docker.internal` ou IP da máquina
- 🔓 Porta 3306 aberta no firewall para containers Docker

### 3. **Broadcasting**
- ❌ Removido: Reverb (Laravel Reverb)
- ✅ Adicionado: **Pusher configurado via .env**
- 📝 Variáveis de ambiente VITE para Pusher
- 🚫 Sem mais containers de Reverb

### 4. **Ambientes**
- ❌ Removido: Ambiente de staging
- ❌ Removido: Separação de staging/production
- ✅ Mantido: **Apenas produção**
- 📁 Estrutura única em `/opt/production`

### 5. **Usuário Deploy**
- ❌ Removido: Usuário `plannerate`
- ✅ Adicionado: Usuário genérico `deploy`

### 6. **Ferramentas Administrativas**
- ❌ Removido: pgAdmin (era para PostgreSQL)
- ✅ Acesso direto: MySQL via terminal com `mysql -u root -p`

### 7. **Networks Docker**
- ❌ Removido: `plannerate-prod`, `plannerate-staging`
- ✅ Adicionado: `app-network` (genérica)
- ✅ Mantido: `traefik-global` (rede externa do Traefik)

### 8. **Containers**
- ✅ Nomes simplificados: `app-prod`, `queue-prod`, `scheduler-prod`, `redis-prod`
- ✅ Mantido: Laravel Horizon para filas
- ✅ Mantido: Scheduler para cron jobs
- ✅ Adicionado: `extra_hosts` para acesso ao MySQL host

## 📦 Arquivos Criados/Modificados

### Novos Arquivos
1. **`setup-vps-new.sh`** (modificado)
   - Solicita configurações no início
   - Instala MySQL localmente
   - Remove referências a staging
   - Gera credenciais para MySQL e Redis
   - Cria estrutura em `/opt/production`

2. **`docker-compose.production.yml`** (reescrito)
   - Remove PostgreSQL e pgAdmin
   - Remove Reverb
   - Adiciona `extra_hosts` para MySQL local
   - Network renomeada para `app-network`
   - Comentários explicando configuração MySQL local

3. **`README.md`**
   - Documentação completa do setup
   - Instruções passo a passo
   - Troubleshooting
   - Comandos úteis

4. **`deploy.sh`**
   - Script exemplo de deploy manual

5. **`github-workflow-example.yml`**
   - Workflow exemplo para GitHub Actions
   - Build, push e deploy automatizado

6. **`.env.example`**
   - Exemplo de variáveis de ambiente
   - Com explicações de cada seção

## 🎯 Como Usar

### Passo 1: Executar Setup na VPS
```bash
sudo bash setup-vps-new.sh
```

O script vai pedir:
- Nome do projeto
- Domínio
- Email
- GitHub repo

### Passo 2: Copiar docker-compose
```bash
scp scripts/simple-deploy-vps/docker-compose.production.yml \
    deploy@IP_VPS:/opt/production/docker-compose.yml
```

### Passo 3: Configurar .env
Editar `/opt/production/.env` e adicionar credenciais do Pusher e email.

### Passo 4: Deploy
Via GitHub Actions ou manualmente com `deploy.sh`

## 🔐 Segurança

### Credenciais Geradas Automaticamente
- MySQL root password
- MySQL usuário da aplicação
- Redis password
- APP_KEY (após primeiro deploy)

Todas salvas em `/root/.credentials` (deve ser copiado e deletado após)

### Firewall Configurado
- 22 (SSH)
- 80/443 (HTTP/HTTPS via Traefik)
- 3306 (MySQL - apenas localhost)

## 🚀 Estrutura Final

```
/opt/
├── production/
│   ├── .env
│   ├── docker-compose.yml
│   ├── backups/
│   └── storage/
└── traefik/
    ├── docker-compose.yml
    ├── .env
    └── letsencrypt/
        └── acme.json
```

## 🎉 Benefícios

1. **Mais simples**: Sem complexidade de múltiplos ambientes
2. **Mais rápido**: MySQL local é mais rápido que container
3. **Mais flexível**: Nome do projeto configurável
4. **Mais seguro**: Senhas geradas automaticamente
5. **Mais leve**: Menos containers rodando
6. **Mais estável**: MySQL gerenciado pelo systemd
7. **Mais econômico**: Usa Pusher (plano grátis disponível)

## 📝 Próximos Passos

1. Testar o script em uma VPS limpa
2. Configurar DNS apontando para a VPS
3. Configurar credenciais do Pusher
4. Fazer primeiro deploy
5. Gerar APP_KEY
6. Configurar backup automático do MySQL

## ⚠️ Migrações Necessárias

Se você já tem uma aplicação rodando com Reverb:

1. Criar conta no Pusher (plano grátis disponível)
2. Obter credenciais (App ID, Key, Secret, Cluster)
3. Atualizar `.env` com credenciais Pusher
4. Atualizar `config/broadcasting.php` se necessário
5. Deploy da nova versão
