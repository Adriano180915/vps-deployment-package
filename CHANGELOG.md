# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [1.0.0] - 2026-02-04

### Adicionado
- 🐳 **Dockerfile** otimizado para Laravel com PHP 8.4 + Nginx
- 🌐 **Traefik** reverse proxy com SSL automático via Let's Encrypt
- 🗄️ **Setup PostgreSQL** com opções: standalone, Docker, ou cluster com replicação
- 🗄️ **Setup MySQL** com opções: standalone ou Docker
- 🚀 **GitHub Actions** workflows para build e deploy automático
- 📦 **Docker Compose** configuração completa para staging
- 🔧 **Scripts de gerenciamento** (helper.sh) com comandos úteis
- 📚 **Documentação completa**:
  - README.md - Visão geral e quick start
  - SETUP-GUIDE.md - Guia passo a passo detalhado
  - TROUBLESHOOTING.md - Resolução de problemas
- 🔒 **Segurança**:
  - Geração automática de senhas fortes
  - Configuração de firewall (UFW)
  - SSL/TLS automático
  - Usuário não-root para deploy
- 🎛️ **Monitoramento**:
  - Health checks configurados
  - Resource limits apropriados
  - Logging configurado
- 📡 **WebSockets** via Laravel Reverb integrado
- 🔄 **Multi-tenancy** support com subdomínios
- 💾 **Backup scripts** automatizados
- ⚙️ **Configuração de ambiente** (.env.example)
- 📜 **Licença MIT**
- 🔀 **Script de inicialização Git** (init-repo.sh)

### Recursos Principais

#### Docker & Containers
- Imagem otimizada com multi-stage build
- Supervisor gerenciando PHP-FPM, Nginx e Reverb
- Health checks e resource limits
- Networks isoladas por ambiente

#### Traefik
- Auto-discovery de containers
- SSL automático com renovação
- Suporte a múltiplos domínios e wildcards
- Dashboard com autenticação
- HTTP → HTTPS redirect automático

#### Banco de Dados
- Scripts para PostgreSQL e MySQL
- Opção de replicação PostgreSQL (1 primário + 2 réplicas)
- Credenciais geradas automaticamente
- Configuração otimizada para performance

#### CI/CD
- Build automático no push
- Deploy automático após build
- Migrations automáticas
- Cache otimizado para builds rápidos
- Suporte a staging e production

#### Scripts de Gerenciamento
- Logs em tempo real
- Shell interativo
- Comandos artisan remotos
- Backup e restore de banco
- Status dos containers

### Casos de Uso
- ✅ Deploy de aplicações Laravel em VPS
- ✅ Ambientes staging + production isolados
- ✅ Multi-tenancy com subdomínios dinâmicos
- ✅ WebSockets com Laravel Reverb
- ✅ Alta disponibilidade com replicação
- ✅ CI/CD via GitHub Actions

### Requisitos
- Ubuntu 22.04 ou 24.04 LTS
- Mínimo 2GB RAM (recomendado 4GB+)
- Docker e Docker Compose
- Domínio configurável
- GitHub Container Registry

### Documentação
- Guia completo de setup passo a passo
- Troubleshooting com soluções para problemas comuns
- Exemplos de configuração
- Comandos úteis para operação diária

---

## [Unreleased]

### Planejado para próximas versões
- [ ] Suporte para mais provedores cloud (AWS, Azure, GCP)
- [ ] Scripts de backup para S3/Spaces
- [ ] Monitoring com Prometheus + Grafana
- [ ] Alertas via Telegram/Slack
- [ ] Failover automático para PostgreSQL
- [ ] Load balancing com múltiplas instâncias
- [ ] Scripts de rollback automático
- [ ] Testes automatizados dos scripts
- [ ] Suporte para Redis Sentinel
- [ ] CDN integration (Cloudflare)

---

## Guia de Versionamento

### Versão Major (X.0.0)
- Mudanças incompatíveis com versões anteriores
- Refatoração significativa
- Mudança de arquitetura

### Versão Minor (x.X.0)
- Novos recursos compatíveis
- Melhorias significativas
- Novas integrações

### Versão Patch (x.x.X)
- Correções de bugs
- Pequenas melhorias
- Atualizações de documentação

---

## Como Contribuir

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

---

## Suporte

Para reportar bugs, sugerir features ou tirar dúvidas:
- Abra uma [issue](https://github.com/seu-usuario/vps-deployment-package/issues)
- Consulte a [documentação](README.md)
- Verifique o [troubleshooting](TROUBLESHOOTING.md)

---

**Desenvolvido para Plannerate - Planogram Editor Application**
