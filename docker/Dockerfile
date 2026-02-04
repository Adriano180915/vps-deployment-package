# ============================================
# DOCKERFILE PRODUCTION - Laravel + Nginx
# Versão otimizada com build args para Vite
# ============================================

FROM php:8.4-fpm-alpine

# Argumentos
ARG USER_ID=1000
ARG GROUP_ID=1000

# Argumentos para build do Vite
ARG VITE_REVERB_APP_KEY
ARG VITE_REVERB_HOST
ARG VITE_REVERB_PORT=443
ARG VITE_REVERB_SCHEME=https

WORKDIR /var/www

# Garantir que shell está disponível primeiro
RUN apk add --no-cache bash

# Instalar dependências do sistema e extensões PHP em uma única camada
RUN apk update && apk add --no-cache \
    # Ferramentas básicas
    curl \
    git \
    unzip \
    zip \
    supervisor \
    nginx \
    nodejs \
    npm \
    # PostgreSQL
    postgresql-client \
    postgresql-dev \
    # MySQL (para conexão ao banco legado)
    mariadb-connector-c-dev \
    # Redis
    redis \
    # Bibliotecas para GD
    freetype \
    freetype-dev \
    libjpeg-turbo \
    libjpeg-turbo-dev \
    libpng \
    libpng-dev \
    libwebp \
    libwebp-dev \
    # Bibliotecas para ZIP
    libzip \
    libzip-dev \
    # Outras bibliotecas
    oniguruma-dev \
    libxml2-dev \
    icu-dev \
    icu-data-full \
    # Build tools
    autoconf \
    g++ \
    make \
    linux-headers \
    && docker-php-ext-configure gd \
        --with-freetype=/usr/include/ \
        --with-jpeg=/usr/include/ \
        --with-webp=/usr/include/ \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql \
        pgsql \
        pdo_mysql \
        zip \
        gd \
        mbstring \
        xml \
        bcmath \
        intl \
        opcache \
        pcntl \
        sockets \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del --purge \
        autoconf \
        g++ \
        make \
        linux-headers \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
        postgresql-dev \
        oniguruma-dev \
        mariadb-connector-c-dev \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Instalar Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Criar usuário não-root
RUN addgroup -g ${GROUP_ID} laravel \
    && adduser -D -u ${USER_ID} -G laravel laravel \
    && mkdir -p /var/www /var/log/supervisor \
    && chown -R laravel:laravel /var/www /var/log/supervisor

# Copiar código da aplicação
COPY --chown=laravel:laravel . .

# Instalar dependências do Composer
USER laravel
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader

# Criar diretórios necessários (incluindo database)
RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache \
    public/build \
    database

# Criar arquivo database.sqlite se não existir (para evitar erros)
RUN touch database/database.sqlite || true

# Garantir permissões corretas para o diretório de build
RUN chown -R laravel:laravel /var/www/public/build \
    && chmod -R 775 /var/www/public/build

# Gerar rotas do Wayfinder antes do build (tolerante a falhas)
# Se falhar, o build continua - wayfinder pode ser gerado depois ou durante runtime
RUN php artisan wayfinder:generate --with-form --no-interaction 2>&1 || (echo "⚠️  Wayfinder generation failed, continuing build..." && true)

# Instalar dependências NPM e buildar assets com variáveis VITE
RUN npm ci --production=false \
    && VITE_REVERB_APP_KEY=${VITE_REVERB_APP_KEY} \
       VITE_REVERB_HOST=${VITE_REVERB_HOST} \
       VITE_REVERB_PORT=${VITE_REVERB_PORT} \
       VITE_REVERB_SCHEME=${VITE_REVERB_SCHEME} \
       npm run build \
    && rm -rf node_modules

# Voltar para root para configurar serviços
USER root

# Ajustar permissões dos diretórios criados
RUN chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache \
    && chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Configurar PHP-FPM
RUN echo "[www]" > /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "user = www-data" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "group = www-data" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "listen.owner = www-data" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "listen.group = www-data" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "pm = dynamic" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "pm.max_children = 20" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "pm.start_servers = 5" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "pm.min_spare_servers = 5" >> /usr/local/etc/php-fpm.d/zz-docker.conf \
    && echo "pm.max_spare_servers = 10" >> /usr/local/etc/php-fpm.d/zz-docker.conf

# Remover configuração padrão do Nginx e criar configuração Laravel + Reverb
RUN rm -f /etc/nginx/http.d/default.conf && \
    cat > /etc/nginx/http.d/00-reverb-map.conf << 'MAPEOF'
