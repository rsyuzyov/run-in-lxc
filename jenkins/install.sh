#!/bin/bash

#############################################
# Jenkins Installation Script for LXC
# Установка Jenkins CI/CD сервера в LXC контейнер
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
JENKINS_VERSION="lts"
JENKINS_PORT=8080
ADMIN_PASSWORD=""
JAVA_VERSION="17"
INSTALL_NGINX=false
DOMAIN=""
SSL=false
LETSENCRYPT=false
EMAIL=""
PLUGINS_FILE=""
INSTALL_DEFAULT_PLUGINS=true
PROMETHEUS=false
JCASC=false
JCASC_FILE=""
CHECK_ONLY=false

# Минимальные требования
MIN_RAM_MB=4096
MIN_DISK_GB=20
MIN_CPU=4

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

Установка Jenkins CI/CD сервера в LXC контейнер.

Опции:
  --version VERSION       Версия Jenkins: lts, weekly или номер версии (по умолчанию: lts)
  --port PORT             HTTP порт (по умолчанию: 8080)
  --admin-password PASS   Пароль администратора (по умолчанию: авто-генерация)
  --java-version VER      Версия OpenJDK: 11, 17, 21 (по умолчанию: 17)
  
Nginx и SSL:
  --with-nginx            Установить Nginx как reverse proxy
  --domain DOMAIN         Доменное имя для виртуального хоста
  --ssl                   Настроить SSL (самоподписанный сертификат)
  --letsencrypt           Получить сертификат Let's Encrypt (требует --domain и --email)
  --email EMAIL           Email для Let's Encrypt
  
Плагины:
  --plugins FILE          Файл со списком плагинов для установки
  --no-default-plugins    Не устанавливать плагины по умолчанию
  --prometheus            Установить плагин Prometheus metrics
  
Configuration as Code:
  --jcasc                 Включить Jenkins Configuration as Code
  --jcasc-file FILE       Путь к файлу конфигурации JCasC (YAML)
  
Прочее:
  --check                 Только проверка системных требований
  --help                  Показать эту справку

Примеры:
  # Базовая установка
  $0

  # С Nginx и SSL
  $0 --with-nginx --domain jenkins.example.com --ssl

  # С Let's Encrypt
  $0 --with-nginx --domain jenkins.example.com --letsencrypt --email admin@example.com

  # С кастомными плагинами и JCasC
  $0 --plugins plugins.txt --jcasc --jcasc-file jenkins.yaml

  # Проверка системных требований
  $0 --check

Системные требования:
  - CPU: ${MIN_CPU}+ ядер
  - RAM: ${MIN_RAM_MB}+ MB
  - Диск: ${MIN_DISK_GB}+ GB
  - ОС: Debian 11+/Ubuntu 20.04+

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            JENKINS_VERSION="$2"
            shift 2
            ;;
        --port)
            JENKINS_PORT="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --java-version)
            JAVA_VERSION="$2"
            shift 2
            ;;
        --with-nginx)
            INSTALL_NGINX=true
            shift
            ;;
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --ssl)
            SSL=true
            shift
            ;;
        --letsencrypt)
            LETSENCRYPT=true
            SSL=true
            shift
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --plugins)
            PLUGINS_FILE="$2"
            shift 2
            ;;
        --no-default-plugins)
            INSTALL_DEFAULT_PLUGINS=false
            shift
            ;;
        --prometheus)
            PROMETHEUS=true
            shift
            ;;
        --jcasc)
            JCASC=true
            shift
            ;;
        --jcasc-file)
            JCASC_FILE="$2"
            shift 2
            ;;
        --check)
            CHECK_ONLY=true
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

# Определение дистрибутива
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    else
        print_error "Не удалось определить дистрибутив"
        exit 1
    fi
    
    case $OS in
        debian|ubuntu)
            print_info "Обнаружена ОС: $OS $VERSION ($CODENAME)"
            ;;
        *)
            print_error "Неподдерживаемый дистрибутив: $OS"
            print_error "Поддерживаются: Debian, Ubuntu"
            exit 1
            ;;
    esac
}

