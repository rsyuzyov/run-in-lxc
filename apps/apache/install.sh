#!/bin/bash

#############################################
# Apache Installation Script for LXC
# Установка и настройка Apache HTTP Server
# в LXC контейнере на Debian/Ubuntu
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
DOMAIN=""
EMAIL=""
ENABLE_SSL=false
ENABLE_PHP=false
PHP_VERSION="8.2"
ENABLE_PROXY=false
PROXY_PASS=""
DOCUMENT_ROOT="/var/www/html"
ENABLE_MPM_EVENT=false
ENABLE_HTTP2=false
CREATE_VHOST=false

# Функции для вывода
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Функция помощи
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Установка Apache HTTP Server в LXC контейнер на Debian/Ubuntu.

Опции:
  --domain DOMAIN         Доменное имя для виртуального хоста
  --email EMAIL           Email для SSL сертификата (Let's Encrypt)
  --ssl                   Включить SSL с самоподписанным сертификатом
  --letsencrypt           Получить SSL сертификат от Let's Encrypt (требует --domain и --email)
  --php                   Установить PHP (по умолчанию: PHP-FPM)
  --php-version VERSION   Версия PHP (по умолчанию: 8.2)
  --proxy-pass URL        Настроить обратный прокси на указанный URL
  --document-root PATH    Корневая директория сайта (по умолчанию: /var/www/html)
  --mpm-event             Использовать MPM Event вместо MPM Prefork
  --http2                 Включить HTTP/2 (требует SSL и MPM Event)
  --help                  Показать эту справку

Примеры:
  # Базовая установка Apache
  $0

  # С виртуальным хостом и SSL
  $0 --domain example.com --ssl

  # С Let's Encrypt сертификатом
  $0 --domain example.com --email admin@example.com --letsencrypt

  # С PHP-FPM
  $0 --php

  # С PHP конкретной версии
  $0 --php --php-version 8.3

  # Как обратный прокси
  $0 --domain app.example.com --proxy-pass http://localhost:3000 --ssl

  # Полная установка с HTTP/2
  $0 --domain example.com --ssl --php --mpm-event --http2

Требования к LXC контейнеру:
  - Debian 11/12 или Ubuntu 22.04/24.04
  - 1 ГБ RAM (минимум 512 MB)
  - 1 ядро CPU

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            CREATE_VHOST=true
            shift 2
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --ssl)
            ENABLE_SSL=true
            shift
            ;;
        --letsencrypt)
            ENABLE_SSL=true
            LETSENCRYPT=true
            shift
            ;;
        --php)
            ENABLE_PHP=true
            shift
            ;;
        --php-version)
            PHP_VERSION="$2"
            shift 2
            ;;
        --proxy-pass)
            ENABLE_PROXY=true
            PROXY_PASS="$2"
            shift 2
            ;;
        --document-root)
            DOCUMENT_ROOT="$2"
            shift 2
            ;;
        --mpm-event)
            ENABLE_MPM_EVENT=true
            shift
            ;;
        --http2)
            ENABLE_HTTP2=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Неизвестный параметр: $1"
            show_help
            ;;
    esac
done

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    print_error "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Проверка ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
    print_info "Обнаружена ОС: $PRETTY_NAME"
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

# Проверка поддерживаемых ОС
case "$OS_ID" in
    debian|ubuntu)
        ;;
    *)
        print_error "Поддерживаются только Debian и Ubuntu"
        exit 1
        ;;
esac

# Валидация параметров
if [ "$LETSENCRYPT" = true ]; then
    if [ -z "$DOMAIN" ]; then
        print_error "Для Let's Encrypt требуется указать --domain"
        exit 1
    fi
    if [ -z "$EMAIL" ]; then
        print_error "Для Let's Encrypt требуется указать --email"
        exit 1
    fi
fi

if [ "$ENABLE_HTTP2" = true ]; then
    if [ "$ENABLE_SSL" != true ]; then
        print_warn "HTTP/2 требует SSL, включаю SSL автоматически"
        ENABLE_SSL=true
    fi
    if [ "$ENABLE_MPM_EVENT" != true ]; then
        print_warn "HTTP/2 лучше работает с MPM Event, включаю автоматически"
        ENABLE_MPM_EVENT=true
    fi
fi

if [ "$ENABLE_PHP" = true ] && [ "$ENABLE_MPM_EVENT" = true ]; then
    print_info "С MPM Event будет использоваться PHP-FPM"
fi

