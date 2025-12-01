#!/bin/bash

#############################################
# RabbitMQ Installation Script for LXC
# Установка RabbitMQ в LXC контейнер
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
RABBITMQ_VERSION="latest"
AMQP_PORT=5672
AMQPS_PORT=5671
MANAGEMENT_PORT=15672
PROMETHEUS_PORT=15692
CLUSTER_PORT=25672
DATA_DIR="/var/lib/rabbitmq"
RABBITMQ_USER="rabbitmq"

# Пользователь администратора
ADMIN_USER="admin"
ADMIN_PASSWORD=""
GENERATE_PASSWORD=true

# Virtual Host
DEFAULT_VHOST="/"

# Кластеризация
CLUSTER=false
CLUSTER_NAME="rabbit"
CLUSTER_NODES=""
ERLANG_COOKIE=""

# TLS
TLS=false
TLS_CERT=""
TLS_KEY=""
TLS_CA=""
TLS_VERIFY=false

# Плагины
MANAGEMENT=true
PROMETHEUS=false
MQTT=false
MQTT_PORT=1883
STOMP=false
STOMP_PORT=61613
SHOVEL=false
FEDERATION=false

# Лимиты
DISK_FREE_LIMIT="1GB"
VM_MEMORY_HIGH_WATERMARK="0.4"
CHANNEL_MAX=2047
CONNECTION_MAX=""

# Nginx
INSTALL_NGINX=false
DOMAIN=""
SSL=false
LETSENCRYPT=false
EMAIL=""

# Прочее
CHECK_ONLY=false

# Минимальные требования
MIN_RAM_MB=2048
MIN_DISK_GB=10
MIN_CPU=2

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

Установка RabbitMQ в LXC контейнер.

Основные опции:
  --version VERSION       Версия RabbitMQ (по умолчанию: latest)
  --port PORT             AMQP порт (по умолчанию: 5672)
  --management-port PORT  Порт Management UI (по умолчанию: 15672)
  --data-dir PATH         Директория данных (по умолчанию: /var/lib/rabbitmq)
  --check                 Только проверка системных требований

Администратор:
  --admin-user USER       Имя администратора (по умолчанию: admin)
  --admin-password PASS   Пароль администратора (генерируется если не указан)
  --vhost VHOST           Virtual host по умолчанию (по умолчанию: /)

Кластеризация:
  --cluster               Включить кластерный режим
  --cluster-name NAME     Имя кластера (по умолчанию: rabbit)
  --cluster-nodes NODES   Узлы кластера (через запятую, например: rabbit@node1,rabbit@node2)
  --erlang-cookie COOKIE  Erlang cookie для кластера (генерируется если не указан)

TLS/SSL:
  --tls                   Включить TLS для AMQP
  --tls-cert PATH         Путь к сертификату
  --tls-key PATH          Путь к приватному ключу
  --tls-ca PATH           Путь к CA сертификату
  --tls-verify            Требовать клиентские сертификаты

Плагины:
  --no-management         Не включать Management plugin
  --prometheus            Включить Prometheus plugin (метрики на порту 15692)
  --mqtt                  Включить MQTT plugin
  --mqtt-port PORT        Порт MQTT (по умолчанию: 1883)
  --stomp                 Включить STOMP plugin
  --stomp-port PORT       Порт STOMP (по умолчанию: 61613)
  --shovel                Включить Shovel plugin
  --federation            Включить Federation plugin

Лимиты:
  --disk-free-limit SIZE  Минимум свободного места (по умолчанию: 1GB)
  --memory-limit RATIO    Лимит памяти 0.0-1.0 (по умолчанию: 0.4)
  --channel-max N         Максимум каналов на соединение (по умолчанию: 2047)
  --connection-max N      Максимум соединений (по умолчанию: без лимита)

Nginx (reverse proxy для Management UI):
  --with-nginx            Установить Nginx как reverse proxy
  --domain DOMAIN         Доменное имя
  --ssl                   Включить SSL (самоподписанный сертификат)
  --letsencrypt           Получить сертификат Let's Encrypt
  --email EMAIL           Email для Let's Encrypt

