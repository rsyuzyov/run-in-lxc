#!/bin/bash

#############################################
# MariaDB Installation Script for LXC
# Поддерживает установку MariaDB, Galera Cluster, Prometheus exporter
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
MARIADB_VERSION="11.4"
USE_DISTRO_REPO=false
ROOT_PASSWORD=""
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
ALLOW_REMOTE=false
CHARSET="utf8mb4"
COLLATION="utf8mb4_unicode_ci"
PROFILE="default"
INSTALL_PROMETHEUS=false
PROMETHEUS_EXPORTER_VERSION="0.15.1"

# Galera Cluster
GALERA_ENABLED=false
GALERA_CLUSTER_NAME=""
GALERA_NODE_NAME=""
GALERA_NODE_ADDRESS=""
GALERA_CLUSTER_NODES=""
GALERA_BOOTSTRAP=false

# Директории
CREDENTIALS_DIR="/root/mariadb-credentials"
CONFIG_DIR="/etc/mysql/mariadb.conf.d"

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

Скрипт установки MariaDB для LXC контейнеров.
Поддерживает установку одиночного сервера и Galera Cluster.

Основные опции:
  --version VERSION         Версия MariaDB (по умолчанию: 11.4)
  --distro                  Использовать пакеты из репозитория дистрибутива
  --root-password PASS      Пароль root для MariaDB (рекомендуется)
  --db-name NAME            Создать базу данных с указанным именем
  --db-user USER            Создать пользователя БД
  --db-password PASS        Пароль для пользователя БД
  --allow-remote            Разрешить удалённые подключения
  --charset CHARSET         Кодировка (по умолчанию: utf8mb4)
  --collation COLLATION     Сортировка (по умолчанию: utf8mb4_unicode_ci)

Профили конфигурации:
  --profile PROFILE         Профиль конфигурации:
                             - default: базовая конфигурация
                             - web: для веб-приложений (WordPress, Drupal)
                             - analytics: для аналитики/OLAP
                             - minimal: минимальные ресурсы (dev/test)

Galera Cluster:
  --galera                  Включить Galera Cluster
  --cluster-name NAME       Имя кластера (обязательно для Galera)
  --node-name NAME          Имя текущего узла
  --node-address IP         IP-адрес текущего узла
  --cluster-nodes NODES     Список узлов кластера (IP1,IP2,IP3)
  --bootstrap               Инициализировать новый кластер (первый узел)

Мониторинг:
  --prometheus              Установить mysqld_exporter для Prometheus

Прочее:
  --help                    Показать эту справку

Примеры:
  # Базовая установка
  $0 --root-password MySecurePass123

  # Для веб-приложений с созданием БД
  $0 --profile web --root-password SecurePass \\
     --db-name wordpress --db-user wpuser --db-password WpPass123

  # Galera Cluster (первый узел)
  $0 --galera --cluster-name my_cluster --bootstrap \\
     --node-name node1 --node-address 192.168.1.10 \\
     --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12

  # Galera Cluster (присоединение к кластеру)
  $0 --galera --cluster-name my_cluster \\
     --node-name node2 --node-address 192.168.1.11 \\
     --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            MARIADB_VERSION="$2"
            shift 2
            ;;
        --distro)
            USE_DISTRO_REPO=true
            shift
            ;;
        --root-password)
            ROOT_PASSWORD="$2"
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
        --allow-remote)
            ALLOW_REMOTE=true
            shift
            ;;
        --charset)
            CHARSET="$2"
            shift 2
            ;;
        --collation)
            COLLATION="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --galera)
            GALERA_ENABLED=true
            shift
            ;;
        --cluster-name)
            GALERA_CLUSTER_NAME="$2"
            shift 2
            ;;
        --node-name)
            GALERA_NODE_NAME="$2"
            shift 2
            ;;
        --node-address)
            GALERA_NODE_ADDRESS="$2"
            shift 2
            ;;
        --cluster-nodes)
            GALERA_CLUSTER_NODES="$2"
            shift 2
            ;;
        --bootstrap)
            GALERA_BOOTSTRAP=true
            shift
            ;;
        --prometheus)
            INSTALL_PROMETHEUS=true
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

# Валидация профиля
case $PROFILE in
    default|web|analytics|minimal)
        ;;
    *)
        print_error "Неизвестный профиль: $PROFILE"
        print_error "Доступные профили: default, web, analytics, minimal"
        exit 1
        ;;
