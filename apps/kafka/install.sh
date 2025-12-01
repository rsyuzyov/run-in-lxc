#!/bin/bash

#############################################
# Apache Kafka Installation Script for LXC
# Поддержка: KRaft mode (default), ZooKeeper mode
# Опционально: Kafka UI, Schema Registry, Kafka Connect, Prometheus Exporter
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Версии по умолчанию
KAFKA_VERSION="3.7.0"
SCALA_VERSION="2.13"
KAFKA_UI_VERSION="latest"
SCHEMA_REGISTRY_VERSION="7.6.0"

# Режим установки
MODE="single"              # single, cluster
USE_ZOOKEEPER=false        # KRaft по умолчанию
NODE_ID=1
CLUSTER_ID=""

# Пути
KAFKA_HOME="/opt/kafka"
DATA_DIR="/var/lib/kafka"
LOG_DIR="/var/log/kafka"
CONFIG_DIR="/etc/kafka"

# Сеть
LISTEN_ADDRESS="0.0.0.0"
ADVERTISED_HOST=""
KAFKA_PORT=9092
CONTROLLER_PORT=9093
ZOOKEEPER_PORT=2181

# Кластер (KRaft)
CONTROLLER_QUORUM=""
BOOTSTRAP_SERVERS=""

# Хранилище
RETENTION_HOURS=168        # 7 дней
RETENTION_BYTES=-1         # без лимита
LOG_SEGMENT_BYTES=1073741824  # 1GB

# JVM
HEAP_SIZE="2g"
JVM_OPTS=""

# Опциональные компоненты
INSTALL_UI=false
UI_TYPE="kafka-ui"         # kafka-ui, akhq, kafdrop
UI_PORT=8080

INSTALL_SCHEMA_REGISTRY=false
SCHEMA_REGISTRY_PORT=8081

INSTALL_CONNECT=false
CONNECT_PORT=8083
CONNECT_GROUP_ID="kafka-connect-cluster"

INSTALL_PROMETHEUS=false
KAFKA_EXPORTER_PORT=9308

# ZooKeeper
ZOOKEEPER_CONNECT="localhost:2181"
ZOOKEEPER_DATA_DIR="/var/lib/zookeeper"

# Безопасность
ENABLE_SSL=false
ENABLE_SASL=false
SSL_KEYSTORE_PATH=""
SSL_KEYSTORE_PASSWORD=""
SSL_TRUSTSTORE_PATH=""
SSL_TRUSTSTORE_PASSWORD=""
SASL_MECHANISM="PLAIN"
SASL_USERS=""

# Скрипт директория
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

# Функция помощи
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Скрипт установки Apache Kafka для LXC контейнеров.
По умолчанию устанавливается single-node Kafka в режиме KRaft (без ZooKeeper).

Рекомендуемые ресурсы LXC: 4 CPU, 8 GB RAM, 50+ GB диска.

Основные опции:
  --version VERSION         Версия Kafka (по умолчанию: ${KAFKA_VERSION})
  --mode single|cluster     Режим установки (по умолчанию: single)
  --with-zookeeper          Использовать ZooKeeper вместо KRaft
  --help                    Показать эту справку

Опции single-node:
  --node-id ID              ID ноды (по умолчанию: 1)

Опции кластера (--mode cluster):
  --node-id ID              ID ноды в кластере (уникальный)
  --controller-quorum HOSTS Контроллеры: 1@host1:9093,2@host2:9093,3@host3:9093
  --bootstrap-servers HOSTS Брокеры: host1:9092,host2:9092,host3:9092

Опции ZooKeeper (--with-zookeeper):
  --zookeeper-connect HOSTS Адреса ZooKeeper (по умолчанию: localhost:2181)

Настройки сети:
  --advertised-host HOST    Внешний адрес для клиентов
  --kafka-port PORT         Порт Kafka (по умолчанию: 9092)

Настройки хранения:
  --data-dir PATH           Путь к данным (по умолчанию: /var/lib/kafka)
  --retention-hours HOURS   Время хранения сообщений (по умолчанию: 168)
  --retention-bytes SIZE    Макс. размер на partition (-1 = без лимита)

Настройки JVM:
  --heap-size SIZE          Размер heap (по умолчанию: 2g)
  --jvm-opts "OPTS"         Дополнительные JVM опции

Дополнительные компоненты:
  --with-ui [TYPE]          Установить Web UI (kafka-ui|akhq|kafdrop)
  --ui-port PORT            Порт Web UI (по умолчанию: 8080)
  --with-schema-registry    Установить Confluent Schema Registry
  --schema-registry-port P  Порт Schema Registry (по умолчанию: 8081)
  --with-connect            Установить Kafka Connect
  --connect-port PORT       Порт Kafka Connect (по умолчанию: 8083)
  --prometheus              Установить Kafka Exporter для Prometheus

Безопасность:
  --ssl                     Включить SSL/TLS
  --ssl-keystore PATH       Путь к keystore
  --ssl-keystore-pass PASS  Пароль keystore
  --ssl-truststore PATH     Путь к truststore
  --ssl-truststore-pass P   Пароль truststore
  --sasl                    Включить SASL аутентификацию
  --sasl-mechanism MECH     Механизм SASL (PLAIN|SCRAM-SHA-256|SCRAM-SHA-512)
  --sasl-users USER:PASS    Пользователи (user1:pass1,user2:pass2)

