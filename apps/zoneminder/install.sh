#!/bin/bash

#############################################
# ZoneMinder Installation Script for LXC
# Система видеонаблюдения для Debian 13 (Trixie)
# Включает: Apache, PHP, MariaDB, ffmpeg
# Опционально: zmeventnotification, ML детекция, Prometheus exporter
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
TIMEZONE="Europe/Moscow"
STORAGE_PATH="/var/cache/zoneminder/events"
RETENTION_DAYS=30

# SSL
ENABLE_SSL=false
LETSENCRYPT=false
EMAIL=""

# База данных
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="zm"
DB_USER="zmuser"
DB_PASSWORD=""
USE_EXTERNAL_DB=false

# Опциональные компоненты
INSTALL_EVENT_NOTIFICATION=false
INSTALL_ML=false
INSTALL_PROMETHEUS_EXPORTER=false

# Порты
ZM_PORT=80
ZM_SSL_PORT=443
PROMETHEUS_EXPORTER_PORT=9120

# Директория скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Функция генерации пароля
generate_password() {
    openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20
}

# Функция помощи
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Скрипт установки ZoneMinder для LXC контейнеров (Debian 13 Trixie).
Устанавливает: ZoneMinder, Apache, PHP, MariaDB (опционально).

Рекомендуемые ресурсы LXC:
  Минимум: 2 CPU, 4 GB RAM, 50 GB диска
  На каждые 4-8 камер 1080p: +1 CPU, +2 GB RAM

Основные опции:
  --domain DOMAIN         Домен для веб-интерфейса (обязательно)
  --timezone TZ           Часовой пояс (по умолчанию: Europe/Moscow)
  --storage-path PATH     Путь хранения видео (по умолчанию: /var/cache/zoneminder/events)
  --retention-days DAYS   Дни хранения записей (по умолчанию: 30)
  --help                  Показать эту справку

Настройки SSL:
  --ssl                   Включить SSL с самоподписанным сертификатом
  --letsencrypt           Использовать Let's Encrypt (требует --email)
  --email EMAIL           Email для Let's Encrypt

Настройки базы данных (по умолчанию: встроенная MariaDB):
  --db-host HOST          Хост внешней БД
  --db-port PORT          Порт БД (по умолчанию: 3306)
  --db-name NAME          Имя базы данных (по умолчанию: zm)
  --db-user USER          Пользователь БД (по умолчанию: zmuser)
  --db-password PASS      Пароль БД (генерируется автоматически если не указан)

Дополнительные компоненты:
  --with-event-notification  Установить zmeventnotification (push-уведомления)
  --with-ml                  Установить ML детекцию объектов (YOLO/OpenCV)
  --prometheus-exporter      Установить Prometheus exporter

Примеры:
  # Базовая установка
  $0 --domain cameras.example.com

  # С SSL Let's Encrypt
  $0 --domain cameras.example.com --email admin@example.com --letsencrypt

  # С внешней БД
  $0 --domain cameras.example.com \\
     --db-host 192.168.1.100 \\
     --db-name zm \\
     --db-user zmuser \\
     --db-password SecurePass123

  # Полная установка с ML
  $0 --domain cameras.example.com \\
     --letsencrypt --email admin@example.com \\
     --with-event-notification --with-ml \\
     --prometheus-exporter

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
        --timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        --storage-path)
            STORAGE_PATH="$2"
            shift 2
            ;;
        --retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --ssl)
            ENABLE_SSL=true
            shift
            ;;
        --letsencrypt)
            LETSENCRYPT=true
            ENABLE_SSL=true
            shift
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --db-host)
            DB_HOST="$2"
            USE_EXTERNAL_DB=true
            shift 2
            ;;
        --db-port)
            DB_PORT="$2"
            shift 2
            ;;
        --db-name)
            DB_NAME="$2"
            shift 2
            ;;
        --db-user)
            DB_USER="$2"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --with-event-notification)
            INSTALL_EVENT_NOTIFICATION=true
            shift
            ;;
        --with-ml)
            INSTALL_ML=true
            INSTALL_EVENT_NOTIFICATION=true  # ML требует event notification
            shift
            ;;
        --prometheus-exporter)
            INSTALL_PROMETHEUS_EXPORTER=true
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

# Проверка обязательных параметров
if [ -z "$DOMAIN" ]; then
    print_error "Необходимо указать --domain"
    exit 1
fi

