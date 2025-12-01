#!/bin/bash

#############################################
# MongoDB Installation Script for LXC
# Поддерживает MongoDB Community Edition
# с опциями Replica Set и Prometheus Exporter
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
MONGODB_VERSION="8.0"
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
ADMIN_PASSWORD=""
BIND_IP="127.0.0.1"
ALLOW_REMOTE=false
ENABLE_AUTH=false
REPLICA_SET=""
INSTALL_PROMETHEUS_EXPORTER=false
EXPORTER_PORT="9216"
MONGODB_PORT="27017"

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

Скрипт установки MongoDB Community Edition для LXC контейнеров.

Опции:
  --version VERSION       Версия MongoDB (по умолчанию: 8.0)
                          Доступные: 7.0, 8.0
  --port PORT             Порт MongoDB (по умолчанию: 27017)
  --db-name NAME          Создать базу данных с указанным именем
  --db-user USER          Создать пользователя БД (требует --db-name и --db-password)
  --db-password PASS      Пароль для пользователя БД
  --admin-password PASS   Пароль администратора (пользователь root)
  --auth                  Включить авторизацию (требует --admin-password)
  --allow-remote          Разрешить удалённые подключения (bind_ip = 0.0.0.0)
  --replica-set NAME      Подготовить для Replica Set с указанным именем
  --prometheus            Установить MongoDB Exporter для мониторинга
  --exporter-port PORT    Порт для MongoDB Exporter (по умолчанию: 9216)
  --help                  Показать эту справку

Примеры:
  # Базовая установка MongoDB 8.0
  $0

  # Установка с авторизацией
  $0 --auth --admin-password SecureAdminPass123

  # Установка с созданием базы и пользователя
  $0 --auth --admin-password AdminPass123 \\
     --db-name myapp --db-user myapp --db-password AppPass123

  # Установка с удалённым доступом и мониторингом
  $0 --auth --admin-password AdminPass123 --allow-remote --prometheus

  # Подготовка для Replica Set
  $0 --auth --admin-password AdminPass123 --replica-set rs0 --allow-remote

  # Установка MongoDB 7.0
  $0 --version 7.0

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            MONGODB_VERSION="$2"
            shift 2
            ;;
        --port)
            MONGODB_PORT="$2"
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
        --admin-password)
            ADMIN_PASSWORD="$2"
            ENABLE_AUTH=true
            shift 2
            ;;
        --auth)
            ENABLE_AUTH=true
            shift
            ;;
        --allow-remote)
            ALLOW_REMOTE=true
            BIND_IP="0.0.0.0"
            shift
            ;;
        --replica-set)
            REPLICA_SET="$2"
            shift 2
            ;;
        --prometheus)
            INSTALL_PROMETHEUS_EXPORTER=true
            shift
            ;;
        --exporter-port)
            EXPORTER_PORT="$2"
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

# Проверка версии
if [[ ! "$MONGODB_VERSION" =~ ^(7\.0|8\.0)$ ]]; then
    print_error "Неподдерживаемая версия MongoDB: $MONGODB_VERSION"
    print_error "Доступные версии: 7.0, 8.0"
    exit 1
fi

# Проверка параметров авторизации
if [ "$ENABLE_AUTH" = true ] && [ -z "$ADMIN_PASSWORD" ]; then
    print_error "При включении авторизации (--auth) необходимо указать --admin-password"
    exit 1
fi

# Проверка параметров пользователя БД
if [ -n "$DB_USER" ]; then
    if [ -z "$DB_PASSWORD" ]; then
        print_error "Если указан --db-user, необходимо также указать --db-password"
        exit 1
    fi
    if [ -z "$DB_NAME" ]; then
        print_error "Если указан --db-user, необходимо также указать --db-name"
        exit 1
    fi
    if [ "$ENABLE_AUTH" != true ]; then
        print_warn "Создание пользователя без включения авторизации. Добавьте --auth для безопасности"
    fi
fi

# Проверка Replica Set
if [ -n "$REPLICA_SET" ] && [ "$ENABLE_AUTH" != true ]; then
    print_warn "Replica Set без авторизации не рекомендуется для production"
