#!/bin/bash

#############################################
# Shinobi CE Installation Script for LXC
# Network Video Recorder (NVR) System
# https://shinobi.video
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
SHINOBI_VERSION="master"
SHINOBI_DIR="/opt/shinobi"
SHINOBI_USER="shinobi"
SHINOBI_GROUP="shinobi"

NODE_VERSION="18"
NVM_DIR="/opt/nvm"

# База данных
DB_TYPE="sqlite"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="shinobi"
DB_USER="shinobi"
DB_PASSWORD=""
INSTALL_POSTGRES=false

# GPU
GPU_TYPE=""
GPU_DEVICE="/dev/dri"

# Хранилище
STORAGE_PATH="/var/lib/shinobi/videos"
RETENTION_DAYS="30"

# Сеть
SHINOBI_PORT="8080"
CRON_PORT="8082"

# Мониторинг
ENABLE_PROMETHEUS=false
PROMETHEUS_PORT="9290"

# Админ
ADMIN_EMAIL="admin@shinobi.video"
ADMIN_PASSWORD=""

# Плагины
INSTALL_PLUGIN_OPENCV=false
INSTALL_PLUGIN_TENSORFLOW=false
INSTALL_PLUGIN_YOLO=false
INSTALL_PLUGIN_FACE=false

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

# Генерация случайного пароля
generate_password() {
    openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 24
}

# Функция помощи
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Скрипт установки Shinobi CE (Community Edition) для LXC контейнеров.
Shinobi - система видеонаблюдения с открытым исходным кодом.

Рекомендуемые ресурсы LXC: 4 CPU, 8 GB RAM, 40 GB диска + отдельное хранилище для записей.

Опции базы данных:
  --with-postgres           Установить встроенный PostgreSQL
  --db-host HOST            Хост внешнего PostgreSQL
  --db-port PORT            Порт PostgreSQL (по умолчанию: 5432)
  --db-name NAME            Имя базы данных (по умолчанию: shinobi)
  --db-user USER            Пользователь БД (по умолчанию: shinobi)
  --db-password PASS        Пароль БД (генерируется если не указан)

Опции GPU:
  --gpu TYPE                Тип GPU: intel, nvidia, amd
  --gpu-device PATH         Путь к устройству GPU (по умолчанию: /dev/dri)

Опции хранилища:
  --storage-path PATH       Путь для записей (по умолчанию: /var/lib/shinobi/videos)
  --retention-days N        Дней хранения записей (по умолчанию: 30)

Опции сети:
  --port PORT               Порт веб-интерфейса (по умолчанию: 8080)

Опции мониторинга:
  --prometheus              Включить экспорт метрик для Prometheus
  --prometheus-port PORT    Порт метрик (по умолчанию: 9290)

Опции администратора:
  --admin-email EMAIL       Email администратора (по умолчанию: admin@shinobi.video)
  --admin-password PASS     Пароль администратора (генерируется если не указан)

Плагины детекции:
  --plugin-opencv           Детекция движения через OpenCV (рекомендуется)
  --plugin-tensorflow       Детекция объектов через TensorFlow
  --plugin-yolo             Детекция объектов через YOLO (Darknet)
  --plugin-face             Распознавание лиц (face-recognition)
  --plugins-all             Установить все плагины

Прочие опции:
  --version VERSION         Версия/ветка Shinobi (по умолчанию: master)
  --check                   Только проверить совместимость
  --help                    Показать эту справку

Примеры:
  # Минимальная установка (SQLite)
  $0

  # С встроенным PostgreSQL
  $0 --with-postgres

  # С внешним PostgreSQL
  $0 --db-host 192.168.1.100 --db-password SecurePass123

  # Полная установка с GPU и мониторингом
  $0 --with-postgres --gpu intel --prometheus \\
     --storage-path /mnt/recordings --admin-email admin@example.com

  # С плагинами детекции объектов
  $0 --with-postgres --gpu intel --plugin-opencv --plugin-tensorflow

  # Полная установка со всеми плагинами
  $0 --with-postgres --gpu intel --plugins-all --prometheus

EOF
    exit 0
}

# Парсинг аргументов
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-postgres)
            INSTALL_POSTGRES=true
            DB_TYPE="postgres"
            shift
            ;;
        --db-host)
            DB_HOST="$2"
            DB_TYPE="postgres"
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
        --gpu)
            GPU_TYPE="$2"
            shift 2
            ;;
        --gpu-device)
            GPU_DEVICE="$2"
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
        --port)
            SHINOBI_PORT="$2"
            shift 2
            ;;
        --prometheus)
            ENABLE_PROMETHEUS=true
            shift
            ;;
        --prometheus-port)
            PROMETHEUS_PORT="$2"
            shift 2
            ;;
        --admin-email)
            ADMIN_EMAIL="$2"
            shift 2
            ;;
        --admin-password)
            ADMIN_PASSWORD="$2"
            shift 2
            ;;
        --plugin-opencv)
            INSTALL_PLUGIN_OPENCV=true
            shift
            ;;
        --plugin-tensorflow)
            INSTALL_PLUGIN_TENSORFLOW=true
            shift
            ;;
        --plugin-yolo)
            INSTALL_PLUGIN_YOLO=true
            shift
            ;;
        --plugin-face)
            INSTALL_PLUGIN_FACE=true
            shift
            ;;
        --plugins-all)
            INSTALL_PLUGIN_OPENCV=true
            INSTALL_PLUGIN_TENSORFLOW=true
            INSTALL_PLUGIN_YOLO=true
            INSTALL_PLUGIN_FACE=true
            shift
            ;;
        --version)
            SHINOBI_VERSION="$2"
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