# Проверка Let's Encrypt
if [ "$LETSENCRYPT" = true ] && [ -z "$EMAIL" ]; then
    print_error "Для Let's Encrypt необходимо указать --email"
    exit 1
fi

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    print_error "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

# Генерация пароля БД если не указан
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(generate_password)
    print_info "Сгенерирован пароль БД: ${DB_PASSWORD}"
fi

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка ZoneMinder"
echo "=============================================="
print_info "Домен: ${DOMAIN}"
print_info "Часовой пояс: ${TIMEZONE}"
print_info "Хранилище: ${STORAGE_PATH}"
print_info "Retention: ${RETENTION_DAYS} дней"
print_info "SSL: $([ "$ENABLE_SSL" = true ] && echo "включен$([ "$LETSENCRYPT" = true ] && echo " (Let's Encrypt)")" || echo "отключен")"
print_info "База данных: $([ "$USE_EXTERNAL_DB" = true ] && echo "${DB_HOST}:${DB_PORT}" || echo "встроенная MariaDB")"
echo ""
print_info "Дополнительные компоненты:"
[ "$INSTALL_EVENT_NOTIFICATION" = true ] && print_info "  • zmeventnotification"
[ "$INSTALL_ML" = true ] && print_info "  • ML детекция (YOLO/OpenCV)"
[ "$INSTALL_PROMETHEUS_EXPORTER" = true ] && print_info "  • Prometheus exporter"
[ "$INSTALL_EVENT_NOTIFICATION" = false ] && [ "$INSTALL_ML" = false ] && [ "$INSTALL_PROMETHEUS_EXPORTER" = false ] && print_info "  (нет)"
echo "=============================================="
echo ""

# Установка часового пояса
print_step "Настройка часового пояса..."
timedatectl set-timezone "$TIMEZONE" 2>/dev/null || ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime

#############################################
# Установка зависимостей
#############################################

print_step "Обновление системы и установка зависимостей..."
apt-get update
apt-get upgrade -y

# Базовые зависимости
apt-get install -y \
    wget curl gnupg2 ca-certificates lsb-release apt-transport-https \
    software-properties-common

# Добавление репозитория ZoneMinder для Debian
print_step "Добавление репозитория ZoneMinder..."

# Ключ репозитория ZoneMinder
wget -qO - https://zmrepo.zoneminder.com/debian/archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/zoneminder-archive-keyring.gpg

# Репозиторий для Debian 13 (Trixie)
cat > /etc/apt/sources.list.d/zoneminder.list << EOF
deb [signed-by=/usr/share/keyrings/zoneminder-archive-keyring.gpg] https://zmrepo.zoneminder.com/debian/release-1.36 trixie/
EOF

apt-get update

#############################################
# Установка MariaDB (если не внешняя БД)
#############################################

if [ "$USE_EXTERNAL_DB" = false ]; then
    print_step "Установка MariaDB..."
    apt-get install -y mariadb-server mariadb-client

    # Запуск MariaDB
    systemctl enable --now mariadb

    # Базовая настройка безопасности
    print_step "Настройка MariaDB..."
    
    # Создание базы данных и пользователя
    mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
    mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    
    print_info "✓ MariaDB настроена"
fi

#############################################
# Установка Apache + PHP
#############################################

print_step "Установка Apache и PHP..."
apt-get install -y \
    apache2 \
    libapache2-mod-php \
    php php-mysql php-gd php-curl php-intl php-json php-apcu \
    php-cli php-common php-mbstring php-xml php-zip

# Включение модулей Apache
a2enmod rewrite
a2enmod headers
a2enmod expires
a2enmod ssl
a2enmod cgi

#############################################
# Установка ZoneMinder
#############################################

print_step "Установка ZoneMinder..."
DEBIAN_FRONTEND=noninteractive apt-get install -y zoneminder

# Установка дополнительных зависимостей
apt-get install -y \
    ffmpeg \
    libvlc-bin vlc-plugin-base \
    libcrypt-eksblowfish-perl \
    libdata-entropy-perl

#############################################
# Настройка ZoneMinder
#############################################

print_step "Настройка ZoneMinder..."

# Настройка прав
chmod 740 /etc/zm/zm.conf
chown root:www-data /etc/zm/zm.conf

