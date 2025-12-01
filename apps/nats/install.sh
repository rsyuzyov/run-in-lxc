#!/bin/bash

#############################################
# NATS Server Installation Script for LXC
# Установка NATS Server в LXC контейнер
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
NATS_VERSION="latest"
NATS_PORT=4222
NATS_HTTP_PORT=8222
DATA_DIR="/var/lib/nats-server"
NATS_USER="nats"

# JetStream
JETSTREAM=false
JS_MAX_MEM="1G"
JS_MAX_FILE="10G"

# Кластер
CLUSTER=false
CLUSTER_NAME="nats-cluster"
CLUSTER_PORT=6222
ROUTES=""
SERVER_NAME=""

# Leaf Nodes
LEAFNODES=false
LEAFNODE_PORT=7422
LEAFNODE_REMOTES=""

# TLS
TLS=false
TLS_CERT=""
TLS_KEY=""
TLS_CA=""
TLS_VERIFY=false

# Аутентификация
AUTH_TOKEN=""
AUTH_USER=""
AUTH_PASSWORD=""
ACCOUNTS_FILE=""

# WebSocket
WEBSOCKET=false
WS_PORT=8080
WS_NO_TLS=false

# MQTT
MQTT=false
MQTT_PORT=1883

# Лимиты
MAX_CONNECTIONS=""
MAX_PAYLOAD=""

# Мониторинг
PROMETHEUS=false

# Nginx
INSTALL_NGINX=false
DOMAIN=""
SSL=false
LETSENCRYPT=false
EMAIL=""

# NATS CLI
INSTALL_CLI=true

# Прочее
CHECK_ONLY=false

# Минимальные требования
MIN_RAM_MB=512
MIN_DISK_GB=2
MIN_CPU=1

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

Установка NATS Server в LXC контейнер.

Основные опции:
  --version VERSION       Версия NATS Server (по умолчанию: latest)
  --port PORT             Клиентский порт (по умолчанию: 4222)
  --http-port PORT        HTTP мониторинг порт (по умолчанию: 8222)
  --data-dir PATH         Директория данных (по умолчанию: /var/lib/nats-server)
  --no-cli                Не устанавливать NATS CLI
  --check                 Только проверка системных требований

JetStream (персистентность):
  --jetstream             Включить JetStream
  --js-max-mem SIZE       Лимит памяти для JetStream (по умолчанию: 1G)
  --js-max-file SIZE      Лимит файлового хранилища (по умолчанию: 10G)

Кластеризация:
  --cluster               Включить кластерный режим
  --cluster-name NAME     Имя кластера (по умолчанию: nats-cluster)
  --cluster-port PORT     Порт кластера (по умолчанию: 6222)
  --routes ROUTES         Маршруты к другим узлам (через запятую)
  --server-name NAME      Имя сервера в кластере

Leaf Nodes:
  --leafnodes             Включить leaf node listener
  --leafnode-port PORT    Порт для leaf nodes (по умолчанию: 7422)
  --leafnode-remotes URLS Удалённые серверы для подключения (через запятую)

TLS/SSL:
  --tls                   Включить TLS для клиентских соединений
  --tls-cert PATH         Путь к сертификату
  --tls-key PATH          Путь к приватному ключу
  --tls-ca PATH           Путь к CA сертификату (для mTLS)
  --tls-verify            Требовать клиентские сертификаты

Аутентификация:
  --auth-token TOKEN      Простой токен аутентификации
  --auth-user USER        Имя пользователя
  --auth-password PASS    Пароль пользователя
  --accounts-file FILE    Файл конфигурации аккаунтов

WebSocket:
  --websocket             Включить WebSocket
  --ws-port PORT          Порт WebSocket (по умолчанию: 8080)
  --ws-no-tls             WebSocket без TLS

MQTT Bridge:
  --mqtt                  Включить MQTT
  --mqtt-port PORT        Порт MQTT (по умолчанию: 1883)

