#!/bin/bash

#############################################
# Prometheus Stack Installation Script for LXC
# Включает: Prometheus, Node Exporter, Blackbox Exporter
# Опционально: Alertmanager, Postgres Exporter, Proxmox Exporter
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
PROMETHEUS_VERSION="latest"
NODE_EXPORTER_VERSION="latest"
BLACKBOX_EXPORTER_VERSION="latest"
ALERTMANAGER_VERSION="latest"
POSTGRES_EXPORTER_VERSION="latest"

INSTALL_NODE_EXPORTER=true
INSTALL_BLACKBOX_EXPORTER=true
INSTALL_ALERTMANAGER=false
INSTALL_POSTGRES_EXPORTER=false
INSTALL_PROXMOX=false

RETENTION="15d"
SCRAPE_INTERVAL="15s"
STORAGE_PATH="/var/lib/prometheus"
LISTEN_ADDRESS="127.0.0.1"
ALLOW_REMOTE=false

# Proxmox параметры
PROXMOX_HOST=""
PROXMOX_USER=""
PROXMOX_TOKEN_ID=""
PROXMOX_TOKEN_SECRET=""

# Postgres Exporter параметры
PG_HOST="localhost"
PG_PORT="5432"
PG_USER="postgres_exporter"
PG_PASSWORD=""
PG_DATABASE="postgres"

# Порты
PROMETHEUS_PORT=9090
NODE_EXPORTER_PORT=9100
BLACKBOX_EXPORTER_PORT=9115
ALERTMANAGER_PORT=9093
POSTGRES_EXPORTER_PORT=9187

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

Скрипт установки Prometheus stack для LXC контейнеров.
По умолчанию устанавливаются: Prometheus, Node Exporter, Blackbox Exporter.

Рекомендуемые ресурсы LXC: 2 CPU, 4 GB RAM, 20 GB диска.

Основные опции:
  --version VERSION         Версия Prometheus (по умолчанию: latest)
  --alertmanager            Установить Alertmanager
  --postgres-exporter       Установить Postgres Exporter
  --proxmox                 Настроить мониторинг Proxmox VE
  --allow-remote            Разрешить удалённые подключения
  --help                    Показать эту справку

Настройки хранения:
  --retention TIME          Время хранения метрик (по умолчанию: 15d)
  --scrape-interval TIME    Интервал сбора метрик (по умолчанию: 15s)
  --storage-path PATH       Путь хранения данных (по умолчанию: /var/lib/prometheus)

Настройки Proxmox (требуют --proxmox):
  --proxmox-host HOST       Адрес Proxmox VE (например: 192.168.1.100:8006)
  --proxmox-user USER       Пользователь API (например: prometheus@pve)
  --proxmox-token-id ID     ID токена API
  --proxmox-token-secret S  Секрет токена API

Настройки Postgres Exporter (требуют --postgres-exporter):
  --pg-host HOST            Хост PostgreSQL (по умолчанию: localhost)
  --pg-port PORT            Порт PostgreSQL (по умолчанию: 5432)
  --pg-user USER            Пользователь PostgreSQL (по умолчанию: postgres_exporter)
  --pg-password PASS        Пароль пользователя PostgreSQL
  --pg-database DB          База данных (по умолчанию: postgres)

Примеры:
  # Базовая установка
  $0

  # С Alertmanager и удалённым доступом
  $0 --alertmanager --allow-remote

  # С мониторингом Proxmox
  $0 --proxmox --proxmox-host 192.168.1.100:8006 \\
     --proxmox-user prometheus@pve \\
     --proxmox-token-id monitoring \\
     --proxmox-token-secret xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

  # С мониторингом PostgreSQL
  $0 --postgres-exporter --pg-host 192.168.1.50 --pg-password SecurePass123

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            PROMETHEUS_VERSION="$2"
            shift 2
            ;;
        --alertmanager)
            INSTALL_ALERTMANAGER=true
            shift
            ;;
        --postgres-exporter)
            INSTALL_POSTGRES_EXPORTER=true
            shift
            ;;
        --proxmox)
            INSTALL_PROXMOX=true
            shift
            ;;
        --allow-remote)
            ALLOW_REMOTE=true
            LISTEN_ADDRESS="0.0.0.0"
            shift
            ;;
        --retention)
            RETENTION="$2"
            shift 2
            ;;
        --scrape-interval)
            SCRAPE_INTERVAL="$2"
            shift 2
            ;;
        --storage-path)
            STORAGE_PATH="$2"
            shift 2
            ;;
        --proxmox-host)
            PROXMOX_HOST="$2"
            shift 2
            ;;
        --proxmox-user)
            PROXMOX_USER="$2"
            shift 2
            ;;
        --proxmox-token-id)
            PROXMOX_TOKEN_ID="$2"
            shift 2
            ;;
        --proxmox-token-secret)
            PROXMOX_TOKEN_SECRET="$2"
            shift 2
            ;;
        --pg-host)
            PG_HOST="$2"
            shift 2
            ;;
        --pg-port)
            PG_PORT="$2"
            shift 2
            ;;
        --pg-user)
            PG_USER="$2"
            shift 2
            ;;
        --pg-password)
            PG_PASSWORD="$2"
            shift 2
            ;;
        --pg-database)
            PG_DATABASE="$2"
            shift 2
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