fi

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка MongoDB Community Edition"
print_info "Версия: ${MONGODB_VERSION}"
print_info "Порт: ${MONGODB_PORT}"

if [ "$ENABLE_AUTH" = true ]; then
    print_info "Авторизация: включена"
else
    print_info "Авторизация: отключена"
fi

if [ "$ALLOW_REMOTE" = true ]; then
    print_info "Удалённый доступ: включен (bind_ip = 0.0.0.0)"
else
    print_info "Удалённый доступ: только localhost"
fi

if [ -n "$REPLICA_SET" ]; then
    print_info "Replica Set: $REPLICA_SET"
fi

if [ -n "$DB_NAME" ]; then
    print_info "База данных: $DB_NAME"
fi

if [ -n "$DB_USER" ]; then
    print_info "Пользователь: $DB_USER"
fi

if [ "$INSTALL_PROMETHEUS_EXPORTER" = true ]; then
    print_info "Prometheus Exporter: да (порт $EXPORTER_PORT)"
fi
echo "=============================================="
echo ""

#############################################
# Установка MongoDB
#############################################

print_step "Установка зависимостей..."
apt-get update
apt-get install -y wget gnupg curl apt-transport-https ca-certificates

print_step "Добавление репозитория MongoDB ${MONGODB_VERSION}..."

# Добавление GPG ключа MongoDB
curl -fsSL https://www.mongodb.org/static/pgp/server-${MONGODB_VERSION}.asc | \
    gpg --dearmor -o /usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg

# Определение дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="$ID"
    DISTRO_CODENAME="$VERSION_CODENAME"
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

# Добавление репозитория в зависимости от дистрибутива
case "$DISTRO_ID" in
    ubuntu)
        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg] https://repo.mongodb.org/apt/ubuntu ${DISTRO_CODENAME}/mongodb-org/${MONGODB_VERSION} multiverse" > /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list
        ;;
    debian)
        echo "deb [signed-by=/usr/share/keyrings/mongodb-server-${MONGODB_VERSION}.gpg] https://repo.mongodb.org/apt/debian ${DISTRO_CODENAME}/mongodb-org/${MONGODB_VERSION} main" > /etc/apt/sources.list.d/mongodb-org-${MONGODB_VERSION}.list
        ;;
    *)
        print_error "Неподдерживаемый дистрибутив: $DISTRO_ID"
        print_error "Поддерживаются: Ubuntu, Debian"
        exit 1
        ;;
esac

print_step "Установка MongoDB ${MONGODB_VERSION}..."
apt-get update
apt-get install -y mongodb-org

#############################################
# Оптимизация системы для MongoDB
#############################################

print_step "Оптимизация системы для MongoDB..."

# Отключение Transparent Huge Pages (THP)
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
    echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
fi

# Создание systemd unit для отключения THP при загрузке
cat > /etc/systemd/system/disable-thp.service << 'EOF'
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null 2>&1 || true'
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/defrag > /dev/null 2>&1 || true'

[Install]
WantedBy=basic.target
EOF

systemctl daemon-reload
systemctl enable disable-thp.service 2>/dev/null || true

# Настройка ulimits для MongoDB
cat > /etc/security/limits.d/mongodb.conf << 'EOF'
mongod soft nofile 64000
mongod hard nofile 64000
mongod soft nproc 64000
mongod hard nproc 64000
EOF

#############################################
# Настройка MongoDB
#############################################

print_step "Настройка MongoDB..."

# Резервное копирование оригинального конфига
cp /etc/mongod.conf /etc/mongod.conf.bak

# Создание нового конфигурационного файла
cat > /etc/mongod.conf << EOF
# MongoDB configuration file
# Документация: https://docs.mongodb.com/manual/reference/configuration-options/

# Хранение данных
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# Логирование
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Сетевые настройки
net:
  port: ${MONGODB_PORT}
  bindIp: ${BIND_IP}

# Управление процессом
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
EOF

# Добавление настроек авторизации
if [ "$ENABLE_AUTH" = true ]; then
    cat >> /etc/mongod.conf << EOF

# Безопасность
security:
  authorization: enabled
EOF
fi

# Добавление настроек Replica Set
if [ -n "$REPLICA_SET" ]; then
    cat >> /etc/mongod.conf << EOF

