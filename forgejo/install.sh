#!/bin/bash

#############################################
# Forgejo Installation Script for LXC
# Поддерживает установку с внешней PostgreSQL БД
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Значения по умолчанию
FORGEJO_VERSION="latest"
DB_HOST=""
DB_PORT="5432"
DB_NAME="forgejo"
DB_USER="forgejo"
DB_PASSWORD=""
HTTP_PORT="3000"
SSH_PORT="2222"
DOMAIN="localhost"
FORGEJO_USER="forgejo"
FORGEJO_HOME="/var/lib/forgejo"
FORGEJO_CONFIG="/etc/forgejo"
INSTALL_LOCAL_POSTGRES=false

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

# Функция помощи
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Опции:
  --version VERSION        Версия Forgejo (по умолчанию: latest)
  --db-host HOST          Адрес PostgreSQL сервера (по умолчанию: localhost)
  --db-port PORT          Порт PostgreSQL (по умолчанию: 5432)
  --db-name NAME          Имя базы данных (по умолчанию: forgejo)
  --db-user USER          Пользователь БД (по умолчанию: forgejo)
  --db-password PASS      Пароль пользователя БД (обязательно)
  --http-port PORT        HTTP порт (по умолчанию: 3000)
  --ssh-port PORT         SSH порт для Git (по умолчанию: 2222)
  --domain DOMAIN         Доменное имя (по умолчанию: localhost)
  --help                  Показать эту справку

Пример:
  $0 --db-host 192.168.1.100 --db-name forgejo --db-user forgejo --db-password SecurePass123

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            FORGEJO_VERSION="$2"
            shift 2
            ;;
        --db-host)
            DB_HOST="$2"
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
        --http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --domain)
            DOMAIN="$2"
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

# Определение необходимости установки локального PostgreSQL
if [ -z "$DB_HOST" ]; then
    print_info "Параметр --db-host не указан. Будет установлен локальный PostgreSQL"
    INSTALL_LOCAL_POSTGRES=true
    DB_HOST="localhost"
    
    # Если пароль не указан, генерируем случайный
    if [ -z "$DB_PASSWORD" ]; then
        DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        print_info "Сгенерирован случайный пароль для БД"
    fi
fi

# Проверка обязательных параметров
if [ -z "$DB_PASSWORD" ] && [ "$INSTALL_LOCAL_POSTGRES" = false ]; then
    print_error "Пароль базы данных обязателен при использовании внешнего PostgreSQL! Используйте --db-password"
    exit 1
fi

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    print_error "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

print_info "Начало установки Forgejo..."
print_info "Версия: $FORGEJO_VERSION"
print_info "База данных: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
print_info "HTTP порт: $HTTP_PORT"
print_info "SSH порт: $SSH_PORT"
print_info "Домен: $DOMAIN"

# Определение архитектуры
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        FORGEJO_ARCH="amd64"
        ;;
    aarch64)
        FORGEJO_ARCH="arm64"
        ;;
    *)
        print_error "Неподдерживаемая архитектура: $ARCH"
        exit 1
        ;;
esac

print_info "Архитектура: $FORGEJO_ARCH"

# Проверка системных требований
print_info "Проверка системных требований..."

# Проверка RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 1024 ]; then
    print_warn "Обнаружено только ${TOTAL_RAM}MB RAM. Рекомендуется минимум 1GB"
fi

# Проверка дискового пространства
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    print_warn "Доступно только ${AVAILABLE_SPACE}GB. Рекомендуется минимум 10GB"
fi

# Установка зависимостей
print_info "Установка зависимостей..."
apt-get update
apt-get install -y git postgresql-client curl wget

# Установка локального PostgreSQL если требуется
if [ "$INSTALL_LOCAL_POSTGRES" = true ]; then
    print_info "Установка локального PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
    
    # Запуск PostgreSQL
    systemctl enable postgresql
    systemctl start postgresql
    
    # Ожидание запуска PostgreSQL
    sleep 3
    
    print_info "Создание базы данных и пользователя..."
    
    # Создание пользователя и базы данных
    sudo -u postgres psql << EOF