# Проверка параметров Proxmox
if [ "$INSTALL_PROXMOX" = true ]; then
    if [ -z "$PROXMOX_HOST" ] || [ -z "$PROXMOX_USER" ] || [ -z "$PROXMOX_TOKEN_ID" ] || [ -z "$PROXMOX_TOKEN_SECRET" ]; then
        print_error "Для мониторинга Proxmox необходимо указать все параметры:"
        print_error "  --proxmox-host, --proxmox-user, --proxmox-token-id, --proxmox-token-secret"
        exit 1
    fi
fi

# Проверка параметров Postgres Exporter
if [ "$INSTALL_POSTGRES_EXPORTER" = true ] && [ -z "$PG_PASSWORD" ]; then
    print_error "Для Postgres Exporter необходимо указать --pg-password"
    exit 1
fi

# Определение архитектуры
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    armv7l)
        ARCH="armv7"
        ;;
    *)
        print_error "Неподдерживаемая архитектура: $ARCH"
        exit 1
        ;;
esac

# Функция получения последней версии с GitHub
get_latest_version() {
    local repo=$1
    curl -s "https://api.github.com/repos/${repo}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/'
}

# Функция скачивания и установки бинарника
download_and_install() {
    local name=$1
    local repo=$2
    local version=$3
    local binary_name=$4
    
    print_step "Установка ${name}..."
    
    if [ "$version" = "latest" ]; then
        version=$(get_latest_version "$repo")
        print_info "Последняя версия ${name}: ${version}"
    fi
    
    local url="https://github.com/${repo}/releases/download/v${version}/${binary_name}-${version}.linux-${ARCH}.tar.gz"
    local tmp_dir=$(mktemp -d)
    
    print_info "Скачивание: ${url}"
    wget -q --show-progress -O "${tmp_dir}/${binary_name}.tar.gz" "$url"
    
    tar -xzf "${tmp_dir}/${binary_name}.tar.gz" -C "$tmp_dir"
    
    # Копирование бинарников
    cp "${tmp_dir}/${binary_name}-${version}.linux-${ARCH}/${binary_name}" /usr/local/bin/
    chmod +x "/usr/local/bin/${binary_name}"
    
    # Копирование дополнительных файлов если есть
    if [ -d "${tmp_dir}/${binary_name}-${version}.linux-${ARCH}/consoles" ]; then
        mkdir -p /etc/prometheus/consoles
        cp -r "${tmp_dir}/${binary_name}-${version}.linux-${ARCH}/consoles/"* /etc/prometheus/consoles/
    fi
    
    if [ -d "${tmp_dir}/${binary_name}-${version}.linux-${ARCH}/console_libraries" ]; then
        mkdir -p /etc/prometheus/console_libraries
        cp -r "${tmp_dir}/${binary_name}-${version}.linux-${ARCH}/console_libraries/"* /etc/prometheus/console_libraries/
    fi
    
    rm -rf "$tmp_dir"
    
    print_info "✓ ${name} ${version} установлен"
}

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка Prometheus Stack"
echo "=============================================="
print_info "Компоненты:"
print_info "  • Prometheus Server"
print_info "  • Node Exporter"
print_info "  • Blackbox Exporter"
[ "$INSTALL_ALERTMANAGER" = true ] && print_info "  • Alertmanager"
[ "$INSTALL_POSTGRES_EXPORTER" = true ] && print_info "  • Postgres Exporter"
[ "$INSTALL_PROXMOX" = true ] && print_info "  • Proxmox VE мониторинг"
echo ""
print_info "Настройки:"
print_info "  Retention: ${RETENTION}"
print_info "  Scrape interval: ${SCRAPE_INTERVAL}"
print_info "  Storage: ${STORAGE_PATH}"
print_info "  Удалённый доступ: $([ "$ALLOW_REMOTE" = true ] && echo "включен" || echo "только localhost")"
echo "=============================================="
echo ""

