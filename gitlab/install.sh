#!/bin/bash

#############################################
# GitLab CE (Omnibus) Installation Script for LXC
# Поддерживает внешние PostgreSQL и Redis
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Значения по умолчанию
DOMAIN="localhost"
EXTERNAL_URL=""
DB_HOST=""
DB_PORT="5432"
DB_NAME="gitlabhq_production"
DB_USER="gitlab"
DB_PASSWORD=""
REDIS_HOST=""
REDIS_PORT="6379"
REDIS_PASSWORD=""
LETSENCRYPT=false
LETSENCRYPT_EMAIL=""
SKIP_RECONFIGURE=false

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
  --domain DOMAIN           Доменное имя (по умолчанию: localhost)
  --external-url URL        Полный URL для доступа (по умолчанию: http://{domain})
  --db-host HOST            Адрес PostgreSQL (если не указан — встроенный)
  --db-port PORT            Порт PostgreSQL (по умолчанию: 5432)
  --db-name NAME            Имя базы данных (по умолчанию: gitlabhq_production)
  --db-user USER            Пользователь БД (по умолчанию: gitlab)
  --db-password PASS        Пароль пользователя БД (обязателен для внешней БД)
  --redis-host HOST         Адрес Redis (если не указан — встроенный)
  --redis-port PORT         Порт Redis (по умолчанию: 6379)
  --redis-password PASS     Пароль Redis (опционально)
  --letsencrypt             Включить Let's Encrypt
  --letsencrypt-email EMAIL Email для Let's Encrypt
  --skip-reconfigure        Не запускать gitlab-ctl reconfigure
  --help                    Показать эту справку

Примеры:
  # Минимальная установка
  $0 --domain gitlab.example.com

  # С внешней БД
  $0 --domain gitlab.example.com --db-host 192.168.1.100 --db-password SecurePass

  # С HTTPS
  $0 --external-url https://gitlab.example.com --letsencrypt --letsencrypt-email admin@example.com

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
        --external-url)
            EXTERNAL_URL="$2"
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
        --redis-host)
            REDIS_HOST="$2"
            shift 2
            ;;
        --redis-port)
            REDIS_PORT="$2"
            shift 2
            ;;
        --redis-password)
            REDIS_PASSWORD="$2"
            shift 2
            ;;
        --letsencrypt)
            LETSENCRYPT=true
            shift
            ;;
        --letsencrypt-email)
            LETSENCRYPT_EMAIL="$2"
            shift 2
            ;;
        --skip-reconfigure)
            SKIP_RECONFIGURE=true
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

# Формирование external_url если не указан
if [ -z "$EXTERNAL_URL" ]; then
    if [ "$LETSENCRYPT" = true ]; then
        EXTERNAL_URL="https://$DOMAIN"
    else
        EXTERNAL_URL="http://$DOMAIN"
    fi
fi

# Проверка обязательных параметров для внешней БД
if [ -n "$DB_HOST" ] && [ -z "$DB_PASSWORD" ]; then
    print_error "Пароль базы данных обязателен при использовании внешнего PostgreSQL!"
    print_error "Используйте --db-password"
    exit 1
fi

# Проверка Let's Encrypt
if [ "$LETSENCRYPT" = true ] && [ -z "$LETSENCRYPT_EMAIL" ]; then
    print_error "Email обязателен для Let's Encrypt!"
    print_error "Используйте --letsencrypt-email"
    exit 1
fi

print_info "Начало установки GitLab CE..."
print_info "External URL: $EXTERNAL_URL"

if [ -n "$DB_HOST" ]; then
    print_info "База данных: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME (внешняя)"
else
    print_info "База данных: встроенная PostgreSQL"
fi

if [ -n "$REDIS_HOST" ]; then
    print_info "Redis: $REDIS_HOST:$REDIS_PORT (внешний)"
else
    print_info "Redis: встроенный"
fi

# Проверка системных требований
print_info "Проверка системных требований..."

# Проверка архитектуры
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    print_error "GitLab Omnibus поддерживает только x86_64 архитектуру"
    print_error "Обнаружено: $ARCH"
    exit 1
fi