# Обновление конфигурации БД
cat > /etc/zm/conf.d/01-database.conf << EOF
# Database configuration
ZM_DB_HOST=${DB_HOST}
ZM_DB_PORT=${DB_PORT}
ZM_DB_NAME=${DB_NAME}
ZM_DB_USER=${DB_USER}
ZM_DB_PASS=${DB_PASSWORD}
EOF

chmod 640 /etc/zm/conf.d/01-database.conf
chown root:www-data /etc/zm/conf.d/01-database.conf

# Настройка хранилища
mkdir -p "$STORAGE_PATH"
chown -R www-data:www-data "$STORAGE_PATH"

# Настройка путей в конфигурации
cat > /etc/zm/conf.d/02-paths.conf << EOF
# Paths configuration
ZM_DIR_EVENTS=${STORAGE_PATH}
EOF

chmod 640 /etc/zm/conf.d/02-paths.conf
chown root:www-data /etc/zm/conf.d/02-paths.conf

# Инициализация базы данных ZoneMinder
if [ "$USE_EXTERNAL_DB" = false ]; then
    print_step "Инициализация базы данных ZoneMinder..."
    mysql ${DB_NAME} < /usr/share/zoneminder/db/zm_create.sql
else
    print_warn "Для внешней БД выполните вручную:"
    print_warn "  mysql -h ${DB_HOST} -u ${DB_USER} -p ${DB_NAME} < /usr/share/zoneminder/db/zm_create.sql"
fi

#############################################
# Настройка Apache
#############################################

print_step "Настройка Apache..."

# Включение конфигурации ZoneMinder
a2enconf zoneminder

# Создание VirtualHost
if [ "$ENABLE_SSL" = true ]; then
    # HTTP -> HTTPS редирект
    cat > /etc/apache2/sites-available/zoneminder.conf << EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<VirtualHost *:443>
    ServerName ${DOMAIN}
    
    DocumentRoot /usr/share/zoneminder/www
    
    SSLEngine on
EOF

    if [ "$LETSENCRYPT" = true ]; then
        cat >> /etc/apache2/sites-available/zoneminder.conf << EOF
    SSLCertificateFile /etc/letsencrypt/live/${DOMAIN}/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN}/privkey.pem
    
    Include /etc/letsencrypt/options-ssl-apache.conf
EOF
    else
        cat >> /etc/apache2/sites-available/zoneminder.conf << EOF
    SSLCertificateFile /etc/ssl/certs/zoneminder.crt
    SSLCertificateKeyFile /etc/ssl/private/zoneminder.key
EOF
    fi

    cat >> /etc/apache2/sites-available/zoneminder.conf << EOF
    
    <Directory /usr/share/zoneminder/www>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ScriptAlias /cgi-bin /usr/lib/zoneminder/cgi-bin
    
    <Directory /usr/lib/zoneminder/cgi-bin>
        Options +ExecCGI
        AllowOverride All
        Require all granted
    </Directory>
    
    Alias /cache /var/cache/zoneminder/cache
    <Directory /var/cache/zoneminder/cache>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    
    Alias /events ${STORAGE_PATH}
    <Directory ${STORAGE_PATH}>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    
    # Performance headers
    <IfModule mod_headers.c>
        Header always set X-Content-Type-Options nosniff
        Header always set X-Frame-Options SAMEORIGIN
        Header always set X-XSS-Protection "1; mode=block"
    </IfModule>
    
    ErrorLog \${APACHE_LOG_DIR}/zoneminder-error.log
    CustomLog \${APACHE_LOG_DIR}/zoneminder-access.log combined
</VirtualHost>
EOF
else
    # Только HTTP
    cat > /etc/apache2/sites-available/zoneminder.conf << EOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    
    DocumentRoot /usr/share/zoneminder/www
    
    <Directory /usr/share/zoneminder/www>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ScriptAlias /cgi-bin /usr/lib/zoneminder/cgi-bin
    
    <Directory /usr/lib/zoneminder/cgi-bin>
        Options +ExecCGI
        AllowOverride All
        Require all granted
    </Directory>
    
    Alias /cache /var/cache/zoneminder/cache
    <Directory /var/cache/zoneminder/cache>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    
    Alias /events ${STORAGE_PATH}
    <Directory ${STORAGE_PATH}>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/zoneminder-error.log
    CustomLog \${APACHE_LOG_DIR}/zoneminder-access.log combined
</VirtualHost>
EOF
fi

# Активация сайта
a2dissite 000-default.conf 2>/dev/null || true
a2ensite zoneminder.conf