esac

# Валидация параметров Galera
if [ "$GALERA_ENABLED" = true ]; then
    if [ -z "$GALERA_CLUSTER_NAME" ]; then
        print_error "Для Galera Cluster необходимо указать --cluster-name"
        exit 1
    fi
    if [ -z "$GALERA_NODE_ADDRESS" ]; then
        # Попытка автоопределения IP
        GALERA_NODE_ADDRESS=$(hostname -I | awk '{print $1}')
        print_warn "IP узла не указан, используется: $GALERA_NODE_ADDRESS"
    fi
    if [ -z "$GALERA_NODE_NAME" ]; then
        GALERA_NODE_NAME=$(hostname)
        print_warn "Имя узла не указано, используется: $GALERA_NODE_NAME"
    fi
fi

# Проверка параметров БД
if [ -n "$DB_USER" ] && [ -z "$DB_PASSWORD" ]; then
    print_error "Если указан --db-user, необходимо также указать --db-password"
    exit 1
fi

# Генерация root пароля если не указан
if [ -z "$ROOT_PASSWORD" ]; then
    ROOT_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)
    print_warn "Пароль root не указан, сгенерирован автоматически"
fi

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
        DISTRO_CODENAME=$VERSION_CODENAME
    else
        print_error "Не удалось определить дистрибутив"
        exit 1
    fi
}

detect_distro

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка MariaDB"
echo "=============================================="
print_info "Версия: MariaDB ${MARIADB_VERSION}"
print_info "Дистрибутив: ${DISTRO} ${DISTRO_VERSION}"
print_info "Профиль: ${PROFILE}"
if [ "$USE_DISTRO_REPO" = true ]; then
    print_info "Источник: репозиторий дистрибутива"
else
    print_info "Источник: официальный репозиторий MariaDB"
fi
if [ "$GALERA_ENABLED" = true ]; then
    print_info "Galera Cluster: включен"
    print_info "  Кластер: ${GALERA_CLUSTER_NAME}"
    print_info "  Узел: ${GALERA_NODE_NAME} (${GALERA_NODE_ADDRESS})"
    if [ "$GALERA_BOOTSTRAP" = true ]; then
        print_info "  Режим: bootstrap (первый узел)"
    else
        print_info "  Режим: присоединение к кластеру"
    fi
fi
if [ "$ALLOW_REMOTE" = true ]; then
    print_info "Удалённый доступ: включен"
fi
if [ "$INSTALL_PROMETHEUS" = true ]; then
    print_info "Prometheus exporter: будет установлен"
fi
if [ -n "$DB_NAME" ]; then
    print_info "База данных: $DB_NAME"
fi
echo "=============================================="
echo ""

# Создание директории для credentials
mkdir -p "$CREDENTIALS_DIR"
chmod 700 "$CREDENTIALS_DIR"

# Установка зависимостей
print_step "Установка базовых зависимостей..."
apt-get update
apt-get install -y wget gnupg2 lsb-release apt-transport-https ca-certificates curl software-properties-common

if [ "$USE_DISTRO_REPO" = true ]; then
    #############################################
    # Установка из репозитория дистрибутива
    #############################################
    print_step "Установка MariaDB из репозитория дистрибутива..."
    
    if [ "$GALERA_ENABLED" = true ]; then
        apt-get install -y mariadb-server mariadb-client galera-4
    else
        apt-get install -y mariadb-server mariadb-client
    fi
else
    #############################################
    # Установка из официального репозитория MariaDB
    #############################################
    print_step "Добавление официального репозитория MariaDB..."
    
    # Скачивание и выполнение скрипта настройки репозитория
    curl -fsSL https://mariadb.org/mariadb_release_signing_key.pgp | gpg --dearmor -o /usr/share/keyrings/mariadb-keyring.gpg
    
    # Определение архитектуры
    ARCH=$(dpkg --print-architecture)
    
    # Добавление репозитория
    cat > /etc/apt/sources.list.d/mariadb.list << EOF
# MariaDB ${MARIADB_VERSION} repository
deb [arch=${ARCH} signed-by=/usr/share/keyrings/mariadb-keyring.gpg] https://mirror.mariadb.org/repo/${MARIADB_VERSION}/${DISTRO} ${DISTRO_CODENAME} main
EOF
    
    apt-get update
    
    print_step "Установка MariaDB ${MARIADB_VERSION}..."
    
    if [ "$GALERA_ENABLED" = true ]; then
        apt-get install -y mariadb-server mariadb-client mariadb-backup galera-4
    else
        apt-get install -y mariadb-server mariadb-client mariadb-backup
    fi