Лимиты:
  --max-connections N     Максимум соединений
  --max-payload SIZE      Максимальный размер сообщения (например: 8MB)

Мониторинг:
  --prometheus            Включить Prometheus endpoint (/metrics на http-port)

Nginx (reverse proxy):
  --with-nginx            Установить Nginx как reverse proxy
  --domain DOMAIN         Доменное имя
  --ssl                   Включить SSL (самоподписанный сертификат)
  --letsencrypt           Получить сертификат Let's Encrypt
  --email EMAIL           Email для Let's Encrypt

Примеры:
  # Базовая установка
  $0

  # С JetStream
  $0 --jetstream

  # С JetStream и мониторингом
  $0 --jetstream --prometheus

  # С аутентификацией
  $0 --jetstream --auth-user nats --auth-password SecurePass123

  # С TLS
  $0 --tls --tls-cert /path/to/cert.pem --tls-key /path/to/key.pem

  # Кластер (master)
  $0 --jetstream --cluster --cluster-name prod --server-name nats-1 \\
     --routes "nats://192.168.1.11:6222,nats://192.168.1.12:6222"

  # С WebSocket и MQTT
  $0 --jetstream --websocket --mqtt --prometheus

  # С leaf nodes
  $0 --jetstream --leafnodes --leafnode-remotes "nats://hub.example.com:7422"

Системные требования:
  - CPU: ${MIN_CPU}+ ядер
  - RAM: ${MIN_RAM_MB}+ MB (2GB+ с JetStream)
  - Диск: ${MIN_DISK_GB}+ GB (20GB+ с JetStream)
  - ОС: Debian 11+/Ubuntu 20.04+

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            NATS_VERSION="$2"
            shift 2
            ;;
        --port)
            NATS_PORT="$2"
            shift 2
            ;;
        --http-port)
            NATS_HTTP_PORT="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --no-cli)
            INSTALL_CLI=false
            shift
            ;;
        --jetstream)
            JETSTREAM=true
            shift
            ;;
        --js-max-mem)
            JS_MAX_MEM="$2"
            shift 2
            ;;
        --js-max-file)
            JS_MAX_FILE="$2"
            shift 2
            ;;
        --cluster)
            CLUSTER=true
            shift
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --cluster-port)
            CLUSTER_PORT="$2"
            shift 2
            ;;
        --routes)
            ROUTES="$2"
            shift 2
            ;;
        --server-name)
            SERVER_NAME="$2"
            shift 2
            ;;
        --leafnodes)
            LEAFNODES=true
            shift
            ;;
        --leafnode-port)
            LEAFNODE_PORT="$2"
            shift 2
            ;;
        --leafnode-remotes)
            LEAFNODE_REMOTES="$2"
            shift 2
            ;;
        --tls)
            TLS=true
            shift
            ;;
        --tls-cert)
            TLS_CERT="$2"
            shift 2
            ;;
        --tls-key)
            TLS_KEY="$2"
            shift 2
            ;;
        --tls-ca)
            TLS_CA="$2"
            shift 2
            ;;
        --tls-verify)
            TLS_VERIFY=true
            shift
            ;;
        --auth-token)
            AUTH_TOKEN="$2"
            shift 2
            ;;
        --auth-user)
            AUTH_USER="$2"
            shift 2
            ;;
        --auth-password)
            AUTH_PASSWORD="$2"
            shift 2
            ;;
        --accounts-file)
            ACCOUNTS_FILE="$2"
            shift 2
            ;;
        --websocket)
            WEBSOCKET=true
            shift
            ;;
        --ws-port)
            WS_PORT="$2"
            shift 2
            ;;
        --ws-no-tls)
            WS_NO_TLS=true
            shift
            ;;
        --mqtt)
            MQTT=true
            shift
            ;;
        --mqtt-port)
            MQTT_PORT="$2"
            shift 2
            ;;
        --max-connections)
            MAX_CONNECTIONS="$2"
            shift 2
            ;;
        --max-payload)
            MAX_PAYLOAD="$2"
            shift 2
            ;;
        --prometheus)
            PROMETHEUS=true
            shift
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