# Map para WebSocket: Connection upgrade quando Upgrade presente
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}
# Repassar proto do Traefik; fallback para $scheme (ex.: dev local)
map $http_x_forwarded_proto $forwarded_proto {
    default $http_x_forwarded_proto;
    ''      $scheme;
}
MAPEOF
RUN cat > /etc/nginx/http.d/laravel.conf << 'NGINXEOF'
server {
    listen 80;
    listen [::]:80;
    server_name _;
    root /var/www/public;
    
    index index.php index.html;
    
    client_max_body_size 50M;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Reverb (WebSocket): mesmo origem, proxy /app para o processo Reverb na porta 8080
    location /app {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $forwarded_proto;
        proxy_buffering off;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_read_timeout 300;
        include fastcgi_params;
    }
    
    location ~ /\.(?!well-known).* {
        deny all;
    }
}
NGINXEOF

# Criar script de inicialização
RUN cat > /usr/local/bin/start.sh << 'EOF'
#!/bin/sh
# Não usar set -e para permitir que o script continue mesmo com falhas não críticas

echo "🚀 Iniciando Plannerate..."

# Ajustar permissões PRIMEIRO (antes de aguardar serviços)
echo "🔧 Configurando permissões..."
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true
chmod -R 775 /var/www/storage /var/www/bootstrap/cache 2>/dev/null || true

# Criar diretórios se não existirem
mkdir -p /var/www/storage/framework/{sessions,views,cache}
mkdir -p /var/www/storage/logs
mkdir -p /var/www/database
chown -R www-data:www-data /var/www/storage /var/www/database
chmod -R 775 /var/www/storage /var/www/database

# Criar arquivo database.sqlite se não existir (para evitar erros)
if [ ! -f /var/www/database/database.sqlite ]; then
  touch /var/www/database/database.sqlite
  chown www-data:www-data /var/www/database/database.sqlite
  chmod 664 /var/www/database/database.sqlite
  echo "✅ Arquivo database.sqlite criado"
fi

# Aguardar PostgreSQL (se configurado, mas não bloquear se falhar)
if [ -n "${DB_HOST}" ] && [ "${DB_HOST}" != "postgres" ]; then
  echo "⏳ Aguardando PostgreSQL em ${DB_HOST}..."
  POSTGRES_READY=false
  for i in $(seq 1 10); do
    if pg_isready -h ${DB_HOST} -p ${DB_PORT:-5432} -U ${DB_USERNAME:-laravel} > /dev/null 2>&1; then
      echo "✅ PostgreSQL pronto!"
      POSTGRES_READY=true
      break
    fi
    [ $i -lt 10 ] && echo "PostgreSQL não está pronto - tentativa $i/10" && sleep 2
  done
  if [ "$POSTGRES_READY" = "false" ]; then
    echo "⚠️  PostgreSQL não está acessível, mas continuando (servidor externo pode estar indisponível)..."
  fi
else
  echo "ℹ️  PostgreSQL externo configurado ou não verificado, continuando..."
fi

# Aguardar Redis
echo "⏳ Aguardando Redis..."
for i in $(seq 1 30); do
  if redis-cli -h ${REDIS_HOST:-redis} -p ${REDIS_PORT:-6379} ${REDIS_PASSWORD:+-a ${REDIS_PASSWORD}} ping > /dev/null 2>&1; then
    echo "✅ Redis pronto!"
    break
  fi
  echo "Redis não está pronto - tentativa $i/30"
  sleep 2
done

# Limpar caches (em caso de restart)
echo "🧹 Limpando caches antigos..."
php artisan config:clear || true
php artisan cache:clear || true
php artisan view:clear || true

# Ajustar permissões novamente (por segurança)
chown -R www-data:www-data /var/www/storage /var/www/bootstrap/cache
chmod -R 775 /var/www/storage /var/www/bootstrap/cache

echo "✅ Iniciando serviços..."
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
EOF

RUN chmod +x /usr/local/bin/start.sh

# Configurar Supervisor
RUN mkdir -p /etc/supervisor/conf.d \
    && cat > /etc/supervisor/conf.d/supervisord.conf << 'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:php-fpm]
command=php-fpm -F
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
user=root

[program:nginx]
command=nginx -g 'daemon off;'
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
user=root

[program:reverb]
command=php artisan reverb:start --host=0.0.0.0 --port=8080
directory=/var/www
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
user=www-data
EOF

# Expor portas
EXPOSE 80 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/up || exit 1

# Comando de inicialização
CMD ["/usr/local/bin/start.sh"]