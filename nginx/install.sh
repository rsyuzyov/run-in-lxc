#!/bin/bash

#############################################
# Nginx Installation Script for LXC
# Установка Nginx с опциональной настройкой
# виртуальных хостов, SSL и PHP
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
ROOT_PATH=""
PROXY_PASS=""
ENABLE_SSL=false
SSL_EMAIL=""
INSTALL_PHP=false
PHP_VERSION="8.2"
USE_MAINLINE=false

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

Скрипт установки Nginx для LXC контейнеров.

Опции:
  --domain DOMAIN         Создать виртуальный хост для указанного домена
  --root PATH             Корневая директория сайта (по умолчанию: /var/www/<domain>)
  --proxy-pass URL        Настроить как обратный прокси на указанный URL
  --ssl                   Настроить SSL через Let's Encrypt (требует --domain и --email)
  --email EMAIL           Email для Let's Encrypt уведомлений
  --php                   Установить PHP-FPM и настроить обработку PHP
  --php-version VERSION   Версия PHP (по умолчанию: 8.2)
  --mainline              Установить mainline версию Nginx
  --help                  Показать эту справку

Примеры:
  # Базовая установка Nginx
  $0

  # Установка с виртуальным хостом
  $0 --domain example.com

  # Обратный прокси
  $0 --domain api.example.com --proxy-pass http://127.0.0.1:3000

  # Веб-сервер с PHP
  $0 --domain blog.example.com --php

  # Полная установка с SSL
  $0 --domain secure.example.com --ssl --email admin@example.com

  # Обратный прокси с SSL
  $0 --domain app.example.com --proxy-pass http://127.0.0.1:8080 --ssl --email admin@example.com

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --root)
            ROOT_PATH="$2"
            shift 2
            ;;
        --proxy-pass)
            PROXY_PASS="$2"
            shift 2
            ;;
        --ssl)
            ENABLE_SSL=true
            shift
            ;;
        --email)
            SSL_EMAIL="$2"
            shift 2
            ;;
        --php)
            INSTALL_PHP=true
            shift
            ;;
        --php-version)
            PHP_VERSION="$2"
            shift 2
            ;;
        --mainline)
            USE_MAINLINE=true
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

# Проверка параметров SSL
if [ "$ENABLE_SSL" = true ]; then
    if [ -z "$DOMAIN" ]; then
        print_error "Для SSL необходимо указать --domain"
        exit 1
    fi
    if [ -z "$SSL_EMAIL" ]; then
        print_error "Для SSL необходимо указать --email"
        exit 1
    fi
fi

# Установка корневой директории по умолчанию
if [ -n "$DOMAIN" ] && [ -z "$ROOT_PATH" ] && [ -z "$PROXY_PASS" ]; then
    ROOT_PATH="/var/www/${DOMAIN}"
fi

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка Nginx"
if [ "$USE_MAINLINE" = true ]; then
    print_info "Версия: mainline (последняя)"
else
    print_info "Версия: stable"
fi
if [ -n "$DOMAIN" ]; then
    print_info "Домен: $DOMAIN"
fi
if [ -n "$PROXY_PASS" ]; then
    print_info "Прокси: $PROXY_PASS"
elif [ -n "$ROOT_PATH" ]; then
    print_info "Корень сайта: $ROOT_PATH"
fi
if [ "$ENABLE_SSL" = true ]; then
    print_info "SSL: Let's Encrypt"
    print_info "Email: $SSL_EMAIL"
fi
if [ "$INSTALL_PHP" = true ]; then
    print_info "PHP: $PHP_VERSION"
fi
echo "=============================================="
echo ""

# Определение дистрибутива
print_step "Определение дистрибутива..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_CODENAME
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

print_info "Обнаружен: $OS $VERSION"

# Установка зависимостей
print_step "Установка базовых зависимостей..."
apt-get update
apt-get install -y curl gnupg2 ca-certificates lsb-release apt-transport-https

# Добавление репозитория Nginx
print_step "Добавление официального репозитория Nginx..."