# Валидация параметров
validate_params() {
    # TLS требует сертификаты
    if [ "$TLS" = true ]; then
        if [ -z "$TLS_CERT" ] || [ -z "$TLS_KEY" ]; then
            print_error "TLS требует указания --tls-cert и --tls-key"
            exit 1
        fi
        if [ ! -f "$TLS_CERT" ]; then
            print_error "Файл сертификата не найден: $TLS_CERT"
            exit 1
        fi
        if [ ! -f "$TLS_KEY" ]; then
            print_error "Файл ключа не найден: $TLS_KEY"
            exit 1
        fi
    fi
    
    # Аутентификация по пользователю требует пароль
    if [ -n "$AUTH_USER" ] && [ -z "$AUTH_PASSWORD" ]; then
        print_error "Указан --auth-user, но не указан --auth-password"
        exit 1
    fi
    
    # Let's Encrypt требует домен и email
    if [ "$LETSENCRYPT" = true ]; then
        if [ -z "$DOMAIN" ]; then
            print_error "Let's Encrypt требует указания --domain"
            exit 1
        fi
        if [ -z "$EMAIL" ]; then
            print_error "Let's Encrypt требует указания --email"
            exit 1
        fi
    fi
    
    # Кластер требует server-name
    if [ "$CLUSTER" = true ] && [ -z "$SERVER_NAME" ]; then
        SERVER_NAME=$(hostname -s)
        print_warn "Имя сервера не указано, используется hostname: $SERVER_NAME"
    fi
}

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

# Определение архитектуры
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm7"
            ;;
        *)
            print_error "Неподдерживаемая архитектура: $arch"
            exit 1
            ;;
    esac
    print_info "Архитектура: $ARCH"
}

# Проверка системных требований
check_requirements() {
    print_step "Проверка системных требований..."
    
    local errors=0
    local min_ram=$MIN_RAM_MB
    local min_disk=$MIN_DISK_GB
    
    # Увеличиваем требования для JetStream
    if [ "$JETSTREAM" = true ]; then
        min_ram=2048
        min_disk=20
    fi
    
    # Проверка CPU
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -ge "$MIN_CPU" ]; then
        print_info "✓ CPU: $cpu_cores ядер (требуется: ${MIN_CPU}+)"
    else
        print_warn "✗ CPU: $cpu_cores ядер (требуется: ${MIN_CPU}+)"
        ((errors++))
    fi
    
    # Проверка RAM
    local ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$ram_mb" -ge "$min_ram" ]; then
        print_info "✓ RAM: ${ram_mb}MB (требуется: ${min_ram}MB+)"
    else
        print_warn "✗ RAM: ${ram_mb}MB (требуется: ${min_ram}MB+)"
        ((errors++))
    fi
    
    # Проверка диска
    local disk_gb=$(df -BG / | awk 'NR==2 {gsub(/G/,""); print $4}')
    if [ "$disk_gb" -ge "$min_disk" ]; then
        print_info "✓ Диск: ${disk_gb}GB свободно (требуется: ${min_disk}GB+)"
    else
        print_warn "✗ Диск: ${disk_gb}GB свободно (требуется: ${min_disk}GB+)"
        ((errors++))
    fi
    
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
        curl \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
        unzip \
        jq
}