# Генерация паролей если не указаны
if [ -z "$DB_PASSWORD" ] && [ "$DB_TYPE" = "postgres" ]; then
    DB_PASSWORD=$(generate_password)
    print_info "Сгенерирован пароль БД: $DB_PASSWORD"
fi

if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD=$(generate_password)
    print_info "Сгенерирован пароль администратора: $ADMIN_PASSWORD"
fi

# Определение дистрибутива
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
    else
        print_error "Не удалось определить дистрибутив"
        exit 1
    fi
}

# Проверка совместимости
check_compatibility() {
    print_step "Проверка совместимости..."
    
    detect_distro
    
    case $DISTRO in
        debian|ubuntu)
            print_info "✓ Дистрибутив: $DISTRO $DISTRO_VERSION"
            ;;
        *)
            print_error "Неподдерживаемый дистрибутив: $DISTRO"
            print_error "Поддерживаются: Debian, Ubuntu"
            exit 1
            ;;
    esac
    
    # Проверка ресурсов
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    CPU_CORES=$(nproc)
    
    print_info "CPU: $CPU_CORES ядер"
    print_info "RAM: $TOTAL_MEM MB"
    
    if [ "$TOTAL_MEM" -lt 2048 ]; then
        print_warn "Рекомендуется минимум 4 GB RAM"
    fi
    
    if [ "$CPU_CORES" -lt 2 ]; then
        print_warn "Рекомендуется минимум 2 CPU"
    fi
    
    # Проверка GPU
    if [ -n "$GPU_TYPE" ]; then
        case $GPU_TYPE in
            intel)
                if [ -d "/dev/dri" ]; then
                    print_info "✓ Intel GPU обнаружен: /dev/dri"
                    ls -la /dev/dri/ 2>/dev/null || true
                else
                    print_warn "Intel GPU не обнаружен. Убедитесь, что /dev/dri проброшен в LXC"
                fi
                ;;
            nvidia)
                if command -v nvidia-smi &> /dev/null; then
                    print_info "✓ NVIDIA GPU обнаружен"
                    nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || true
                else
                    print_warn "NVIDIA GPU не обнаружен. Установите драйверы NVIDIA"
                fi
                ;;
            amd)
                if [ -d "/dev/dri" ]; then
                    print_info "✓ AMD GPU обнаружен: /dev/dri"
                else
                    print_warn "AMD GPU не обнаружен"
                fi
                ;;
            *)
                print_error "Неподдерживаемый тип GPU: $GPU_TYPE"
                print_error "Поддерживаются: intel, nvidia, amd"
                exit 1
                ;;
        esac
    fi
    
    # Проверка внешнего PostgreSQL
    if [ "$DB_TYPE" = "postgres" ] && [ "$DB_HOST" != "localhost" ] && [ "$INSTALL_POSTGRES" = false ]; then
        print_step "Проверка подключения к PostgreSQL..."
        if command -v psql &> /dev/null; then
            if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
                print_info "✓ Подключение к PostgreSQL успешно"
            else
                print_warn "Не удалось подключиться к PostgreSQL. Проверьте параметры."
            fi
        else
            print_info "psql не установлен, проверка подключения пропущена"
        fi
    fi
    
    print_info "✓ Проверка совместимости завершена"
}

# Вывод информации об установке
show_install_info() {
    echo ""
    echo "=============================================="
    print_info "Установка Shinobi CE"
    echo "=============================================="
    print_info "Версия: ${SHINOBI_VERSION}"
    print_info "База данных: ${DB_TYPE}"
    [ "$DB_TYPE" = "postgres" ] && print_info "  Хост: ${DB_HOST}:${DB_PORT}"
    [ "$INSTALL_POSTGRES" = true ] && print_info "  (встроенный PostgreSQL)"
    [ -n "$GPU_TYPE" ] && print_info "GPU: ${GPU_TYPE} (${GPU_DEVICE})"
    print_info "Порт: ${SHINOBI_PORT}"
    print_info "Хранилище: ${STORAGE_PATH}"
    print_info "Retention: ${RETENTION_DAYS} дней"
    [ "$ENABLE_PROMETHEUS" = true ] && print_info "Prometheus: порт ${PROMETHEUS_PORT}"
    
    # Плагины
    PLUGINS_LIST=""
    [ "$INSTALL_PLUGIN_OPENCV" = true ] && PLUGINS_LIST="${PLUGINS_LIST}OpenCV, "
    [ "$INSTALL_PLUGIN_TENSORFLOW" = true ] && PLUGINS_LIST="${PLUGINS_LIST}TensorFlow, "
    [ "$INSTALL_PLUGIN_YOLO" = true ] && PLUGINS_LIST="${PLUGINS_LIST}YOLO, "
    [ "$INSTALL_PLUGIN_FACE" = true ] && PLUGINS_LIST="${PLUGINS_LIST}Face, "
    if [ -n "$PLUGINS_LIST" ]; then
        print_info "Плагины: ${PLUGINS_LIST%, }"
    fi
    echo "=============================================="
    echo ""
}