# Создание директории для ключей, если не существует
mkdir -p /usr/share/keyrings

# Скачивание ключа
curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg

# Добавление репозитория
if [ "$USE_MAINLINE" = true ]; then
    NGINX_REPO="mainline"
else
    NGINX_REPO="nginx"
fi

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/${NGINX_REPO}/${OS} ${VERSION} nginx" > /etc/apt/sources.list.d/nginx.list

# Приоритет репозитория Nginx
cat > /etc/apt/preferences.d/99nginx << EOF
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF

# Установка Nginx
print_step "Установка Nginx..."
apt-get update
apt-get install -y nginx

# Создание структуры директорий для виртуальных хостов (если не существует)
mkdir -p /etc/nginx/sites-available
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/snippets

# Добавление include для sites-enabled в nginx.conf (если отсутствует)
if ! grep -q "include /etc/nginx/sites-enabled" /etc/nginx/nginx.conf; then
    print_step "Настройка структуры sites-enabled..."
    sed -i '/include \/etc\/nginx\/conf\.d\/\*\.conf;/a\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf
fi

# Установка PHP-FPM (если запрошено)
if [ "$INSTALL_PHP" = true ]; then
    print_step "Установка PHP ${PHP_VERSION}-FPM..."
    
    # Добавление репозитория PHP (для новых версий)
    if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
        apt-get install -y software-properties-common
        if [ "$OS" = "ubuntu" ]; then
            add-apt-repository -y ppa:ondrej/php
        else
            # Для Debian используем sury.org
            curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
            echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${VERSION} main" > /etc/apt/sources.list.d/php.list
        fi
        apt-get update
    fi
    
    apt-get install -y php${PHP_VERSION}-fpm php${PHP_VERSION}-common php${PHP_VERSION}-cli \
        php${PHP_VERSION}-mysql php${PHP_VERSION}-pgsql php${PHP_VERSION}-sqlite3 \
        php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-intl
    
    # Запуск PHP-FPM
    systemctl enable php${PHP_VERSION}-fpm
    systemctl start php${PHP_VERSION}-fpm
    
    print_info "✓ PHP ${PHP_VERSION}-FPM установлен"
fi

# Создание виртуального хоста (если указан домен)
if [ -n "$DOMAIN" ]; then
    print_step "Создание виртуального хоста для $DOMAIN..."
    
    VHOST_FILE="/etc/nginx/sites-available/${DOMAIN}.conf"
    
    if [ -n "$PROXY_PASS" ]; then
        # Конфигурация обратного прокси
        cat > "$VHOST_FILE" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    location / {
        proxy_pass ${PROXY_PASS};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
}
EOF
        print_info "✓ Конфигурация обратного прокси создана"
        
    elif [ "$INSTALL_PHP" = true ]; then
        # Конфигурация PHP-сайта
        mkdir -p "$ROOT_PATH"
        
        cat > "$VHOST_FILE" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${ROOT_PATH};
    index index.php index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)\$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF
        
        # Создание тестового PHP-файла
        cat > "${ROOT_PATH}/index.php" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>PHP Info</title>
</head>
<body>
    <h1>PHP работает!</h1>
    <?php phpinfo(); ?>
</body>
</html>
EOF
        
        chown -R www-data:www-data "$ROOT_PATH"
        print_info "✓ Конфигурация PHP-сайта создана"
        
    else
        # Конфигурация статического сайта
        mkdir -p "$ROOT_PATH"
        
        cat > "$VHOST_FILE" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    root ${ROOT_PATH};
    index index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log /var/log/nginx/${DOMAIN}.error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)\$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF
        
        # Создание тестовой страницы
        cat > "${ROOT_PATH}/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to ${DOMAIN}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 ${DOMAIN}</h1>
        <p>Nginx успешно настроен и работает!</p>
    </div>