# Проверка системных требований
check_requirements() {
    print_step "Проверка системных требований..."
    
    local errors=0
    
    # Проверка CPU
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -ge "$MIN_CPU" ]; then
        print_info "✓ CPU: $cpu_cores ядер (требуется: $MIN_CPU+)"
    else
        print_warn "✗ CPU: $cpu_cores ядер (требуется: $MIN_CPU+)"
        ((errors++))
    fi
    
    # Проверка RAM
    local ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$ram_mb" -ge "$MIN_RAM_MB" ]; then
        print_info "✓ RAM: ${ram_mb}MB (требуется: ${MIN_RAM_MB}MB+)"
    else
        print_warn "✗ RAM: ${ram_mb}MB (требуется: ${MIN_RAM_MB}MB+)"
        ((errors++))
    fi
    
    # Проверка диска
    local disk_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,""); print $4}')
    if [ "$disk_gb" -ge "$MIN_DISK_GB" ]; then
        print_info "✓ Диск: ${disk_gb}GB свободно (требуется: ${MIN_DISK_GB}GB+)"
    else
        print_warn "✗ Диск: ${disk_gb}GB свободно (требуется: ${MIN_DISK_GB}GB+)"
        ((errors++))
    fi
    
    # Проверка архитектуры
    local arch=$(uname -m)
    case $arch in
        x86_64|aarch64)
            print_info "✓ Архитектура: $arch"
            ;;
        *)
            print_error "✗ Неподдерживаемая архитектура: $arch"
            ((errors++))
            ;;
    esac
    
    if [ "$errors" -gt 0 ]; then
        print_warn "Обнаружено $errors предупреждений о системных требованиях"
        if [ "$CHECK_ONLY" = true ]; then
            exit 1
        fi
        echo ""
        read -p "Продолжить установку? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_info "✓ Все системные требования выполнены"
    fi
}

# Установка зависимостей
install_dependencies() {
    print_step "Установка зависимостей..."
    
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        wget \
        fontconfig
}

# Установка Java
install_java() {
    print_step "Установка OpenJDK ${JAVA_VERSION}..."
    
    case $JAVA_VERSION in
        11|17|21)
            apt-get install -y "openjdk-${JAVA_VERSION}-jdk-headless"
            ;;
        *)
            print_error "Неподдерживаемая версия Java: $JAVA_VERSION"
            print_error "Доступные версии: 11, 17, 21"
            exit 1
            ;;
    esac
    
    # Проверка
    local java_ver=$(java -version 2>&1 | head -n1)
    print_info "Установлена Java: $java_ver"
}

# Установка Jenkins
install_jenkins() {
    print_step "Установка Jenkins..."
    
    # Добавление ключа репозитория
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
        gpg --dearmor -o /usr/share/keyrings/jenkins-keyring.gpg
    
    # Добавление репозитория
    case $JENKINS_VERSION in
        lts|stable)
            echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | \
                tee /etc/apt/sources.list.d/jenkins.list > /dev/null
            ;;
        weekly|latest)
            echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian binary/" | \
                tee /etc/apt/sources.list.d/jenkins.list > /dev/null
            ;;
        *)
            # Конкретная версия - используем LTS репозиторий
            echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.gpg] https://pkg.jenkins.io/debian-stable binary/" | \
                tee /etc/apt/sources.list.d/jenkins.list > /dev/null
            ;;
    esac
    
    apt-get update
    
    # Установка
    if [ "$JENKINS_VERSION" = "lts" ] || [ "$JENKINS_VERSION" = "stable" ] || \
       [ "$JENKINS_VERSION" = "weekly" ] || [ "$JENKINS_VERSION" = "latest" ]; then
        apt-get install -y jenkins
    else
        apt-get install -y "jenkins=${JENKINS_VERSION}"
    fi
    
    # Настройка порта
    if [ "$JENKINS_PORT" != "8080" ]; then
        print_info "Настройка порта: $JENKINS_PORT"
        
        # Создание override для systemd
        mkdir -p /etc/systemd/system/jenkins.service.d
        cat > /etc/systemd/system/jenkins.service.d/override.conf << EOF