# Установка зависимостей
install_dependencies() {
    print_step "Установка системных зависимостей..."
    
    apt-get update
    apt-get install -y \
        curl \
        wget \
        git \
        build-essential \
        python3 \
        ffmpeg \
        x264 \
        x265 \
        openssl \
        ca-certificates \
        gnupg \
        lsb-release \
        jq
    
    # Установка дополнительных кодеков и библиотек для FFmpeg
    apt-get install -y \
        libavcodec-extra \
        libavformat-dev \
        libavutil-dev \
        libswscale-dev \
        libmp3lame0 \
        libopus0 \
        libvpx7 || apt-get install -y libvpx6 || true
    
    # Для GPU ускорения
    if [ "$GPU_TYPE" = "intel" ]; then
        print_info "Установка Intel VAAPI..."
        apt-get install -y \
            vainfo \
            intel-media-va-driver \
            i965-va-driver \
            libva-drm2 \
            libva2 || print_warn "Некоторые пакеты Intel VAAPI недоступны"
    fi
    
    if [ "$GPU_TYPE" = "nvidia" ]; then
        print_info "Установка NVIDIA инструментов..."
        # NVENC обычно включен в драйвер, нужен только nvidia-smi для проверки
        apt-get install -y nvidia-utils-535 || apt-get install -y nvidia-utils || print_warn "nvidia-utils недоступен"
    fi
    
    print_info "✓ Системные зависимости установлены"
}

# Установка nvm и Node.js
install_nodejs() {
    print_step "Установка nvm и Node.js ${NODE_VERSION}..."
    
    # Создание директории nvm
    mkdir -p "$NVM_DIR"
    
    # Установка nvm
    export NVM_DIR="$NVM_DIR"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Загрузка nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Установка Node.js
    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    
    # Создание симлинков для systemd
    NODE_PATH=$(which node)
    NPM_PATH=$(which npm)
    
    ln -sf "$NODE_PATH" /usr/local/bin/node
    ln -sf "$NPM_PATH" /usr/local/bin/npm
    
    # Проверка
    print_info "Node.js: $(node --version)"
    print_info "npm: $(npm --version)"
    
    print_info "✓ Node.js установлен"
}

# Установка PostgreSQL
install_postgres() {
    print_step "Установка PostgreSQL..."
    
    apt-get install -y postgresql postgresql-contrib
    
    # Запуск PostgreSQL
    systemctl enable postgresql
    systemctl start postgresql
    
    # Создание пользователя и базы данных
    print_info "Создание базы данных ${DB_NAME}..."
    
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" 2>/dev/null || \
        sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
    
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" 2>/dev/null || \
        print_info "База данных уже существует"
    
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
    
    print_info "✓ PostgreSQL установлен и настроен"
}

# Создание пользователя Shinobi
create_shinobi_user() {
    print_step "Создание системного пользователя ${SHINOBI_USER}..."
    
    if ! id "$SHINOBI_USER" &>/dev/null; then
        useradd --system --home-dir "$SHINOBI_DIR" --shell /bin/bash "$SHINOBI_USER"
    fi
    
    # Добавление в группу video для доступа к GPU
    if [ -n "$GPU_TYPE" ]; then
        usermod -aG video "$SHINOBI_USER" 2>/dev/null || true
        usermod -aG render "$SHINOBI_USER" 2>/dev/null || true
    fi
    
    print_info "✓ Пользователь создан"
}

# Клонирование Shinobi
clone_shinobi() {
    print_step "Клонирование Shinobi CE..."
    
    if [ -d "$SHINOBI_DIR" ]; then
        print_info "Директория существует, обновление..."
        cd "$SHINOBI_DIR"
        git fetch origin
        git checkout "$SHINOBI_VERSION"
        git pull origin "$SHINOBI_VERSION" || true
    else
        git clone -b "$SHINOBI_VERSION" https://gitlab.com/Shinobi-Systems/Shinobi.git "$SHINOBI_DIR"
    fi
    
    cd "$SHINOBI_DIR"
    
    print_info "✓ Shinobi клонирован"
}

# Установка npm зависимостей
install_npm_dependencies() {
    print_step "Установка npm зависимостей..."
    
    cd "$SHINOBI_DIR"
    
    # Загрузка nvm
    export NVM_DIR="$NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    npm install --unsafe-perm
    
    # Установка PM2 для управления процессами
    npm install -g pm2
    ln -sf "$(which pm2)" /usr/local/bin/pm2
    
    print_info "✓ npm зависимости установлены"
}