Примеры:
  # Базовая установка
  $0

  # С Prometheus мониторингом
  $0 --prometheus

  # С указанным паролем
  $0 --admin-user admin --admin-password SecurePass123

  # С TLS
  $0 --tls --tls-cert /path/to/cert.pem --tls-key /path/to/key.pem

  # Кластер (на каждом узле)
  $0 --cluster --cluster-name prod --erlang-cookie "SECRETCOOKIE" \\
     --cluster-nodes "rabbit@rabbit1,rabbit@rabbit2,rabbit@rabbit3"

  # С MQTT и STOMP
  $0 --mqtt --stomp --prometheus

  # С Nginx и Let's Encrypt
  $0 --with-nginx --domain rabbitmq.example.com --letsencrypt --email admin@example.com

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
            RABBITMQ_VERSION="$2"
            shift 2
            ;;
        --port)
            AMQP_PORT="$2"
            shift 2
            ;;
        --management-port)
            MANAGEMENT_PORT="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --admin-user)
            ADMIN_USER="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            GENERATE_PASSWORD=false
            shift 2
            ;;
        --vhost)
            DEFAULT_VHOST="$2"
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
        --cluster-nodes)
            CLUSTER_NODES="$2"
            shift 2
            ;;
        --erlang-cookie)
            ERLANG_COOKIE="$2"
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
        --no-management)
            MANAGEMENT=false
            shift
            ;;
        --prometheus)
            PROMETHEUS=true
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
        --stomp)
            STOMP=true
            shift
            ;;
        --stomp-port)
            STOMP_PORT="$2"
            shift 2
            ;;
        --shovel)
            SHOVEL=true
            shift
            ;;
        --federation)
            FEDERATION=true
            shift
            ;;
        --disk-free-limit)
            DISK_FREE_LIMIT="$2"
            shift 2
            ;;
        --memory-limit)
            VM_MEMORY_HIGH_WATERMARK="$2"
            shift 2
            ;;
        --channel-max)
            CHANNEL_MAX="$2"
            shift 2
            ;;
        --connection-max)
            CONNECTION_MAX="$2"
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
    
    # Генерация пароля если не указан
    if [ "$GENERATE_PASSWORD" = true ]; then
        ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)
        print_info "Сгенерирован пароль администратора"
    fi
    
    # Генерация Erlang cookie для кластера
    if [ "$CLUSTER" = true ] && [ -z "$ERLANG_COOKIE" ]; then
        ERLANG_COOKIE=$(openssl rand -base64 32 | tr -dc 'A-Z' | head -c 20)
        print_warn "Сгенерирован Erlang cookie: $ERLANG_COOKIE"
        print_warn "Используйте этот же cookie на всех узлах кластера!"
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

# Проверка системных требований
check_requirements() {
    print_step "Проверка системных требований..."
    
    local errors=0
    
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
        apt-transport-https \
        software-properties-common
}