[Service]
Environment="JENKINS_PORT=$JENKINS_PORT"
EOF
        systemctl daemon-reload
    fi
    
    # Проверка версии
    local jenkins_ver=$(dpkg -l jenkins | awk '/jenkins/{print $3}')
    print_info "Установлен Jenkins: $jenkins_ver"
}

# Настройка пароля администратора
setup_admin_password() {
    print_step "Настройка пароля администратора..."
    
    # Генерация пароля если не указан
    if [ -z "$ADMIN_PASSWORD" ]; then
        ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        print_info "Сгенерирован пароль администратора"
    fi
    
    # Сохранение учётных данных
    mkdir -p /root/jenkins-credentials
    cat > /root/jenkins-credentials/admin.txt << EOF
Jenkins Administrator Credentials
==================================
URL: http://$(hostname -I | awk '{print $1}'):${JENKINS_PORT}
Username: admin
Password: ${ADMIN_PASSWORD}
Generated: $(date)
EOF
    chmod 600 /root/jenkins-credentials/admin.txt
    
    print_info "Учётные данные сохранены: /root/jenkins-credentials/admin.txt"
}

# Установка плагинов по умолчанию
get_default_plugins() {
    cat << 'EOF'
# Основные
git
workflow-aggregator
pipeline-stage-view
blueocean

# Docker
docker-workflow
docker-plugin

# Kubernetes
kubernetes

# Git хостинги
gitlab-plugin
github
gitea

# Утилиты
credentials
credentials-binding
ssh-credentials
plain-credentials
timestamper
ws-cleanup
build-timeout
antisamy-markup-formatter

# UI
dark-theme
locale

# Configuration as Code
configuration-as-code
EOF
}

# Установка плагинов
install_plugins() {
    print_step "Установка плагинов..."
    
    # Ждём запуска Jenkins
    print_info "Ожидание запуска Jenkins..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${JENKINS_PORT}/login" | grep -q "200\|403"; then
            print_info "Jenkins запущен"
            break
        fi
        sleep 5
        ((attempt++))
        echo -n "."
    done
    echo ""
    
    if [ $attempt -eq $max_attempts ]; then
        print_warn "Jenkins не отвечает, плагины можно установить позже"
        return 1
    fi
    
    # Получение initial admin password
    local init_password=""
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        init_password=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    fi
    
    # Создание списка плагинов
    local plugins_list=""
    
    if [ "$INSTALL_DEFAULT_PLUGINS" = true ]; then
        plugins_list=$(get_default_plugins | grep -v "^#" | grep -v "^$")
    fi
    
    # Добавление плагинов из файла
    if [ -n "$PLUGINS_FILE" ] && [ -f "$PLUGINS_FILE" ]; then
        plugins_list="$plugins_list"$'\n'"$(cat "$PLUGINS_FILE" | grep -v "^#" | grep -v "^$")"
    fi
    
    # Prometheus плагин
    if [ "$PROMETHEUS" = true ]; then
        plugins_list="$plugins_list"$'\n'"prometheus"
    fi
    
    # JCasC плагин (если не включён по умолчанию)
    if [ "$JCASC" = true ]; then
        plugins_list="$plugins_list"$'\n'"configuration-as-code"
    fi
    
    # Установка через jenkins-cli
    if [ -n "$plugins_list" ]; then
        print_info "Загрузка jenkins-cli.jar..."
        
        local cli_jar="/tmp/jenkins-cli.jar"
        local jenkins_url="http://localhost:${JENKINS_PORT}"
        
        # Скачивание CLI
        wget -q "${jenkins_url}/jnlpJars/jenkins-cli.jar" -O "$cli_jar" || {
            print_warn "Не удалось загрузить jenkins-cli.jar"
            print_warn "Плагины можно установить вручную через веб-интерфейс"
            
            # Сохраняем список плагинов для ручной установки
            echo "$plugins_list" | sort -u > /root/jenkins-credentials/plugins-to-install.txt
            print_info "Список плагинов: /root/jenkins-credentials/plugins-to-install.txt"
            return 1
        }
        
        print_info "Установка плагинов (это может занять несколько минут)..."
        
        # Установка каждого плагина
        echo "$plugins_list" | sort -u | while read -r plugin; do
            if [ -n "$plugin" ]; then
                echo -n "  Установка $plugin... "
                if java -jar "$cli_jar" -s "$jenkins_url" -auth "admin:${init_password}" install-plugin "$plugin" -deploy 2>/dev/null; then
                    echo "OK"
                else
                    echo "SKIP (возможно уже установлен)"
                fi
            fi
        done
        
        # Перезапуск Jenkins для применения плагинов
        print_info "Перезапуск Jenkins для применения плагинов..."
        java -jar "$cli_jar" -s "$jenkins_url" -auth "admin:${init_password}" safe-restart 2>/dev/null || \
            systemctl restart jenkins
        
        rm -f "$cli_jar"
    fi
}

