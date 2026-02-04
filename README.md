# 🚀 VPS Deployment Package

Pacote para deploy de aplicações Laravel em VPS com Docker, Traefik e GitHub Actions.

## 📦 Uso

### 1. Instalar no Projeto Laravel

```bash
bash install.sh /caminho/do/seu-projeto-laravel
```

Copia: `Dockerfile`, `docker-compose.staging.yml`, `traefik-docker-compose.yml`, workflows e helper.sh

### 2. Configurar VPS

Copie os scripts para a VPS e execute:

```bash
scp scripts/setup-*.sh user@vps:/root/
ssh user@vps
bash setup-vps-new.sh        # Configura Docker, Traefik, usuários
bash setup-postgres.sh       # ou setup-mysql.sh
```

## 📁 Estrutura

```
vps-deployment-package/
├── install.sh                              # Instala arquivos no projeto Laravel
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.staging.yml
│   └── traefik-docker-compose.yml
├── scripts/
│   ├── setup-vps-new.sh                    # Setup completo da VPS
│   ├── setup-mysql.sh                      # Configuração MySQL
│   ├── setup-postgres.sh                   # Configuração PostgreSQL
│   ├── helper.sh                           # Comandos úteis
│   └── (outros scripts auxiliares)
└── github-workflows/
    ├── build-and-push.yml
    └── deploy-staging.yml
```

## 🛠️ Scripts Principais

- **install.sh**: Copia arquivos para projeto Laravel
- **setup-vps-new.sh**: Instala Docker, Traefik, configura usuários e firewall
- **setup-postgres.sh**: PostgreSQL standalone, Docker ou cluster com replicação
- **setup-mysql.sh**: MySQL standalone ou Docker
- **helper.sh**: Logs, restart, shell, artisan, backup/restore

## ⚙️ Configuração

Após executar `install.sh`, edite no seu projeto:

1. **docker-compose.staging.yml**: Seus domínios e configurações
2. **GitHub Secrets**: `GHCR_TOKEN`, `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`
3. **.env**: Variáveis do projeto (DB, Redis, etc.)

Pronto para deploy! 🚀