# Получение последней версии NATS
get_latest_version() {
    local latest
    latest=$(curl -s https://api.github.com/repos/nats-io/nats-server/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    echo "$latest"
}

# Установка NATS Server
install_nats_server() {
    print_step "Установка NATS Server..."
    
    # Определение версии
    if [ "$NATS_VERSION" = "latest" ]; then
        NATS_VERSION=$(get_latest_version)
        print_info "Последняя версия: $NATS_VERSION"
    fi
    
    local download_url="https://github.com/nats-io/nats-server/releases/download/v${NATS_VERSION}/nats-server-v${NATS_VERSION}-linux-${ARCH}.tar.gz"
    local tmp_dir=$(mktemp -d)
    
    print_info "Загрузка NATS Server v${NATS_VERSION}..."
    wget -q "$download_url" -O "$tmp_dir/nats-server.tar.gz" || {
        print_error "Не удалось загрузить NATS Server"
        print_error "URL: $download_url"
        exit 1
    }
    
    print_info "Распаковка..."
    tar -xzf "$tmp_dir/nats-server.tar.gz" -C "$tmp_dir"
    
    # Установка бинарника
    cp "$tmp_dir/nats-server-v${NATS_VERSION}-linux-${ARCH}/nats-server" /usr/local/bin/
    chmod +x /usr/local/bin/nats-server
    
    # Очистка
    rm -rf "$tmp_dir"
    
    # Проверка
    local installed_version=$(/usr/local/bin/nats-server --version 2>&1 | head -n1)
    print_info "Установлен: $installed_version"
}

# Установка NATS CLI
install_nats_cli() {
    if [ "$INSTALL_CLI" != true ]; then
        return 0
    fi
    
    print_step "Установка NATS CLI..."
    
    # Получение последней версии CLI
    local cli_version
    cli_version=$(curl -s https://api.github.com/repos/nats-io/natscli/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    
    local download_url="https://github.com/nats-io/natscli/releases/download/v${cli_version}/nats-${cli_version}-linux-${ARCH}.tar.gz"
    local tmp_dir=$(mktemp -d)
    
    print_info "Загрузка NATS CLI v${cli_version}..."
    wget -q "$download_url" -O "$tmp_dir/nats-cli.tar.gz" || {
        print_warn "Не удалось загрузить NATS CLI, пропускаем..."
        return 0
    }
    
    tar -xzf "$tmp_dir/nats-cli.tar.gz" -C "$tmp_dir"
    cp "$tmp_dir/nats-${cli_version}-linux-${ARCH}/nats" /usr/local/bin/
    chmod +x /usr/local/bin/nats
    
    rm -rf "$tmp_dir"
    
    print_info "NATS CLI установлен: $(nats --version 2>&1)"
}

# Создание системного пользователя
create_system_user() {
    print_step "Создание системного пользователя..."
    
    if id "$NATS_USER" &>/dev/null; then
        print_info "Пользователь $NATS_USER уже существует"
    else
        useradd --system --no-create-home --shell /usr/sbin/nologin "$NATS_USER"
        print_info "Создан пользователь: $NATS_USER"
    fi
}

# Создание директорий
create_directories() {
    print_step "Создание директорий..."
    
    mkdir -p "$DATA_DIR"
    mkdir -p /etc/nats
    mkdir -p /var/log/nats
    mkdir -p /root/nats-credentials
    
    chown -R "$NATS_USER:$NATS_USER" "$DATA_DIR"
    chown -R "$NATS_USER:$NATS_USER" /var/log/nats
    
    print_info "Директория данных: $DATA_DIR"
}

# Генерация конфигурации
generate_config() {
    print_step "Генерация конфигурации..."
    
    local config_file="/etc/nats/nats-server.conf"
    
    cat > "$config_file" << EOF
# NATS Server Configuration
# Generated by install.sh on $(date)

# Имя сервера
$([ -n "$SERVER_NAME" ] && echo "server_name: $SERVER_NAME" || echo "# server_name: nats-server")

# Сетевые настройки
port: $NATS_PORT
http_port: $NATS_HTTP_PORT

# Логирование
log_file: /var/log/nats/nats-server.log
logtime: true
debug: false
trace: false

# Директория данных
$([ "$JETSTREAM" = true ] && echo "# JetStream хранилище в store_dir")

EOF

    # Лимиты
    if [ -n "$MAX_CONNECTIONS" ] || [ -n "$MAX_PAYLOAD" ]; then
        cat >> "$config_file" << EOF
# Лимиты
$([ -n "$MAX_CONNECTIONS" ] && echo "max_connections: $MAX_CONNECTIONS")
$([ -n "$MAX_PAYLOAD" ] && echo "max_payload: $MAX_PAYLOAD")

EOF
    fi

    # Аутентификация
    if [ -n "$AUTH_TOKEN" ]; then
        cat >> "$config_file" << EOF
# Аутентификация по токену
authorization {
    token: "$AUTH_TOKEN"
}

EOF
    elif [ -n "$AUTH_USER" ]; then
        cat >> "$config_file" << EOF
# Аутентификация по логину/паролю
authorization {
    user: "$AUTH_USER"
    password: "$AUTH_PASSWORD"
}

EOF
    elif [ -n "$ACCOUNTS_FILE" ] && [ -f "$ACCOUNTS_FILE" ]; then
        cat >> "$config_file" << EOF
# Аутентификация через файл аккаунтов
include "$ACCOUNTS_FILE"

EOF
    fi

    # TLS
    if [ "$TLS" = true ]; then
        cat >> "$config_file" << EOF
# TLS конфигурация
tls {
    cert_file: "$TLS_CERT"
    key_file: "$TLS_KEY"
$([ -n "$TLS_CA" ] && echo "    ca_file: \"$TLS_CA\"")
$([ "$TLS_VERIFY" = true ] && echo "    verify: true")
}

EOF
    fi

    # JetStream
    if [ "$JETSTREAM" = true ]; then
        cat >> "$config_file" << EOF
# JetStream
jetstream {
    store_dir: "$DATA_DIR/jetstream"
    max_mem: $JS_MAX_MEM
    max_file: $JS_MAX_FILE
}

EOF
    fi

    # Кластер
    if [ "$CLUSTER" = true ]; then
        cat >> "$config_file" << EOF
# Кластер
cluster {
    name: $CLUSTER_NAME
    port: $CLUSTER_PORT
    
EOF
        if [ -n "$ROUTES" ]; then
            cat >> "$config_file" << EOF
    routes: [
EOF
            IFS=',' read -ra ROUTE_ARRAY <<< "$ROUTES"
            for route in "${ROUTE_ARRAY[@]}"; do
                echo "        $route" >> "$config_file"
            done
            cat >> "$config_file" << EOF
    ]
EOF
        fi
        cat >> "$config_file" << EOF
}

EOF
    fi

    # Leaf Nodes
    if [ "$LEAFNODES" = true ]; then
        cat >> "$config_file" << EOF
# Leaf Nodes
leafnodes {
    port: $LEAFNODE_PORT
EOF
        if [ -n "$LEAFNODE_REMOTES" ]; then
            cat >> "$config_file" << EOF
    remotes: [
EOF
            IFS=',' read -ra REMOTE_ARRAY <<< "$LEAFNODE_REMOTES"
            for remote in "${REMOTE_ARRAY[@]}"; do
                cat >> "$config_file" << EOF
        {
            url: "$remote"
        }
EOF
            done
            cat >> "$config_file" << EOF
    ]
EOF
        fi
        cat >> "$config_file" << EOF
}

EOF
    fi

    # WebSocket
    if [ "$WEBSOCKET" = true ]; then
        cat >> "$config_file" << EOF
# WebSocket
websocket {
    port: $WS_PORT
$([ "$WS_NO_TLS" = true ] && echo "    no_tls: true")
$([ "$TLS" = true ] && [ "$WS_NO_TLS" != true ] && cat << WSTLS
    tls {
        cert_file: "$TLS_CERT"
        key_file: "$TLS_KEY"
    }
WSTLS
)
}

EOF
    fi

    # MQTT
    if [ "$MQTT" = true ]; then
        cat >> "$config_file" << EOF
# MQTT
mqtt {
    port: $MQTT_PORT
$([ "$TLS" = true ] && cat << MQTTTLS
    tls {
        cert_file: "$TLS_CERT"
        key_file: "$TLS_KEY"
    }
MQTTTLS
)
}

EOF
    fi

    chown "$NATS_USER:$NATS_USER" "$config_file"
    chmod 640 "$config_file"
    
    print_info "Конфигурация создана: $config_file"
}

# Создание systemd сервиса
create_systemd_service() {
    print_step "Создание systemd сервиса..."
    
    cat > /etc/systemd/system/nats-server.service << EOF
[Unit]
Description=NATS Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$NATS_USER
Group=$NATS_USER
ExecStart=/usr/local/bin/nats-server -c /etc/nats/nats-server.conf
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s SIGINT \$MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

# Безопасность
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR /var/log/nats
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_info "Systemd сервис создан"
}

# Сохранение учётных данных
save_credentials() {
    print_step "Сохранение учётных данных..."
    
    local ip=$(hostname -I | awk '{print $1}')
    local creds_file="/root/nats-credentials/info.txt"
    
    cat > "$creds_file" << EOF
NATS Server Credentials
========================
Generated: $(date)

Connection URL: nats://${ip}:${NATS_PORT}
HTTP Monitoring: http://${ip}:${NATS_HTTP_PORT}

EOF

    if [ -n "$AUTH_TOKEN" ]; then
        cat >> "$creds_file" << EOF
Authentication: Token
Token: $AUTH_TOKEN

Connection string: nats://${AUTH_TOKEN}@${ip}:${NATS_PORT}
EOF
    elif [ -n "$AUTH_USER" ]; then
        cat >> "$creds_file" << EOF
Authentication: User/Password
Username: $AUTH_USER
Password: $AUTH_PASSWORD

Connection string: nats://${AUTH_USER}:${AUTH_PASSWORD}@${ip}:${NATS_PORT}
EOF
    else
        cat >> "$creds_file" << EOF
Authentication: None (anonymous access allowed)
EOF
    fi

    cat >> "$creds_file" << EOF

Features:
  - JetStream: $([ "$JETSTREAM" = true ] && echo "enabled" || echo "disabled")
  - Cluster: $([ "$CLUSTER" = true ] && echo "enabled ($CLUSTER_NAME)" || echo "disabled")
  - WebSocket: $([ "$WEBSOCKET" = true ] && echo "enabled (port $WS_PORT)" || echo "disabled")
  - MQTT: $([ "$MQTT" = true ] && echo "enabled (port $MQTT_PORT)" || echo "disabled")
  - Leaf Nodes: $([ "$LEAFNODES" = true ] && echo "enabled (port $LEAFNODE_PORT)" || echo "disabled")
  - TLS: $([ "$TLS" = true ] && echo "enabled" || echo "disabled")
  - Prometheus: $([ "$PROMETHEUS" = true ] && echo "enabled (http://${ip}:${NATS_HTTP_PORT}/metrics)" || echo "disabled")

Configuration: /etc/nats/nats-server.conf
Data Directory: $DATA_DIR
Log File: /var/log/nats/nats-server.log
EOF

    chmod 600 "$creds_file"
    print_info "Учётные данные: $creds_file"
}

# Установка Nginx
install_nginx() {
    if [ "$INSTALL_NGINX" != true ]; then
        return 0
    fi
    
    print_step "Установка и настройка Nginx..."
    
    apt-get install -y nginx
    
    local server_name="${DOMAIN:-$(hostname -I | awk '{print $1}')}"
    
    # Создание конфигурации для WebSocket проксирования
    cat > /etc/nginx/sites-available/nats << EOF
# NATS Server Nginx Configuration

# WebSocket upstream
upstream nats_websocket {
    server 127.0.0.1:${WS_PORT};
}

# HTTP monitoring upstream
upstream nats_http {
    server 127.0.0.1:${NATS_HTTP_PORT};
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name ${server_name};

$(if [ "$SSL" = true ]; then
    echo "    return 301 https://\$server_name\$request_uri;"
else
    cat << 'NGINX_HTTP'
    # HTTP мониторинг
    location /nats/ {
        proxy_pass http://nats_http/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
    
    # WebSocket
    location /ws {
        proxy_pass http://nats_websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 86400;
    }
NGINX_HTTP
fi)
}

$(if [ "$SSL" = true ]; then
cat << NGINX_SSL
server {
    listen 443 ssl http2;
    server_name ${server_name};
    
    ssl_certificate /etc/nginx/ssl/nats.crt;
    ssl_certificate_key /etc/nginx/ssl/nats.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # HTTP мониторинг
    location /nats/ {
        proxy_pass http://nats_http/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # WebSocket
    location /ws {
        proxy_pass http://nats_websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 86400;
    }
}
NGINX_SSL
fi)
EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/nats /etc/nginx/sites-enabled/
    
    # SSL сертификаты
    if [ "$SSL" = true ]; then
        setup_nginx_ssl
    fi
    
    nginx -t
    systemctl enable nginx
    systemctl restart nginx
    
    print_info "✓ Nginx настроен"
}

# Настройка SSL для Nginx
setup_nginx_ssl() {
    print_step "Настройка SSL для Nginx..."
    
    mkdir -p /etc/nginx/ssl
    
    if [ "$LETSENCRYPT" = true ]; then
        print_info "Получение сертификата Let's Encrypt..."
        
        apt-get install -y certbot python3-certbot-nginx
        
        systemctl start nginx || true
        
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect
        
        sed -i "s|/etc/nginx/ssl/nats.crt|/etc/letsencrypt/live/${DOMAIN}/fullchain.pem|g" /etc/nginx/sites-available/nats
        sed -i "s|/etc/nginx/ssl/nats.key|/etc/letsencrypt/live/${DOMAIN}/privkey.pem|g" /etc/nginx/sites-available/nats
        
        systemctl enable certbot.timer
        
        print_info "✓ Let's Encrypt сертификат получен"
    else
        print_info "Генерация самоподписанного сертификата..."
        
        local cn="${DOMAIN:-nats.local}"
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/nats.key \
            -out /etc/nginx/ssl/nats.crt \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=NATS/CN=${cn}"
        
        chmod 600 /etc/nginx/ssl/nats.key
        
        print_info "✓ Самоподписанный сертификат создан"
    fi
}

# Запуск NATS
start_nats() {
    print_step "Запуск NATS Server..."
    
    # Создание директории JetStream если нужно
    if [ "$JETSTREAM" = true ]; then
        mkdir -p "$DATA_DIR/jetstream"
        chown -R "$NATS_USER:$NATS_USER" "$DATA_DIR"
    fi
    
    systemctl enable nats-server
    systemctl start nats-server
    
    # Ожидание запуска
    print_info "Ожидание запуска NATS..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if systemctl is-active --quiet nats-server; then
            if curl -s "http://localhost:${NATS_HTTP_PORT}/healthz" 2>/dev/null | grep -q "ok"; then
                print_info "✓ NATS Server запущен"
                return 0
            fi
        fi
        sleep 1
        ((attempt++))
        echo -n "."
    done
    echo ""
    
    print_error "NATS Server не запустился"
    print_error "Проверьте логи: journalctl -u nats-server -n 50"
    exit 1
}

# Вывод итоговой информации
print_summary() {
    local ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    print_info "NATS Server успешно установлен!"
    echo "=============================================="
    echo ""
    
    print_info "Версия: NATS Server v${NATS_VERSION}"
    print_info "Клиентский порт: $NATS_PORT"
    print_info "HTTP мониторинг: http://${ip}:${NATS_HTTP_PORT}"
    
    echo ""
    print_info "Подключение:"
    if [ -n "$AUTH_TOKEN" ]; then
        echo "  nats://${AUTH_TOKEN}@${ip}:${NATS_PORT}"
    elif [ -n "$AUTH_USER" ]; then
        echo "  nats://${AUTH_USER}:***@${ip}:${NATS_PORT}"
    else
        echo "  nats://${ip}:${NATS_PORT}"
    fi
    
    if [ "$JETSTREAM" = true ]; then
        echo ""
        print_info "JetStream: включен"
        echo "  Хранилище: $DATA_DIR/jetstream"
        echo "  Лимит памяти: $JS_MAX_MEM"
        echo "  Лимит диска: $JS_MAX_FILE"
    fi
    
    if [ "$CLUSTER" = true ]; then
        echo ""
        print_info "Кластер: $CLUSTER_NAME"
        echo "  Порт кластера: $CLUSTER_PORT"
        echo "  Имя сервера: $SERVER_NAME"
    fi
    
    if [ "$LEAFNODES" = true ]; then
        echo ""
        print_info "Leaf Nodes: порт $LEAFNODE_PORT"
    fi
    
    if [ "$WEBSOCKET" = true ]; then
        echo ""
        print_info "WebSocket: ws://${ip}:${WS_PORT}"
    fi
    
    if [ "$MQTT" = true ]; then
        echo ""
        print_info "MQTT: ${ip}:${MQTT_PORT}"
    fi
    
    if [ "$PROMETHEUS" = true ]; then
        echo ""
        print_info "Prometheus метрики: http://${ip}:${NATS_HTTP_PORT}/metrics"
    fi
    
    if [ "$INSTALL_NGINX" = true ]; then
        echo ""
        print_info "Nginx:"
        if [ "$SSL" = true ]; then
            echo "  https://${DOMAIN:-$ip}/nats/ - мониторинг"
            echo "  wss://${DOMAIN:-$ip}/ws - WebSocket"
        else
            echo "  http://${DOMAIN:-$ip}/nats/ - мониторинг"
            echo "  ws://${DOMAIN:-$ip}/ws - WebSocket"
        fi
    fi
    
    echo ""
    print_info "Управление сервисом:"
    echo "  systemctl status nats-server   - статус"
    echo "  systemctl restart nats-server  - перезапуск"
    echo "  systemctl stop nats-server     - остановка"
    echo "  journalctl -u nats-server -f   - логи"
    
    echo ""
    print_info "Конфигурация:"
    echo "  /etc/nats/nats-server.conf - конфигурация"
    echo "  $DATA_DIR                  - данные"
    echo "  /var/log/nats/             - логи"
    
    echo ""
    print_info "Учётные данные: /root/nats-credentials/info.txt"
    
    if [ "$INSTALL_CLI" = true ]; then
        echo ""
        print_info "NATS CLI примеры:"
        local auth_flag=""
        if [ -n "$AUTH_USER" ]; then
            auth_flag="--user $AUTH_USER --password '***'"
        elif [ -n "$AUTH_TOKEN" ]; then
            auth_flag="--creds (или через NATS_TOKEN)"
        fi
        echo "  nats server info $auth_flag         - информация о сервере"
        echo "  nats pub test 'Hello' $auth_flag    - публикация сообщения"
        echo "  nats sub test $auth_flag            - подписка на топик"
        if [ "$JETSTREAM" = true ]; then
            echo "  nats stream ls $auth_flag           - список стримов"
            echo "  nats consumer ls STREAM $auth_flag  - список консьюмеров"
        fi
    fi
    
    echo ""
}

# Основная функция
main() {
    echo ""
    echo "=============================================="
    echo "   NATS Server Installation Script for LXC"
    echo "=============================================="
    echo ""
    
    validate_params
    detect_os
    detect_arch
    check_requirements
    
    if [ "$CHECK_ONLY" = true ]; then
        print_info "Проверка завершена"
        exit 0
    fi
    
    install_dependencies
    install_nats_server
    install_nats_cli
    create_system_user
    create_directories
    generate_config
    create_systemd_service
    save_credentials
    start_nats
    install_nginx
    
    print_summary
}

# Запуск
main