#############################################
# SSL сертификаты
#############################################

if [ "$ENABLE_SSL" = true ]; then
    if [ "$LETSENCRYPT" = true ]; then
        print_step "Настройка Let's Encrypt..."
        apt-get install -y certbot python3-certbot-apache
        
        # Временно отключаем SSL для получения сертификата
        sed -i 's/SSLEngine on/SSLEngine off/' /etc/apache2/sites-available/zoneminder.conf
        systemctl restart apache2
        
        # Получение сертификата
        certbot --apache -d "${DOMAIN}" --email "${EMAIL}" --agree-tos --non-interactive --redirect
        
        print_info "✓ Let's Encrypt сертификат получен"
    else
        print_step "Создание самоподписанного сертификата..."
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/zoneminder.key \
            -out /etc/ssl/certs/zoneminder.crt \
            -subj "/CN=${DOMAIN}/O=ZoneMinder/C=RU"
        
        chmod 600 /etc/ssl/private/zoneminder.key
        
        print_info "✓ Самоподписанный сертификат создан"
    fi
fi

#############################################
# Настройка PHP
#############################################

print_step "Настройка PHP..."

PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
PHP_INI="/etc/php/${PHP_VERSION}/apache2/php.ini"

# Увеличение лимитов для ZoneMinder
sed -i "s/^memory_limit = .*/memory_limit = 512M/" "$PHP_INI"
sed -i "s/^upload_max_filesize = .*/upload_max_filesize = 64M/" "$PHP_INI"
sed -i "s/^post_max_size = .*/post_max_size = 64M/" "$PHP_INI"
sed -i "s/^max_execution_time = .*/max_execution_time = 300/" "$PHP_INI"
sed -i "s/^;date.timezone =.*/date.timezone = ${TIMEZONE//\//\\/}/" "$PHP_INI"

#############################################
# zmeventnotification (опционально)
#############################################

if [ "$INSTALL_EVENT_NOTIFICATION" = true ]; then
    print_step "Установка zmeventnotification..."
    
    # Зависимости Perl
    apt-get install -y \
        libconfig-inifiles-perl \
        libcrypt-mysql-perl \
        liblwp-protocol-https-perl \
        libnet-mqtt-simple-perl \
        libpath-tiny-perl \
        libtry-tiny-perl \
        libjson-maybexs-perl \
        liburi-perl \
        libwww-perl \
        libgetopt-long-descriptive-perl
    
    # Клонирование репозитория
    cd /opt
    if [ ! -d "zmeventnotification" ]; then
        git clone https://github.com/ZoneMinder/zmeventnotification.git
    fi
    cd zmeventnotification
    
    # Установка
    ./install.sh --install-es --install-hook --install-config --no-interactive
    
    # Копирование конфигурации
    cp /etc/zm/zmeventnotification.ini /etc/zm/zmeventnotification.ini.bak
    
    # Настройка конфигурации
    cat > /etc/zm/zmeventnotification.ini << 'EOCONFIG'
[general]
secrets=/etc/zm/secrets.ini
base_data_path=/var/lib/zmeventnotification

[network]
port=9000

[auth]
enable=yes
timeout=20

[push]
use_api_push=yes

[fcm]
# Закомментируйте если не используете Firebase
#fcm_api_key=

[mqtt]
enable=no
#server=127.0.0.1
#username=
#password=

[ssl]
enable=no
#cert=/etc/apache2/ssl/zoneminder.crt
#key=/etc/apache2/ssl/zoneminder.key

[hooks]
hook_on_event_start=/var/lib/zmeventnotification/bin/zm_event_start.sh
hook_on_event_end=/var/lib/zmeventnotification/bin/zm_event_end.sh
EOCONFIG

    # Создание secrets.ini
    cat > /etc/zm/secrets.ini << EOF
[secrets]
ZM_USER=admin
ZM_PASSWORD=admin
ZM_PORTAL=http://localhost/zm
ZM_API_PORTAL=http://localhost/zm/api
EOF

    chmod 600 /etc/zm/secrets.ini
    chown www-data:www-data /etc/zm/secrets.ini
    
    print_info "✓ zmeventnotification установлен"
fi

#############################################
# ML детекция (опционально)
#############################################

