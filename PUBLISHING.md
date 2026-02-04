# 📤 Como Publicar no GitHub

Este guia mostra como publicar o VPS Deployment Package no GitHub.

## 1️⃣ Criar Repositório no GitHub

### Via Web Interface

1. Acessar [github.com/new](https://github.com/new)
2. Preencher:
   - **Repository name**: `vps-deployment-package` (ou outro nome)
   - **Description**: `Complete VPS deployment package for Laravel apps with Docker, Traefik, and CI/CD`
   - **Visibility**: Public ou Private
   - ⚠️ **NÃO** marcar "Initialize repository with README"
   - ⚠️ **NÃO** adicionar .gitignore ou license (já temos)
3. Clicar em "Create repository"

### Via GitHub CLI

```bash
# Instalar gh (se necessário)
sudo apt install gh

# Login
gh auth login

# Criar repositório
gh repo create vps-deployment-package --public --description "Complete VPS deployment package for Laravel apps"
```

## 2️⃣ Conectar Repositório Local ao GitHub

No diretório `vps-deployment-package`:

```bash
# Renomear branch para main (se necessário)
git branch -M main

# Adicionar remote
git remote add origin git@github.com:SEU_USUARIO/vps-deployment-package.git

# Ou com HTTPS
git remote add origin https://github.com/SEU_USUARIO/vps-deployment-package.git

# Verificar
git remote -v
```

## 3️⃣ Push Inicial

```bash
# Push com upstream tracking
git push -u origin main

# Verificar
git log --oneline
```

## 4️⃣ Configurar Repositório no GitHub

### Topics (Tags)

Adicionar topics para facilitar descoberta:

```
docker, laravel, deployment, devops, vps, traefik, github-actions, 
automation, postgresql, mysql, ci-cd, infrastructure, docker-compose
```

No GitHub:
- Settings → Topics → Add topics

### About

Editar a descrição:

```
Complete VPS deployment package for Laravel applications with Docker, 
Traefik reverse proxy, SSL automation, database setup scripts, and 
GitHub Actions CI/CD workflows.
```

### README Badges

Adicionar ao topo do README.md:

```markdown
![License](https://img.shields.io/github/license/SEU_USUARIO/vps-deployment-package)
![GitHub release](https://img.shields.io/github/v/release/SEU_USUARIO/vps-deployment-package)
![GitHub stars](https://img.shields.io/github/stars/SEU_USUARIO/vps-deployment-package)
```

### Wiki (Opcional)

Criar páginas wiki para:
- Guia de contribuição
- Casos de uso detalhados
- FAQ

## 5️⃣ Criar Release v1.0.0

### Via GitHub Web

1. Ir em "Releases" → "Create a new release"
2. Preencher:
   - **Tag**: `v1.0.0`
   - **Release title**: `v1.0.0 - Initial Release`
   - **Description**: Copiar do CHANGELOG.md
3. Marcar "Set as the latest release"
4. Clicar em "Publish release"

### Via GitHub CLI

```bash
gh release create v1.0.0 \
  --title "v1.0.0 - Initial Release" \
  --notes "Complete VPS deployment package with Docker, Traefik, database setup, and CI/CD workflows."
```

### Via Git Tag

```bash
# Criar tag anotada
git tag -a v1.0.0 -m "v1.0.0 - Initial Release"

# Push tag
git push origin v1.0.0

# Push todas tags
git push origin --tags
```

## 6️⃣ Configurar Branch Protection (Recomendado)

Settings → Branches → Add rule:

- **Branch name pattern**: `main`
- ✅ Require pull request reviews before merging
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Include administrators

## 7️⃣ Criar README para Seu Projeto

No seu projeto Laravel que vai usar este pacote, referenciar:

```markdown
## Deployment

Este projeto usa o [VPS Deployment Package](https://github.com/SEU_USUARIO/vps-deployment-package) 
para deployment automatizado em VPS.

### Setup Rápido

```bash
# Clonar pacote de deployment
git clone https://github.com/SEU_USUARIO/vps-deployment-package.git

# Seguir instruções do README
cd vps-deployment-package
```

Ver [documentação completa](https://github.com/SEU_USUARIO/vps-deployment-package).
```

## 8️⃣ Opcional: GitHub Pages

Criar documentação estática:

```bash
# Criar branch gh-pages
git checkout --orphan gh-pages

# Copiar docs
mkdir docs
cp README.md docs/index.md
cp SETUP-GUIDE.md docs/
cp TROUBLESHOOTING.md docs/
cp QUICK-REFERENCE.md docs/

# Commit e push
git add docs
git commit -m "Add GitHub Pages documentation"
git push origin gh-pages

# No GitHub
# Settings → Pages → Source: gh-pages branch → /docs
```

## 9️⃣ Compartilhar

### Comunidades

Compartilhar em:
- [Laravel News](https://laravel-news.com/)
- [dev.to](https://dev.to/)
- [Reddit r/laravel](https://reddit.com/r/laravel)
- [Reddit r/devops](https://reddit.com/r/devops)
- Twitter/X com hashtags: #Laravel #Docker #DevOps

### Template de Postagem

```markdown
🚀 VPS Deployment Package for Laravel

I created a complete deployment package for Laravel apps with:

✅ Docker & Traefik setup
✅ Automatic SSL with Let's Encrypt
✅ PostgreSQL/MySQL setup scripts
✅ GitHub Actions CI/CD workflows
✅ Complete documentation

Perfect for deploying Laravel apps to any VPS!

Check it out: https://github.com/SEU_USUARIO/vps-deployment-package

#Laravel #Docker #DevOps #Deployment
```

## 🔟 Manutenção

### Atualizar Versão

```bash
# Fazer mudanças
git add .
git commit -m "feat: add new feature"

# Atualizar CHANGELOG.md

# Criar nova tag
git tag -a v1.1.0 -m "v1.1.0 - Added new features"

# Push
git push origin main
git push origin v1.1.0

# Criar release no GitHub
gh release create v1.1.0 --generate-notes
```

### Issues e Pull Requests

- Responder issues em 24-48h
- Revisar PRs semanalmente
- Manter labels organizados
- Usar milestones para próximas versões

### Dependências

- Atualizar Docker images regularmente
- Testar com novas versões do Laravel
- Manter documentação atualizada

## ✅ Checklist de Publicação

- [ ] Repositório criado no GitHub
- [ ] Remote configurado e push realizado
- [ ] README.md completo e claro
- [ ] LICENSE presente
- [ ] .gitignore configurado
- [ ] Topics adicionados
- [ ] Descrição configurada
- [ ] Release v1.0.0 criada
- [ ] Branch protection configurado (opcional)
- [ ] README badges adicionados (opcional)
- [ ] GitHub Pages configurado (opcional)
- [ ] Compartilhado em comunidades (opcional)

## 🎉 Pronto!

Seu pacote está publicado e pronto para ser usado pela comunidade!

**URL do repositório:**
```
https://github.com/SEU_USUARIO/vps-deployment-package
```

**Para clonar:**
```bash
git clone https://github.com/SEU_USUARIO/vps-deployment-package.git
```

---

**Dúvidas?** Consulte [GitHub Docs](https://docs.github.com/)
