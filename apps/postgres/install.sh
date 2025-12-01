#!/bin/bash

#############################################
# PostgreSQL Installation Script for LXC
# Поддерживает установку PostgreSQL для 1С и ванильный PostgreSQL
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
POSTGRES_VARIANT="1c"  # 1c или vanilla
POSTGRES_1C_VERSION="18"
POSTGRES_VANILLA_VERSION="16"
STANDALONE_INSTALL=true  # true = единственный Postgres, false = параллельная установка
DB_NAME=""
DB_USER=""
DB_PASSWORD=""
LISTEN_ADDRESSES="localhost"
ALLOW_REMOTE=false

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

Скрипт установки PostgreSQL для LXC контейнеров.
По умолчанию устанавливается PostgreSQL для 1С от Postgres Professional.

Опции:
  --vanilla                 Установить ванильный PostgreSQL вместо версии для 1С
  --1c-version VERSION      Версия PostgresPro для 1С (по умолчанию: 18)
  --vanilla-version VERSION Версия ванильного PostgreSQL (по умолчанию: 16)
  --parallel                Параллельная установка (не будет конфликтовать с другим Postgres)
  --db-name NAME            Создать базу данных с указанным именем
  --db-user USER            Создать пользователя БД
  --db-password PASS        Пароль для пользователя БД
  --allow-remote            Разрешить удалённые подключения (настроит listen_addresses='*')
  --help                    Показать эту справку

Примеры:
  # Установка PostgreSQL для 1С (рекомендуется)
  $0

  # Установка PostgreSQL для 1С с созданием БД для приложения
  $0 --db-name myapp --db-user myapp --db-password SecurePass123

  # Установка ванильного PostgreSQL
  $0 --vanilla

  # Параллельная установка PostgreSQL для 1С (если уже есть другой Postgres)
  $0 --parallel

  # Установка с разрешением удалённых подключений
  $0 --allow-remote --db-name erp --db-user erp_user --db-password MyPassword

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --vanilla)
            POSTGRES_VARIANT="vanilla"
            shift
            ;;
        --1c-version)
            POSTGRES_1C_VERSION="$2"
            shift 2
            ;;
        --vanilla-version)
            POSTGRES_VANILLA_VERSION="$2"
            shift 2
            ;;
        --parallel)
            STANDALONE_INSTALL=false
            shift
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
            LISTEN_ADDRESSES="*"
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

# Проверка параметров БД
if [ -n "$DB_USER" ] && [ -z "$DB_PASSWORD" ]; then
    print_error "Если указан --db-user, необходимо также указать --db-password"
    exit 1
fi

if [ -n "$DB_NAME" ] && [ -z "$DB_USER" ]; then
    print_warn "База данных будет создана, но пользователь не указан. Используйте --db-user для создания пользователя"
fi

# Вывод информации об установке
echo ""
echo "=============================================="
if [ "$POSTGRES_VARIANT" = "1c" ]; then
    print_info "Установка PostgreSQL для 1С (Postgres Professional)"
    print_info "Версия: postgrespro-1c-${POSTGRES_1C_VERSION}"
else
    print_info "Установка ванильного PostgreSQL"
    print_info "Версия: PostgreSQL ${POSTGRES_VANILLA_VERSION}"
fi

if [ "$STANDALONE_INSTALL" = true ]; then
    print_info "Режим: единственный Postgres на машине"
else
    print_info "Режим: параллельная установка"
fi

if [ "$ALLOW_REMOTE" = true ]; then
    print_info "Удалённый доступ: включен"
else
    print_info "Удалённый доступ: только localhost"
fi

if [ -n "$DB_NAME" ]; then
    print_info "База данных: $DB_NAME"
fi
if [ -n "$DB_USER" ]; then
    print_info "Пользователь: $DB_USER"
fi
echo "=============================================="
echo ""

# Установка зависимостей
print_step "Установка базовых зависимостей..."
apt-get update
apt-get install -y wget gnupg2 lsb-release apt-transport-https ca-certificates