fi

# Создание директории конфигурации если не существует
mkdir -p "$CONFIG_DIR"

#############################################
# Применение профиля конфигурации
#############################################
print_step "Применение профиля конфигурации: ${PROFILE}..."

generate_profile_config() {
    local profile=$1
    local config_file="${CONFIG_DIR}/99-profile-${profile}.cnf"
    
    case $profile in
        default)
            cat > "$config_file" << EOF
# MariaDB Profile: default
# Базовая конфигурация для общего использования

[mysqld]
# Кодировка
character-set-server = ${CHARSET}
collation-server = ${COLLATION}

# InnoDB настройки
innodb_buffer_pool_size = 256M
innodb_log_file_size = 64M
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT

# Общие настройки
max_connections = 150
thread_cache_size = 8
query_cache_type = 0
query_cache_size = 0

# Логирование
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

[client]
default-character-set = ${CHARSET}
EOF
            ;;
        web)
            cat > "$config_file" << EOF
# MariaDB Profile: web
# Оптимизация для веб-приложений (WordPress, Drupal, etc.)
# Много коротких запросов, частые соединения

[mysqld]
# Кодировка
character-set-server = ${CHARSET}
collation-server = ${COLLATION}

# InnoDB настройки для веб
innodb_buffer_pool_size = 512M
innodb_buffer_pool_instances = 2
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_io_capacity = 1000
innodb_io_capacity_max = 2000

# Соединения
max_connections = 300
thread_cache_size = 16
thread_handling = pool-of-threads
thread_pool_size = 4
thread_pool_max_threads = 100

# Временные таблицы
tmp_table_size = 64M
max_heap_table_size = 64M

# Кэширование
table_open_cache = 2000
table_definition_cache = 1400

# Оптимизация запросов
join_buffer_size = 2M
sort_buffer_size = 2M
read_buffer_size = 1M
read_rnd_buffer_size = 1M

# Логирование
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1

[client]
default-character-set = ${CHARSET}
EOF
            ;;
        analytics)
            cat > "$config_file" << EOF
# MariaDB Profile: analytics
# Оптимизация для аналитики и OLAP
# Сложные запросы, большие объёмы данных

[mysqld]
# Кодировка
character-set-server = ${CHARSET}
collation-server = ${COLLATION}

# InnoDB настройки для аналитики
innodb_buffer_pool_size = 1G
innodb_buffer_pool_instances = 4
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_read_io_threads = 8
innodb_write_io_threads = 8

# Соединения (меньше, но длительнее)
max_connections = 100
thread_cache_size = 8
wait_timeout = 600
interactive_timeout = 600

# Большие буферы для сложных запросов
join_buffer_size = 16M
sort_buffer_size = 16M
read_buffer_size = 4M
read_rnd_buffer_size = 8M
tmp_table_size = 256M
max_heap_table_size = 256M

# Кэширование
table_open_cache = 4000
table_definition_cache = 2000

# Параллельное выполнение
optimizer_switch = 'join_cache_incremental=on,join_cache_hashed=on,join_cache_bka=on'

# Логирование
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 5
log_queries_not_using_indexes = 1

[client]
default-character-set = ${CHARSET}
EOF
            ;;
        minimal)
            cat > "$config_file" << EOF
# MariaDB Profile: minimal
# Минимальное потребление ресурсов для dev/test

[mysqld]
# Кодировка
character-set-server = ${CHARSET}
collation-server = ${COLLATION}

# Минимальные InnoDB настройки
innodb_buffer_pool_size = 64M
innodb_log_file_size = 16M
innodb_flush_log_at_trx_commit = 2

# Минимальные соединения
max_connections = 50
thread_cache_size = 4

# Минимальные буферы
join_buffer_size = 256K
sort_buffer_size = 256K
read_buffer_size = 128K
tmp_table_size = 16M
max_heap_table_size = 16M

# Кэширование
table_open_cache = 200
table_definition_cache = 200

# Отключить производительные функции
performance_schema = OFF