Примеры:
  # Single-node (KRaft mode)
  $0

  # Single-node с Web UI и Schema Registry
  $0 --with-ui --with-schema-registry

  # Single-node с ZooKeeper
  $0 --with-zookeeper

  # Кластер из 3 нод (запустить на каждой ноде)
  # Нода 1:
  $0 --mode cluster --node-id 1 \\
     --controller-quorum "1@node1:9093,2@node2:9093,3@node3:9093" \\
     --bootstrap-servers "node1:9092,node2:9092,node3:9092" \\
     --advertised-host node1

  # С полным стеком мониторинга
  $0 --with-ui --with-schema-registry --with-connect --prometheus

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            KAFKA_VERSION="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            if [[ "$MODE" != "single" && "$MODE" != "cluster" ]]; then
                print_error "Неверный режим: $MODE. Используйте: single или cluster"
                exit 1
            fi
            shift 2
            ;;
        --with-zookeeper)
            USE_ZOOKEEPER=true
            shift
            ;;
        --node-id)
            NODE_ID="$2"
            shift 2
            ;;
        --cluster-id)
            CLUSTER_ID="$2"
            shift 2
            ;;
        --controller-quorum)
            CONTROLLER_QUORUM="$2"
            shift 2
            ;;
        --bootstrap-servers)
            BOOTSTRAP_SERVERS="$2"
            shift 2
            ;;
        --zookeeper-connect)
            ZOOKEEPER_CONNECT="$2"
            shift 2
            ;;
        --advertised-host)
            ADVERTISED_HOST="$2"
            shift 2
            ;;
        --kafka-port)
            KAFKA_PORT="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --retention-hours)
            RETENTION_HOURS="$2"
            shift 2
            ;;
        --retention-bytes)
            RETENTION_BYTES="$2"
            shift 2
            ;;
        --heap-size)
            HEAP_SIZE="$2"
            shift 2
            ;;
        --jvm-opts)
            JVM_OPTS="$2"
            shift 2
            ;;
        --with-ui)
            INSTALL_UI=true
            if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
                UI_TYPE="$2"
                shift
            fi
            shift
            ;;
        --ui-port)
            UI_PORT="$2"
            shift 2
            ;;
        --with-schema-registry)
            INSTALL_SCHEMA_REGISTRY=true
            shift
            ;;
        --schema-registry-port)
            SCHEMA_REGISTRY_PORT="$2"
            shift 2
            ;;
        --with-connect)
            INSTALL_CONNECT=true
            shift
            ;;
        --connect-port)
            CONNECT_PORT="$2"
            shift 2
            ;;
        --prometheus)
            INSTALL_PROMETHEUS=true
            shift
            ;;
        --ssl)
            ENABLE_SSL=true
            shift
            ;;
        --ssl-keystore)
            SSL_KEYSTORE_PATH="$2"
            shift 2
            ;;
        --ssl-keystore-pass)
            SSL_KEYSTORE_PASSWORD="$2"
            shift 2
            ;;
        --ssl-truststore)
            SSL_TRUSTSTORE_PATH="$2"
            shift 2
            ;;
        --ssl-truststore-pass)
            SSL_TRUSTSTORE_PASSWORD="$2"
            shift 2
            ;;
        --sasl)
            ENABLE_SASL=true
            shift
            ;;
        --sasl-mechanism)
            SASL_MECHANISM="$2"
            shift 2
            ;;
        --sasl-users)
            SASL_USERS="$2"
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

# Определение advertised host
if [ -z "$ADVERTISED_HOST" ]; then
    ADVERTISED_HOST=$(hostname -I | awk '{print $1}')
fi

# Проверка параметров кластера
if [ "$MODE" = "cluster" ]; then
    if [ -z "$CONTROLLER_QUORUM" ]; then
        print_error "Для кластерного режима необходимо указать --controller-quorum"
        exit 1
    fi
    if [ -z "$BOOTSTRAP_SERVERS" ]; then
        print_error "Для кластерного режима необходимо указать --bootstrap-servers"
        exit 1
    fi
else
    # Single-node defaults
    CONTROLLER_QUORUM="${NODE_ID}@localhost:${CONTROLLER_PORT}"
    BOOTSTRAP_SERVERS="localhost:${KAFKA_PORT}"
fi

# Проверка SSL параметров
if [ "$ENABLE_SSL" = true ]; then
    if [ -z "$SSL_KEYSTORE_PATH" ] || [ -z "$SSL_KEYSTORE_PASSWORD" ]; then
        print_warn "SSL включен, но keystore не указан. Будет создан self-signed сертификат."
    fi
fi

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка Apache Kafka"
echo "=============================================="
print_info "Версия: ${KAFKA_VERSION}"
print_info "Режим: ${MODE}"
print_info "Координация: $([ "$USE_ZOOKEEPER" = true ] && echo "ZooKeeper" || echo "KRaft")"
print_info "Node ID: ${NODE_ID}"
print_info "Advertised Host: ${ADVERTISED_HOST}"
echo ""
print_info "Компоненты:"
print_info "  • Apache Kafka ${KAFKA_VERSION}"
[ "$USE_ZOOKEEPER" = true ] && print_info "  • ZooKeeper (встроенный)"
[ "$INSTALL_UI" = true ] && print_info "  • Web UI (${UI_TYPE})"
[ "$INSTALL_SCHEMA_REGISTRY" = true ] && print_info "  • Schema Registry"
[ "$INSTALL_CONNECT" = true ] && print_info "  • Kafka Connect"
[ "$INSTALL_PROMETHEUS" = true ] && print_info "  • Kafka Exporter (Prometheus)"
echo ""
print_info "Настройки:"
print_info "  Data dir: ${DATA_DIR}"
print_info "  Retention: ${RETENTION_HOURS} часов"
print_info "  Heap size: ${HEAP_SIZE}"
[ "$ENABLE_SSL" = true ] && print_info "  SSL: включен"
[ "$ENABLE_SASL" = true ] && print_info "  SASL: включен (${SASL_MECHANISM})"
echo "=============================================="
echo ""

#############################################
# Установка зависимостей
#############################################

print_step "Установка зависимостей..."
apt-get update
apt-get install -y wget curl tar gzip openjdk-17-jdk-headless netcat-openbsd jq

# Проверка Java
JAVA_VERSION=$(java -version 2>&1 | head -n 1)
print_info "Java: ${JAVA_VERSION}"

#############################################
# Создание пользователя и директорий
#############################################

print_step "Создание системного пользователя kafka..."
if ! id "kafka" &>/dev/null; then
    useradd --system --no-create-home --shell /bin/false kafka
fi

print_step "Создание директорий..."
mkdir -p "$KAFKA_HOME"
mkdir -p "$DATA_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "${DATA_DIR}/kraft-combined-logs"

if [ "$USE_ZOOKEEPER" = true ]; then
    mkdir -p "$ZOOKEEPER_DATA_DIR"
fi

#############################################
# Скачивание и установка Kafka
#############################################

print_step "Скачивание Apache Kafka ${KAFKA_VERSION}..."

KAFKA_ARCHIVE="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
KAFKA_URL="https://downloads.apache.org/kafka/${KAFKA_VERSION}/${KAFKA_ARCHIVE}"

# Проверка доступности основного URL, если нет - используем архив
if ! curl -sf --head "$KAFKA_URL" > /dev/null 2>&1; then
    KAFKA_URL="https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/${KAFKA_ARCHIVE}"
fi

cd /tmp
wget -q --show-progress "$KAFKA_URL"

print_step "Распаковка Kafka..."
tar -xzf "$KAFKA_ARCHIVE" -C /opt
rm -f "$KAFKA_ARCHIVE"