# Добавление репозитория RabbitMQ
add_rabbitmq_repo() {
    print_step "Добавление репозитория RabbitMQ..."
    
    # Добавление ключей
    print_info "Добавление GPG ключей..."
    
    # Cloudsmith signing key for RabbitMQ
    curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | \
        gpg --dearmor -o /usr/share/keyrings/com.rabbitmq.team.gpg
    
    # Cloudsmith signing key for Erlang
    curl -1sLf "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key" | \
        gpg --dearmor -o /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg
    
    # Cloudsmith signing key for RabbitMQ
    curl -1sLf "https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key" | \
        gpg --dearmor -o /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg
    
    # Определение дистрибутива для репозитория
    local repo_dist="$CODENAME"
    
    # Создание файла репозитория
    cat > /etc/apt/sources.list.d/rabbitmq.list << EOF
## Erlang from RabbitMQ team
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-erlang/deb/${OS} ${repo_dist} main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-erlang/deb/${OS} ${repo_dist} main

## RabbitMQ server
deb [arch=amd64 signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-server/deb/${OS} ${repo_dist} main
deb-src [signed-by=/usr/share/keyrings/rabbitmq.9F4587F226208342.gpg] https://ppa1.novemberain.com/rabbitmq/rabbitmq-server/deb/${OS} ${repo_dist} main
EOF

    # Приоритеты пакетов
    cat > /etc/apt/preferences.d/erlang << EOF
Package: erlang*
Pin: origin ppa1.novemberain.com
Pin-Priority: 1001
EOF

    cat > /etc/apt/preferences.d/rabbitmq << EOF
Package: rabbitmq-server
Pin: origin ppa1.novemberain.com
Pin-Priority: 1001
EOF

    apt-get update
    
    print_info "✓ Репозиторий RabbitMQ добавлен"
}

# Установка Erlang
install_erlang() {
    print_step "Установка Erlang..."
    
    apt-get install -y erlang-base \
        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
        erlang-runtime-tools erlang-snmp erlang-ssl \
        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl
    
    local erlang_version=$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell 2>&1 | tr -d '"')
    print_info "✓ Установлен Erlang OTP $erlang_version"
}

# Установка RabbitMQ
install_rabbitmq() {
    print_step "Установка RabbitMQ Server..."
    
    if [ "$RABBITMQ_VERSION" = "latest" ]; then
        apt-get install -y rabbitmq-server
    else
        apt-get install -y rabbitmq-server="$RABBITMQ_VERSION"
    fi
    
    # Остановка сервиса для настройки
    systemctl stop rabbitmq-server || true
    
    local installed_version=$(dpkg -s rabbitmq-server | grep "Version" | cut -d' ' -f2)
    print_info "✓ Установлен RabbitMQ $installed_version"
}

# Настройка Erlang cookie для кластера
setup_erlang_cookie() {
    if [ "$CLUSTER" = true ] && [ -n "$ERLANG_COOKIE" ]; then
        print_step "Настройка Erlang cookie..."
        
        echo "$ERLANG_COOKIE" > /var/lib/rabbitmq/.erlang.cookie
        chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
        chmod 400 /var/lib/rabbitmq/.erlang.cookie
        
        print_info "✓ Erlang cookie настроен"
    fi
}

# Включение плагинов
enable_plugins() {
    print_step "Включение плагинов..."
    
    local plugins=""
    
    if [ "$MANAGEMENT" = true ]; then
        plugins="$plugins rabbitmq_management"
    fi
    
    if [ "$PROMETHEUS" = true ]; then
        plugins="$plugins rabbitmq_prometheus"
    fi
    
    if [ "$MQTT" = true ]; then
        plugins="$plugins rabbitmq_mqtt"
    fi
    
    if [ "$STOMP" = true ]; then
        plugins="$plugins rabbitmq_stomp rabbitmq_web_stomp"
    fi
    
    if [ "$SHOVEL" = true ]; then
        plugins="$plugins rabbitmq_shovel rabbitmq_shovel_management"
    fi
    
    if [ "$FEDERATION" = true ]; then
        plugins="$plugins rabbitmq_federation rabbitmq_federation_management"
    fi
    
    if [ -n "$plugins" ]; then
        rabbitmq-plugins enable $plugins
        print_info "✓ Плагины включены: $plugins"
    fi
}