# Создание конфигурации Shinobi
create_shinobi_config() {
    print_step "Создание конфигурации Shinobi..."
    
    cd "$SHINOBI_DIR"
    
    # Определение настроек БД
    if [ "$DB_TYPE" = "sqlite" ]; then
        DB_CONFIG='"databaseType": "sqlite3",'
        DB_DETAILS='"db": {
        "filename": "./shinobi.sqlite"
    }'
    else
        DB_CONFIG='"databaseType": "pg",'
        DB_DETAILS='"db": {
        "host": "'"${DB_HOST}"'",
        "port": '"${DB_PORT}"',
        "user": "'"${DB_USER}"'",
        "password": "'"${DB_PASSWORD}"'",
        "database": "'"${DB_NAME}"'"
    }'
    fi
    
    # Определение настроек GPU для FFmpeg
    FFMPEG_OPTIONS=""
    if [ "$GPU_TYPE" = "intel" ]; then
        FFMPEG_OPTIONS='"hwaccel": "vaapi",
        "hwaccelDevice": "/dev/dri/renderD128",'
    elif [ "$GPU_TYPE" = "nvidia" ]; then
        FFMPEG_OPTIONS='"hwaccel": "cuvid",
        "hwaccelDevice": "0",'
    fi
    
    # Создание conf.json
    cat > "$SHINOBI_DIR/conf.json" << EOF
{
    "cpuUsageMarker": "CPU",
    "cron": {
        "enabled": true,
        "port": ${CRON_PORT}
    },
    ${DB_CONFIG}
    ${DB_DETAILS},
    "ip": "0.0.0.0",
    "port": ${SHINOBI_PORT},
    "passwordType": "sha256",
    "passwordSalt": "",
    "addStorage": [
        {
            "name": "recordings",
            "path": "${STORAGE_PATH}"
        }
    ],
    "videosDir": "${STORAGE_PATH}",
    "retention": "${RETENTION_DAYS}d",
    ${FFMPEG_OPTIONS}
    "subscriptionId": "",
    "ssl": {
        "enabled": false,
        "key": "",
        "cert": "",
        "port": 443
    },
    "mail": {
        "from": "",
        "host": "",
        "port": 25,
        "secure": false,
        "auth": {
            "user": "",
            "pass": ""
        }
    },
    "customAutoLoad": "",
    "language": "ru",
    "region": "Europe/Moscow"
}
EOF
    
    print_info "✓ Создан conf.json"
    
    # Создание super.json (суперпользователь для управления)
    ADMIN_PASSWORD_HASH=$(echo -n "${ADMIN_PASSWORD}" | sha256sum | awk '{print $1}')
    
    cat > "$SHINOBI_DIR/super.json" << EOF
[
    {
        "mail": "${ADMIN_EMAIL}",
        "pass": "${ADMIN_PASSWORD_HASH}"
    }
]
EOF
    
    print_info "✓ Создан super.json"
    
    # Права на файлы
    chown -R "$SHINOBI_USER:$SHINOBI_GROUP" "$SHINOBI_DIR"
    chmod 600 "$SHINOBI_DIR/conf.json"
    chmod 600 "$SHINOBI_DIR/super.json"
}

# Создание директорий хранилища
create_storage_dirs() {
    print_step "Создание директорий хранилища..."
    
    mkdir -p "$STORAGE_PATH"
    mkdir -p "$SHINOBI_DIR/videos"
    mkdir -p "$SHINOBI_DIR/plugins"
    
    chown -R "$SHINOBI_USER:$SHINOBI_GROUP" "$STORAGE_PATH"
    chown -R "$SHINOBI_USER:$SHINOBI_GROUP" "$SHINOBI_DIR"
    
    print_info "✓ Директории созданы"
}

# Инициализация базы данных
init_database() {
    print_step "Инициализация базы данных..."
    
    cd "$SHINOBI_DIR"
    
    # Загрузка nvm
    export NVM_DIR="$NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    if [ "$DB_TYPE" = "postgres" ]; then
        # Импорт схемы PostgreSQL
        if [ -f "$SHINOBI_DIR/sql/postgresql.sql" ]; then
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$SHINOBI_DIR/sql/postgresql.sql" || true
        fi
    fi
    
    print_info "✓ База данных инициализирована"
}