[client]
default-character-set = ${CHARSET}
EOF
            ;;
    esac
    
    chmod 644 "$config_file"
    print_info "Создан файл конфигурации: $config_file"
}

generate_profile_config "$PROFILE"

#############################################
# Настройка Galera Cluster
#############################################
if [ "$GALERA_ENABLED" = true ]; then
    print_step "Настройка Galera Cluster..."
    
    # Формирование списка узлов для wsrep_cluster_address
    WSREP_CLUSTER_ADDRESS="gcomm://"
    if [ -n "$GALERA_CLUSTER_NODES" ]; then
        WSREP_CLUSTER_ADDRESS="gcomm://${GALERA_CLUSTER_NODES}"
    fi
    
    cat > "${CONFIG_DIR}/60-galera.cnf" << EOF
# Galera Cluster Configuration
# Cluster: ${GALERA_CLUSTER_NAME}
# Node: ${GALERA_NODE_NAME}

[mysqld]
# Galera Provider
wsrep_on = ON
wsrep_provider = /usr/lib/galera/libgalera_smm.so

# Cluster Configuration
wsrep_cluster_name = "${GALERA_CLUSTER_NAME}"
wsrep_cluster_address = "${WSREP_CLUSTER_ADDRESS}"

# Node Configuration
wsrep_node_name = "${GALERA_NODE_NAME}"
wsrep_node_address = "${GALERA_NODE_ADDRESS}"

# State Transfer
wsrep_sst_method = mariabackup
wsrep_sst_auth = "mariabackup:${ROOT_PASSWORD}"

# Galera Synchronization
wsrep_slave_threads = 4
wsrep_log_conflicts = ON
wsrep_certify_nonPK = ON

# InnoDB requirements for Galera
binlog_format = ROW
default_storage_engine = InnoDB
innodb_autoinc_lock_mode = 2
innodb_doublewrite = 1

# Prevent deadlocks
wsrep_retry_autocommit = 3
EOF
    
    chmod 644 "${CONFIG_DIR}/60-galera.cnf"
    print_info "Создана конфигурация Galera: ${CONFIG_DIR}/60-galera.cnf"
fi

#############################################
# Настройка удалённого доступа
#############################################
if [ "$ALLOW_REMOTE" = true ]; then
    print_step "Настройка удалённого доступа..."
    
    # Изменение bind-address
    MAIN_CONFIG="/etc/mysql/mariadb.conf.d/50-server.cnf"
    if [ -f "$MAIN_CONFIG" ]; then
        sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' "$MAIN_CONFIG"
    fi
    
    cat > "${CONFIG_DIR}/98-remote-access.cnf" << EOF
# Remote Access Configuration
[mysqld]
bind-address = 0.0.0.0
EOF
    
    chmod 644 "${CONFIG_DIR}/98-remote-access.cnf"
    print_info "Удалённый доступ настроен"
fi

#############################################
# Запуск MariaDB
#############################################
print_step "Запуск MariaDB..."

if [ "$GALERA_ENABLED" = true ] && [ "$GALERA_BOOTSTRAP" = true ]; then
    # Bootstrap нового кластера
    print_info "Инициализация нового Galera кластера..."
    galera_new_cluster
else
    systemctl enable mariadb
    systemctl start mariadb
fi

# Ожидание запуска
sleep 3

# Проверка статуса
if systemctl is-active --quiet mariadb; then
    print_info "✓ MariaDB успешно запущен"
else
    print_error "Не удалось запустить MariaDB!"
    print_error "Проверьте логи: journalctl -u mariadb -n 50"
    exit 1
fi

#############################################
# Установка пароля root и базовая настройка
#############################################
print_step "Настройка безопасности MariaDB..."

# Установка пароля root
mysql -u root << EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
FLUSH PRIVILEGES;
EOF

# Создание .my.cnf для удобного подключения
cat > /root/.my.cnf << EOF
[client]
user = root
password = ${ROOT_PASSWORD}
EOF
chmod 600 /root/.my.cnf

print_info "✓ Пароль root установлен"

# Создание пользователя для Galera SST если включен
if [ "$GALERA_ENABLED" = true ]; then
    mysql << EOF
CREATE USER IF NOT EXISTS 'mariabackup'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
GRANT RELOAD, PROCESS, LOCK TABLES, BINLOG MONITOR ON *.* TO 'mariabackup'@'localhost';
FLUSH PRIVILEGES;
EOF
    print_info "✓ Создан пользователь для Galera SST"