# Генерация конфигурации
generate_config() {
    print_step "Генерация конфигурации..."
    
    local config_file="/etc/rabbitmq/rabbitmq.conf"
    local advanced_config="/etc/rabbitmq/advanced.config"
    
    # Основная конфигурация
    cat > "$config_file" << EOF
# RabbitMQ Configuration
# Generated by install.sh on $(date)

# ===========================================
# Сетевые настройки
# ===========================================
listeners.tcp.default = $AMQP_PORT
EOF

    # TLS настройки
    if [ "$TLS" = true ]; then
        cat >> "$config_file" << EOF

# TLS для AMQP
listeners.ssl.default = $AMQPS_PORT
ssl_options.cacertfile = $TLS_CA
ssl_options.certfile = $TLS_CERT
ssl_options.keyfile = $TLS_KEY
ssl_options.verify = $([ "$TLS_VERIFY" = true ] && echo "verify_peer" || echo "verify_none")
ssl_options.fail_if_no_peer_cert = $([ "$TLS_VERIFY" = true ] && echo "true" || echo "false")
EOF
    fi

    # Management настройки
    if [ "$MANAGEMENT" = true ]; then
        cat >> "$config_file" << EOF

# ===========================================
# Management UI
# ===========================================
management.tcp.port = $MANAGEMENT_PORT
management.tcp.ip = 0.0.0.0
EOF
    fi

    # Prometheus настройки
    if [ "$PROMETHEUS" = true ]; then
        cat >> "$config_file" << EOF

# ===========================================
# Prometheus метрики
# ===========================================
prometheus.tcp.port = $PROMETHEUS_PORT
prometheus.return_per_object_metrics = true
EOF
    fi

    # MQTT настройки
    if [ "$MQTT" = true ]; then
        cat >> "$config_file" << EOF

# ===========================================
# MQTT
# ===========================================
mqtt.listeners.tcp.default = $MQTT_PORT
mqtt.allow_anonymous = false
mqtt.default_user = $ADMIN_USER
mqtt.default_pass = $ADMIN_PASSWORD
mqtt.vhost = $DEFAULT_VHOST
EOF
    fi

    # STOMP настройки
    if [ "$STOMP" = true ]; then
        cat >> "$config_file" << EOF

# ===========================================
# STOMP
# ===========================================
stomp.listeners.tcp.default = $STOMP_PORT
EOF
    fi

    # Лимиты ресурсов
    cat >> "$config_file" << EOF

# ===========================================
# Лимиты ресурсов
# ===========================================
disk_free_limit.absolute = $DISK_FREE_LIMIT
vm_memory_high_watermark.relative = $VM_MEMORY_HIGH_WATERMARK
channel_max = $CHANNEL_MAX
EOF

    if [ -n "$CONNECTION_MAX" ]; then
        echo "connection_max = $CONNECTION_MAX" >> "$config_file"
    fi

    # Кластер настройки
    if [ "$CLUSTER" = true ]; then
        cat >> "$config_file" << EOF

# ===========================================
# Кластер
# ===========================================
cluster_formation.peer_discovery_backend = classic_config
cluster_name = $CLUSTER_NAME
EOF
        
        if [ -n "$CLUSTER_NODES" ]; then
            local i=1
            IFS=',' read -ra NODES <<< "$CLUSTER_NODES"
            for node in "${NODES[@]}"; do
                echo "cluster_formation.classic_config.nodes.$i = $node" >> "$config_file"
                ((i++))
            done
        fi
    fi

    # Логирование
    cat >> "$config_file" << EOF

# ===========================================
# Логирование
# ===========================================
log.file.level = info
log.console = false
log.console.level = info
EOF

    # Настройка директории данных
    mkdir -p "$DATA_DIR"
    chown -R rabbitmq:rabbitmq "$DATA_DIR"
    
    # Environment файл
    cat > /etc/rabbitmq/rabbitmq-env.conf << EOF
# RabbitMQ Environment
RABBITMQ_MNESIA_BASE=$DATA_DIR/mnesia
RABBITMQ_LOG_BASE=/var/log/rabbitmq
NODENAME=rabbit@$(hostname -s)
EOF

    chmod 644 "$config_file"
    chmod 644 /etc/rabbitmq/rabbitmq-env.conf
    
    print_info "✓ Конфигурация создана: $config_file"
}