# Создание systemd сервиса
create_systemd_service() {
    print_step "Создание systemd сервисов..."
    
    # Определение пути к node
    NODE_BIN="/usr/local/bin/node"
    
    # Основной сервис Shinobi
    cat > /etc/systemd/system/shinobi.service << EOF
[Unit]
Description=Shinobi CCTV
Documentation=https://shinobi.video
After=network.target postgresql.service
Wants=shinobi-cron.service

[Service]
Type=simple
User=${SHINOBI_USER}
Group=${SHINOBI_GROUP}
WorkingDirectory=${SHINOBI_DIR}
Environment=NODE_ENV=production
Environment=NVM_DIR=${NVM_DIR}
ExecStart=${NODE_BIN} camera.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=shinobi

# Безопасность
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    # Cron сервис для очистки записей
    cat > /etc/systemd/system/shinobi-cron.service << EOF
[Unit]
Description=Shinobi CCTV Cron
Documentation=https://shinobi.video
After=network.target shinobi.service

[Service]
Type=simple
User=${SHINOBI_USER}
Group=${SHINOBI_GROUP}
WorkingDirectory=${SHINOBI_DIR}
Environment=NODE_ENV=production
Environment=NVM_DIR=${NVM_DIR}
ExecStart=${NODE_BIN} cron.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=shinobi-cron

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    print_info "✓ Systemd сервисы созданы"
}

# Настройка Prometheus экспортера
setup_prometheus() {
    if [ "$ENABLE_PROMETHEUS" != true ]; then
        return
    fi
    
    print_step "Настройка Prometheus экспортера..."
    
    # Создание простого экспортера метрик
    cat > "$SHINOBI_DIR/prometheus-exporter.js" << 'EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PROMETHEUS_PORT || 9290;
const CONFIG_PATH = path.join(__dirname, 'conf.json');

// Чтение конфигурации
let config = {};
try {
    config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
} catch (e) {
    console.error('Cannot read config:', e);
}

const server = http.createServer(async (req, res) => {
    if (req.url === '/metrics') {
        try {
            const metrics = await collectMetrics();
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(metrics);
        } catch (e) {
            res.writeHead(500);
            res.end('Error collecting metrics');
        }
    } else if (req.url === '/health') {
        res.writeHead(200);
        res.end('OK');
    } else {
        res.writeHead(404);
        res.end('Not found');
    }
});

async function collectMetrics() {
    const lines = [];
    const now = Date.now();
    
    // Системные метрики
    const memUsage = process.memoryUsage();
    lines.push(`# HELP shinobi_memory_usage_bytes Memory usage of Shinobi exporter`);
    lines.push(`# TYPE shinobi_memory_usage_bytes gauge`);
    lines.push(`shinobi_memory_usage_bytes{type="rss"} ${memUsage.rss}`);
    lines.push(`shinobi_memory_usage_bytes{type="heapUsed"} ${memUsage.heapUsed}`);
    
    // Метрики хранилища
    const videosDir = config.videosDir || '/var/lib/shinobi/videos';
    try {
        const { execSync } = require('child_process');
        const dfOutput = execSync(`df -B1 "${videosDir}" 2>/dev/null | tail -1`).toString();
        const parts = dfOutput.trim().split(/\s+/);
        if (parts.length >= 4) {
            lines.push(`# HELP shinobi_storage_bytes Storage usage`);
            lines.push(`# TYPE shinobi_storage_bytes gauge`);
            lines.push(`shinobi_storage_bytes{type="total"} ${parts[1]}`);
            lines.push(`shinobi_storage_bytes{type="used"} ${parts[2]}`);
            lines.push(`shinobi_storage_bytes{type="available"} ${parts[3]}`);
        }
    } catch (e) {}
    
    // Метрики записей
    try {
        const { execSync } = require('child_process');
        const fileCount = execSync(`find "${videosDir}" -type f -name "*.mp4" 2>/dev/null | wc -l`).toString().trim();
        lines.push(`# HELP shinobi_recordings_total Total number of recordings`);
        lines.push(`# TYPE shinobi_recordings_total gauge`);
        lines.push(`shinobi_recordings_total ${fileCount}`);
    } catch (e) {}
    
    // Uptime
    lines.push(`# HELP shinobi_exporter_up Exporter is up`);
    lines.push(`# TYPE shinobi_exporter_up gauge`);
    lines.push(`shinobi_exporter_up 1`);
    
    return lines.join('\n') + '\n';
}

server.listen(PORT, '0.0.0.0', () => {
    console.log(`Prometheus exporter listening on port ${PORT}`);
});
EOF
    
    chown "$SHINOBI_USER:$SHINOBI_GROUP" "$SHINOBI_DIR/prometheus-exporter.js"
    
    # Создание systemd сервиса для экспортера
    cat > /etc/systemd/system/shinobi-exporter.service << EOF
[Unit]
Description=Shinobi Prometheus Exporter
After=network.target shinobi.service

[Service]
Type=simple
User=${SHINOBI_USER}
Group=${SHINOBI_GROUP}
WorkingDirectory=${SHINOBI_DIR}
Environment=NODE_ENV=production
Environment=PROMETHEUS_PORT=${PROMETHEUS_PORT}
ExecStart=/usr/local/bin/node prometheus-exporter.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable shinobi-exporter
    
    print_info "✓ Prometheus экспортер настроен на порту ${PROMETHEUS_PORT}"
}

