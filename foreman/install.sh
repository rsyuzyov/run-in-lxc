#!/bin/bash

#############################################
# Foreman Installation Script for LXC
# Обёртка над https://github.com/rsyuzyov/foreman-setup
# с адаптированными параметрами в GNU-стиле
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Значения по умолчанию
VERSION="3.17"
CHECK=false
DB_HOST=""
DB_USER="postgres"
DB_PASSWORD=""
REDIS_HOST=""
REDIS_PASSWORD=""
FOREMAN_SETUP_REPO="https://github.com/rsyuzyov/foreman-setup.git"
FOREMAN_SETUP_DIR="/tmp/foreman-setup"
USE_LOCAL_ASSETS=false

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

Установка Foreman в LXC контейнер на Debian 12.

Опции:
  --version VERSION       Версия Foreman (по умолчанию: 3.17)
  --check                 Выполнить проверки перед установкой
  --db-host HOST          Адрес PostgreSQL (если не указан — встроенный)
  --db-user USER          Пользователь БД (по умолчанию: postgres)
  --db-password PASS      Пароль пользователя БД
  --redis-host HOST       Адрес Redis (если не указан — встроенный)
  --redis-password PASS   Пароль Redis (опционально)
  --use-local-assets      Использовать локальные .deb пакеты puppet из assets/
  --help                  Показать эту справку

Примеры:
  # Минимальная установка (версия по умолчанию)
  $0

  # Установка конкретной версии с проверками
  $0 --version 3.16 --check

  # С внешней БД PostgreSQL
  $0 --db-host 192.168.1.100 --db-user postgres --db-password SecurePass

  # С внешними PostgreSQL и Redis
  $0 --db-host 192.168.1.100 --db-password SecurePass --redis-host 192.168.1.101

  # С локальными assets (при проблемах со скачиванием puppet)
  $0 --use-local-assets

Требования к LXC контейнеру:
  - Привилегированный, либо включена опция keyctl
  - Debian 12 (Bookworm)
  - 4 ядра (минимум 2)
  - 8 ГБ RAM (минимум 4)
  - Опции: keyctl, nesting

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --check)
            CHECK=true
            shift
            ;;
        --db-host)
            DB_HOST="$2"
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
        --redis-password)
            REDIS_PASSWORD="$2"
            shift 2
            ;;
        --use-local-assets)
            USE_LOCAL_ASSETS=true
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

# Определение директории скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS_DIR="$SCRIPT_DIR/assets"

# Проверка ОС
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "debian" ] || [ "$VERSION_ID" != "12" ]; then
        print_warn "Обнаружена ОС: $ID $VERSION_ID"
        print_warn "Рекомендуется Debian 12 (Bookworm)"
        print_warn "На Debian 13 установка может не работать из-за несовместимости Ruby"
    fi
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

# Проверка системных требований
print_info "Проверка системных требований..."

# Проверка RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 4096 ]; then
    print_warn "Обнаружено только ${TOTAL_RAM}MB RAM"
    print_warn "Foreman требует минимум 4GB RAM, рекомендуется 8GB"
fi

# Проверка CPU
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 2 ]; then
    print_warn "Обнаружено только ${CPU_CORES} ядер CPU"
    print_warn "Рекомендуется минимум 4 ядра"
fi

print_info "Начало установки Foreman..."
print_info "Версия: $VERSION"

if [ -n "$DB_HOST" ]; then
    print_info "База данных: $DB_USER@$DB_HOST (внешняя)"
else
    print_info "База данных: встроенная PostgreSQL"
fi

if [ -n "$REDIS_HOST" ]; then
    print_info "Redis: $REDIS_HOST (внешний)"
else
    print_info "Redis: встроенный"
fi

# Установка git если не установлен
if ! command -v git &> /dev/null; then
    print_info "Установка git..."
    apt-get update -y
    apt-get install -y git
fi

# Клонирование репозитория foreman-setup
print_info "Клонирование репозитория foreman-setup..."
rm -rf "$FOREMAN_SETUP_DIR"
git clone "$FOREMAN_SETUP_REPO" "$FOREMAN_SETUP_DIR"

# Копирование локальных assets если указано
if [ "$USE_LOCAL_ASSETS" = true ]; then
    if [ -d "$ASSETS_DIR" ] && [ "$(ls -A "$ASSETS_DIR"/*.deb 2>/dev/null)" ]; then
        print_info "Копирование локальных assets..."
        mkdir -p "$FOREMAN_SETUP_DIR/assets"
        cp "$ASSETS_DIR"/*.deb "$FOREMAN_SETUP_DIR/assets/"
    else
        print_warn "Локальные assets не найдены в $ASSETS_DIR"
        print_warn "Скачайте пакеты puppet вручную:"
        print_warn "  https://apt.puppet.com/pool/bookworm/puppet8/p/puppet-agent/"
        print_warn "  https://apt.puppet.com/pool/bookworm/puppet8/p/puppetserver/"
    fi
fi

# Формирование аргументов для foreman-setup.sh
FOREMAN_ARGS="-v $VERSION"

if [ "$CHECK" = true ]; then
    FOREMAN_ARGS="$FOREMAN_ARGS -check"
fi

if [ -n "$DB_HOST" ]; then
    FOREMAN_ARGS="$FOREMAN_ARGS -pghost $DB_HOST -pglogin $DB_USER"
    if [ -n "$DB_PASSWORD" ]; then
        FOREMAN_ARGS="$FOREMAN_ARGS -pgpass $DB_PASSWORD"
    fi
fi

if [ -n "$REDIS_HOST" ]; then
    FOREMAN_ARGS="$FOREMAN_ARGS -redishost $REDIS_HOST"
    if [ -n "$REDIS_PASSWORD" ]; then
        FOREMAN_ARGS="$FOREMAN_ARGS -redispass $REDIS_PASSWORD"
    fi
fi

# Запуск установки
print_info "Запуск foreman-setup.sh с параметрами: $FOREMAN_ARGS"
cd "$FOREMAN_SETUP_DIR"
chmod +x foreman-setup.sh
./foreman-setup.sh $FOREMAN_ARGS

# Информация после установки
echo ""
echo "=============================================="
print_info "Установка Foreman завершена!"
echo "=============================================="
echo ""
print_info "Адрес: https://$(hostname)"
print_info "Логин: admin"
print_info "Пароль: changeme"
echo ""
print_warn "⚠️  Смените пароль сразу после первого входа!"
echo ""

if [ -n "$DB_HOST" ]; then
    print_info "База данных: $DB_USER@$DB_HOST"
else
    print_info "База данных: встроенная PostgreSQL"
fi

if [ -n "$REDIS_HOST" ]; then
    print_info "Redis: $REDIS_HOST"
else
    print_info "Redis: встроенный"
fi

echo ""
print_info "Управление сервисами:"
echo "  foreman-maintain service status  - статус"
echo "  foreman-maintain service restart - перезапуск"
echo "  foreman-maintain service stop    - остановка"
echo ""
print_info "Логи: /var/log/foreman/"
print_info "Конфигурация: /etc/foreman/"
echo ""

# Очистка
print_info "Очистка временных файлов..."
rm -rf "$FOREMAN_SETUP_DIR"

print_info "Готово!"