# Создание символической ссылки
rm -f "$KAFKA_HOME"
ln -sf "/opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}" "$KAFKA_HOME"

# Создание ссылок на бинарники
for bin in kafka-topics.sh kafka-console-producer.sh kafka-console-consumer.sh \
           kafka-consumer-groups.sh kafka-configs.sh kafka-acls.sh \
           kafka-metadata.sh kafka-storage.sh kafka-cluster.sh; do
    if [ -f "${KAFKA_HOME}/bin/${bin}" ]; then
        ln -sf "${KAFKA_HOME}/bin/${bin}" "/usr/local/bin/${bin%.sh}"
    fi
done

print_info "✓ Kafka ${KAFKA_VERSION} установлен в ${KAFKA_HOME}"

#############################################
# Генерация Cluster ID (для KRaft)
#############################################

if [ "$USE_ZOOKEEPER" = false ]; then
    if [ -z "$CLUSTER_ID" ]; then
        print_step "Генерация Cluster ID..."
        CLUSTER_ID=$("${KAFKA_HOME}/bin/kafka-storage.sh" random-uuid)
        print_info "Cluster ID: ${CLUSTER_ID}"
        
        # Сохранение Cluster ID для использования на других нодах
        echo "$CLUSTER_ID" > "${CONFIG_DIR}/cluster-id"
    fi
fi

#############################################
# Конфигурация Kafka (KRaft mode)
#############################################

if [ "$USE_ZOOKEEPER" = false ]; then
    print_step "Создание конфигурации Kafka (KRaft mode)..."
    
    # Определение роли процесса
    if [ "$MODE" = "single" ]; then
        PROCESS_ROLES="broker,controller"
        LISTENERS="PLAINTEXT://${LISTEN_ADDRESS}:${KAFKA_PORT},CONTROLLER://${LISTEN_ADDRESS}:${CONTROLLER_PORT}"
        ADVERTISED_LISTENERS="PLAINTEXT://${ADVERTISED_HOST}:${KAFKA_PORT}"
        CONTROLLER_LISTENER_NAMES="CONTROLLER"
    else
        PROCESS_ROLES="broker,controller"
        LISTENERS="PLAINTEXT://${LISTEN_ADDRESS}:${KAFKA_PORT},CONTROLLER://${LISTEN_ADDRESS}:${CONTROLLER_PORT}"
        ADVERTISED_LISTENERS="PLAINTEXT://${ADVERTISED_HOST}:${KAFKA_PORT}"
        CONTROLLER_LISTENER_NAMES="CONTROLLER"
    fi
    
    # SSL настройки
    SSL_CONFIG=""
    if [ "$ENABLE_SSL" = true ]; then
        LISTENERS="SSL://${LISTEN_ADDRESS}:${KAFKA_PORT},CONTROLLER://${LISTEN_ADDRESS}:${CONTROLLER_PORT}"
        ADVERTISED_LISTENERS="SSL://${ADVERTISED_HOST}:${KAFKA_PORT}"
        
        SSL_CONFIG="
# SSL Configuration
ssl.keystore.location=${SSL_KEYSTORE_PATH:-/etc/kafka/ssl/kafka.keystore.jks}
ssl.keystore.password=${SSL_KEYSTORE_PASSWORD:-changeit}
ssl.key.password=${SSL_KEYSTORE_PASSWORD:-changeit}
ssl.truststore.location=${SSL_TRUSTSTORE_PATH:-/etc/kafka/ssl/kafka.truststore.jks}
ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD:-changeit}
ssl.endpoint.identification.algorithm=
ssl.client.auth=required
"
    fi
    
    # SASL настройки
    SASL_CONFIG=""
    if [ "$ENABLE_SASL" = true ]; then
        if [ "$ENABLE_SSL" = true ]; then
            LISTENERS="SASL_SSL://${LISTEN_ADDRESS}:${KAFKA_PORT},CONTROLLER://${LISTEN_ADDRESS}:${CONTROLLER_PORT}"
            ADVERTISED_LISTENERS="SASL_SSL://${ADVERTISED_HOST}:${KAFKA_PORT}"
            SECURITY_PROTOCOL="SASL_SSL"
        else
            LISTENERS="SASL_PLAINTEXT://${LISTEN_ADDRESS}:${KAFKA_PORT},CONTROLLER://${LISTEN_ADDRESS}:${CONTROLLER_PORT}"
            ADVERTISED_LISTENERS="SASL_PLAINTEXT://${ADVERTISED_HOST}:${KAFKA_PORT}"
            SECURITY_PROTOCOL="SASL_PLAINTEXT"
        fi
        
        SASL_CONFIG="
# SASL Configuration
sasl.enabled.mechanisms=${SASL_MECHANISM}
sasl.mechanism.inter.broker.protocol=${SASL_MECHANISM}
security.inter.broker.protocol=${SECURITY_PROTOCOL}
"
    fi
    
    cat > "${CONFIG_DIR}/server.properties" << EOF
# Apache Kafka Configuration (KRaft Mode)
# Generated by install.sh

#############################################
# Server Basics
#############################################

# Node ID (unique in cluster)
node.id=${NODE_ID}

# Process roles (broker, controller, or both)
process.roles=${PROCESS_ROLES}

# Controller quorum voters
controller.quorum.voters=${CONTROLLER_QUORUM}

#############################################
# Listeners
#############################################

# Network listeners
listeners=${LISTENERS}

# Advertised listeners for clients
advertised.listeners=${ADVERTISED_LISTENERS}

# Controller listener name
controller.listener.names=${CONTROLLER_LISTENER_NAMES}

# Listener security protocol map
listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL

# Inter-broker listener
inter.broker.listener.name=PLAINTEXT

#############################################
# Log Directories
#############################################

# Kafka data directory
log.dirs=${DATA_DIR}/kraft-combined-logs

#############################################
# Topic Defaults
#############################################

# Default number of partitions
num.partitions=3

# Default replication factor
default.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")

# Min in-sync replicas
min.insync.replicas=$([ "$MODE" = "cluster" ] && echo "2" || echo "1")

# Auto create topics
auto.create.topics.enable=true

#############################################
# Log Retention
#############################################

# Retention time (hours)
log.retention.hours=${RETENTION_HOURS}

# Retention size per partition (-1 = unlimited)
log.retention.bytes=${RETENTION_BYTES}

# Log segment size
log.segment.bytes=${LOG_SEGMENT_BYTES}

# Log cleanup policy (delete, compact, or both)
log.cleanup.policy=delete

# Check interval for log cleaner
log.retention.check.interval.ms=300000