# Установка плагинов
install_plugins() {
    local ANY_PLUGIN=false
    
    if [ "$INSTALL_PLUGIN_OPENCV" = true ] || [ "$INSTALL_PLUGIN_TENSORFLOW" = true ] || \
       [ "$INSTALL_PLUGIN_YOLO" = true ] || [ "$INSTALL_PLUGIN_FACE" = true ]; then
        ANY_PLUGIN=true
    fi
    
    if [ "$ANY_PLUGIN" = false ]; then
        return
    fi
    
    print_step "Установка плагинов..."
    
    # Общие зависимости для плагинов
    apt-get install -y python3 python3-pip python3-venv cmake pkg-config
    
    # Загрузка nvm
    export NVM_DIR="$NVM_DIR"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Директория плагинов
    PLUGINS_DIR="$SHINOBI_DIR/plugins"
    mkdir -p "$PLUGINS_DIR"
    
    # ===== OpenCV Plugin =====
    if [ "$INSTALL_PLUGIN_OPENCV" = true ]; then
        print_info "Установка плагина OpenCV..."
        
        # Установка OpenCV
        apt-get install -y \
            libopencv-dev \
            python3-opencv || true
        
        # Клонирование плагина
        if [ ! -d "$PLUGINS_DIR/opencv" ]; then
            git clone https://gitlab.com/Shinobi-Systems/shinobi-opencv.git "$PLUGINS_DIR/opencv" || \
            git clone https://github.com/ShinobiCCTV/Shinobi-OpenCV.git "$PLUGINS_DIR/opencv" || true
        fi
        
        if [ -d "$PLUGINS_DIR/opencv" ]; then
            cd "$PLUGINS_DIR/opencv"
            npm install 2>/dev/null || true
            
            # Создание конфигурации
            if [ -f "conf.sample.json" ] && [ ! -f "conf.json" ]; then
                cp conf.sample.json conf.json
            fi
            
            # Systemd сервис
            cat > /etc/systemd/system/shinobi-opencv.service << EOF
[Unit]
Description=Shinobi OpenCV Plugin
After=shinobi.service

[Service]
Type=simple
User=${SHINOBI_USER}
Group=${SHINOBI_GROUP}
WorkingDirectory=${PLUGINS_DIR}/opencv
Environment=NODE_ENV=production
ExecStart=/usr/local/bin/node shinobi-opencv.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            print_info "✓ Плагин OpenCV установлен"
        fi
    fi
    
    # ===== TensorFlow Plugin =====
    if [ "$INSTALL_PLUGIN_TENSORFLOW" = true ]; then
        print_info "Установка плагина TensorFlow..."
        
        # Клонирование плагина
        if [ ! -d "$PLUGINS_DIR/tensorflow" ]; then
            git clone https://gitlab.com/Shinobi-Systems/shinobi-tensorflow.git "$PLUGINS_DIR/tensorflow" || \
            git clone https://github.com/ShinobiCCTV/Shinobi-TensorFlow.git "$PLUGINS_DIR/tensorflow" || true
        fi
        
        if [ -d "$PLUGINS_DIR/tensorflow" ]; then
            cd "$PLUGINS_DIR/tensorflow"
            
            # Создание виртуального окружения Python
            python3 -m venv venv
            source venv/bin/activate
            
            # Установка TensorFlow (lite для ARM, полный для x86)
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                pip install tensorflow || pip install tensorflow-cpu
            else
                pip install tflite-runtime || pip install tensorflow-lite
            fi
            
            pip install numpy pillow
            deactivate
            
            npm install 2>/dev/null || true
            
            # Создание конфигурации
            if [ -f "conf.sample.json" ] && [ ! -f "conf.json" ]; then
                cp conf.sample.json conf.json
            fi
            
            # Systemd сервис
            cat > /etc/systemd/system/shinobi-tensorflow.service << EOF
[Unit]
Description=Shinobi TensorFlow Plugin
After=shinobi.service

[Service]
Type=simple
User=${SHINOBI_USER}
Group=${SHINOBI_GROUP}
WorkingDirectory=${PLUGINS_DIR}/tensorflow
Environment=NODE_ENV=production
Environment=PATH=${PLUGINS_DIR}/tensorflow/venv/bin:/usr/local/bin:/usr/bin
ExecStart=/usr/local/bin/node shinobi-tensorflow.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            print_info "✓ Плагин TensorFlow установлен"
        fi
    fi
    
    # ===== YOLO Plugin =====
    if [ "$INSTALL_PLUGIN_YOLO" = true ]; then
        print_info "Установка плагина YOLO (Darknet)..."
        
        # Клонирование плагина
        if [ ! -d "$PLUGINS_DIR/yolo" ]; then
            git clone https://gitlab.com/Shinobi-Systems/shinobi-yolo.git "$PLUGINS_DIR/yolo" || \
            git clone https://github.com/ShinobiCCTV/Shinobi-YOLO.git "$PLUGINS_DIR/yolo" || true
        fi
        
        if [ -d "$PLUGINS_DIR/yolo" ]; then
            cd "$PLUGINS_DIR/yolo"
            
            # Установка darknet
            if [ ! -d "darknet" ]; then
                git clone https://github.com/AlexeyAB/darknet.git
                cd darknet
                
                # Сборка с GPU если доступен
                if [ -n "$GPU_TYPE" ] && [ "$GPU_TYPE" = "nvidia" ]; then
                    sed -i 's/GPU=0/GPU=1/' Makefile
                    sed -i 's/CUDNN=0/CUDNN=1/' Makefile
                fi
                
                make -j$(nproc) || print_warn "Сборка darknet завершилась с ошибками"
                cd ..
            fi
            
            npm install 2>/dev/null || true
            
            # Скачивание модели YOLOv4-tiny
            if [ ! -f "yolov4-tiny.weights" ]; then
                wget -q https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.weights || true
            fi
            
            # Создание конфигурации
            if [ -f "conf.sample.json" ] && [ ! -f "conf.json" ]; then
                cp conf.sample.json conf.json
            fi
            
            # Systemd сервис
            cat > /etc/systemd/system/shinobi-yolo.service << EOF
[Unit]
Description=Shinobi YOLO Plugin
After=shinobi.service

[Service]
Type=simple
User=${SHINOBI_USER}
Group=${SHINOBI_GROUP}
WorkingDirectory=${PLUGINS_DIR}/yolo
Environment=NODE_ENV=production
ExecStart=/usr/local/bin/node shinobi-yolo.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            print_info "✓ Плагин YOLO установлен"
        fi
    fi
    
    # ===== Face Recognition Plugin =====
    if [ "$INSTALL_PLUGIN_FACE" = true ]; then
        print_info "Установка плагина распознавания лиц..."
        
        # Зависимости для dlib
        apt-get install -y \
            libboost-all-dev \
            libopenblas-dev \
            liblapack-dev || true
        
        # Клонирование плагина
        if [ ! -d "$PLUGINS_DIR/face" ]; then
            git clone https://gitlab.com/Shinobi-Systems/shinobi-face.git "$PLUGINS_DIR/face" || \
            git clone https://github.com/ShinobiCCTV/Shinobi-Face.git "$PLUGINS_DIR/face" || true
        fi
        
        if [ -d "$PLUGINS_DIR/face" ]; then
            cd "$PLUGINS_DIR/face"
            
            # Создание виртуального окружения Python
            python3 -m venv venv
            source venv/bin/activate
            
            # Установка face_recognition (это может занять много времени на сборку dlib)
            pip install numpy pillow
            pip install dlib || print_warn "Установка dlib может занять 10-30 минут..."
            pip install face_recognition || print_warn "Не удалось установить face_recognition"
            
            deactivate
            
            npm install 2>/dev/null || true
            
            # Создание конфигурации
            if [ -f "conf.sample.json" ] && [ ! -f "conf.json" ]; then
                cp conf.sample.json conf.json
            fi
            
            # Systemd сервис
            cat > /etc/systemd/system/shinobi-face.service << EOF
[Unit]
Description=Shinobi Face Recognition Plugin
After=shinobi.service

[Service]
Type=simple
User=${SHINOBI_USER}
Group=${SHINOBI_GROUP}
WorkingDirectory=${PLUGINS_DIR}/face
Environment=NODE_ENV=production
Environment=PATH=${PLUGINS_DIR}/face/venv/bin:/usr/local/bin:/usr/bin
ExecStart=/usr/local/bin/node shinobi-face.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
            print_info "✓ Плагин распознавания лиц установлен"
        fi
    fi
    
    # Установка прав
    chown -R "$SHINOBI_USER:$SHINOBI_GROUP" "$PLUGINS_DIR"
    
    systemctl daemon-reload
    
    print_info "✓ Установка плагинов завершена"
}