# Запуск RabbitMQ
start_rabbitmq() {
    print_step "Запуск RabbitMQ..."
    
    systemctl enable rabbitmq-server
    systemctl start rabbitmq-server
    
    # Ожидание запуска
    print_info "Ожидание запуска RabbitMQ..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if rabbitmqctl status &>/dev/null; then
            print_info "✓ RabbitMQ запущен"
            return 0
        fi
        sleep 2
        ((attempt++))
        echo -n "."
    done
    echo ""
    
    print_error "RabbitMQ не запустился"
    print_error "Проверьте логи: journalctl -u rabbitmq-server -n 50"
    exit 1
}

# Настройка пользователей и прав
setup_users() {
    print_step "Настройка пользователей..."
    
    # Удаление guest пользователя
    rabbitmqctl delete_user guest 2>/dev/null || true
    
    # Создание администратора
    rabbitmqctl add_user "$ADMIN_USER" "$ADMIN_PASSWORD" 2>/dev/null || \
        rabbitmqctl change_password "$ADMIN_USER" "$ADMIN_PASSWORD"
    
    rabbitmqctl set_user_tags "$ADMIN_USER" administrator
    
    # Права на все vhosts
    rabbitmqctl set_permissions -p "$DEFAULT_VHOST" "$ADMIN_USER" ".*" ".*" ".*"
    
    print_info "✓ Пользователь $ADMIN_USER настроен"
}

# Присоединение к кластеру
join_cluster() {
    if [ "$CLUSTER" != true ] || [ -z "$CLUSTER_NODES" ]; then
        return 0
    fi
    
    print_step "Присоединение к кластеру..."
    
    local current_node="rabbit@$(hostname -s)"
    
    # Получение первого узла из списка
    IFS=',' read -ra NODES <<< "$CLUSTER_NODES"
    local first_node="${NODES[0]}"
    
    # Пропуск если это первый узел
    if [ "$first_node" = "$current_node" ]; then
        print_info "Это первый узел кластера, пропускаем присоединение"
        return 0
    fi
    
    # Проверка доступности первого узла
    print_info "Проверка доступности $first_node..."
    
    rabbitmqctl stop_app
    rabbitmqctl reset
    rabbitmqctl join_cluster "$first_node"
    rabbitmqctl start_app
    
    print_info "✓ Присоединён к кластеру через $first_node"
}

# Сохранение учётных данных
save_credentials() {
    print_step "Сохранение учётных данных..."
    
    local ip=$(hostname -I | awk '{print $1}')
    local creds_dir="/root/rabbitmq-credentials"
    local creds_file="$creds_dir/info.txt"
    
    mkdir -p "$creds_dir"
    
    cat > "$creds_file" << EOF
RabbitMQ Credentials
====================
Generated: $(date)

AMQP URL: amqp://${ADMIN_USER}:${ADMIN_PASSWORD}@${ip}:${AMQP_PORT}/${DEFAULT_VHOST}
$([ "$TLS" = true ] && echo "AMQPS URL: amqps://${ADMIN_USER}:${ADMIN_PASSWORD}@${ip}:${AMQPS_PORT}/${DEFAULT_VHOST}")

Administrator:
  Username: $ADMIN_USER
  Password: $ADMIN_PASSWORD
  Virtual Host: $DEFAULT_VHOST

$([ "$MANAGEMENT" = true ] && echo "Management UI: http://${ip}:${MANAGEMENT_PORT}")
$([ "$PROMETHEUS" = true ] && echo "Prometheus Metrics: http://${ip}:${PROMETHEUS_PORT}/metrics")

Ports:
  - AMQP: $AMQP_PORT
$([ "$TLS" = true ] && echo "  - AMQPS: $AMQPS_PORT")
$([ "$MANAGEMENT" = true ] && echo "  - Management: $MANAGEMENT_PORT")
$([ "$PROMETHEUS" = true ] && echo "  - Prometheus: $PROMETHEUS_PORT")
$([ "$MQTT" = true ] && echo "  - MQTT: $MQTT_PORT")
$([ "$STOMP" = true ] && echo "  - STOMP: $STOMP_PORT")
  - Cluster: $CLUSTER_PORT

Features:
  - Management UI: $([ "$MANAGEMENT" = true ] && echo "enabled" || echo "disabled")
  - Prometheus: $([ "$PROMETHEUS" = true ] && echo "enabled" || echo "disabled")
  - MQTT: $([ "$MQTT" = true ] && echo "enabled" || echo "disabled")
  - STOMP: $([ "$STOMP" = true ] && echo "enabled" || echo "disabled")
  - Shovel: $([ "$SHOVEL" = true ] && echo "enabled" || echo "disabled")
  - Federation: $([ "$FEDERATION" = true ] && echo "enabled" || echo "disabled")
  - TLS: $([ "$TLS" = true ] && echo "enabled" || echo "disabled")
  - Cluster: $([ "$CLUSTER" = true ] && echo "enabled ($CLUSTER_NAME)" || echo "disabled")

$([ "$CLUSTER" = true ] && cat << CLUSTER_INFO
Cluster Configuration:
  - Name: $CLUSTER_NAME
  - Erlang Cookie: $ERLANG_COOKIE
  - Nodes: $CLUSTER_NODES
CLUSTER_INFO
)

Configuration: /etc/rabbitmq/rabbitmq.conf
Data Directory: $DATA_DIR
Log Directory: /var/log/rabbitmq
EOF

    chmod 600 "$creds_file"
    print_info "✓ Учётные данные: $creds_file"
}