#############################################
# Performance Tuning
#############################################

# Number of network threads
num.network.threads=3

# Number of I/O threads
num.io.threads=8

# Socket buffer sizes
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

# Number of recovery threads per data directory
num.recovery.threads.per.data.dir=1

#############################################
# Group Coordinator
#############################################

# Offsets topic replication factor
offsets.topic.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")

# Transaction state log replication factor
transaction.state.log.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")

# Transaction state log min ISR
transaction.state.log.min.isr=$([ "$MODE" = "cluster" ] && echo "2" || echo "1")

#############################################
# Metrics
#############################################

# Enable JMX
# JMX is configured via environment variables

${SSL_CONFIG}
${SASL_CONFIG}
EOF

    # Форматирование хранилища
    print_step "Форматирование хранилища KRaft..."
    "${KAFKA_HOME}/bin/kafka-storage.sh" format \
        -t "$CLUSTER_ID" \
        -c "${CONFIG_DIR}/server.properties" \
        --ignore-formatted
    
    print_info "✓ Конфигурация KRaft создана"
fi

#############################################
# Конфигурация ZooKeeper (если включен)
#############################################

if [ "$USE_ZOOKEEPER" = true ]; then
    print_step "Создание конфигурации ZooKeeper..."
    
    cat > "${CONFIG_DIR}/zookeeper.properties" << EOF
# ZooKeeper Configuration
# Generated by install.sh

# Data directory
dataDir=${ZOOKEEPER_DATA_DIR}

# Client port
clientPort=${ZOOKEEPER_PORT}

# Disable admin server
admin.enableServer=false

# Max client connections
maxClientCnxns=100

# Tick time (ms)
tickTime=2000

# Init limit (ticks)
initLimit=10

# Sync limit (ticks)
syncLimit=5

# Autopurge settings
autopurge.snapRetainCount=3
autopurge.purgeInterval=1
EOF

    # Создание myid файла
    echo "${NODE_ID}" > "${ZOOKEEPER_DATA_DIR}/myid"
    
    # Конфигурация Kafka для ZooKeeper
    print_step "Создание конфигурации Kafka (ZooKeeper mode)..."
    
    SSL_CONFIG=""
    if [ "$ENABLE_SSL" = true ]; then
        SSL_CONFIG="
# SSL Configuration
ssl.keystore.location=${SSL_KEYSTORE_PATH:-/etc/kafka/ssl/kafka.keystore.jks}
ssl.keystore.password=${SSL_KEYSTORE_PASSWORD:-changeit}
ssl.key.password=${SSL_KEYSTORE_PASSWORD:-changeit}
ssl.truststore.location=${SSL_TRUSTSTORE_PATH:-/etc/kafka/ssl/kafka.truststore.jks}
ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD:-changeit}
ssl.endpoint.identification.algorithm=
ssl.client.auth=required
listeners=SSL://${LISTEN_ADDRESS}:${KAFKA_PORT}
advertised.listeners=SSL://${ADVERTISED_HOST}:${KAFKA_PORT}
"
    else
        SSL_CONFIG="
listeners=PLAINTEXT://${LISTEN_ADDRESS}:${KAFKA_PORT}
advertised.listeners=PLAINTEXT://${ADVERTISED_HOST}:${KAFKA_PORT}
"
    fi
    
    cat > "${CONFIG_DIR}/server.properties" << EOF
# Apache Kafka Configuration (ZooKeeper Mode)
# Generated by install.sh

#############################################
# Server Basics
#############################################

# Broker ID (unique in cluster)
broker.id=${NODE_ID}

#############################################
# ZooKeeper
#############################################

# ZooKeeper connection string
zookeeper.connect=${ZOOKEEPER_CONNECT}

# ZooKeeper session timeout
zookeeper.session.timeout.ms=18000

# ZooKeeper connection timeout
zookeeper.connection.timeout.ms=18000

#############################################
# Listeners
#############################################
${SSL_CONFIG}

#############################################
# Log Directories
#############################################

log.dirs=${DATA_DIR}/kafka-logs

#############################################
# Topic Defaults
#############################################

num.partitions=3
default.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")
min.insync.replicas=$([ "$MODE" = "cluster" ] && echo "2" || echo "1")
auto.create.topics.enable=true

#############################################
# Log Retention
#############################################

log.retention.hours=${RETENTION_HOURS}
log.retention.bytes=${RETENTION_BYTES}
log.segment.bytes=${LOG_SEGMENT_BYTES}
log.cleanup.policy=delete
log.retention.check.interval.ms=300000

#############################################
# Performance Tuning
#############################################

num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
num.recovery.threads.per.data.dir=1

#############################################
# Group Coordinator
#############################################

offsets.topic.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")
transaction.state.log.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")
transaction.state.log.min.isr=$([ "$MODE" = "cluster" ] && echo "2" || echo "1")
EOF

    mkdir -p "${DATA_DIR}/kafka-logs"
    
    print_info "✓ Конфигурация ZooKeeper создана"
fi

#############################################
# SASL конфигурация
#############################################

if [ "$ENABLE_SASL" = true ]; then
    print_step "Создание SASL конфигурации..."
    
    mkdir -p "${CONFIG_DIR}/sasl"
    
    # JAAS конфигурация
    cat > "${CONFIG_DIR}/sasl/kafka_server_jaas.conf" << EOF
KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="admin"
    password="admin-secret"
    user_admin="admin-secret"
EOF
    
    # Добавление пользователей
    if [ -n "$SASL_USERS" ]; then
        IFS=',' read -ra USERS <<< "$SASL_USERS"
        for user_pass in "${USERS[@]}"; do
            IFS=':' read -r user pass <<< "$user_pass"
            echo "    user_${user}=\"${pass}\"" >> "${CONFIG_DIR}/sasl/kafka_server_jaas.conf"
        done
    fi
    
    echo ";" >> "${CONFIG_DIR}/sasl/kafka_server_jaas.conf"
    echo "};" >> "${CONFIG_DIR}/sasl/kafka_server_jaas.conf"
    
    chmod 600 "${CONFIG_DIR}/sasl/kafka_server_jaas.conf"
    
    print_info "✓ SASL конфигурация создана"
fi

#############################################
# SSL сертификаты (self-signed)
#############################################