if [ "$POSTGRES_VARIANT" = "1c" ]; then
    #############################################
    # Установка PostgreSQL для 1С
    #############################################
    
    print_step "Добавление репозитория Postgres Professional для 1С..."
    
    # Скачивание и выполнение скрипта добавления репозитория
    cd /tmp
    wget -q https://repo.postgrespro.ru/1c/1c-${POSTGRES_1C_VERSION}/keys/pgpro-repo-add.sh
    chmod +x pgpro-repo-add.sh
    sh pgpro-repo-add.sh
    
    if [ "$STANDALONE_INSTALL" = true ]; then
        # Единственный Postgres - полная установка с инициализацией
        print_step "Установка postgrespro-1c-${POSTGRES_1C_VERSION} (полная установка)..."
        apt-get install -y postgrespro-1c-${POSTGRES_1C_VERSION}
        
        PGDATA="/var/lib/pgpro/1c-${POSTGRES_1C_VERSION}/data"
        PGBIN="/opt/pgpro/1c-${POSTGRES_1C_VERSION}/bin"
        SERVICE_NAME="postgrespro-1c-${POSTGRES_1C_VERSION}"
        
    else
        # Параллельная установка
        print_step "Установка postgrespro-1c-${POSTGRES_1C_VERSION}-contrib (параллельная установка)..."
        apt-get install -y postgrespro-1c-${POSTGRES_1C_VERSION}-contrib
        
        PGBIN="/opt/pgpro/1c-${POSTGRES_1C_VERSION}/bin"
        PGDATA="/var/lib/pgpro/1c-${POSTGRES_1C_VERSION}/data"
        SERVICE_NAME="postgrespro-1c-${POSTGRES_1C_VERSION}"
        
        print_step "Инициализация кластера базы данных..."
        ${PGBIN}/pg-setup initdb
        
        print_step "Включение автозапуска сервиса..."
        ${PGBIN}/pg-setup service enable
        
        print_step "Запуск PostgreSQL..."
        ${PGBIN}/pg-setup service start
    fi
    
    # Путь к утилитам
    PSQL="${PGBIN}/psql"
    
else
    #############################################
    # Установка ванильного PostgreSQL
    #############################################
    
    print_step "Добавление официального репозитория PostgreSQL..."
    
    # Добавление ключа репозитория
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg
    
    # Добавление репозитория
    DISTRO=$(lsb_release -cs)
    echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt ${DISTRO}-pgdg main" > /etc/apt/sources.list.d/pgdg.list
    
    apt-get update
    
    print_step "Установка PostgreSQL ${POSTGRES_VANILLA_VERSION}..."
    apt-get install -y postgresql-${POSTGRES_VANILLA_VERSION} postgresql-contrib-${POSTGRES_VANILLA_VERSION}
    
    PGDATA="/var/lib/postgresql/${POSTGRES_VANILLA_VERSION}/main"
    PGBIN="/usr/lib/postgresql/${POSTGRES_VANILLA_VERSION}/bin"
    PSQL="psql"
    SERVICE_NAME="postgresql"
    
    # Запуск сервиса
    print_step "Запуск PostgreSQL..."
    systemctl enable postgresql
    systemctl start postgresql
fi

# Ожидание запуска PostgreSQL
print_step "Ожидание запуска PostgreSQL..."
sleep 3

# Проверка статуса
if [ "$POSTGRES_VARIANT" = "1c" ]; then
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_info "✓ PostgreSQL для 1С успешно запущен"
    else
        print_error "Не удалось запустить PostgreSQL!"
        print_error "Проверьте логи: journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
else
    if systemctl is-active --quiet postgresql; then
        print_info "✓ PostgreSQL успешно запущен"
    else
        print_error "Не удалось запустить PostgreSQL!"
        print_error "Проверьте логи: journalctl -u postgresql -n 50"
        exit 1
    fi
fi

# Настройка удалённого доступа
if [ "$ALLOW_REMOTE" = true ]; then
    print_step "Настройка удалённого доступа..."
    
    if [ "$POSTGRES_VARIANT" = "1c" ]; then
        PG_CONF="${PGDATA}/postgresql.conf"
        PG_HBA="${PGDATA}/pg_hba.conf"
    else
        PG_CONF="/etc/postgresql/${POSTGRES_VANILLA_VERSION}/main/postgresql.conf"
        PG_HBA="/etc/postgresql/${POSTGRES_VANILLA_VERSION}/main/pg_hba.conf"
    fi
    
    # Настройка listen_addresses
    if grep -q "^listen_addresses" "$PG_CONF"; then
        sed -i "s/^listen_addresses.*/listen_addresses = '*'/" "$PG_CONF"
    else
        echo "listen_addresses = '*'" >> "$PG_CONF"
    fi
    
    # Добавление правила в pg_hba.conf для подключения по паролю
    if ! grep -q "host.*all.*all.*0.0.0.0/0.*scram-sha-256" "$PG_HBA"; then
        echo "# Разрешить подключения со всех адресов по паролю" >> "$PG_HBA"
        echo "host    all             all             0.0.0.0/0               scram-sha-256" >> "$PG_HBA"
        echo "host    all             all             ::/0                    scram-sha-256" >> "$PG_HBA"
    fi
    
    # Перезапуск для применения изменений
    print_step "Перезапуск PostgreSQL для применения настроек..."
    systemctl restart "$SERVICE_NAME"
    sleep 2
    
    print_info "✓ Удалённый доступ настроен"