# Запуск сервисов
start_services() {
    print_step "Запуск сервисов..."
    
    systemctl enable shinobi
    systemctl enable shinobi-cron
    
    systemctl start shinobi
    sleep 3
    systemctl start shinobi-cron
    
    if [ "$ENABLE_PROMETHEUS" = true ]; then
        systemctl start shinobi-exporter
    fi
    
    # Запуск плагинов
    if [ "$INSTALL_PLUGIN_OPENCV" = true ] && [ -f /etc/systemd/system/shinobi-opencv.service ]; then
        systemctl enable --now shinobi-opencv || true
    fi
    if [ "$INSTALL_PLUGIN_TENSORFLOW" = true ] && [ -f /etc/systemd/system/shinobi-tensorflow.service ]; then
        systemctl enable --now shinobi-tensorflow || true
    fi
    if [ "$INSTALL_PLUGIN_YOLO" = true ] && [ -f /etc/systemd/system/shinobi-yolo.service ]; then
        systemctl enable --now shinobi-yolo || true
    fi
    if [ "$INSTALL_PLUGIN_FACE" = true ] && [ -f /etc/systemd/system/shinobi-face.service ]; then
        systemctl enable --now shinobi-face || true
    fi
    
    # Проверка статуса
    if systemctl is-active --quiet shinobi; then
        print_info "✓ Shinobi запущен"
    else
        print_error "✗ Shinobi не запустился"
        journalctl -u shinobi -n 20 --no-pager
        exit 1
    fi
}