# Проверка RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 4096 ]; then
    print_warn "Обнаружено только ${TOTAL_RAM}MB RAM"
    print_warn "GitLab требует минимум 4GB RAM, рекомендуется 8GB"
    print_warn "Продолжаем установку, но возможны проблемы с производительностью"
fi

# Проверка дискового пространства
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 20 ]; then
    print_warn "Доступно только ${AVAILABLE_SPACE}GB дискового пространства"
    print_warn "Рекомендуется минимум 50GB"
fi

# Определение дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

print_info "Обнаружена ОС: $OS $VERSION"

# Установка зависимостей
print_info "Установка зависимостей..."
apt-get update
apt-get install -y curl openssh-server ca-certificates tzdata perl postfix

# Настройка postfix для локальной доставки
if [ -f /etc/postfix/main.cf ]; then
    print_info "Настройка Postfix..."
    postconf -e "inet_interfaces = loopback-only"
    systemctl restart postfix 2>/dev/null || true
fi

# Проверка подключения к внешней БД
if [ -n "$DB_HOST" ]; then
    print_info "Проверка подключения к внешней PostgreSQL..."
    apt-get install -y postgresql-client
    
    export PGPASSWORD="$DB_PASSWORD"
    if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
        print_error "Не удалось подключиться к базе данных!"
        print_error "Проверьте:"
        print_error "  1. PostgreSQL сервер запущен и доступен по адресу $DB_HOST:$DB_PORT"
        print_error "  2. База данных '$DB_NAME' создана"
        print_error "  3. Пользователь '$DB_USER' имеет права на базу"
        print_error "  4. Пароль корректен"
        exit 1
    fi
    
    # Проверка расширений
    print_info "Проверка расширений PostgreSQL..."
    EXTENSIONS=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT extname FROM pg_extension;" 2>/dev/null)
    
    if ! echo "$EXTENSIONS" | grep -q "pg_trgm"; then
        print_warn "Расширение pg_trgm не установлено"
        print_warn "Выполните на сервере PostgreSQL: CREATE EXTENSION pg_trgm;"
    fi
    
    if ! echo "$EXTENSIONS" | grep -q "btree_gist"; then
        print_warn "Расширение btree_gist не установлено"
        print_warn "Выполните на сервере PostgreSQL: CREATE EXTENSION btree_gist;"
    fi
    
    unset PGPASSWORD
    print_info "Подключение к внешней БД успешно"
fi

# Проверка подключения к внешнему Redis
if [ -n "$REDIS_HOST" ]; then
    print_info "Проверка подключения к внешнему Redis..."
    apt-get install -y redis-tools
    
    REDIS_CLI_ARGS="-h $REDIS_HOST -p $REDIS_PORT"
    if [ -n "$REDIS_PASSWORD" ]; then
        REDIS_CLI_ARGS="$REDIS_CLI_ARGS -a $REDIS_PASSWORD"
    fi
    
    if ! redis-cli $REDIS_CLI_ARGS ping 2>/dev/null | grep -q "PONG"; then
        print_error "Не удалось подключиться к Redis!"
        print_error "Проверьте доступность $REDIS_HOST:$REDIS_PORT"
        exit 1
    fi
    
    print_info "Подключение к внешнему Redis успешно"
fi

# Добавление репозитория GitLab
print_info "Добавление репозитория GitLab..."

curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash

# Установка GitLab
print_info "Установка GitLab CE..."
print_info "Это может занять 5-10 минут..."

GITLAB_EXTERNAL_URL="$EXTERNAL_URL" apt-get install -y gitlab-ce

# Создание конфигурации
print_info "Настройка конфигурации..."

# Бэкап оригинального конфига
if [ -f /etc/gitlab/gitlab.rb ]; then
    cp /etc/gitlab/gitlab.rb /etc/gitlab/gitlab.rb.backup.$(date +%Y%m%d_%H%M%S)
fi

# Формирование дополнительной конфигурации
GITLAB_CONFIG=""

# Настройка внешней БД
if [ -n "$DB_HOST" ]; then
    GITLAB_CONFIG+="