if [ "$ENABLE_SSL" = true ] && [ -z "$SSL_KEYSTORE_PATH" ]; then
    print_step "Генерация self-signed SSL сертификатов..."
    
    mkdir -p "${CONFIG_DIR}/ssl"
    SSL_KEYSTORE_PATH="${CONFIG_DIR}/ssl/kafka.keystore.jks"
    SSL_TRUSTSTORE_PATH="${CONFIG_DIR}/ssl/kafka.truststore.jks"
    SSL_KEYSTORE_PASSWORD="kafka-ssl-password"
    SSL_TRUSTSTORE_PASSWORD="kafka-ssl-password"
    
    # Генерация keystore
    keytool -genkeypair \
        -alias kafka \
        -keyalg RSA \
        -keysize 2048 \
        -validity 365 \
        -keystore "$SSL_KEYSTORE_PATH" \
        -storepass "$SSL_KEYSTORE_PASSWORD" \
        -keypass "$SSL_KEYSTORE_PASSWORD" \
        -dname "CN=${ADVERTISED_HOST}, OU=Kafka, O=Organization, L=City, ST=State, C=US" \
        -ext "SAN=DNS:${ADVERTISED_HOST},DNS:localhost,IP:${ADVERTISED_HOST},IP:127.0.0.1"
    
    # Экспорт сертификата
    keytool -exportcert \
        -alias kafka \
        -keystore "$SSL_KEYSTORE_PATH" \
        -storepass "$SSL_KEYSTORE_PASSWORD" \
        -file "${CONFIG_DIR}/ssl/kafka.crt"
    
    # Создание truststore
    keytool -importcert \
        -alias kafka \
        -file "${CONFIG_DIR}/ssl/kafka.crt" \
        -keystore "$SSL_TRUSTSTORE_PATH" \
        -storepass "$SSL_TRUSTSTORE_PASSWORD" \
        -noprompt
    
    # Обновление конфигурации
    sed -i "s|ssl.keystore.location=.*|ssl.keystore.location=${SSL_KEYSTORE_PATH}|" "${CONFIG_DIR}/server.properties"
    sed -i "s|ssl.keystore.password=.*|ssl.keystore.password=${SSL_KEYSTORE_PASSWORD}|" "${CONFIG_DIR}/server.properties"
    sed -i "s|ssl.key.password=.*|ssl.key.password=${SSL_KEYSTORE_PASSWORD}|" "${CONFIG_DIR}/server.properties"
    sed -i "s|ssl.truststore.location=.*|ssl.truststore.location=${SSL_TRUSTSTORE_PATH}|" "${CONFIG_DIR}/server.properties"
    sed -i "s|ssl.truststore.password=.*|ssl.truststore.password=${SSL_TRUSTSTORE_PASSWORD}|" "${CONFIG_DIR}/server.properties"
    
    chmod 600 "${CONFIG_DIR}/ssl/"*
    
    print_info "✓ SSL сертификаты созданы"
    print_warn "Пароль keystore/truststore: ${SSL_KEYSTORE_PASSWORD}"
fi

#############################################
# Установка прав
#############################################

print_step "Установка прав на директории..."
chown -R kafka:kafka "$KAFKA_HOME" || true
chown -R kafka:kafka "$DATA_DIR"
chown -R kafka:kafka "$LOG_DIR"
chown -R kafka:kafka "$CONFIG_DIR"
chown -R kafka:kafka "/opt/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"

if [ "$USE_ZOOKEEPER" = true ]; then
    chown -R kafka:kafka "$ZOOKEEPER_DATA_DIR"
fi

#############################################
# Создание systemd сервисов
#############################################

print_step "Создание systemd сервисов..."

# Переменные окружения для JVM
cat > /etc/default/kafka << EOF
# Kafka Environment Variables
KAFKA_HOME=${KAFKA_HOME}
KAFKA_HEAP_OPTS="-Xmx${HEAP_SIZE} -Xms${HEAP_SIZE}"
KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:+ExplicitGCInvokesConcurrent -XX:MaxInlineLevel=15 -Djava.awt.headless=true"
KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.port=9999 -Dcom.sun.management.jmxremote.rmi.port=9999 -Djava.rmi.server.hostname=${ADVERTISED_HOST}"
KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:${KAFKA_HOME}/config/log4j.properties"
${JVM_OPTS:+KAFKA_OPTS="${JVM_OPTS}"}
EOF

if [ "$ENABLE_SASL" = true ]; then
    echo "KAFKA_OPTS=\"\${KAFKA_OPTS} -Djava.security.auth.login.config=${CONFIG_DIR}/sasl/kafka_server_jaas.conf\"" >> /etc/default/kafka
fi

# ZooKeeper systemd сервис
if [ "$USE_ZOOKEEPER" = true ]; then
    cat > /etc/systemd/system/zookeeper.service << EOF
[Unit]
Description=Apache ZooKeeper
Documentation=https://zookeeper.apache.org/
After=network.target

[Service]
Type=simple
User=kafka
Group=kafka
EnvironmentFile=/etc/default/kafka
ExecStart=${KAFKA_HOME}/bin/zookeeper-server-start.sh ${CONFIG_DIR}/zookeeper.properties
ExecStop=${KAFKA_HOME}/bin/zookeeper-server-stop.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
fi

# Kafka systemd сервис
cat > /etc/systemd/system/kafka.service << EOF
[Unit]
Description=Apache Kafka
Documentation=https://kafka.apache.org/
$([ "$USE_ZOOKEEPER" = true ] && echo "After=network.target zookeeper.service" || echo "After=network.target")
$([ "$USE_ZOOKEEPER" = true ] && echo "Requires=zookeeper.service" || echo "")

[Service]
Type=simple
User=kafka
Group=kafka
EnvironmentFile=/etc/default/kafka
ExecStart=${KAFKA_HOME}/bin/kafka-server-start.sh ${CONFIG_DIR}/server.properties
ExecStop=${KAFKA_HOME}/bin/kafka-server-stop.sh
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#############################################
# Установка Kafka UI (опционально)
#############################################