if [ "$INSTALL_ML" = true ]; then
    print_step "Установка ML детекции..."
    
    # Зависимости Python для ML
    apt-get install -y \
        python3 python3-pip python3-venv \
        python3-opencv python3-numpy python3-scipy \
        python3-pycryptodome
    
    # Создание виртуального окружения
    python3 -m venv /opt/zm-ml-venv
    source /opt/zm-ml-venv/bin/activate
    
    # Установка Python зависимостей
    pip install --upgrade pip
    pip install \
        opencv-python-headless \
        numpy \
        requests \
        pyyaml \
        face_recognition \
        shapely
    
    deactivate
    
    # Скачивание YOLO моделей
    mkdir -p /var/lib/zmeventnotification/models/yolov4
    cd /var/lib/zmeventnotification/models/yolov4
    
    if [ ! -f "yolov4.weights" ]; then
        print_info "Скачивание YOLO модели (это может занять время)..."
        wget -q --show-progress https://github.com/AlexeyAB/darknet/releases/download/yolov4/yolov4.weights
    fi
    
    if [ ! -f "yolov4.cfg" ]; then
        wget -q https://raw.githubusercontent.com/AlexeyAB/darknet/master/cfg/yolov4.cfg
    fi
    
    if [ ! -f "coco.names" ]; then
        wget -q https://raw.githubusercontent.com/pjreddie/darknet/master/data/coco.names
    fi
    
    chown -R www-data:www-data /var/lib/zmeventnotification
    
    # Настройка ML в конфигурации
    cat >> /etc/zm/zmeventnotification.ini << 'EOML'

[ml]
use_hooks=yes
ml_gateway=
ml_fallback_local=yes

[object]
use_object_detection=yes
object_detection_type=yolov4
object_framework=opencv
object_processor=cpu
object_config=/var/lib/zmeventnotification/models/yolov4/yolov4.cfg
object_weights=/var/lib/zmeventnotification/models/yolov4/yolov4.weights
object_labels=/var/lib/zmeventnotification/models/yolov4/coco.names
object_min_confidence=0.5
object_detection_pattern=(person|car|truck|bus|motorbike|bicycle)

[face]
use_face_detection=no

[alpr]
use_alpr=no
EOML
    
    print_info "✓ ML детекция установлена"
    print_warn "ML работает на CPU. Для GPU ускорения требуется CUDA."
fi

#############################################
# Prometheus Exporter (опционально)
#############################################

if [ "$INSTALL_PROMETHEUS_EXPORTER" = true ]; then
    print_step "Установка Prometheus exporter..."
    
    # Установка Python зависимостей
    apt-get install -y python3 python3-pip python3-venv
    
    # Создание виртуального окружения
    python3 -m venv /opt/zm-exporter-venv
    /opt/zm-exporter-venv/bin/pip install --upgrade pip
    /opt/zm-exporter-venv/bin/pip install prometheus_client requests pymysql
    
    # Создание exporter скрипта
    mkdir -p /opt/zoneminder-exporter
    
    cat > /opt/zoneminder-exporter/exporter.py << 'PYEOF'
#!/usr/bin/env python3
"""
ZoneMinder Prometheus Exporter
"""

import time
import os
import pymysql
from prometheus_client import start_http_server, Gauge, Counter, Info

# Metrics
ZM_UP = Gauge('zoneminder_up', 'ZoneMinder is running')
ZM_MONITORS_TOTAL = Gauge('zoneminder_monitors_total', 'Total number of monitors')
ZM_MONITORS_ACTIVE = Gauge('zoneminder_monitors_active', 'Number of active monitors')
ZM_EVENTS_TOTAL = Counter('zoneminder_events_total', 'Total number of events', ['monitor_id', 'monitor_name'])
ZM_EVENTS_24H = Gauge('zoneminder_events_24h', 'Events in last 24 hours', ['monitor_id', 'monitor_name'])
ZM_STORAGE_USED = Gauge('zoneminder_storage_used_bytes', 'Storage used by events')
ZM_MONITOR_STATUS = Gauge('zoneminder_monitor_status', 'Monitor status (1=running)', ['monitor_id', 'monitor_name'])
ZM_MONITOR_FPS = Gauge('zoneminder_monitor_fps', 'Monitor FPS', ['monitor_id', 'monitor_name'])
ZM_DAEMON_STATUS = Gauge('zoneminder_daemon_status', 'Daemon status (1=running)', ['daemon'])