# Установка зависимостей
print_step "Установка зависимостей..."
apt-get update
apt-get install -y wget curl tar gzip

# Создание пользователя prometheus
print_step "Создание системного пользователя prometheus..."
if ! id "prometheus" &>/dev/null; then
    useradd --no-create-home --shell /bin/false prometheus
fi

# Создание директорий
print_step "Создание директорий..."
mkdir -p /etc/prometheus
mkdir -p /etc/prometheus/rules
mkdir -p /etc/prometheus/targets
mkdir -p "$STORAGE_PATH"
mkdir -p /var/lib/alertmanager

chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus "$STORAGE_PATH"
chown -R prometheus:prometheus /var/lib/alertmanager

#############################################
# Установка Prometheus
#############################################

download_and_install "Prometheus" "prometheus/prometheus" "$PROMETHEUS_VERSION" "prometheus"

# Создание конфигурации Prometheus
print_step "Создание конфигурации Prometheus..."

cat > /etc/prometheus/prometheus.yml << EOF
# Prometheus configuration
# Generated by install.sh

global:
  scrape_interval: ${SCRAPE_INTERVAL}
  evaluation_interval: ${SCRAPE_INTERVAL}
  external_labels:
    monitor: 'prometheus-lxc'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
EOF

if [ "$INSTALL_ALERTMANAGER" = true ]; then
    cat >> /etc/prometheus/prometheus.yml << EOF
            - localhost:${ALERTMANAGER_PORT}
EOF
else
    cat >> /etc/prometheus/prometheus.yml << EOF
            []
EOF
fi

cat >> /etc/prometheus/prometheus.yml << EOF

# Rule files
rule_files:
  - "rules/*.yml"

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:${PROMETHEUS_PORT}']

  # Node Exporter
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:${NODE_EXPORTER_PORT}']

  # Blackbox Exporter
  - job_name: 'blackbox'
    static_configs:
      - targets: ['localhost:${BLACKBOX_EXPORTER_PORT}']

  # Blackbox HTTP probes
  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module: [http_2xx]
    file_sd_configs:
      - files:
          - 'targets/blackbox-http.yml'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:${BLACKBOX_EXPORTER_PORT}

  # Blackbox ICMP probes (ping)
  - job_name: 'blackbox-icmp'
    metrics_path: /probe
    params:
      module: [icmp]
    file_sd_configs:
      - files:
          - 'targets/blackbox-icmp.yml'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:${BLACKBOX_EXPORTER_PORT}

  # Additional node exporters (file-based discovery)
  - job_name: 'node-exporters'
    file_sd_configs:
      - files:
          - 'targets/nodes.yml'
EOF

# Добавление Postgres Exporter если включен
if [ "$INSTALL_POSTGRES_EXPORTER" = true ]; then
    cat >> /etc/prometheus/prometheus.yml << EOF

  # Postgres Exporter
  - job_name: 'postgres'
    static_configs:
      - targets: ['localhost:${POSTGRES_EXPORTER_PORT}']
EOF
fi

# Добавление Proxmox если включен
if [ "$INSTALL_PROXMOX" = true ]; then
    cat >> /etc/prometheus/prometheus.yml << EOF

  # Proxmox VE
  - job_name: 'proxmox'
    static_configs:
      - targets: ['${PROXMOX_HOST}']
    metrics_path: /pve
    params:
      module: [default]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9221
EOF
fi

# Создание пустых файлов для file_sd
cat > /etc/prometheus/targets/nodes.yml << EOF
# Дополнительные Node Exporters
# Пример:
# - targets:
#     - '192.168.1.10:9100'
#     - '192.168.1.11:9100'
#   labels:
#     env: 'production'
[]
EOF

cat > /etc/prometheus/targets/blackbox-http.yml << EOF
# HTTP endpoints для мониторинга
# Пример:
# - targets:
#     - 'https://example.com'
#     - 'https://api.example.com/health'
#   labels:
#     env: 'production'
[]
EOF