if [ "$INSTALL_UI" = true ]; then
    print_step "Установка Kafka UI (${UI_TYPE})..."
    
    case "$UI_TYPE" in
        kafka-ui)
            # Kafka UI (провкафка/kafka-ui)
            mkdir -p /opt/kafka-ui
            
            if [ "$KAFKA_UI_VERSION" = "latest" ]; then
                KAFKA_UI_VERSION=$(curl -s https://api.github.com/repos/provectus/kafka-ui/releases/latest | jq -r '.tag_name' | sed 's/^v//')
            fi
            
            UI_JAR_URL="https://github.com/provectus/kafka-ui/releases/download/v${KAFKA_UI_VERSION}/kafka-ui-api-v${KAFKA_UI_VERSION}.jar"
            
            print_info "Скачивание Kafka UI ${KAFKA_UI_VERSION}..."
            wget -q --show-progress -O /opt/kafka-ui/kafka-ui.jar "$UI_JAR_URL"
            
            # Конфигурация
            cat > /opt/kafka-ui/application.yaml << EOF
kafka:
  clusters:
    - name: local
      bootstrapServers: ${BOOTSTRAP_SERVERS}
$([ "$INSTALL_SCHEMA_REGISTRY" = true ] && echo "      schemaRegistry: http://localhost:${SCHEMA_REGISTRY_PORT}")
$([ "$INSTALL_CONNECT" = true ] && echo "      kafkaConnect:")
$([ "$INSTALL_CONNECT" = true ] && echo "        - name: local-connect")
$([ "$INSTALL_CONNECT" = true ] && echo "          address: http://localhost:${CONNECT_PORT}")

server:
  port: ${UI_PORT}

spring:
  jmx:
    enabled: true
EOF
            
            chown -R kafka:kafka /opt/kafka-ui
            
            # Systemd сервис
            cat > /etc/systemd/system/kafka-ui.service << EOF
[Unit]
Description=Kafka UI
Documentation=https://github.com/provectus/kafka-ui
After=network.target kafka.service

[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/usr/bin/java -jar /opt/kafka-ui/kafka-ui.jar --spring.config.location=/opt/kafka-ui/application.yaml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            ;;
            
        akhq)
            # AKHQ
            mkdir -p /opt/akhq
            
            AKHQ_VERSION=$(curl -s https://api.github.com/repos/tchiotludo/akhq/releases/latest | jq -r '.tag_name')
            AKHQ_JAR_URL="https://github.com/tchiotludo/akhq/releases/download/${AKHQ_VERSION}/akhq-${AKHQ_VERSION}-all.jar"
            
            print_info "Скачивание AKHQ ${AKHQ_VERSION}..."
            wget -q --show-progress -O /opt/akhq/akhq.jar "$AKHQ_JAR_URL"
            
            cat > /opt/akhq/application.yaml << EOF
akhq:
  connections:
    local:
      properties:
        bootstrap.servers: "${BOOTSTRAP_SERVERS}"
$([ "$INSTALL_SCHEMA_REGISTRY" = true ] && echo "      schema-registry:")
$([ "$INSTALL_SCHEMA_REGISTRY" = true ] && echo "        url: \"http://localhost:${SCHEMA_REGISTRY_PORT}\"")
$([ "$INSTALL_CONNECT" = true ] && echo "      connect:")
$([ "$INSTALL_CONNECT" = true ] && echo "        - name: \"local-connect\"")
$([ "$INSTALL_CONNECT" = true ] && echo "          url: \"http://localhost:${CONNECT_PORT}\"")

micronaut:
  server:
    port: ${UI_PORT}
EOF
            
            chown -R kafka:kafka /opt/akhq
            
            cat > /etc/systemd/system/kafka-ui.service << EOF
[Unit]
Description=AKHQ (Kafka HQ)
Documentation=https://akhq.io/
After=network.target kafka.service

[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/usr/bin/java -jar /opt/akhq/akhq.jar
Environment="MICRONAUT_CONFIG_FILES=/opt/akhq/application.yaml"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            ;;
            
        kafdrop)
            # Kafdrop
            mkdir -p /opt/kafdrop
            
            KAFDROP_VERSION=$(curl -s https://api.github.com/repos/obsidiandynamics/kafdrop/releases/latest | jq -r '.tag_name')
            KAFDROP_JAR_URL="https://github.com/obsidiandynamics/kafdrop/releases/download/${KAFDROP_VERSION}/kafdrop-${KAFDROP_VERSION}.jar"
            
            print_info "Скачивание Kafdrop ${KAFDROP_VERSION}..."
            wget -q --show-progress -O /opt/kafdrop/kafdrop.jar "$KAFDROP_JAR_URL"
            
            chown -R kafka:kafka /opt/kafdrop
            
            KAFDROP_OPTS="--kafka.brokerConnect=${BOOTSTRAP_SERVERS}"
            [ "$INSTALL_SCHEMA_REGISTRY" = true ] && KAFDROP_OPTS="${KAFDROP_OPTS} --schemaregistry.connect=http://localhost:${SCHEMA_REGISTRY_PORT}"
            
            cat > /etc/systemd/system/kafka-ui.service << EOF
[Unit]
Description=Kafdrop
Documentation=https://github.com/obsidiandynamics/kafdrop
After=network.target kafka.service

[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/usr/bin/java -jar /opt/kafdrop/kafdrop.jar --server.port=${UI_PORT} ${KAFDROP_OPTS}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            ;;
    esac
    
    print_info "✓ ${UI_TYPE} установлен"
fi

#############################################
# Установка Schema Registry (опционально)
#############################################

if [ "$INSTALL_SCHEMA_REGISTRY" = true ]; then
    print_step "Установка Confluent Schema Registry..."
    
    # Добавление репозитория Confluent
    wget -qO - https://packages.confluent.io/deb/7.6/archive.key | gpg --dearmor -o /usr/share/keyrings/confluent-archive-keyring.gpg
    
    echo "deb [signed-by=/usr/share/keyrings/confluent-archive-keyring.gpg] https://packages.confluent.io/deb/7.6 stable main" > /etc/apt/sources.list.d/confluent.list
    
    apt-get update
    apt-get install -y confluent-schema-registry
    
    # Конфигурация
    cat > /etc/schema-registry/schema-registry.properties << EOF
# Schema Registry Configuration
# Generated by install.sh

listeners=http://0.0.0.0:${SCHEMA_REGISTRY_PORT}

kafkastore.bootstrap.servers=${BOOTSTRAP_SERVERS}
kafkastore.topic=_schemas
kafkastore.topic.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")

debug=false

# Schema compatibility level
schema.compatibility.level=backward
EOF
    
    # Systemd сервис (переопределение)
    mkdir -p /etc/systemd/system/confluent-schema-registry.service.d
    cat > /etc/systemd/system/confluent-schema-registry.service.d/override.conf << EOF
[Service]
User=kafka
Group=kafka
EOF
    
    chown kafka:kafka /etc/schema-registry/schema-registry.properties
    
    print_info "✓ Schema Registry установлен"
fi

#############################################
# Установка Kafka Connect (опционально)
#############################################

if [ "$INSTALL_CONNECT" = true ]; then
    print_step "Настройка Kafka Connect..."
    
    mkdir -p /opt/kafka-connect/plugins
    mkdir -p /var/lib/kafka-connect
    
    # Конфигурация Connect (distributed mode)
    cat > "${CONFIG_DIR}/connect-distributed.properties" << EOF
# Kafka Connect Distributed Configuration
# Generated by install.sh

bootstrap.servers=${BOOTSTRAP_SERVERS}

group.id=${CONNECT_GROUP_ID}

key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=org.apache.kafka.connect.json.JsonConverter

key.converter.schemas.enable=true
value.converter.schemas.enable=true

$([ "$INSTALL_SCHEMA_REGISTRY" = true ] && cat << SCHEMA_EOF
# Schema Registry integration
key.converter=io.confluent.connect.avro.AvroConverter
key.converter.schema.registry.url=http://localhost:${SCHEMA_REGISTRY_PORT}
value.converter=io.confluent.connect.avro.AvroConverter
value.converter.schema.registry.url=http://localhost:${SCHEMA_REGISTRY_PORT}
SCHEMA_EOF
)

# Internal topic settings
offset.storage.topic=connect-offsets
offset.storage.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")
offset.storage.partitions=25

config.storage.topic=connect-configs
config.storage.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")

status.storage.topic=connect-status
status.storage.replication.factor=$([ "$MODE" = "cluster" ] && echo "3" || echo "1")
status.storage.partitions=5

# Flush settings
offset.flush.interval.ms=10000

# REST API
rest.port=${CONNECT_PORT}
rest.advertised.host.name=${ADVERTISED_HOST}
rest.advertised.port=${CONNECT_PORT}

# Plugin path
plugin.path=/opt/kafka-connect/plugins
EOF
    
    chown -R kafka:kafka /opt/kafka-connect
    chown -R kafka:kafka /var/lib/kafka-connect
    chown kafka:kafka "${CONFIG_DIR}/connect-distributed.properties"
    
    # Systemd сервис
    cat > /etc/systemd/system/kafka-connect.service << EOF
[Unit]
Description=Apache Kafka Connect
Documentation=https://kafka.apache.org/documentation/#connect
After=network.target kafka.service

[Service]
Type=simple
User=kafka
Group=kafka
EnvironmentFile=/etc/default/kafka
ExecStart=${KAFKA_HOME}/bin/connect-distributed.sh ${CONFIG_DIR}/connect-distributed.properties
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
    
    print_info "✓ Kafka Connect настроен"
    print_info "  Плагины размещайте в /opt/kafka-connect/plugins/"
fi

#############################################
# Установка Kafka Exporter (опционально)
#############################################

if [ "$INSTALL_PROMETHEUS" = true ]; then
    print_step "Установка Kafka Exporter..."
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
    esac
    
    EXPORTER_VERSION=$(curl -s https://api.github.com/repos/danielqsj/kafka_exporter/releases/latest | jq -r '.tag_name' | sed 's/^v//')
    EXPORTER_URL="https://github.com/danielqsj/kafka_exporter/releases/download/v${EXPORTER_VERSION}/kafka_exporter-${EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
    
    cd /tmp
    wget -q --show-progress "$EXPORTER_URL"
    tar -xzf "kafka_exporter-${EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
    mv "kafka_exporter-${EXPORTER_VERSION}.linux-${ARCH}/kafka_exporter" /usr/local/bin/
    rm -rf "kafka_exporter-${EXPORTER_VERSION}.linux-${ARCH}"*
    
    chmod +x /usr/local/bin/kafka_exporter
    
    # Systemd сервис
    cat > /etc/systemd/system/kafka-exporter.service << EOF
[Unit]
Description=Kafka Exporter for Prometheus
Documentation=https://github.com/danielqsj/kafka_exporter
After=network.target kafka.service

[Service]
Type=simple
User=kafka
Group=kafka
ExecStart=/usr/local/bin/kafka_exporter \\
    --kafka.server=${BOOTSTRAP_SERVERS} \\
    --web.listen-address=:${KAFKA_EXPORTER_PORT} \\
    --topic.filter=".*" \\
    --group.filter=".*"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    print_info "✓ Kafka Exporter установлен"
fi

#############################################
# Создание credential файла
#############################################

print_step "Сохранение информации об установке..."

mkdir -p "${CONFIG_DIR}/credentials"
chmod 700 "${CONFIG_DIR}/credentials"

cat > "${CONFIG_DIR}/credentials/info.txt" << EOF
# Kafka Installation Info
# Generated: $(date)

Mode: ${MODE}
Coordination: $([ "$USE_ZOOKEEPER" = true ] && echo "ZooKeeper" || echo "KRaft")
Node ID: ${NODE_ID}
$([ "$USE_ZOOKEEPER" = false ] && echo "Cluster ID: ${CLUSTER_ID}")

Bootstrap Servers: ${BOOTSTRAP_SERVERS}
$([ "$USE_ZOOKEEPER" = true ] && echo "ZooKeeper: ${ZOOKEEPER_CONNECT}")

Kafka Port: ${KAFKA_PORT}
$([ "$USE_ZOOKEEPER" = false ] && echo "Controller Port: ${CONTROLLER_PORT}")
JMX Port: 9999

$([ "$ENABLE_SSL" = true ] && cat << SSL_INFO
SSL Enabled: yes
Keystore: ${SSL_KEYSTORE_PATH}
Keystore Password: ${SSL_KEYSTORE_PASSWORD}
Truststore: ${SSL_TRUSTSTORE_PATH}
Truststore Password: ${SSL_TRUSTSTORE_PASSWORD}
SSL_INFO
)

$([ "$ENABLE_SASL" = true ] && cat << SASL_INFO
SASL Enabled: yes
Mechanism: ${SASL_MECHANISM}
JAAS Config: ${CONFIG_DIR}/sasl/kafka_server_jaas.conf
SASL_INFO
)

Components:
- Kafka: ${KAFKA_PORT}
$([ "$USE_ZOOKEEPER" = true ] && echo "- ZooKeeper: ${ZOOKEEPER_PORT}")
$([ "$INSTALL_UI" = true ] && echo "- Web UI (${UI_TYPE}): ${UI_PORT}")
$([ "$INSTALL_SCHEMA_REGISTRY" = true ] && echo "- Schema Registry: ${SCHEMA_REGISTRY_PORT}")
$([ "$INSTALL_CONNECT" = true ] && echo "- Kafka Connect: ${CONNECT_PORT}")
$([ "$INSTALL_PROMETHEUS" = true ] && echo "- Kafka Exporter: ${KAFKA_EXPORTER_PORT}")
EOF

chmod 600 "${CONFIG_DIR}/credentials/info.txt"

#############################################
# Запуск сервисов
#############################################

print_step "Перезагрузка systemd и запуск сервисов..."

systemctl daemon-reload

# Запуск ZooKeeper (если включен)
if [ "$USE_ZOOKEEPER" = true ]; then
    systemctl enable --now zookeeper
    print_info "Ожидание запуска ZooKeeper..."
    sleep 5
    
    # Проверка ZooKeeper
    if ! nc -z localhost ${ZOOKEEPER_PORT}; then
        print_error "ZooKeeper не запустился. Проверьте логи: journalctl -u zookeeper"
        exit 1
    fi
fi

# Запуск Kafka
systemctl enable --now kafka

print_info "Ожидание запуска Kafka..."
sleep 10

# Проверка Kafka
RETRIES=30
while [ $RETRIES -gt 0 ]; do
    if nc -z localhost ${KAFKA_PORT}; then
        break
    fi
    RETRIES=$((RETRIES - 1))
    sleep 2
done

if ! nc -z localhost ${KAFKA_PORT}; then
    print_error "Kafka не запустился. Проверьте логи: journalctl -u kafka"
    exit 1
fi

print_info "✓ Kafka запущен"

# Запуск дополнительных компонентов
if [ "$INSTALL_SCHEMA_REGISTRY" = true ]; then
    systemctl enable --now confluent-schema-registry
    sleep 3
fi

if [ "$INSTALL_CONNECT" = true ]; then
    systemctl enable --now kafka-connect
    sleep 3
fi

if [ "$INSTALL_UI" = true ]; then
    systemctl enable --now kafka-ui
    sleep 3
fi

if [ "$INSTALL_PROMETHEUS" = true ]; then
    systemctl enable --now kafka-exporter
    sleep 2
fi

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

[ "$USE_ZOOKEEPER" = true ] && { check_service zookeeper || FAILED=true; }
check_service kafka || FAILED=true
[ "$INSTALL_SCHEMA_REGISTRY" = true ] && { check_service confluent-schema-registry || FAILED=true; }
[ "$INSTALL_CONNECT" = true ] && { check_service kafka-connect || FAILED=true; }
[ "$INSTALL_UI" = true ] && { check_service kafka-ui || FAILED=true; }
[ "$INSTALL_PROMETHEUS" = true ] && { check_service kafka-exporter || FAILED=true; }

if [ "$FAILED" = true ]; then
    print_error ""
    print_error "Некоторые сервисы не запустились. Проверьте логи:"
    print_error "  journalctl -u <service_name> -n 50"
fi

#############################################
# Создание тестового топика
#############################################

print_step "Создание тестового топика..."

"${KAFKA_HOME}/bin/kafka-topics.sh" --create \
    --topic test-topic \
    --partitions 3 \
    --replication-factor 1 \
    --if-not-exists \
    --bootstrap-server localhost:${KAFKA_PORT} 2>/dev/null || true

print_info "✓ Тестовый топик 'test-topic' создан"

#############################################
# Итоговая информация
#############################################

echo ""
echo "=============================================="
print_info "✓ Установка Apache Kafka завершена!"
echo "=============================================="
echo ""

IP_ADDR=$(hostname -I | awk '{print $1}')

print_info "Установленные компоненты:"
print_info "  • Kafka:              ${IP_ADDR}:${KAFKA_PORT}"
[ "$USE_ZOOKEEPER" = true ] && print_info "  • ZooKeeper:          ${IP_ADDR}:${ZOOKEEPER_PORT}"
print_info "  • JMX:                ${IP_ADDR}:9999"
[ "$INSTALL_UI" = true ] && print_info "  • Web UI (${UI_TYPE}): http://${IP_ADDR}:${UI_PORT}"
[ "$INSTALL_SCHEMA_REGISTRY" = true ] && print_info "  • Schema Registry:    http://${IP_ADDR}:${SCHEMA_REGISTRY_PORT}"
[ "$INSTALL_CONNECT" = true ] && print_info "  • Kafka Connect:      http://${IP_ADDR}:${CONNECT_PORT}"
[ "$INSTALL_PROMETHEUS" = true ] && print_info "  • Kafka Exporter:     http://${IP_ADDR}:${KAFKA_EXPORTER_PORT}/metrics"

echo ""
print_info "Конфигурация:"
print_info "  Kafka config:        ${CONFIG_DIR}/server.properties"
[ "$USE_ZOOKEEPER" = true ] && print_info "  ZooKeeper config:    ${CONFIG_DIR}/zookeeper.properties"
[ "$INSTALL_CONNECT" = true ] && print_info "  Connect config:      ${CONFIG_DIR}/connect-distributed.properties"
print_info "  Data directory:      ${DATA_DIR}"
print_info "  Logs:                ${LOG_DIR}"
print_info "  Credentials:         ${CONFIG_DIR}/credentials/info.txt"

if [ "$USE_ZOOKEEPER" = false ]; then
    echo ""
    print_info "KRaft Cluster ID: ${CLUSTER_ID}"
    print_info "  (сохраните для добавления других нод)"
fi

echo ""
print_info "Управление сервисами:"
print_info "  systemctl status kafka"
print_info "  systemctl restart kafka"
print_info "  journalctl -u kafka -f"

echo ""
print_info "Полезные команды:"
print_info "  # Список топиков"
print_info "  kafka-topics --list --bootstrap-server localhost:${KAFKA_PORT}"
print_info ""
print_info "  # Создание топика"
print_info "  kafka-topics --create --topic my-topic --partitions 3 --replication-factor 1 --bootstrap-server localhost:${KAFKA_PORT}"
print_info ""
print_info "  # Отправка сообщений"
print_info "  echo 'Hello Kafka' | kafka-console-producer --topic test-topic --bootstrap-server localhost:${KAFKA_PORT}"
print_info ""
print_info "  # Чтение сообщений"
print_info "  kafka-console-consumer --topic test-topic --from-beginning --bootstrap-server localhost:${KAFKA_PORT}"

if [ "$MODE" = "cluster" ]; then
    echo ""
    print_warn "Для добавления других нод в кластер используйте:"
    print_warn "  ./install.sh --mode cluster --node-id <ID> \\"
    print_warn "    --cluster-id ${CLUSTER_ID} \\"
    print_warn "    --controller-quorum \"${CONTROLLER_QUORUM}\" \\"
    print_warn "    --bootstrap-servers \"${BOOTSTRAP_SERVERS}\" \\"
    print_warn "    --advertised-host <HOST>"
fi

echo ""