# Начало установки
echo ""
echo "=============================================="
print_info "Установка Apache HTTP Server"
echo "=============================================="
echo ""

if [ -n "$DOMAIN" ]; then
    print_info "Домен: $DOMAIN"
fi
print_info "Document Root: $DOCUMENT_ROOT"
print_info "SSL: $([ "$ENABLE_SSL" = true ] && echo "Да" || echo "Нет")"
print_info "PHP: $([ "$ENABLE_PHP" = true ] && echo "Да (версия $PHP_VERSION)" || echo "Нет")"
print_info "Proxy: $([ "$ENABLE_PROXY" = true ] && echo "$PROXY_PASS" || echo "Нет")"
print_info "MPM Event: $([ "$ENABLE_MPM_EVENT" = true ] && echo "Да" || echo "Нет")"
print_info "HTTP/2: $([ "$ENABLE_HTTP2" = true ] && echo "Да" || echo "Нет")"
echo ""

# Обновление системы
print_step "Обновление списка пакетов..."
apt-get update -y

# Установка Apache
print_step "Установка Apache..."
apt-get install -y apache2 apache2-utils

# Включение основных модулей
print_step "Включение базовых модулей..."
a2enmod rewrite
a2enmod headers
a2enmod expires
a2enmod deflate

# Настройка MPM
if [ "$ENABLE_MPM_EVENT" = true ]; then
    print_step "Переключение на MPM Event..."
    a2dismod mpm_prefork 2>/dev/null || true
    a2dismod mpm_worker 2>/dev/null || true
    a2enmod mpm_event
fi

# Установка SSL
if [ "$ENABLE_SSL" = true ]; then
    print_step "Настройка SSL..."
    a2enmod ssl
    
    if [ "$ENABLE_HTTP2" = true ]; then
        print_step "Включение HTTP/2..."
        a2enmod http2
    fi
fi

# Установка модулей для прокси
if [ "$ENABLE_PROXY" = true ]; then
    print_step "Включение модулей прокси..."
    a2enmod proxy
    a2enmod proxy_http
    a2enmod proxy_wstunnel
    a2enmod proxy_balancer
    a2enmod lbmethod_byrequests
fi

# Установка PHP
if [ "$ENABLE_PHP" = true ]; then
    print_step "Установка PHP $PHP_VERSION..."
    
    # Добавление репозитория Sury для PHP (если нужна конкретная версия)
    if [ "$OS_ID" = "debian" ] || [ "$OS_ID" = "ubuntu" ]; then
        if ! dpkg -l | grep -q "php${PHP_VERSION}-fpm"; then
            apt-get install -y apt-transport-https lsb-release ca-certificates curl gnupg
            
            # Добавляем репозиторий Sury если версия PHP не в стандартных репозиториях
            if ! apt-cache show php${PHP_VERSION}-fpm &>/dev/null; then
                print_info "Добавление репозитория Sury для PHP..."
                curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
                echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list
                apt-get update -y
            fi
        fi
    fi
    
    # Установка PHP-FPM и расширений
    apt-get install -y \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-sqlite3 \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-opcache \
        libapache2-mod-fcgid
    
    # Настройка Apache для PHP-FPM
    a2enmod proxy_fcgi setenvif
    a2enconf php${PHP_VERSION}-fpm
    
    # Запуск PHP-FPM
    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm
fi

# Создание директории для сайта
print_step "Настройка Document Root..."
mkdir -p "$DOCUMENT_ROOT"
chown -R www-data:www-data "$DOCUMENT_ROOT"
chmod -R 755 "$DOCUMENT_ROOT"