# Replica Set
replication:
  replSetName: ${REPLICA_SET}
EOF
fi

#############################################
# Запуск MongoDB
#############################################

print_step "Запуск MongoDB..."
systemctl daemon-reload
systemctl enable mongod
systemctl start mongod

# Ожидание запуска
print_step "Ожидание запуска MongoDB..."
sleep 5

# Проверка статуса
if systemctl is-active --quiet mongod; then
    print_info "✓ MongoDB успешно запущен"
else
    print_error "Не удалось запустить MongoDB!"
    print_error "Проверьте логи: journalctl -u mongod -n 50"
    print_error "Также: cat /var/log/mongodb/mongod.log"
    exit 1
fi

#############################################
# Инициализация Replica Set
#############################################

if [ -n "$REPLICA_SET" ]; then
    print_step "Инициализация Replica Set..."
    
    # Получаем IP адрес
    IP_ADDR=$(hostname -I | awk '{print $1}')
    
    # Инициализация RS (без авторизации пока)
    mongosh --quiet --eval "
        try {
            rs.initiate({
                _id: '${REPLICA_SET}',
                members: [{ _id: 0, host: '${IP_ADDR}:${MONGODB_PORT}' }]
            });
            print('Replica Set инициализирован');
        } catch(e) {
            if (e.codeName === 'AlreadyInitialized') {
                print('Replica Set уже инициализирован');
            } else {
                throw e;
            }
        }
    " 2>/dev/null || print_warn "Replica Set будет инициализирован позже"
    
    # Ожидание выбора primary
    sleep 5
fi

#############################################
# Создание администратора и пользователей
#############################################

if [ "$ENABLE_AUTH" = true ]; then
    print_step "Создание администратора..."
    
    # Временно останавливаем MongoDB и запускаем без авторизации для создания пользователя
    systemctl stop mongod
    
    # Временный конфиг без авторизации
    cp /etc/mongod.conf /etc/mongod.conf.tmp
    sed -i '/security:/,/authorization:/d' /etc/mongod.conf
    
    systemctl start mongod
    sleep 5
    
    # Создание администратора
    mongosh --quiet admin --eval "
        db.createUser({
            user: 'root',
            pwd: '${ADMIN_PASSWORD}',
            roles: [
                { role: 'root', db: 'admin' },
                { role: 'userAdminAnyDatabase', db: 'admin' },
                { role: 'dbAdminAnyDatabase', db: 'admin' },
                { role: 'readWriteAnyDatabase', db: 'admin' }
            ]
        });
        print('Администратор создан');
    " 2>/dev/null || print_warn "Администратор возможно уже существует"
    
    # Создание пользователя для базы данных
    if [ -n "$DB_USER" ] && [ -n "$DB_NAME" ]; then
        print_step "Создание пользователя $DB_USER для базы $DB_NAME..."
        
        mongosh --quiet admin --eval "
            db = db.getSiblingDB('${DB_NAME}');
            db.createUser({
                user: '${DB_USER}',
                pwd: '${DB_PASSWORD}',
                roles: [
                    { role: 'readWrite', db: '${DB_NAME}' },
                    { role: 'dbAdmin', db: '${DB_NAME}' }
                ]
            });
            print('Пользователь ${DB_USER} создан');
        " 2>/dev/null || print_warn "Пользователь возможно уже существует"
    fi
    
    # Создание пользователя для Prometheus Exporter
    if [ "$INSTALL_PROMETHEUS_EXPORTER" = true ]; then
        print_step "Создание пользователя для мониторинга..."
        
        EXPORTER_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24)
        
        mongosh --quiet admin --eval "
            db.createUser({
                user: 'mongodb_exporter',
                pwd: '${EXPORTER_PASSWORD}',
                roles: [
                    { role: 'clusterMonitor', db: 'admin' },
                    { role: 'read', db: 'local' }
                ]
            });
            print('Пользователь mongodb_exporter создан');
        " 2>/dev/null || print_warn "Пользователь mongodb_exporter возможно уже существует"
    fi
    
    # Восстановление конфига с авторизацией и перезапуск
    cp /etc/mongod.conf.tmp /etc/mongod.conf
    rm /etc/mongod.conf.tmp
    
    systemctl restart mongod
    sleep 5
    
    if systemctl is-active --quiet mongod; then
        print_info "✓ MongoDB перезапущен с авторизацией"
    else
        print_error "Не удалось перезапустить MongoDB с авторизацией!"
        exit 1
    fi
    