-- Создание пользователя
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Создание базы данных
CREATE DATABASE $DB_NAME OWNER $DB_USER;

-- Выдача прав
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Для PostgreSQL 15+
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF
    
    if [ $? -eq 0 ]; then
        print_info "✓ PostgreSQL успешно установлен и настроен"
        print_info "  База данных: $DB_NAME"
        print_info "  Пользователь: $DB_USER"
        print_info "  Пароль: $DB_PASSWORD"
    else
        print_error "Ошибка при настройке PostgreSQL"
        exit 1
    fi
fi

# Получение последней версии если указано "latest"
if [ "$FORGEJO_VERSION" = "latest" ]; then
    print_info "Получение информации о последней версии..."
    FORGEJO_VERSION=$(curl -s https://api.github.com/repos/go-gitea/gitea/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    if [ -z "$FORGEJO_VERSION" ]; then
        print_error "Не удалось получить последнюю версию"
        exit 1
    fi
    print_info "Последняя версия: $FORGEJO_VERSION"
fi

# Формирование URL для скачивания
DOWNLOAD_URL="https://github.com/go-gitea/gitea/releases/download/v${FORGEJO_VERSION}/gitea-${FORGEJO_VERSION}-linux-${FORGEJO_ARCH}"

print_info "URL для скачивания: $DOWNLOAD_URL"

# Создание пользователя forgejo
if ! id "$FORGEJO_USER" &>/dev/null; then
    print_info "Создание пользователя $FORGEJO_USER..."
    useradd --system --shell /bin/bash --home "$FORGEJO_HOME" --create-home "$FORGEJO_USER"
else
    print_info "Пользователь $FORGEJO_USER уже существует"
fi

# Создание необходимых директорий
print_info "Создание директорий..."
mkdir -p "$FORGEJO_HOME"/{custom,data,log}
mkdir -p "$FORGEJO_CONFIG"

# Скачивание Forgejo
print_info "Скачивание Forgejo v${FORGEJO_VERSION}..."
wget -O /usr/local/bin/gitea "$DOWNLOAD_URL"
chmod +x /usr/local/bin/gitea

# Проверка подключения к БД
print_info "Проверка подключения к PostgreSQL..."
export PGPASSWORD="$DB_PASSWORD"
if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
    print_error "Не удалось подключиться к базе данных!"
    print_error "Убедитесь, что:"
    print_error "  1. PostgreSQL сервер запущен и доступен"
    print_error "  2. База данных '$DB_NAME' создана"
    print_error "  3. Пользователь '$DB_USER' имеет права на базу"
    print_error "  4. Пароль корректен"
    exit 1
fi
unset PGPASSWORD

print_info "Подключение к БД успешно"

# Создание конфигурационного файла
print_info "Создание конфигурации..."
cat > "$FORGEJO_CONFIG/app.ini" << EOF
APP_NAME = Forgejo: Git with a cup of tea
RUN_MODE = prod
RUN_USER = $FORGEJO_USER

[server]
DOMAIN           = $DOMAIN
HTTP_PORT        = $HTTP_PORT
ROOT_URL         = http://$DOMAIN:$HTTP_PORT/
DISABLE_SSH      = false
SSH_PORT         = $SSH_PORT
START_SSH_SERVER = true
LFS_START_SERVER = true
OFFLINE_MODE     = false

[database]
DB_TYPE  = postgres
HOST     = $DB_HOST:$DB_PORT
NAME     = $DB_NAME
USER     = $DB_USER
PASSWD   = $DB_PASSWORD
SSL_MODE = disable
CHARSET  = utf8

[repository]
ROOT = $FORGEJO_HOME/data/gitea-repositories

[repository.local]
LOCAL_COPY_PATH = $FORGEJO_HOME/data/tmp/local-repo

[repository.upload]
TEMP_PATH = $FORGEJO_HOME/data/tmp/uploads

[log]
MODE      = console, file
LEVEL     = info
ROOT_PATH = $FORGEJO_HOME/log

[security]
INSTALL_LOCK   = false
SECRET_KEY     = 
INTERNAL_TOKEN = 

[service]
DISABLE_REGISTRATION              = false
REQUIRE_SIGNIN_VIEW               = false
REGISTER_EMAIL_CONFIRM            = false
ENABLE_NOTIFY_MAIL                = false
ALLOW_ONLY_EXTERNAL_REGISTRATION  = false
ENABLE_CAPTCHA                    = false
DEFAULT_KEEP_EMAIL_PRIVATE        = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true
DEFAULT_ENABLE_TIMETRACKING       = true
NO_REPLY_ADDRESS                  = noreply.$DOMAIN

[picture]
DISABLE_GRAVATAR        = false
ENABLE_FEDERATED_AVATAR = true

[openid]
ENABLE_OPENID_SIGNIN = false
ENABLE_OPENID_SIGNUP = false

[session]
PROVIDER = file

[mailer]
ENABLED = false
EOF

# Установка прав доступа
print_info "Установка прав доступа..."
chown -R "$FORGEJO_USER:$FORGEJO_USER" "$FORGEJO_HOME"
chown -R "$FORGEJO_USER:$FORGEJO_USER" "$FORGEJO_CONFIG"
chmod 750 "$FORGEJO_HOME"
chmod 640 "$FORGEJO_CONFIG/app.ini"

# Создание systemd service
print_info "Создание systemd сервиса..."
cat > /etc/systemd/system/forgejo.service << EOF
[Unit]
Description=Forgejo (Git with a cup of tea)
After=syslog.target
After=network.target
After=postgresql.service

[Service]
Type=simple
User=$FORGEJO_USER
Group=$FORGEJO_USER
WorkingDirectory=$FORGEJO_HOME
ExecStart=/usr/local/bin/gitea web --config $FORGEJO_CONFIG/app.ini
Restart=always
Environment=USER=$FORGEJO_USER HOME=$FORGEJO_HOME GITEA_WORK_DIR=$FORGEJO_HOME

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd и запуск сервиса
print_info "Запуск Forgejo..."
systemctl daemon-reload
systemctl enable forgejo
systemctl restart forgejo

# Ожидание запуска
print_info "Ожидание запуска сервиса..."
sleep 5

# Проверка статуса
if systemctl is-active --quiet forgejo; then
    print_info "✓ Forgejo успешно установлен и запущен!"
    echo ""
    print_info "Доступ к веб-интерфейсу: http://$DOMAIN:$HTTP_PORT"
    print_info "SSH клонирование: ssh://git@$DOMAIN:$SSH_PORT/user/repo.git"
    echo ""
    
    if [ "$INSTALL_LOCAL_POSTGRES" = true ]; then
        print_info "База данных PostgreSQL:"
        print_info "  Хост: localhost"
        print_info "  База: $DB_NAME"
        print_info "  Пользователь: $DB_USER"
        print_info "  Пароль: $DB_PASSWORD"
        echo ""
        print_warn "ВАЖНО: Сохраните пароль базы данных в безопасном месте!"
        echo ""
    fi
    
    print_info "Управление сервисом:"
    print_info "  systemctl status forgejo   - статус"
    print_info "  systemctl restart forgejo  - перезапуск"
    print_info "  systemctl stop forgejo     - остановка"
    print_info "  journalctl -u forgejo -f   - логи"
    echo ""
    print_info "Конфигурация: $FORGEJO_CONFIG/app.ini"
    print_info "Данные: $FORGEJO_HOME"
    echo ""
    print_warn "При первом входе завершите настройку через веб-интерфейс"
else
    print_error "Не удалось запустить Forgejo!"
    print_error "Проверьте логи: journalctl -u forgejo -n 50"
    exit 1
fi