</body>
</html>
EOF
        
        chown -R www-data:www-data "$ROOT_PATH"
        print_info "✓ Конфигурация статического сайта создана"
    fi
    
    # Включение виртуального хоста
    ln -sf "$VHOST_FILE" /etc/nginx/sites-enabled/
    
    # Удаление default сайта (если существует)
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/conf.d/default.conf
fi

# Проверка конфигурации
print_step "Проверка конфигурации Nginx..."
if nginx -t; then
    print_info "✓ Конфигурация корректна"
else
    print_error "Ошибка в конфигурации Nginx!"
    exit 1
fi

# Запуск Nginx
print_step "Запуск Nginx..."
systemctl enable nginx
systemctl restart nginx

# Проверка статуса
if systemctl is-active --quiet nginx; then
    print_info "✓ Nginx успешно запущен"
else
    print_error "Не удалось запустить Nginx!"
    print_error "Проверьте логи: journalctl -u nginx -n 50"
    exit 1
fi

# Установка SSL (если запрошено)
if [ "$ENABLE_SSL" = true ]; then
    print_step "Установка Certbot для Let's Encrypt..."
    apt-get install -y certbot python3-certbot-nginx
    
    print_step "Получение SSL-сертификата для $DOMAIN..."
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect
    
    if [ $? -eq 0 ]; then
        print_info "✓ SSL-сертификат успешно установлен"
        
        # Проверка автопродления
        print_step "Проверка автопродления сертификата..."
        certbot renew --dry-run
        
        if [ $? -eq 0 ]; then
            print_info "✓ Автопродление настроено"
        else
            print_warn "Проверка автопродления завершилась с ошибкой"
        fi
    else
        print_error "Ошибка получения SSL-сертификата!"
        print_warn "Возможные причины:"
        print_warn "  - Домен $DOMAIN не указывает на этот сервер"
        print_warn "  - Порт 80 недоступен извне"
        print_warn "  - Лимит запросов Let's Encrypt превышен"
    fi
fi

# Итоговая информация
echo ""
echo "=============================================="
print_info "✓ Установка Nginx завершена успешно!"
echo "=============================================="
echo ""

print_info "Управление сервисом:"
print_info "  systemctl status nginx"
print_info "  systemctl restart nginx"
print_info "  systemctl reload nginx"
echo ""

print_info "Проверка конфигурации:"
print_info "  nginx -t"
echo ""

print_info "Логи:"
print_info "  journalctl -u nginx -f"
print_info "  tail -f /var/log/nginx/access.log"
print_info "  tail -f /var/log/nginx/error.log"
echo ""

if [ -n "$DOMAIN" ]; then
    print_info "Виртуальный хост:"
    print_info "  Конфигурация: /etc/nginx/sites-available/${DOMAIN}.conf"
    if [ -n "$ROOT_PATH" ]; then
        print_info "  Корень сайта: $ROOT_PATH"
    fi
    if [ -n "$PROXY_PASS" ]; then
        print_info "  Прокси на: $PROXY_PASS"
    fi
    echo ""
    
    IP_ADDR=$(hostname -I | awk '{print $1}')
    if [ "$ENABLE_SSL" = true ]; then
        print_info "Сайт доступен по адресу:"
        print_info "  https://${DOMAIN}"
        print_info "  https://${IP_ADDR} (по IP)"
    else
        print_info "Сайт доступен по адресу:"
        print_info "  http://${DOMAIN}"
        print_info "  http://${IP_ADDR} (по IP)"
    fi
    echo ""
fi

if [ "$INSTALL_PHP" = true ]; then
    print_info "PHP-FPM:"
    print_info "  Версия: PHP ${PHP_VERSION}"
    print_info "  Сервис: php${PHP_VERSION}-fpm"
    print_info "  Сокет: /var/run/php/php${PHP_VERSION}-fpm.sock"
    echo ""
fi

print_info "Полезные пути:"
print_info "  Конфигурация: /etc/nginx/"
print_info "  Виртуальные хосты: /etc/nginx/sites-available/"
print_info "  Включённые сайты: /etc/nginx/sites-enabled/"
print_info "  Логи: /var/log/nginx/"
echo ""