cat > /etc/prometheus/targets/blackbox-icmp.yml << EOF
# Хосты для ping мониторинга
# Пример:
# - targets:
#     - '192.168.1.1'
#     - '8.8.8.8'
#   labels:
#     env: 'network'
[]
EOF

# Создание базовых правил алертов
cat > /etc/prometheus/rules/alerts.yml << EOF
groups:
  - name: node_alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ \$labels.instance }} down"
          description: "{{ \$labels.instance }} of job {{ \$labels.job }} has been down for more than 5 minutes."

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ \$labels.instance }}"
          description: "CPU usage is above 80% for more than 10 minutes."

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ \$labels.instance }}"
          description: "Memory usage is above 85% for more than 10 minutes."

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) * 100 < 15
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ \$labels.instance }}"
          description: "Disk space is below 15% on {{ \$labels.mountpoint }}."

      - alert: DiskSpaceCritical
        expr: (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}) * 100 < 5
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Critical disk space on {{ \$labels.instance }}"
          description: "Disk space is below 5% on {{ \$labels.mountpoint }}."

  - name: blackbox_alerts
    rules:
      - alert: EndpointDown
        expr: probe_success == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Endpoint {{ \$labels.instance }} is down"
          description: "{{ \$labels.instance }} has been unreachable for more than 2 minutes."

      - alert: SSLCertExpiringSoon
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 14
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "SSL certificate expiring soon on {{ \$labels.instance }}"
          description: "SSL certificate will expire in less than 14 days."

      - alert: SSLCertExpiryCritical
        expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 7
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "SSL certificate expiring very soon on {{ \$labels.instance }}"
          description: "SSL certificate will expire in less than 7 days."
EOF

chown -R prometheus:prometheus /etc/prometheus

# Создание systemd сервиса для Prometheus
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=${STORAGE_PATH} \\
  --storage.tsdb.retention.time=${RETENTION} \\
  --web.listen-address=${LISTEN_ADDRESS}:${PROMETHEUS_PORT} \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.enable-lifecycle

SyslogIdentifier=prometheus
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#############################################
# Установка Node Exporter
#############################################

download_and_install "Node Exporter" "prometheus/node_exporter" "$NODE_EXPORTER_VERSION" "node_exporter"

# Создание systemd сервиса для Node Exporter
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/node_exporter \\
  --web.listen-address=${LISTEN_ADDRESS}:${NODE_EXPORTER_PORT} \\
  --collector.filesystem.mount-points-exclude="^/(sys|proc|dev|host|etc)($$|/)" \\
  --collector.netclass.ignored-devices="^(veth.*|docker.*|br-.*)$$"

SyslogIdentifier=node_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#############################################
# Установка Blackbox Exporter
#############################################

download_and_install "Blackbox Exporter" "prometheus/blackbox_exporter" "$BLACKBOX_EXPORTER_VERSION" "blackbox_exporter"

# Создание конфигурации Blackbox Exporter
mkdir -p /etc/blackbox_exporter

cat > /etc/blackbox_exporter/blackbox.yml << EOF
modules:
  http_2xx:
    prober: http
    timeout: 10s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200, 201, 202, 204, 301, 302, 303, 304, 307, 308]
      method: GET
      follow_redirects: true
      fail_if_ssl: false
      fail_if_not_ssl: false
      tls_config:
        insecure_skip_verify: false

  http_post_2xx:
    prober: http
    timeout: 10s
    http:
      method: POST

  tcp_connect:
    prober: tcp
    timeout: 10s

  icmp:
    prober: icmp
    timeout: 5s
    icmp:
      preferred_ip_protocol: "ip4"

  dns_udp:
    prober: dns
    timeout: 5s
    dns:
      query_name: "example.com"
      query_type: "A"
      transport_protocol: "udp"
EOF

chown -R prometheus:prometheus /etc/blackbox_exporter

# Создание systemd сервиса для Blackbox Exporter
cat > /etc/systemd/system/blackbox_exporter.service << EOF
[Unit]
Description=Prometheus Blackbox Exporter
Documentation=https://github.com/prometheus/blackbox_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/blackbox_exporter \\
  --config.file=/etc/blackbox_exporter/blackbox.yml \\
  --web.listen-address=${LISTEN_ADDRESS}:${BLACKBOX_EXPORTER_PORT}

SyslogIdentifier=blackbox_exporter
Restart=always
RestartSec=5