# Внешняя PostgreSQL
postgresql['enable'] = false
gitlab_rails['db_adapter'] = 'postgresql'
gitlab_rails['db_encoding'] = 'unicode'
gitlab_rails['db_host'] = '$DB_HOST'
gitlab_rails['db_port'] = $DB_PORT
gitlab_rails['db_database'] = '$DB_NAME'
gitlab_rails['db_username'] = '$DB_USER'
gitlab_rails['db_password'] = '$DB_PASSWORD'
"
fi

# Настройка внешнего Redis
if [ -n "$REDIS_HOST" ]; then
    GITLAB_CONFIG+="
# Внешний Redis
redis['enable'] = false
gitlab_rails['redis_host'] = '$REDIS_HOST'
gitlab_rails['redis_port'] = $REDIS_PORT
"
    if [ -n "$REDIS_PASSWORD" ]; then
        GITLAB_CONFIG+="gitlab_rails['redis_password'] = '$REDIS_PASSWORD'
"
    fi
fi

# Настройка Let's Encrypt
if [ "$LETSENCRYPT" = true ]; then
    GITLAB_CONFIG+="
# Let's Encrypt
letsencrypt['enable'] = true
letsencrypt['contact_emails'] = ['$LETSENCRYPT_EMAIL']
letsencrypt['auto_renew'] = true
"
fi

# Добавление конфигурации в gitlab.rb
if [ -n "$GITLAB_CONFIG" ]; then
    print_info "Добавление пользовательской конфигурации..."
    
    # Добавляем маркер и конфигурацию
    echo "" >> /etc/gitlab/gitlab.rb
    echo "##############################################" >> /etc/gitlab/gitlab.rb
    echo "# Конфигурация добавлена скриптом install.sh" >> /etc/gitlab/gitlab.rb
    echo "# $(date)" >> /etc/gitlab/gitlab.rb
    echo "##############################################" >> /etc/gitlab/gitlab.rb
    echo "$GITLAB_CONFIG" >> /etc/gitlab/gitlab.rb
fi

# Применение конфигурации
if [ "$SKIP_RECONFIGURE" = false ]; then
    print_info "Применение конфигурации (gitlab-ctl reconfigure)..."
    print_info "Это может занять несколько минут..."
    
    gitlab-ctl reconfigure
    
    # Ожидание запуска всех сервисов
    print_info "Ожидание запуска сервисов..."
    sleep 10
    
    # Проверка статуса
    if gitlab-ctl status | grep -q "run:"; then
        print_info "✓ GitLab CE успешно установлен!"
    else
        print_error "Некоторые сервисы не запустились"
        print_error "Проверьте: sudo gitlab-ctl status"
        exit 1
    fi
else
    print_info "Пропуск gitlab-ctl reconfigure (--skip-reconfigure)"
    print_info "Выполните вручную: sudo gitlab-ctl reconfigure"
fi

# Вывод информации
echo ""
echo "=============================================="
print_info "GitLab CE установлен!"
echo "=============================================="
echo ""
print_info "URL: $EXTERNAL_URL"
echo ""
print_info "Начальный пароль root:"
echo "  sudo cat /etc/gitlab/initial_root_password"
echo ""
print_warn "⚠️  Файл с паролем удалится через 24 часа!"
print_warn "⚠️  Смените пароль сразу после первого входа!"
echo ""

if [ -n "$DB_HOST" ]; then
    print_info "База данных: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
else
    print_info "База данных: встроенная PostgreSQL"
fi

if [ -n "$REDIS_HOST" ]; then
    print_info "Redis: $REDIS_HOST:$REDIS_PORT"
else
    print_info "Redis: встроенный"
fi

echo ""
print_info "Управление:"
echo "  gitlab-ctl status     - статус сервисов"
echo "  gitlab-ctl restart    - перезапуск"
echo "  gitlab-ctl tail       - логи"
echo "  gitlab-ctl reconfigure - применить изменения конфига"
echo ""
print_info "Конфигурация: /etc/gitlab/gitlab.rb"
print_info "Данные: /var/opt/gitlab/"
print_info "Логи: /var/log/gitlab/"
echo ""

if [ "$LETSENCRYPT" = true ]; then
    print_info "HTTPS: Let's Encrypt включен"
    print_info "Сертификаты обновляются автоматически"
fi

echo ""
print_info "Для CI/CD установите GitLab Runner:"
echo "  См. ../gitlab-runner/README.md"
echo ""