# Настройка JCasC
setup_jcasc() {
    if [ "$JCASC" != true ]; then
        return 0
    fi
    
    print_step "Настройка Jenkins Configuration as Code..."
    
    local jcasc_dir="/var/lib/jenkins/casc_configs"
    mkdir -p "$jcasc_dir"
    
    if [ -n "$JCASC_FILE" ] && [ -f "$JCASC_FILE" ]; then
        cp "$JCASC_FILE" "$jcasc_dir/jenkins.yaml"
        print_info "Скопирован файл конфигурации: $JCASC_FILE"
    else
        # Создание базовой конфигурации
        cat > "$jcasc_dir/jenkins.yaml" << EOF
jenkins:
  systemMessage: "Jenkins configured by JCasC"
  numExecutors: 2
  mode: NORMAL
  scmCheckoutRetryCount: 3
  
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          name: "Administrator"
          password: "${ADMIN_PASSWORD}"
          
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false

  globalNodeProperties:
    - envVars:
        env:
          - key: "JAVA_HOME"
            value: "/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64"

unclassified:
  location:
    url: "http://$(hostname -I | awk '{print $1}'):${JENKINS_PORT}/"
    adminAddress: "${EMAIL:-admin@localhost}"
EOF
        print_info "Создана базовая конфигурация JCasC"
    fi
    
    chown -R jenkins:jenkins "$jcasc_dir"
    
    # Добавление переменной окружения для JCasC
    mkdir -p /etc/systemd/system/jenkins.service.d
    cat >> /etc/systemd/system/jenkins.service.d/override.conf << EOF
Environment="CASC_JENKINS_CONFIG=$jcasc_dir"
EOF
    
    systemctl daemon-reload
    print_info "JCasC настроен: $jcasc_dir/jenkins.yaml"
}