# ICMP requires CAP_NET_RAW
AmbientCapabilities=CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF

#############################################
# Установка Alertmanager (опционально)
#############################################

if [ "$INSTALL_ALERTMANAGER" = true ]; then
    download_and_install "Alertmanager" "prometheus/alertmanager" "$ALERTMANAGER_VERSION" "alertmanager"
    
    # Создание конфигурации Alertmanager
    mkdir -p /etc/alertmanager
    
    cat > /etc/alertmanager/alertmanager.yml << EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default'
  routes:
    - match:
        severity: critical
      receiver: 'critical'

receivers:
  - name: 'default'
    # Настройте получателей уведомлений
    # webhook_configs:
    #   - url: 'http://alertmanager-webhook:5001/'

  - name: 'critical'
    # Настройте получателей критических уведомлений

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF
    
    chown -R prometheus:prometheus /etc/alertmanager
    
    # Создание systemd сервиса для Alertmanager
    cat > /etc/systemd/system/alertmanager.service << EOF
[Unit]
Description=Prometheus Alertmanager
Documentation=https://prometheus.io/docs/alerting/alertmanager/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/alertmanager \\
  --config.file=/etc/alertmanager/alertmanager.yml \\
  --storage.path=/var/lib/alertmanager \\
  --web.listen-address=${LISTEN_ADDRESS}:${ALERTMANAGER_PORT}

SyslogIdentifier=alertmanager
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

#############################################
# Установка Postgres Exporter (опционально)
#############################################

if [ "$INSTALL_POSTGRES_EXPORTER" = true ]; then
    download_and_install "Postgres Exporter" "prometheus-community/postgres_exporter" "$POSTGRES_EXPORTER_VERSION" "postgres_exporter"
    
    # Создание файла с переменными окружения для подключения
    mkdir -p /etc/postgres_exporter
    
    cat > /etc/postgres_exporter/postgres_exporter.env << EOF
DATA_SOURCE_NAME=postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DATABASE}?sslmode=disable
EOF
    
    chmod 600 /etc/postgres_exporter/postgres_exporter.env
    chown prometheus:prometheus /etc/postgres_exporter/postgres_exporter.env
    
    # Создание systemd сервиса для Postgres Exporter
    cat > /etc/systemd/system/postgres_exporter.service << EOF
[Unit]
Description=Prometheus PostgreSQL Exporter
Documentation=https://github.com/prometheus-community/postgres_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
EnvironmentFile=/etc/postgres_exporter/postgres_exporter.env
ExecStart=/usr/local/bin/postgres_exporter \\
  --web.listen-address=${LISTEN_ADDRESS}:${POSTGRES_EXPORTER_PORT}

SyslogIdentifier=postgres_exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    print_info ""
    print_warn "Для работы Postgres Exporter необходимо создать пользователя в PostgreSQL:"
    print_info "  CREATE USER ${PG_USER} WITH PASSWORD '${PG_PASSWORD}';"
    print_info "  GRANT pg_monitor TO ${PG_USER};"
fi

#############################################
# Установка Proxmox VE Exporter (опционально)
#############################################

if [ "$INSTALL_PROXMOX" = true ]; then
    print_step "Установка Proxmox VE Exporter..."
    
    # Установка pve-exporter через pip
    apt-get install -y python3-pip python3-venv
    
    # Создание виртуального окружения
    python3 -m venv /opt/prometheus-pve-exporter
    /opt/prometheus-pve-exporter/bin/pip install prometheus-pve-exporter
    
    # Создание конфигурации
    mkdir -p /etc/prometheus-pve-exporter
    
    cat > /etc/prometheus-pve-exporter/pve.yml << EOF
default:
  user: ${PROXMOX_USER}
  token_name: ${PROXMOX_TOKEN_ID}
  token_value: ${PROXMOX_TOKEN_SECRET}
  verify_ssl: false
EOF
    
    chmod 600 /etc/prometheus-pve-exporter/pve.yml
    chown prometheus:prometheus /etc/prometheus-pve-exporter/pve.yml
    
    # Создание systemd сервиса для PVE Exporter
    cat > /etc/systemd/system/prometheus-pve-exporter.service << EOF
[Unit]
Description=Prometheus Proxmox VE Exporter
Documentation=https://github.com/prometheus-pve/prometheus-pve-exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/opt/prometheus-pve-exporter/bin/pve_exporter \\
  --config.file=/etc/prometheus-pve-exporter/pve.yml \\
  --web.listen-address=${LISTEN_ADDRESS}:9221