fi

#############################################
# Создание базы данных и пользователя
#############################################
if [ -n "$DB_NAME" ] || [ -n "$DB_USER" ]; then
    print_step "Создание базы данных и пользователя..."
    
    SQL_COMMANDS=""
    
    if [ -n "$DB_NAME" ]; then
        SQL_COMMANDS+="CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET ${CHARSET} COLLATE ${COLLATION};"
        print_info "Создаётся база данных: $DB_NAME"
    fi
    
    if [ -n "$DB_USER" ]; then
        if [ "$ALLOW_REMOTE" = true ]; then
            SQL_COMMANDS+="CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';"
            if [ -n "$DB_NAME" ]; then
                SQL_COMMANDS+="GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';"
            fi
        fi
        SQL_COMMANDS+="CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
        if [ -n "$DB_NAME" ]; then
            SQL_COMMANDS+="GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
        fi
        SQL_COMMANDS+="FLUSH PRIVILEGES;"
        print_info "Создаётся пользователь: $DB_USER"
    fi
    
    mysql << EOF
${SQL_COMMANDS}
EOF
    
    print_info "✓ База данных и пользователь созданы"
fi

#############################################
# Установка Prometheus exporter
#############################################
if [ "$INSTALL_PROMETHEUS" = true ]; then
    print_step "Установка mysqld_exporter для Prometheus..."
    
    # Определение архитектуры
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) EXPORTER_ARCH="amd64" ;;
        aarch64) EXPORTER_ARCH="arm64" ;;
        armv7l) EXPORTER_ARCH="armv7" ;;
        *) 
            print_error "Неподдерживаемая архитектура: $ARCH"
            INSTALL_PROMETHEUS=false
            ;;
    esac
    
    if [ "$INSTALL_PROMETHEUS" = true ]; then
        # Создание пользователя для экспортера
        EXPORTER_PASSWORD=$(openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16)
        
        mysql << EOF
CREATE USER IF NOT EXISTS 'exporter'@'localhost' IDENTIFIED BY '${EXPORTER_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';
FLUSH PRIVILEGES;
EOF
        
        # Скачивание и установка экспортера
        cd /tmp
        wget -q "https://github.com/prometheus/mysqld_exporter/releases/download/v${PROMETHEUS_EXPORTER_VERSION}/mysqld_exporter-${PROMETHEUS_EXPORTER_VERSION}.linux-${EXPORTER_ARCH}.tar.gz"
        tar xzf "mysqld_exporter-${PROMETHEUS_EXPORTER_VERSION}.linux-${EXPORTER_ARCH}.tar.gz"
        mv "mysqld_exporter-${PROMETHEUS_EXPORTER_VERSION}.linux-${EXPORTER_ARCH}/mysqld_exporter" /usr/local/bin/
        chmod +x /usr/local/bin/mysqld_exporter
        rm -rf "mysqld_exporter-${PROMETHEUS_EXPORTER_VERSION}.linux-${EXPORTER_ARCH}"*
        
        # Создание конфигурации экспортера
        mkdir -p /etc/mysqld_exporter
        cat > /etc/mysqld_exporter/.my.cnf << EOF
[client]
user = exporter
password = ${EXPORTER_PASSWORD}
EOF
        chmod 600 /etc/mysqld_exporter/.my.cnf
        
        # Создание systemd сервиса
        cat > /etc/systemd/system/mysqld_exporter.service << EOF
[Unit]
Description=MySQL/MariaDB Exporter for Prometheus
After=mariadb.service
Wants=mariadb.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/mysqld_exporter \\
    --config.my-cnf=/etc/mysqld_exporter/.my.cnf \\
    --web.listen-address=:9104 \\
    --collect.global_status \\
    --collect.global_variables \\
    --collect.info_schema.tables \\
    --collect.info_schema.innodb_metrics \\
    --collect.info_schema.processlist
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable mysqld_exporter
        systemctl start mysqld_exporter
        
        if systemctl is-active --quiet mysqld_exporter; then
            print_info "✓ mysqld_exporter установлен и запущен на порту 9104"
        else
            print_warn "mysqld_exporter установлен, но не удалось запустить"
        fi
        
        # Сохранение credentials экспортера
        cat >> "${CREDENTIALS_DIR}/prometheus-exporter.txt" << EOF