# Сохранение учётных данных
save_credentials() {
    print_step "Сохранение учётных данных..."
    
    CREDS_DIR="$SHINOBI_DIR/credentials"
    mkdir -p "$CREDS_DIR"
    chmod 700 "$CREDS_DIR"
    
    cat > "$CREDS_DIR/admin.txt" << EOF
Shinobi CE Credentials
======================
URL: http://$(hostname -I | awk '{print $1}'):${SHINOBI_PORT}/super
Email: ${ADMIN_EMAIL}
Password: ${ADMIN_PASSWORD}

Generated: $(date)
EOF
    
    if [ "$DB_TYPE" = "postgres" ]; then
        cat > "$CREDS_DIR/database.txt" << EOF
PostgreSQL Credentials
======================
Host: ${DB_HOST}
Port: ${DB_PORT}
Database: ${DB_NAME}
User: ${DB_USER}
Password: ${DB_PASSWORD}

Generated: $(date)
EOF
    fi
    
    chmod 600 "$CREDS_DIR"/*.txt
    chown -R root:root "$CREDS_DIR"
    
    print_info "✓ Учётные данные сохранены в $CREDS_DIR"
}

# Вывод итоговой информации
show_summary() {
    IP_ADDR=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    print_info "✓ Установка Shinobi CE завершена!"
    echo "=============================================="
    echo ""
    print_info "Веб-интерфейс:"
    print_info "  Супер-админ: http://${IP_ADDR}:${SHINOBI_PORT}/super"
    print_info "  Вход пользователя: http://${IP_ADDR}:${SHINOBI_PORT}/"
    echo ""
    print_info "Учётные данные супер-админа:"
    print_info "  Email: ${ADMIN_EMAIL}"
    print_info "  Password: ${ADMIN_PASSWORD}"
    echo ""
    
    if [ "$DB_TYPE" = "postgres" ]; then
        print_info "База данных: PostgreSQL"
        print_info "  Хост: ${DB_HOST}:${DB_PORT}"
        print_info "  База: ${DB_NAME}"
        print_info "  Пользователь: ${DB_USER}"
    else
        print_info "База данных: SQLite"
        print_info "  Файл: ${SHINOBI_DIR}/shinobi.sqlite"
    fi
    echo ""
    
    if [ -n "$GPU_TYPE" ]; then
        print_info "GPU ускорение: ${GPU_TYPE}"
    fi
    
    print_info "Хранилище записей: ${STORAGE_PATH}"
    print_info "Retention: ${RETENTION_DAYS} дней"
    echo ""
    
    if [ "$ENABLE_PROMETHEUS" = true ]; then
        print_info "Prometheus метрики: http://${IP_ADDR}:${PROMETHEUS_PORT}/metrics"
    fi
    
    # Информация о плагинах
    INSTALLED_PLUGINS=""
    [ "$INSTALL_PLUGIN_OPENCV" = true ] && INSTALLED_PLUGINS="${INSTALLED_PLUGINS}OpenCV, "
    [ "$INSTALL_PLUGIN_TENSORFLOW" = true ] && INSTALLED_PLUGINS="${INSTALLED_PLUGINS}TensorFlow, "
    [ "$INSTALL_PLUGIN_YOLO" = true ] && INSTALLED_PLUGINS="${INSTALLED_PLUGINS}YOLO, "
    [ "$INSTALL_PLUGIN_FACE" = true ] && INSTALLED_PLUGINS="${INSTALLED_PLUGINS}Face Recognition, "
    
    if [ -n "$INSTALLED_PLUGINS" ]; then
        echo ""
        print_info "Установленные плагины: ${INSTALLED_PLUGINS%, }"
        print_info "  Директория: ${SHINOBI_DIR}/plugins/"
        print_info "  Управление: systemctl status shinobi-opencv"
    fi
    
    echo ""
    print_info "Управление сервисами:"
    print_info "  systemctl status shinobi"
    print_info "  systemctl restart shinobi"
    print_info "  journalctl -u shinobi -f"
    echo ""
    print_info "Учётные данные сохранены в: ${SHINOBI_DIR}/credentials/"
    echo ""
    print_warn "Следующие шаги:"
    print_warn "  1. Откройте http://${IP_ADDR}:${SHINOBI_PORT}/super"
    print_warn "  2. Войдите с учётными данными супер-админа"
    print_warn "  3. Создайте обычного пользователя через меню 'Accounts'"
    print_warn "  4. Добавьте камеры через интерфейс пользователя"
    echo ""
}

#############################################
# Основная логика
#############################################

check_compatibility

if [ "$CHECK_ONLY" = true ]; then
    print_info "Режим проверки. Установка не выполняется."
    exit 0
fi

show_install_info

# Основные шаги установки
install_dependencies
install_nodejs
[ "$INSTALL_POSTGRES" = true ] && install_postgres
create_shinobi_user
clone_shinobi
install_npm_dependencies
create_shinobi_config
create_storage_dirs
init_database
create_systemd_service
setup_prometheus
install_plugins
start_services
save_credentials

show_summary