SyslogIdentifier=prometheus-pve-exporter
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    print_info "✓ Proxmox VE Exporter установлен"
    print_info ""
    print_warn "Для работы необходимо создать API токен в Proxmox VE:"
    print_info "  1. Datacenter → Permissions → API Tokens → Add"
    print_info "  2. User: ${PROXMOX_USER}"
    print_info "  3. Token ID: ${PROXMOX_TOKEN_ID}"
    print_info "  4. Privilege Separation: включить"
    print_info "  5. Добавить роль PVEAuditor для токена на уровне /"
fi

#############################################
# Запуск сервисов
#############################################

print_step "Перезагрузка systemd и запуск сервисов..."

systemctl daemon-reload

# Запуск и включение сервисов
systemctl enable --now prometheus
systemctl enable --now node_exporter
systemctl enable --now blackbox_exporter

[ "$INSTALL_ALERTMANAGER" = true ] && systemctl enable --now alertmanager
[ "$INSTALL_POSTGRES_EXPORTER" = true ] && systemctl enable --now postgres_exporter
[ "$INSTALL_PROXMOX" = true ] && systemctl enable --now prometheus-pve-exporter

# Ожидание запуска
sleep 3

# Проверка статуса
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

check_service prometheus || FAILED=true
check_service node_exporter || FAILED=true
check_service blackbox_exporter || FAILED=true
[ "$INSTALL_ALERTMANAGER" = true ] && { check_service alertmanager || FAILED=true; }
[ "$INSTALL_POSTGRES_EXPORTER" = true ] && { check_service postgres_exporter || FAILED=true; }
[ "$INSTALL_PROXMOX" = true ] && { check_service prometheus-pve-exporter || FAILED=true; }

if [ "$FAILED" = true ]; then
    print_error ""
    print_error "Некоторые сервисы не запустились. Проверьте логи:"
    print_error "  journalctl -u <service_name> -n 50"
    exit 1
fi

# Итоговая информация
echo ""
echo "=============================================="
print_info "✓ Установка Prometheus Stack завершена!"
echo "=============================================="
echo ""

IP_ADDR=$(hostname -I | awk '{print $1}')

print_info "Установленные компоненты:"
print_info "  • Prometheus:        http://${IP_ADDR}:${PROMETHEUS_PORT}"
print_info "  • Node Exporter:     http://${IP_ADDR}:${NODE_EXPORTER_PORT}/metrics"
print_info "  • Blackbox Exporter: http://${IP_ADDR}:${BLACKBOX_EXPORTER_PORT}"
[ "$INSTALL_ALERTMANAGER" = true ] && print_info "  • Alertmanager:      http://${IP_ADDR}:${ALERTMANAGER_PORT}"
[ "$INSTALL_POSTGRES_EXPORTER" = true ] && print_info "  • Postgres Exporter: http://${IP_ADDR}:${POSTGRES_EXPORTER_PORT}/metrics"
[ "$INSTALL_PROXMOX" = true ] && print_info "  • PVE Exporter:      http://${IP_ADDR}:9221/pve"

echo ""
print_info "Конфигурация:"
print_info "  Prometheus config:   /etc/prometheus/prometheus.yml"
print_info "  Alerting rules:      /etc/prometheus/rules/"
print_info "  Targets (file_sd):   /etc/prometheus/targets/"
print_info "  Data storage:        ${STORAGE_PATH}"

echo ""
print_info "Управление сервисами:"
print_info "  systemctl status prometheus"
print_info "  systemctl restart prometheus"
print_info "  systemctl reload prometheus  # перечитать конфигурацию"

echo ""
print_info "Добавление целей для мониторинга:"
print_info "  1. Отредактируйте /etc/prometheus/targets/nodes.yml"
print_info "  2. Или /etc/prometheus/targets/blackbox-http.yml"
print_info "  3. Prometheus автоматически подхватит изменения"

if [ "$ALLOW_REMOTE" = false ]; then
    echo ""
    print_warn "Удалённый доступ отключен. Для подключения Grafana используйте:"
    print_warn "  SSH туннель: ssh -L 9090:localhost:9090 root@${IP_ADDR}"
    print_warn "  Или перезапустите с --allow-remote"
fi

echo ""