# Создание тестовой страницы
if [ ! -f "$DOCUMENT_ROOT/index.html" ]; then
    cat > "$DOCUMENT_ROOT/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Apache работает!</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        .status {
            display: inline-block;
            background: rgba(255,255,255,0.2);
            padding: 0.5rem 1.5rem;
            border-radius: 2rem;
            margin-top: 1rem;
        }
        .status::before {
            content: '●';
            color: #4ade80;
            margin-right: 0.5rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Apache работает!</h1>
        <p>Веб-сервер успешно установлен и настроен.</p>
        <div class="status">Сервер активен</div>
    </div>
</body>
</html>
HTMLEOF
fi

# Создание тестовой PHP страницы
if [ "$ENABLE_PHP" = true ] && [ ! -f "$DOCUMENT_ROOT/info.php" ]; then
    cat > "$DOCUMENT_ROOT/info.php" << 'PHPEOF'
<?php
phpinfo();
PHPEOF
    chown www-data:www-data "$DOCUMENT_ROOT/info.php"
fi

# Создание виртуального хоста
if [ "$CREATE_VHOST" = true ] && [ -n "$DOMAIN" ]; then
    print_step "Создание виртуального хоста для $DOMAIN..."
    
    VHOST_FILE="/etc/apache2/sites-available/${DOMAIN}.conf"
    
    # HTTP конфигурация
    cat > "$VHOST_FILE" << VHOSTEOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot ${DOCUMENT_ROOT}
    
    <Directory ${DOCUMENT_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Логи
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
    
VHOSTEOF

    # Добавление конфигурации прокси
    if [ "$ENABLE_PROXY" = true ]; then
        cat >> "$VHOST_FILE" << PROXYEOF
    # Обратный прокси
    ProxyPreserveHost On
    ProxyPass / ${PROXY_PASS}/
    ProxyPassReverse / ${PROXY_PASS}/
    
    # WebSocket поддержка
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://${PROXY_PASS#http://}/\$1" [P,L]
    
PROXYEOF
    fi

    # Добавление PHP-FPM конфигурации
    if [ "$ENABLE_PHP" = true ]; then
        cat >> "$VHOST_FILE" << PHPFPMEOF
    # PHP-FPM
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
PHPFPMEOF
    fi

    echo "</VirtualHost>" >> "$VHOST_FILE"
    
    # Активация виртуального хоста
    a2ensite "${DOMAIN}.conf"
    
    # SSL конфигурация
    if [ "$ENABLE_SSL" = true ]; then
        SSL_VHOST_FILE="/etc/apache2/sites-available/${DOMAIN}-ssl.conf"
        
        # Создание самоподписанного сертификата (если не Let's Encrypt)
        if [ "$LETSENCRYPT" != true ]; then
            print_step "Генерация самоподписанного SSL сертификата..."
            mkdir -p /etc/apache2/ssl
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/apache2/ssl/${DOMAIN}.key \
                -out /etc/apache2/ssl/${DOMAIN}.crt \
                -subj "/CN=${DOMAIN}/O=Self-Signed/C=RU"
            
            SSL_CERT="/etc/apache2/ssl/${DOMAIN}.crt"
            SSL_KEY="/etc/apache2/ssl/${DOMAIN}.key"
        fi
        
        # HTTPS конфигурация
        cat > "$SSL_VHOST_FILE" << SSLVHOSTEOF
<VirtualHost *:443>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot ${DOCUMENT_ROOT}
    
    # SSL
    SSLEngine on
SSLVHOSTEOF

        if [ "$LETSENCRYPT" != true ]; then
            cat >> "$SSL_VHOST_FILE" << SSLCERTEOF
    SSLCertificateFile ${SSL_CERT}
    SSLCertificateKeyFile ${SSL_KEY}
SSLCERTEOF
        fi

        cat >> "$SSL_VHOST_FILE" << SSLCONFEOF
    
    # Современные SSL настройки
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder off
    SSLSessionTickets off
    
    # Заголовки безопасности
    Header always set Strict-Transport-Security "max-age=63072000"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    
SSLCONFEOF

        if [ "$ENABLE_HTTP2" = true ]; then
            cat >> "$SSL_VHOST_FILE" << HTTP2EOF
    # HTTP/2
    Protocols h2 http/1.1
    
HTTP2EOF
        fi

        cat >> "$SSL_VHOST_FILE" << DIREOF
    <Directory ${DOCUMENT_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Логи
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_ssl_error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_ssl_access.log combined
    
DIREOF

        # Добавление конфигурации прокси для SSL
        if [ "$ENABLE_PROXY" = true ]; then
            cat >> "$SSL_VHOST_FILE" << SSLPROXYEOF
    # Обратный прокси
    ProxyPreserveHost On
    ProxyPass / ${PROXY_PASS}/
    ProxyPassReverse / ${PROXY_PASS}/
    
    # WebSocket поддержка
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} websocket [NC]
    RewriteCond %{HTTP:Connection} upgrade [NC]
    RewriteRule ^/?(.*) "ws://${PROXY_PASS#http://}/\$1" [P,L]
    
SSLPROXYEOF
        fi

        # Добавление PHP-FPM конфигурации для SSL
        if [ "$ENABLE_PHP" = true ]; then
            cat >> "$SSL_VHOST_FILE" << SSLPHPEOF
    # PHP-FPM
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost"
    </FilesMatch>
    
SSLPHPEOF
        fi

        echo "</VirtualHost>" >> "$SSL_VHOST_FILE"
        
        # Активация SSL виртуального хоста
        a2ensite "${DOMAIN}-ssl.conf"
        
        # Редирект HTTP -> HTTPS
        cat > "/etc/apache2/sites-available/${DOMAIN}-redirect.conf" << REDIRECTEOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}\$1 [R=301,L]
</VirtualHost>
REDIRECTEOF
        
        # Отключаем HTTP и включаем редирект
        a2dissite "${DOMAIN}.conf"
        a2ensite "${DOMAIN}-redirect.conf"
    fi
fi

# Let's Encrypt
if [ "$LETSENCRYPT" = true ]; then
    print_step "Установка Certbot для Let's Encrypt..."
    apt-get install -y certbot python3-certbot-apache
    
    print_step "Получение SSL сертификата от Let's Encrypt..."
    certbot --apache -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
    
    # Настройка автоматического обновления
    systemctl enable certbot.timer
    systemctl start certbot.timer
fi

# Оптимизация конфигурации Apache
print_step "Оптимизация конфигурации..."

# Отключение ServerTokens и ServerSignature
cat > /etc/apache2/conf-available/security-hardening.conf << 'SECURITYEOF'
# Скрытие версии Apache
ServerTokens Prod
ServerSignature Off

# Защита от clickjacking
Header always set X-Frame-Options "SAMEORIGIN"

# Защита от XSS
Header always set X-XSS-Protection "1; mode=block"

# Запрет MIME-sniffing
Header always set X-Content-Type-Options "nosniff"

# Referrer Policy
Header always set Referrer-Policy "strict-origin-when-cross-origin"
SECURITYEOF

a2enconf security-hardening

# Отключение default site если создан виртуальный хост
if [ "$CREATE_VHOST" = true ]; then
    a2dissite 000-default.conf 2>/dev/null || true
fi

# Проверка конфигурации
print_step "Проверка конфигурации Apache..."
if apache2ctl configtest; then
    print_info "Конфигурация корректна"
else
    print_error "Ошибка в конфигурации Apache"
    exit 1
fi

# Перезапуск Apache
print_step "Перезапуск Apache..."
systemctl enable apache2
systemctl restart apache2

# Информация после установки
echo ""
echo "=============================================="
print_info "Установка Apache завершена!"
echo "=============================================="
echo ""

# Определение IP адреса
IP_ADDR=$(hostname -I | awk '{print $1}')

if [ -n "$DOMAIN" ]; then
    if [ "$ENABLE_SSL" = true ]; then
        print_info "Адрес: https://${DOMAIN}"
    else
        print_info "Адрес: http://${DOMAIN}"
    fi
else
    print_info "Адрес: http://${IP_ADDR}"
fi

print_info "Document Root: $DOCUMENT_ROOT"

if [ "$ENABLE_PHP" = true ]; then
    print_info "PHP версия: $PHP_VERSION"
    print_info "PHP info: http://${IP_ADDR}/info.php"
    print_warn "⚠️  Удалите info.php после проверки: rm $DOCUMENT_ROOT/info.php"
fi

if [ "$ENABLE_PROXY" = true ]; then
    print_info "Прокси на: $PROXY_PASS"
fi

if [ "$LETSENCRYPT" = true ]; then
    print_info "SSL: Let's Encrypt (автообновление настроено)"
elif [ "$ENABLE_SSL" = true ]; then
    print_info "SSL: Самоподписанный сертификат"
    print_warn "⚠️  Замените сертификат на доверенный для production"
fi

echo ""
print_info "Управление сервисом:"
echo "  systemctl status apache2   - статус"
echo "  systemctl restart apache2  - перезапуск"
echo "  systemctl reload apache2   - перезагрузка конфигурации"
echo "  apache2ctl configtest      - проверка конфигурации"
echo ""
print_info "Логи:"
echo "  /var/log/apache2/error.log"
echo "  /var/log/apache2/access.log"
if [ -n "$DOMAIN" ]; then
    echo "  /var/log/apache2/${DOMAIN}_error.log"
    echo "  /var/log/apache2/${DOMAIN}_access.log"
fi
echo ""
print_info "Конфигурация:"
echo "  /etc/apache2/apache2.conf      - основной конфиг"
echo "  /etc/apache2/sites-available/  - доступные сайты"
echo "  /etc/apache2/sites-enabled/    - активные сайты"
echo ""

print_info "Готово!"