elif [ -n "$DB_NAME" ]; then
    # Создание базы данных без авторизации
    print_step "Создание базы данных $DB_NAME..."
    
    mongosh --quiet --eval "
        db = db.getSiblingDB('${DB_NAME}');
        db.createCollection('_init');
        db._init.drop();
        print('База данных ${DB_NAME} создана');
    " 2>/dev/null || print_warn "Не удалось создать базу данных"
fi

#############################################
# Установка MongoDB Exporter
#############################################

if [ "$INSTALL_PROMETHEUS_EXPORTER" = true ]; then
    print_step "Установка MongoDB Exporter..."
    
    # Определение архитектуры
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            EXPORTER_ARCH="amd64"
            ;;
        aarch64)
            EXPORTER_ARCH="arm64"
            ;;
        *)
            print_error "Неподдерживаемая архитектура: $ARCH"
            exit 1
            ;;
    esac
    
    # Скачивание последней версии MongoDB Exporter
    EXPORTER_VERSION=$(curl -s https://api.github.com/repos/percona/mongodb_exporter/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [ -z "$EXPORTER_VERSION" ]; then
        EXPORTER_VERSION="0.43.0"
        print_warn "Не удалось определить последнюю версию, используется $EXPORTER_VERSION"
    fi
    
    print_info "Версия MongoDB Exporter: $EXPORTER_VERSION"
    
    cd /tmp
    wget -q "https://github.com/percona/mongodb_exporter/releases/download/v${EXPORTER_VERSION}/mongodb_exporter-${EXPORTER_VERSION}.linux-${EXPORTER_ARCH}.tar.gz" -O mongodb_exporter.tar.gz
    
    tar xzf mongodb_exporter.tar.gz
    cp mongodb_exporter-${EXPORTER_VERSION}.linux-${EXPORTER_ARCH}/mongodb_exporter /usr/local/bin/
    chmod +x /usr/local/bin/mongodb_exporter
    rm -rf mongodb_exporter.tar.gz mongodb_exporter-${EXPORTER_VERSION}.linux-${EXPORTER_ARCH}
    
    # Создание пользователя для экспортера
    useradd --no-create-home --shell /bin/false mongodb_exporter 2>/dev/null || true
    
    # Формирование URI подключения
    if [ "$ENABLE_AUTH" = true ]; then
        MONGODB_URI="mongodb://mongodb_exporter:${EXPORTER_PASSWORD}@127.0.0.1:${MONGODB_PORT}/admin"
    else
        MONGODB_URI="mongodb://127.0.0.1:${MONGODB_PORT}"
    fi
    
    # Создание systemd unit
    cat > /etc/systemd/system/mongodb_exporter.service << EOF
[Unit]
Description=MongoDB Exporter for Prometheus
Documentation=https://github.com/percona/mongodb_exporter
After=network.target mongod.service
Wants=mongod.service

[Service]
Type=simple
User=mongodb_exporter
Group=mongodb_exporter
Environment="MONGODB_URI=${MONGODB_URI}"
ExecStart=/usr/local/bin/mongodb_exporter \\
    --web.listen-address=:${EXPORTER_PORT} \\
    --collect-all \\
    --discovering-mode
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable mongodb_exporter
    systemctl start mongodb_exporter
    
    sleep 2
    
    if systemctl is-active --quiet mongodb_exporter; then
        print_info "✓ MongoDB Exporter запущен на порту $EXPORTER_PORT"
    else
        print_warn "MongoDB Exporter не запустился, проверьте: journalctl -u mongodb_exporter -n 20"
    fi
fi

#############################################
# Сохранение учётных данных
#############################################

CREDENTIALS_DIR="/root/mongodb-credentials"
mkdir -p "$CREDENTIALS_DIR"
chmod 700 "$CREDENTIALS_DIR"

cat > "${CREDENTIALS_DIR}/credentials.txt" << EOF
MongoDB Credentials
===================
Дата установки: $(date)
Версия: MongoDB ${MONGODB_VERSION}
Порт: ${MONGODB_PORT}

EOF

if [ "$ENABLE_AUTH" = true ]; then
    cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
Администратор:
  Пользователь: root
  Пароль: ${ADMIN_PASSWORD}
  База: admin

EOF
fi

if [ -n "$DB_USER" ]; then
    cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
Пользователь приложения:
  Пользователь: ${DB_USER}
  Пароль: ${DB_PASSWORD}
  База: ${DB_NAME}

EOF
fi

if [ "$INSTALL_PROMETHEUS_EXPORTER" = true ] && [ "$ENABLE_AUTH" = true ]; then
    cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
MongoDB Exporter:
  Пользователь: mongodb_exporter
  Пароль: ${EXPORTER_PASSWORD}
  Порт: ${EXPORTER_PORT}

EOF
fi

if [ -n "$REPLICA_SET" ]; then
    cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
Replica Set: ${REPLICA_SET}

EOF
fi

IP_ADDR=$(hostname -I | awk '{print $1}')

cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
Строки подключения:
EOF

if [ "$ENABLE_AUTH" = true ]; then
    if [ -n "$DB_USER" ]; then
        cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
  Приложение: mongodb://${DB_USER}:${DB_PASSWORD}@${IP_ADDR}:${MONGODB_PORT}/${DB_NAME}
EOF
    fi
    cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
  Администратор: mongodb://root:${ADMIN_PASSWORD}@${IP_ADDR}:${MONGODB_PORT}/admin
EOF
else
    cat >> "${CREDENTIALS_DIR}/credentials.txt" << EOF
  mongodb://${IP_ADDR}:${MONGODB_PORT}
EOF
fi

chmod 600 "${CREDENTIALS_DIR}/credentials.txt"

#############################################
# Итоговая информация
#############################################

echo ""
echo "=============================================="
print_info "✓ Установка MongoDB завершена успешно!"
echo "=============================================="
echo ""

print_info "MongoDB ${MONGODB_VERSION} установлен"
print_info "Порт: ${MONGODB_PORT}"
print_info "Данные: /var/lib/mongodb"
print_info "Логи: /var/log/mongodb/mongod.log"
print_info "Конфиг: /etc/mongod.conf"
echo ""

print_info "Управление сервисом:"
print_info "  systemctl status mongod"
print_info "  systemctl restart mongod"
print_info "  systemctl stop mongod"
echo ""

print_info "Подключение:"
if [ "$ENABLE_AUTH" = true ]; then
    print_info "  mongosh -u root -p '${ADMIN_PASSWORD}' --authenticationDatabase admin"
    if [ -n "$DB_USER" ]; then
        print_info "  mongosh -u ${DB_USER} -p '${DB_PASSWORD}' ${DB_NAME}"
    fi
else
    print_info "  mongosh"
fi
echo ""

if [ -n "$REPLICA_SET" ]; then
    print_info "Replica Set: $REPLICA_SET"
    print_info "  Статус: mongosh --eval 'rs.status()'"
    print_info "  Добавить узел: rs.add('hostname:port')"
    echo ""
fi

if [ "$INSTALL_PROMETHEUS_EXPORTER" = true ]; then
    print_info "MongoDB Exporter:"
    print_info "  Метрики: http://${IP_ADDR}:${EXPORTER_PORT}/metrics"
    print_info "  Статус: systemctl status mongodb_exporter"
    echo ""
fi

print_info "Учётные данные сохранены в: ${CREDENTIALS_DIR}/credentials.txt"
echo ""

if [ "$ALLOW_REMOTE" = true ]; then
    print_warn "ВНИМАНИЕ: Удалённый доступ включен!"
    print_warn "Убедитесь, что настроен firewall для порта ${MONGODB_PORT}"
fi

if [ -n "$REPLICA_SET" ]; then
    echo ""
    print_info "Для добавления узлов в Replica Set:"
    print_info "1. Установите MongoDB на других узлах с теми же параметрами"
    print_info "2. На primary выполните: rs.add('node2:${MONGODB_PORT}')"
    print_info "3. Проверьте статус: rs.status()"
fi

echo ""