# Установка Nginx
install_nginx() {
    if [ "$INSTALL_NGINX" != true ]; then
        return 0
    fi
    
    print_step "Установка и настройка Nginx..."
    
    apt-get install -y nginx
    
    # Определение имени сервера
    local server_name="${DOMAIN:-$(hostname -I | awk '{print $1}')}"
    
    # Создание конфигурации
    cat > /etc/nginx/sites-available/jenkins << EOF
upstream jenkins {
    keepalive 32;
    server 127.0.0.1:${JENKINS_PORT};
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name ${server_name};

    # Redirect to HTTPS if SSL is enabled
    $(if [ "$SSL" = true ]; then echo "return 301 https://\$server_name\$request_uri;"; fi)
    
    $(if [ "$SSL" != true ]; then cat << 'NGINX_HTTP'
    location / {
        proxy_pass http://jenkins;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        
        proxy_max_temp_file_size 0;
        proxy_connect_timeout 150;
        proxy_send_timeout 100;
        proxy_read_timeout 100;
        proxy_buffering off;
        proxy_request_buffering off;
        
        client_max_body_size 100m;
    }
NGINX_HTTP
    fi)
}

$(if [ "$SSL" = true ]; then cat << NGINX_SSL
server {
    listen 443 ssl http2;
    server_name ${server_name};
    
    ssl_certificate /etc/nginx/ssl/jenkins.crt;
    ssl_certificate_key /etc/nginx/ssl/jenkins.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    location / {
        proxy_pass http://jenkins;
        proxy_http_version 1.1;
        
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        
        proxy_max_temp_file_size 0;
        proxy_connect_timeout 150;
        proxy_send_timeout 100;
        proxy_read_timeout 100;
        proxy_buffering off;
        proxy_request_buffering off;
        
        client_max_body_size 100m;
    }
}
NGINX_SSL
fi)
EOF

    # Активация сайта
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
    
    # SSL сертификаты
    if [ "$SSL" = true ]; then
        setup_ssl
    fi
    
    # Проверка конфигурации
    nginx -t
    
    systemctl enable nginx
    systemctl restart nginx
    
    print_info "✓ Nginx настроен"
}

# Настройка SSL
setup_ssl() {
    print_step "Настройка SSL..."
    
    mkdir -p /etc/nginx/ssl
    
    if [ "$LETSENCRYPT" = true ]; then
        if [ -z "$DOMAIN" ]; then
            print_error "Для Let's Encrypt требуется указать --domain"
            exit 1
        fi
        if [ -z "$EMAIL" ]; then
            print_error "Для Let's Encrypt требуется указать --email"
            exit 1
        fi
        
        print_info "Получение сертификата Let's Encrypt..."
        
        apt-get install -y certbot python3-certbot-nginx
        
        # Временно запускаем nginx без SSL для проверки домена
        systemctl start nginx || true
        
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect
        
        # Обновление путей к сертификатам
        sed -i "s|/etc/nginx/ssl/jenkins.crt|/etc/letsencrypt/live/${DOMAIN}/fullchain.pem|g" /etc/nginx/sites-available/jenkins
        sed -i "s|/etc/nginx/ssl/jenkins.key|/etc/letsencrypt/live/${DOMAIN}/privkey.pem|g" /etc/nginx/sites-available/jenkins
        
        # Автообновление сертификатов
        systemctl enable certbot.timer
        
        print_info "✓ Let's Encrypt сертификат получен"
    else
        print_info "Генерация самоподписанного сертификата..."
        
        local cn="${DOMAIN:-jenkins.local}"
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/jenkins.key \
            -out /etc/nginx/ssl/jenkins.crt \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=Jenkins/CN=${cn}"
        
        chmod 600 /etc/nginx/ssl/jenkins.key
        
        print_info "✓ Самоподписанный сертификат создан"
    fi
}

# Настройка firewall (если установлен)
setup_firewall() {
    if command -v ufw &> /dev/null; then
        print_step "Настройка firewall (UFW)..."
        
        ufw allow "$JENKINS_PORT"/tcp comment "Jenkins HTTP"
        
        if [ "$INSTALL_NGINX" = true ]; then
            ufw allow 80/tcp comment "Nginx HTTP"
            if [ "$SSL" = true ]; then
                ufw allow 443/tcp comment "Nginx HTTPS"
            fi
        fi
        
        print_info "✓ Firewall настроен"
    fi
}