fi

# Создание базы данных и пользователя
if [ -n "$DB_USER" ] || [ -n "$DB_NAME" ]; then
    print_step "Создание базы данных и пользователя..."
    
    if [ "$POSTGRES_VARIANT" = "1c" ]; then
        # Для PostgresPro используем полный путь к psql
        SU_CMD="su - postgres -c \"${PSQL}\""
    else
        SU_CMD="su - postgres -c \"psql\""
    fi
    
    # Формируем SQL команды
    SQL_COMMANDS=""
    
    if [ -n "$DB_USER" ]; then
        SQL_COMMANDS+="CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';"
        print_info "Создаётся пользователь: $DB_USER"
    fi
    
    if [ -n "$DB_NAME" ]; then
        if [ -n "$DB_USER" ]; then
            SQL_COMMANDS+="CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
            SQL_COMMANDS+="GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
        else
            SQL_COMMANDS+="CREATE DATABASE ${DB_NAME};"
        fi
        print_info "Создаётся база данных: $DB_NAME"
    fi
    
    # Выполняем команды
    if [ "$POSTGRES_VARIANT" = "1c" ]; then
        su - postgres -c "${PSQL} -c \"${SQL_COMMANDS}\""
    else
        su - postgres -c "psql -c \"${SQL_COMMANDS}\""
    fi
    
    if [ $? -eq 0 ]; then
        print_info "✓ База данных и пользователь успешно созданы"
    else
        print_warn "Возможно, база данных или пользователь уже существуют"
    fi
fi

# Итоговая информация
echo ""
echo "=============================================="
print_info "✓ Установка PostgreSQL завершена успешно!"
echo "=============================================="
echo ""

if [ "$POSTGRES_VARIANT" = "1c" ]; then
    print_info "Установлен: PostgreSQL для 1С (Postgres Professional)"
    print_info "Версия: postgrespro-1c-${POSTGRES_1C_VERSION}"
    print_info "Путь к данным: ${PGDATA}"
    print_info "Путь к утилитам: ${PGBIN}"
    echo ""
    print_info "Управление сервисом:"
    print_info "  systemctl status ${SERVICE_NAME}"
    print_info "  systemctl restart ${SERVICE_NAME}"
    print_info "  systemctl stop ${SERVICE_NAME}"
    echo ""
    print_info "Подключение к PostgreSQL:"
    print_info "  ${PSQL} -U postgres"
else
    print_info "Установлен: PostgreSQL ${POSTGRES_VANILLA_VERSION}"
    print_info "Путь к данным: ${PGDATA}"
    echo ""
    print_info "Управление сервисом:"
    print_info "  systemctl status postgresql"
    print_info "  systemctl restart postgresql"
    print_info "  systemctl stop postgresql"
    echo ""
    print_info "Подключение к PostgreSQL:"
    print_info "  sudo -u postgres psql"
fi

if [ -n "$DB_NAME" ]; then
    echo ""
    print_info "Созданная база данных:"
    print_info "  Имя БД: $DB_NAME"
    if [ -n "$DB_USER" ]; then
        print_info "  Пользователь: $DB_USER"
        print_info "  Пароль: $DB_PASSWORD"
    fi
fi

if [ "$ALLOW_REMOTE" = true ]; then
    echo ""
    print_info "Удалённое подключение:"
    IP_ADDR=$(hostname -I | awk '{print $1}')
    print_info "  Host: $IP_ADDR"
    print_info "  Port: 5432"
    if [ -n "$DB_USER" ]; then
        print_info "  Строка подключения: postgresql://${DB_USER}:***@${IP_ADDR}:5432/${DB_NAME}"
    fi
fi

echo ""
print_warn "ВАЖНО: Для работы с 1С необходимо дополнительно настроить сервер 1С!"
echo ""