def get_db_connection():
    """Get database connection from ZoneMinder config."""
    config = {}
    for conf_file in ['/etc/zm/zm.conf', '/etc/zm/conf.d/01-database.conf']:
        if os.path.exists(conf_file):
            with open(conf_file) as f:
                for line in f:
                    line = line.strip()
                    if '=' in line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()
    
    return pymysql.connect(
        host=config.get('ZM_DB_HOST', 'localhost'),
        port=int(config.get('ZM_DB_PORT', 3306)),
        user=config.get('ZM_DB_USER', 'zmuser'),
        password=config.get('ZM_DB_PASS', ''),
        database=config.get('ZM_DB_NAME', 'zm'),
        cursorclass=pymysql.cursors.DictCursor
    )

def collect_metrics():
    """Collect ZoneMinder metrics."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Check if ZM is up
        cursor.execute("SELECT 1")
        ZM_UP.set(1)
        
        # Monitor counts
        cursor.execute("SELECT COUNT(*) as total, SUM(CASE WHEN Enabled=1 THEN 1 ELSE 0 END) as active FROM Monitors")
        row = cursor.fetchone()
        ZM_MONITORS_TOTAL.set(row['total'])
        ZM_MONITORS_ACTIVE.set(row['active'] or 0)
        
        # Per-monitor metrics
        cursor.execute("SELECT Id, Name, Enabled FROM Monitors")
        monitors = cursor.fetchall()
        
        for monitor in monitors:
            mid = str(monitor['Id'])
            mname = monitor['Name']
            
            ZM_MONITOR_STATUS.labels(monitor_id=mid, monitor_name=mname).set(monitor['Enabled'])
            
            # Events in 24h
            cursor.execute("""
                SELECT COUNT(*) as cnt FROM Events 
                WHERE MonitorId = %s AND StartDateTime > DATE_SUB(NOW(), INTERVAL 24 HOUR)
            """, (monitor['Id'],))
            events_24h = cursor.fetchone()['cnt']
            ZM_EVENTS_24H.labels(monitor_id=mid, monitor_name=mname).set(events_24h)
        
        # Storage usage
        cursor.execute("SELECT SUM(DiskSpace) as total FROM Events")
        storage = cursor.fetchone()['total'] or 0
        ZM_STORAGE_USED.set(storage)
        
        conn.close()
        
    except Exception as e:
        print(f"Error collecting metrics: {e}")
        ZM_UP.set(0)

def main():
    port = int(os.environ.get('EXPORTER_PORT', 9120))
    interval = int(os.environ.get('SCRAPE_INTERVAL', 30))
    
    print(f"Starting ZoneMinder exporter on port {port}")
    start_http_server(port)
    
    while True:
        collect_metrics()
        time.sleep(interval)

if __name__ == '__main__':
    main()
PYEOF

    chmod +x /opt/zoneminder-exporter/exporter.py
    
    # Systemd сервис для exporter
    cat > /etc/systemd/system/zoneminder-exporter.service << EOF
[Unit]
Description=ZoneMinder Prometheus Exporter
After=zoneminder.service

[Service]
Type=simple
User=www-data
Group=www-data
Environment=EXPORTER_PORT=${PROMETHEUS_EXPORTER_PORT}
ExecStart=/opt/zm-exporter-venv/bin/python /opt/zoneminder-exporter/exporter.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable --now zoneminder-exporter
    
    print_info "✓ Prometheus exporter установлен на порту ${PROMETHEUS_EXPORTER_PORT}"
fi

#############################################
# Настройка автоочистки старых событий
#############################################

print_step "Настройка автоочистки событий..."

cat > /etc/cron.daily/zoneminder-cleanup << EOF
#!/bin/bash
# Удаление событий старше ${RETENTION_DAYS} дней
/usr/bin/zmaudit.pl -e ${RETENTION_DAYS} -r 2>&1 | logger -t zoneminder-cleanup
EOF

chmod +x /etc/cron.daily/zoneminder-cleanup

#############################################
# Запуск сервисов
#############################################

print_step "Запуск сервисов..."

systemctl daemon-reload

# Перезапуск Apache
systemctl enable apache2
systemctl restart apache2

# Запуск ZoneMinder
systemctl enable zoneminder
systemctl start zoneminder

# Ожидание запуска
sleep 5

#############################################
# Проверка статуса
#############################################

print_step "Проверка статуса сервисов..."

check_service() {
    local service=$1
    if systemctl is-active --quiet "$service"; then
        print_info "✓ ${service} запущен"
        return 0
    else
        print_error "✗ ${service} не запущен"
        return 1
    fi
}

FAILED=false

check_service apache2 || FAILED=true
check_service zoneminder || FAILED=true
[ "$USE_EXTERNAL_DB" = false ] && { check_service mariadb || FAILED=true; }
[ "$INSTALL_PROMETHEUS_EXPORTER" = true ] && { check_service zoneminder-exporter || FAILED=true; }

if [ "$FAILED" = true ]; then
    print_error ""
    print_error "Некоторые сервисы не запустились. Проверьте логи:"
    print_error "  journalctl -u zoneminder -n 50"
    print_error "  journalctl -u apache2 -n 50"
    exit 1
fi

#############################################
# Сохранение учётных данных
#############################################

CREDENTIALS_FILE="/root/zoneminder-credentials.txt"

cat > "$CREDENTIALS_FILE" << EOF
ZoneMinder Installation Credentials
====================================
Date: $(date)

Web Interface:
  URL: $([ "$ENABLE_SSL" = true ] && echo "https://${DOMAIN}/zm" || echo "http://${DOMAIN}/zm")
  Default user: admin
  Default pass: admin

Database:
  Host: ${DB_HOST}
  Port: ${DB_PORT}
  Database: ${DB_NAME}
  User: ${DB_USER}
  Password: ${DB_PASSWORD}

Storage:
  Events path: ${STORAGE_PATH}
  Retention: ${RETENTION_DAYS} days

EOF

[ "$INSTALL_PROMETHEUS_EXPORTER" = true ] && cat >> "$CREDENTIALS_FILE" << EOF
Prometheus Exporter:
  URL: http://localhost:${PROMETHEUS_EXPORTER_PORT}/metrics

EOF

chmod 600 "$CREDENTIALS_FILE"
print_info "Учётные данные сохранены в: ${CREDENTIALS_FILE}"

#############################################
# Итоговая информация
#############################################

echo ""
echo "=============================================="
print_info "✓ Установка ZoneMinder завершена!"
echo "=============================================="
echo ""

IP_ADDR=$(hostname -I | awk '{print $1}')

print_info "Веб-интерфейс:"
if [ "$ENABLE_SSL" = true ]; then
    print_info "  https://${DOMAIN}/zm"
else
    print_info "  http://${DOMAIN}/zm"
fi
print_info "  http://${IP_ADDR}/zm (локально)"
print_info ""
print_info "Логин по умолчанию:"
print_info "  Пользователь: admin"
print_info "  Пароль: admin"
print_warn "  ⚠ Обязательно смените пароль после первого входа!"

echo ""
print_info "Конфигурация:"
print_info "  ZoneMinder config: /etc/zm/zm.conf"
print_info "  Database config:   /etc/zm/conf.d/01-database.conf"
print_info "  Apache config:     /etc/apache2/sites-available/zoneminder.conf"
print_info "  Storage:           ${STORAGE_PATH}"

echo ""
print_info "Управление сервисами:"
print_info "  systemctl status zoneminder"
print_info "  systemctl restart zoneminder"
print_info "  zmpkg.pl status  # статус демонов ZM"

echo ""
print_info "Добавление камер:"
print_info "  1. Откройте веб-интерфейс"
print_info "  2. Console → Add Monitor"
print_info "  3. Укажите Source Type и настройки камеры"

if [ "$INSTALL_PROMETHEUS_EXPORTER" = true ]; then
    echo ""
    print_info "Prometheus exporter:"
    print_info "  http://${IP_ADDR}:${PROMETHEUS_EXPORTER_PORT}/metrics"
    print_info ""
    print_info "Добавьте в prometheus.yml:"
    print_info "  - job_name: 'zoneminder'"
    print_info "    static_configs:"
    print_info "      - targets: ['${IP_ADDR}:${PROMETHEUS_EXPORTER_PORT}']"
fi

if [ "$INSTALL_EVENT_NOTIFICATION" = true ]; then
    echo ""
    print_info "Event Notification Server:"
    print_info "  Порт: 9000 (WebSocket)"
    print_info "  Конфиг: /etc/zm/zmeventnotification.ini"
fi

if [ "$INSTALL_ML" = true ]; then
    echo ""
    print_info "ML Detection:"
    print_info "  Модель: YOLOv4"
    print_info "  Процессор: CPU"
    print_warn "  Для GPU требуется настройка CUDA"
fi

echo ""