# Prometheus mysqld_exporter
Endpoint: http://$(hostname -I | awk '{print $1}'):9104/metrics
User: exporter
Password: ${EXPORTER_PASSWORD}
EOF
    fi
fi

#############################################
# Сохранение credentials
#############################################
print_step "Сохранение учётных данных..."

cat > "${CREDENTIALS_DIR}/root.txt" << EOF
# MariaDB Root Credentials
# Generated: $(date)

Host: localhost
Port: 3306
User: root
Password: ${ROOT_PASSWORD}

Connection string: mysql -u root -p'${ROOT_PASSWORD}'
EOF

if [ -n "$DB_NAME" ] || [ -n "$DB_USER" ]; then
    cat > "${CREDENTIALS_DIR}/database.txt" << EOF
# MariaDB Database Credentials
# Generated: $(date)

Database: ${DB_NAME:-"(not created)"}
User: ${DB_USER:-"(not created)"}
Password: ${DB_PASSWORD:-"(not set)"}

Local connection:
  mysql -u ${DB_USER} -p'${DB_PASSWORD}' ${DB_NAME}

EOF
    
    if [ "$ALLOW_REMOTE" = true ]; then
        IP_ADDR=$(hostname -I | awk '{print $1}')
        cat >> "${CREDENTIALS_DIR}/database.txt" << EOF
Remote connection:
  mysql -h ${IP_ADDR} -u ${DB_USER} -p'${DB_PASSWORD}' ${DB_NAME}

Connection string:
  mysql://${DB_USER}:${DB_PASSWORD}@${IP_ADDR}:3306/${DB_NAME}
EOF
    fi
fi

if [ "$GALERA_ENABLED" = true ]; then
    cat > "${CREDENTIALS_DIR}/galera.txt" << EOF
# Galera Cluster Information
# Generated: $(date)

Cluster Name: ${GALERA_CLUSTER_NAME}
Node Name: ${GALERA_NODE_NAME}
Node Address: ${GALERA_NODE_ADDRESS}
Cluster Nodes: ${GALERA_CLUSTER_NODES}

SST User: mariabackup
SST Password: ${ROOT_PASSWORD}

Check cluster status:
  mysql -e "SHOW STATUS LIKE 'wsrep_%';"

Check cluster size:
  mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
EOF
fi

chmod 600 "${CREDENTIALS_DIR}"/*.txt

#############################################
# Итоговая информация
#############################################
echo ""
echo "=============================================="
print_info "✓ Установка MariaDB завершена успешно!"
echo "=============================================="
echo ""

print_info "Версия: MariaDB ${MARIADB_VERSION}"
print_info "Профиль: ${PROFILE}"
print_info "Кодировка: ${CHARSET} / ${COLLATION}"

echo ""
print_info "Управление сервисом:"
print_info "  systemctl status mariadb"
print_info "  systemctl restart mariadb"
print_info "  systemctl stop mariadb"

echo ""
print_info "Подключение к MariaDB:"
print_info "  mysql  (использует /root/.my.cnf)"
print_info "  mysql -u root -p"

if [ -n "$DB_NAME" ]; then
    echo ""
    print_info "Созданная база данных:"
    print_info "  Имя БД: $DB_NAME"
    if [ -n "$DB_USER" ]; then
        print_info "  Пользователь: $DB_USER"
    fi
fi

if [ "$GALERA_ENABLED" = true ]; then
    echo ""
    print_info "Galera Cluster:"
    print_info "  Кластер: ${GALERA_CLUSTER_NAME}"
    print_info "  Узел: ${GALERA_NODE_NAME}"
    print_info "  Проверка статуса: mysql -e \"SHOW STATUS LIKE 'wsrep_%';\""
fi

if [ "$ALLOW_REMOTE" = true ]; then
    echo ""
    IP_ADDR=$(hostname -I | awk '{print $1}')
    print_info "Удалённое подключение:"
    print_info "  Host: $IP_ADDR"
    print_info "  Port: 3306"
fi

if [ "$INSTALL_PROMETHEUS" = true ]; then
    echo ""
    print_info "Prometheus exporter:"
    print_info "  Endpoint: http://$(hostname -I | awk '{print $1}'):9104/metrics"
fi

echo ""
print_info "Учётные данные сохранены в: ${CREDENTIALS_DIR}/"
print_warn "ВАЖНО: Сохраните учётные данные в безопасном месте!"
echo ""