# Запуск Jenkins
start_jenkins() {
    print_step "Запуск Jenkins..."
    
    systemctl daemon-reload
    systemctl enable jenkins
    systemctl start jenkins
    
    # Ожидание запуска
    print_info "Ожидание запуска Jenkins..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if systemctl is-active --quiet jenkins; then
            if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${JENKINS_PORT}/login" 2>/dev/null | grep -q "200\|403"; then
                print_info "✓ Jenkins запущен"
                return 0
            fi
        fi
        sleep 5
        ((attempt++))
        echo -n "."
    done
    echo ""
    
    print_error "Jenkins не запустился в течение ожидаемого времени"
    print_error "Проверьте логи: journalctl -u jenkins -n 100"
    exit 1
}

# Вывод итоговой информации
print_summary() {
    local ip=$(hostname -I | awk '{print $1}')
    local url=""
    
    if [ "$INSTALL_NGINX" = true ]; then
        if [ "$SSL" = true ]; then
            url="https://${DOMAIN:-$ip}"
        else
            url="http://${DOMAIN:-$ip}"
        fi
    else
        url="http://${ip}:${JENKINS_PORT}"
    fi
    
    # Получение initial admin password
    local init_password=""
    if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
        init_password=$(cat /var/lib/jenkins/secrets/initialAdminPassword)
    fi
    
    echo ""
    echo "=============================================="
    print_info "Jenkins успешно установлен!"
    echo "=============================================="
    echo ""
    print_info "URL: $url"
    print_info "Порт: $JENKINS_PORT"
    print_info "Java: OpenJDK $JAVA_VERSION"
    
    if [ -n "$init_password" ]; then
        echo ""
        print_info "Initial Admin Password: $init_password"
        print_info "(также в файле /var/lib/jenkins/secrets/initialAdminPassword)"
    fi
    
    if [ -n "$ADMIN_PASSWORD" ]; then
        echo ""
        print_info "Учётные данные: /root/jenkins-credentials/admin.txt"
    fi
    
    if [ "$JCASC" = true ]; then
        echo ""
        print_info "JCasC конфигурация: /var/lib/jenkins/casc_configs/jenkins.yaml"
    fi
    
    echo ""
    print_info "Управление сервисом:"
    echo "  systemctl status jenkins   - статус"
    echo "  systemctl restart jenkins  - перезапуск"
    echo "  journalctl -u jenkins -f   - логи"
    
    echo ""
    print_info "Конфигурация:"
    echo "  /var/lib/jenkins/          - домашняя директория"
    echo "  /etc/default/jenkins       - переменные окружения"
    
    if [ "$INSTALL_NGINX" = true ]; then
        echo ""
        print_info "Nginx:"
        echo "  /etc/nginx/sites-available/jenkins - конфигурация"
        echo "  systemctl restart nginx            - перезапуск"
    fi
    
    if [ "$PROMETHEUS" = true ]; then
        echo ""
        print_info "Prometheus метрики: ${url}/prometheus/"
    fi
    
    echo ""
    print_info "Первоначальная настройка:"
    echo "  1. Откройте $url в браузере"
    echo "  2. Введите Initial Admin Password"
    echo "  3. Установите рекомендуемые плагины или выберите свои"
    echo "  4. Создайте пользователя администратора"
    echo ""
}

# Основная функция
main() {
    echo ""
    echo "=============================================="
    echo "   Jenkins Installation Script for LXC"
    echo "=============================================="
    echo ""
    
    detect_os
    check_requirements
    
    if [ "$CHECK_ONLY" = true ]; then
        print_info "Проверка завершена"
        exit 0
    fi
    
    install_dependencies
    install_java
    install_jenkins
    setup_admin_password
    setup_jcasc
    start_jenkins
    install_plugins
    install_nginx
    setup_firewall
    
    # Финальный перезапуск если были изменения
    if [ "$JCASC" = true ] || [ "$INSTALL_NGINX" = true ]; then
        systemctl restart jenkins
        sleep 10
    fi
    
    print_summary
}

# Запуск
main