# Установка Nginx
install_nginx() {
    if [ "$INSTALL_NGINX" != true ]; then
        return 0
    fi
    
    print_step "Установка и настройка Nginx..."
    
    apt-get install -y nginx
    
    local server_name="${DOMAIN:-$(hostname -I | awk '{print $1}')}"
    
    cat > /etc/nginx/sites-available/rabbitmq << EOF
# RabbitMQ Management Nginx Configuration

upstream rabbitmq_management {
    server 127.0.0.1:${MANAGEMENT_PORT};
}

server {
    listen 80;
    server_name ${server_name};

$(if [ "$SSL" = true ]; then
    echo "    return 301 https://\$server_name\$request_uri;"
else
    cat << 'NGINX_HTTP'
    location / {
        proxy_pass http://rabbitmq_management;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
NGINX_HTTP
fi)
}

$(if [ "$SSL" = true ]; then
cat << NGINX_SSL
server {
    listen 443 ssl http2;
    server_name ${server_name};
    
    ssl_certificate /etc/nginx/ssl/rabbitmq.crt;
    ssl_certificate_key /etc/nginx/ssl/rabbitmq.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    location / {
        proxy_pass http://rabbitmq_management;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX_SSL
fi)
EOF

    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/rabbitmq /etc/nginx/sites-enabled/
    
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
        
        sed -i "s|/etc/nginx/ssl/rabbitmq.crt|/etc/letsencrypt/live/${DOMAIN}/fullchain.pem|g" /etc/nginx/sites-available/rabbitmq
        sed -i "s|/etc/nginx/ssl/rabbitmq.key|/etc/letsencrypt/live/${DOMAIN}/privkey.pem|g" /etc/nginx/sites-available/rabbitmq
        
        systemctl enable certbot.timer
        
        print_info "✓ Let's Encrypt сертификат получен"
    else
        print_info "Генерация самоподписанного сертификата..."
        
        local cn="${DOMAIN:-rabbitmq.local}"
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/rabbitmq.key \
            -out /etc/nginx/ssl/rabbitmq.crt \
            -subj "/C=RU/ST=Moscow/L=Moscow/O=RabbitMQ/CN=${cn}"
        
        chmod 600 /etc/nginx/ssl/rabbitmq.key
        
        print_info "✓ Самоподписанный сертификат создан"
    fi
}

# Вывод итоговой информации
print_summary() {
    local ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    print_info "RabbitMQ успешно установлен!"
    echo "=============================================="
    echo ""
    
    local version=$(rabbitmqctl version 2>/dev/null || echo "unknown")
    print_info "Версия: RabbitMQ $version"
    print_info "Erlang: $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell 2>&1 | tr -d '"')"
    
    echo ""
    print_info "Подключение AMQP:"
    echo "  amqp://${ADMIN_USER}:***@${ip}:${AMQP_PORT}/"
    
    if [ "$TLS" = true ]; then
        echo "  amqps://${ADMIN_USER}:***@${ip}:${AMQPS_PORT}/"
    fi
    
    if [ "$MANAGEMENT" = true ]; then
        echo ""
        print_info "Management UI:"
        if [ "$INSTALL_NGINX" = true ] && [ "$SSL" = true ]; then
            echo "  https://${DOMAIN:-$ip}/"
        elif [ "$INSTALL_NGINX" = true ]; then
            echo "  http://${DOMAIN:-$ip}/"
        else
            echo "  http://${ip}:${MANAGEMENT_PORT}/"
        fi
        echo "  Логин: $ADMIN_USER"
        echo "  Пароль: $ADMIN_PASSWORD"
    fi
    
    if [ "$PROMETHEUS" = true ]; then
        echo ""
        print_info "Prometheus метрики:"
        echo "  http://${ip}:${PROMETHEUS_PORT}/metrics"
    fi
    
    if [ "$MQTT" = true ]; then
        echo ""
        print_info "MQTT:"
        echo "  mqtt://${ip}:${MQTT_PORT}"
    fi
    
    if [ "$STOMP" = true ]; then
        echo ""
        print_info "STOMP:"
        echo "  stomp://${ip}:${STOMP_PORT}"
    fi
    
    if [ "$CLUSTER" = true ]; then
        echo ""
        print_info "Кластер: $CLUSTER_NAME"
        echo "  Узел: rabbit@$(hostname -s)"
        echo "  Cookie: $ERLANG_COOKIE"
        if [ -n "$CLUSTER_NODES" ]; then
            echo "  Узлы: $CLUSTER_NODES"
        fi
    fi
    
    echo ""
    print_info "Управление сервисом:"
    echo "  systemctl status rabbitmq-server   - статус"
    echo "  systemctl restart rabbitmq-server  - перезапуск"
    echo "  systemctl stop rabbitmq-server     - остановка"
    echo "  journalctl -u rabbitmq-server -f   - логи"
    
    echo ""
    print_info "Полезные команды rabbitmqctl:"
    echo "  rabbitmqctl status                 - статус сервера"
    echo "  rabbitmqctl list_users             - список пользователей"
    echo "  rabbitmqctl list_queues            - список очередей"
    echo "  rabbitmqctl list_exchanges         - список exchanges"
    echo "  rabbitmqctl list_connections       - список соединений"
    if [ "$CLUSTER" = true ]; then
        echo "  rabbitmqctl cluster_status         - статус кластера"
    fi
    
    echo ""
    print_info "Конфигурация:"
    echo "  /etc/rabbitmq/rabbitmq.conf        - конфигурация"
    echo "  $DATA_DIR                          - данные"
    echo "  /var/log/rabbitmq/                 - логи"
    
    echo ""
    print_info "Учётные данные: /root/rabbitmq-credentials/info.txt"
    echo ""
}

# Основная функция
main() {
    echo ""
    echo "=============================================="
    echo "   RabbitMQ Installation Script for LXC"
    echo "=============================================="
    echo ""
    
    validate_params
    detect_os
    check_requirements
    
    if [ "$CHECK_ONLY" = true ]; then
        print_info "Проверка завершена"
        exit 0
    fi
    
    install_dependencies
    add_rabbitmq_repo
    install_erlang
    install_rabbitmq
    setup_erlang_cookie
    generate_config
    start_rabbitmq
    enable_plugins
    setup_users
    join_cluster
    save_credentials
    install_nginx
    
    print_summary
}

# Запуск
main

