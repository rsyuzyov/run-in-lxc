#!/bin/bash

#############################################
# 1C:Enterprise Server Installation Script for LXC
# Установка сервера 1С:Предприятие 8 в LXC контейнер
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
VERSION=""
ITS_LOGIN=""
ITS_PASSWORD=""
DISTRIB_DIR=""
INSTALL_CRS=false
INSTALL_WS=false
CLUSTER_PORT=1541
RAS_PORT=1545
RAGENT_PORT=1540
CREATE_CLUSTER=true
ARCH="amd64"

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

Установка сервера 1С:Предприятие 8 в LXC контейнер.
Поддерживает скачивание с releases.1c.ru или установку из локального каталога.

ОБЯЗАТЕЛЬНЫЕ ОПЦИИ (одна из групп):

  Вариант 1 - Скачивание с ИТС:
    --version VERSION       Версия платформы (например: 8.3.25.1257)
    --its-login LOGIN       Логин пользователя ИТС
    --its-password PASS     Пароль пользователя ИТС

  Вариант 2 - Локальные дистрибутивы:
    --distrib-dir PATH      Каталог с .deb пакетами 1С

ДОПОЛНИТЕЛЬНЫЕ ОПЦИИ:

  --with-crs               Установить сервер хранилища конфигураций
  --with-ws                Установить веб-расширения (для публикации на веб-сервере)
  --cluster-port PORT      Порт менеджера кластера (по умолчанию: 1541)
  --ras-port PORT          Порт сервера администрирования (по умолчанию: 1545)
  --ragent-port PORT       Порт агента сервера (по умолчанию: 1540)
  --no-cluster             Не создавать кластер автоматически
  --help                   Показать эту справку

ПРИМЕРЫ:

  # Установка с releases.1c.ru
  $0 --version 8.3.25.1257 --its-login user@example.com --its-password MyPass123

  # Установка из локального каталога
  $0 --distrib-dir /opt/distrib/1c

  # Полная установка с дополнительными компонентами
  $0 --version 8.3.25.1257 --its-login user@example.com --its-password MyPass \\
     --with-crs --with-ws

  # Установка без автоматического создания кластера
  $0 --distrib-dir /opt/distrib/1c --no-cluster

СТРУКТУРА КАТАЛОГА ДИСТРИБУТИВОВ:

  При использовании --distrib-dir каталог должен содержать .deb пакеты:
    1c-enterprise*-common*.deb      (обязательно)
    1c-enterprise*-server*.deb      (обязательно)
    1c-enterprise*-crs*.deb         (для --with-crs)
    1c-enterprise*-ws*.deb          (для --with-ws)

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
        --its-login)
            ITS_LOGIN="$2"
            shift 2
            ;;
        --its-password)
            ITS_PASSWORD="$2"
            shift 2
            ;;
        --distrib-dir)
            DISTRIB_DIR="$2"
            shift 2
            ;;
        --with-crs)
            INSTALL_CRS=true
            shift
            ;;
        --with-ws)
            INSTALL_WS=true
            shift
            ;;
        --cluster-port)
            CLUSTER_PORT="$2"
            shift 2
            ;;
        --ras-port)
            RAS_PORT="$2"
            shift 2
            ;;
        --ragent-port)
            RAGENT_PORT="$2"
            shift 2
            ;;
        --no-cluster)
            CREATE_CLUSTER=false
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
if [ -n "$DISTRIB_DIR" ]; then
    # Режим локальных дистрибутивов
    if [ ! -d "$DISTRIB_DIR" ]; then
        print_error "Каталог дистрибутивов не найден: $DISTRIB_DIR"
        exit 1
    fi
    SOURCE_MODE="local"
elif [ -n "$VERSION" ] && [ -n "$ITS_LOGIN" ] && [ -n "$ITS_PASSWORD" ]; then
    # Режим скачивания с ИТС
    SOURCE_MODE="its"
else
    print_error "Необходимо указать либо --distrib-dir, либо --version с --its-login и --its-password"
    echo ""
    show_help
fi

# Определение архитектуры
MACHINE_ARCH=$(uname -m)
case $MACHINE_ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        print_error "Неподдерживаемая архитектура: $MACHINE_ARCH"
        exit 1
        ;;
esac

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка сервера 1С:Предприятие 8"
echo "=============================================="
if [ "$SOURCE_MODE" = "its" ]; then
    print_info "Источник: releases.1c.ru"
    print_info "Версия: $VERSION"
    print_info "Пользователь ИТС: $ITS_LOGIN"
else
    print_info "Источник: локальный каталог"
    print_info "Каталог: $DISTRIB_DIR"
fi
print_info "Архитектура: $ARCH"
print_info "Сервер хранилища (CRS): $([ "$INSTALL_CRS" = true ] && echo "да" || echo "нет")"
print_info "Веб-расширения (WS): $([ "$INSTALL_WS" = true ] && echo "да" || echo "нет")"
print_info "Порт менеджера кластера: $CLUSTER_PORT"
print_info "Порт агента сервера: $RAGENT_PORT"
print_info "Порт сервера администрирования: $RAS_PORT"
print_info "Создать кластер: $([ "$CREATE_CLUSTER" = true ] && echo "да" || echo "нет")"
echo "=============================================="
echo ""

# Функция для скачивания с releases.1c.ru
download_from_its() {
    local version="$1"
    local login="$2"
    local password="$3"
    local dest_dir="$4"
    
    print_step "Скачивание дистрибутивов с releases.1c.ru..."
    
    # Создаём временную директорию
    mkdir -p "$dest_dir"
    
    # Парсим версию
    # Формат версии: 8.3.25.1257
    local major_minor=$(echo "$version" | cut -d. -f1-2)  # 8.3
    local release=$(echo "$version" | cut -d. -f3)        # 25
    local build=$(echo "$version" | cut -d. -f4)          # 1257
    
    # URL для скачивания
    local base_url="https://releases.1c.ru/version_file"
    
    # Получаем cookie для авторизации
    print_info "Авторизация на releases.1c.ru..."
    
    local cookie_file=$(mktemp)
    local auth_response=$(curl -s -c "$cookie_file" -b "$cookie_file" \
        -d "login=$login&password=$password" \
        -L "https://releases.1c.ru/login" 2>/dev/null)
    
    if echo "$auth_response" | grep -q "Неверный логин или пароль"; then
        print_error "Ошибка авторизации на releases.1c.ru"
        print_error "Проверьте логин и пароль ИТС"
        rm -f "$cookie_file"
        exit 1
    fi
    
    print_info "Авторизация успешна"
    
    # Формируем имена файлов для скачивания
    # Пример: deb64_8_3_25_1257.tar.gz
    local archive_name="deb64_${major_minor//./_}_${release}_${build}.tar.gz"
    local download_url="${base_url}?nick=Platform83&ver=${version}&path=Platform%5C${major_minor//./_}_${release}_${build}%5C${archive_name}"
    
    print_info "Скачивание: $archive_name"
    
    # Скачиваем архив
    local archive_path="$dest_dir/$archive_name"
    if ! curl -s -L -b "$cookie_file" -o "$archive_path" "$download_url"; then
        print_error "Ошибка скачивания архива"
        rm -f "$cookie_file"
        exit 1
    fi
    
    # Проверяем, что скачался tar.gz, а не HTML с ошибкой
    if file "$archive_path" | grep -q "HTML"; then
        print_error "Не удалось скачать архив. Возможно, версия не найдена."
        print_error "Проверьте правильность указанной версии: $version"
        cat "$archive_path"
        rm -f "$cookie_file" "$archive_path"
        exit 1
    fi
    
    print_info "Распаковка архива..."
    tar -xzf "$archive_path" -C "$dest_dir"
    rm -f "$archive_path"
    
    rm -f "$cookie_file"
    
    print_info "Дистрибутивы успешно скачаны в $dest_dir"
}

# Функция поиска пакетов в каталоге
find_packages() {
    local dir="$1"
    local pattern="$2"
    
    find "$dir" -maxdepth 2 -name "$pattern" -type f 2>/dev/null | head -1
}

# Создание рабочего каталога
WORK_DIR=$(mktemp -d)
trap "rm -rf $WORK_DIR" EXIT

# Получение дистрибутивов
if [ "$SOURCE_MODE" = "its" ]; then
    download_from_its "$VERSION" "$ITS_LOGIN" "$ITS_PASSWORD" "$WORK_DIR"
    PKG_DIR="$WORK_DIR"
else
    PKG_DIR="$DISTRIB_DIR"
fi

# Поиск необходимых пакетов
print_step "Поиск пакетов для установки..."

PKG_COMMON=$(find_packages "$PKG_DIR" "*common*${ARCH}.deb")
PKG_SERVER=$(find_packages "$PKG_DIR" "*server*${ARCH}.deb")

if [ -z "$PKG_COMMON" ]; then
    print_error "Не найден пакет common (*common*${ARCH}.deb)"
    print_error "Содержимое каталога $PKG_DIR:"
    ls -la "$PKG_DIR"
    exit 1
fi

if [ -z "$PKG_SERVER" ]; then
    print_error "Не найден пакет server (*server*${ARCH}.deb)"
    exit 1
fi

print_info "Найден пакет common: $(basename "$PKG_COMMON")"
print_info "Найден пакет server: $(basename "$PKG_SERVER")"

# Опциональные пакеты
PACKAGES_TO_INSTALL=("$PKG_COMMON" "$PKG_SERVER")

if [ "$INSTALL_CRS" = true ]; then
    PKG_CRS=$(find_packages "$PKG_DIR" "*crs*${ARCH}.deb")
    if [ -z "$PKG_CRS" ]; then
        print_error "Не найден пакет CRS (*crs*${ARCH}.deb)"
        exit 1
    fi
    print_info "Найден пакет CRS: $(basename "$PKG_CRS")"
    PACKAGES_TO_INSTALL+=("$PKG_CRS")
fi

if [ "$INSTALL_WS" = true ]; then
    PKG_WS=$(find_packages "$PKG_DIR" "*ws*${ARCH}.deb")
    if [ -z "$PKG_WS" ]; then
        print_error "Не найден пакет WS (*ws*${ARCH}.deb)"
        exit 1
    fi
    print_info "Найден пакет WS: $(basename "$PKG_WS")"
    PACKAGES_TO_INSTALL+=("$PKG_WS")
fi

# Установка зависимостей
print_step "Установка системных зависимостей..."
apt-get update
apt-get install -y \
    fontconfig \
    libfreetype6 \
    libgsf-1-114 \
    libglib2.0-0 \
    libodbc1 \
    libmagickwand-6.q16-6 \
    libkrb5-3 \
    unixodbc \
    locales \
    imagemagick \
    ttf-mscorefonts-installer || true

# Настройка локали
print_step "Настройка локали..."
if ! locale -a | grep -q "ru_RU.utf8"; then
    sed -i '/ru_RU.UTF-8/s/^# //g' /etc/locale.gen
    locale-gen
fi

# Установка пакетов 1С
print_step "Установка пакетов 1С:Предприятие..."
for pkg in "${PACKAGES_TO_INSTALL[@]}"; do
    print_info "Установка: $(basename "$pkg")"
    dpkg -i "$pkg" || true
done

# Исправление зависимостей
print_info "Исправление зависимостей..."
apt-get install -f -y

# Определение установленной версии
INSTALLED_VERSION=$(ls /opt/1cv8/x86_64/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
if [ -z "$INSTALLED_VERSION" ]; then
    # Попробуем arm64
    INSTALLED_VERSION=$(ls /opt/1cv8/aarch64/ 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
fi

if [ -z "$INSTALLED_VERSION" ]; then
    print_error "Не удалось определить установленную версию 1С"
    exit 1
fi

print_info "Установлена версия: $INSTALLED_VERSION"

# Определение пути к бинарникам
if [ -d "/opt/1cv8/x86_64/$INSTALLED_VERSION" ]; then
    BIN_PATH="/opt/1cv8/x86_64/$INSTALLED_VERSION"
else
    BIN_PATH="/opt/1cv8/aarch64/$INSTALLED_VERSION"
fi

# Настройка сервера
print_step "Настройка сервера 1С..."

# Создание/проверка пользователя usr1cv8
if ! id "usr1cv8" &>/dev/null; then
    print_info "Создание пользователя usr1cv8..."
    useradd --system --shell /bin/bash --home-dir /home/usr1cv8 --create-home usr1cv8
fi

# Создание необходимых каталогов
mkdir -p /home/usr1cv8/.1cv8/1C/1cv8
mkdir -p /var/log/1C
mkdir -p /var/1C/licenses

chown -R usr1cv8:usr1cv8 /home/usr1cv8
chown -R usr1cv8:usr1cv8 /var/log/1C
chown -R usr1cv8:usr1cv8 /var/1C

# Создание конфигурационного файла для сервера
print_info "Создание конфигурации сервера..."

# Конфигурация srv1cv8
cat > /etc/default/srv1cv8 << EOF
# Конфигурация сервера 1С:Предприятие
# Сгенерировано автоматически скриптом install.sh

# Диапазон портов рабочих процессов
SRV1CV8_PORT=$RAGENT_PORT

# Диапазон портов для менеджера кластера
SRV1CV8_REGPORT=$CLUSTER_PORT

# Диапазон портов
SRV1CV8_RANGE=1560:1591

# Отладка (0 - выключена, 1 - включена)
SRV1CV8_DEBUG=0

# Пользователь для запуска сервера
SRV1CV8_USER=usr1cv8

# Каталог данных кластера
SRV1CV8_DATA=/home/usr1cv8/.1cv8/1C/1cv8

# Безопасный режим (0 - выключен)
SRV1CV8_SAFEMODE=0

# Включить сервер администрирования (RAS)
SRV1CV8_RAS=1

# Порт сервера администрирования
SRV1CV8_RAS_PORT=$RAS_PORT

# Максимальный размер виртуальной памяти рабочего процесса (байты)
# 0 - не ограничивать
SRV1CV8_VM=0

# Максимальный объем данных CALL (байты)
# 0 - не ограничивать
SRV1CV8_CALL=0

# Максимальное время ожидания блокировки (секунды)
# 0 - не ограничивать  
SRV1CV8_LOCK=0
EOF

# Настройка systemd сервиса
print_step "Настройка systemd сервиса..."

# Создание systemd unit файла
cat > /etc/systemd/system/srv1cv8.service << EOF
[Unit]
Description=1C:Enterprise Server 8
After=network.target

[Service]
Type=forking
EnvironmentFile=/etc/default/srv1cv8
User=\${SRV1CV8_USER}
Group=\${SRV1CV8_USER}
ExecStart=${BIN_PATH}/ragent -daemon -port \${SRV1CV8_PORT} -regport \${SRV1CV8_REGPORT} -range \${SRV1CV8_RANGE} -d \${SRV1CV8_DATA}
ExecStop=/bin/kill -SIGTERM \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
LimitCORE=infinity
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

# Создание systemd unit для RAS
cat > /etc/systemd/system/ras.service << EOF
[Unit]
Description=1C:Enterprise RAS (Remote Administration Server)
After=srv1cv8.service
Requires=srv1cv8.service

[Service]
Type=simple
EnvironmentFile=/etc/default/srv1cv8
User=\${SRV1CV8_USER}
Group=\${SRV1CV8_USER}
ExecStart=${BIN_PATH}/ras --port \${SRV1CV8_RAS_PORT} cluster
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Если установлен CRS
if [ "$INSTALL_CRS" = true ]; then
    cat > /etc/systemd/system/crs1cv8.service << EOF
[Unit]
Description=1C:Enterprise Configuration Repository Server
After=network.target

[Service]
Type=forking
User=usr1cv8
Group=usr1cv8
ExecStart=${BIN_PATH}/crserver -daemon
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
fi

# Перезагрузка systemd
systemctl daemon-reload

# Запуск сервисов
print_step "Запуск сервисов..."

systemctl enable srv1cv8
systemctl start srv1cv8

print_info "Ожидание запуска сервера..."
sleep 5

if systemctl is-active --quiet srv1cv8; then
    print_info "✓ Сервер 1С успешно запущен"
else
    print_error "Не удалось запустить сервер 1С!"
    print_error "Проверьте логи: journalctl -u srv1cv8 -n 50"
    exit 1
fi

# Запуск RAS
systemctl enable ras
systemctl start ras

sleep 2

if systemctl is-active --quiet ras; then
    print_info "✓ Сервер администрирования (RAS) запущен"
else
    print_warn "Не удалось запустить RAS. Проверьте логи: journalctl -u ras -n 50"
fi

# Запуск CRS если установлен
if [ "$INSTALL_CRS" = true ]; then
    systemctl enable crs1cv8
    systemctl start crs1cv8
    
    sleep 2
    
    if systemctl is-active --quiet crs1cv8; then
        print_info "✓ Сервер хранилища конфигураций (CRS) запущен"
    else
        print_warn "Не удалось запустить CRS. Проверьте логи: journalctl -u crs1cv8 -n 50"
    fi
fi

# Создание кластера
if [ "$CREATE_CLUSTER" = true ]; then
    print_step "Создание кластера серверов..."
    
    # Ожидание полного запуска RAS
    sleep 3
    
    # Получение списка кластеров
    RAC_PATH="${BIN_PATH}/rac"
    
    if [ -x "$RAC_PATH" ]; then
        # Проверяем, есть ли уже кластер
        EXISTING_CLUSTERS=$("$RAC_PATH" cluster list --ras=localhost:$RAS_PORT 2>/dev/null || echo "")
        
        if [ -z "$EXISTING_CLUSTERS" ]; then
            print_info "Создание нового кластера..."
            
            # Создание кластера
            CLUSTER_ID=$("$RAC_PATH" cluster insert \
                --ras=localhost:$RAS_PORT \
                --host=localhost \
                --port=$CLUSTER_PORT \
                --name="LocalCluster" 2>/dev/null | grep -oP 'cluster\s*:\s*\K[a-f0-9-]+' || echo "")
            
            if [ -n "$CLUSTER_ID" ]; then
                print_info "✓ Кластер создан: $CLUSTER_ID"
            else
                print_warn "Не удалось создать кластер автоматически"
                print_warn "Создайте кластер вручную через консоль администрирования"
            fi
        else
            print_info "Кластер уже существует"
        fi
    else
        print_warn "Утилита rac не найдена, кластер не создан"
    fi
fi

# Добавление путей в системный профиль
print_step "Настройка переменных окружения..."

cat > /etc/profile.d/1c-enterprise.sh << EOF
# 1C:Enterprise paths
export PATH="\$PATH:${BIN_PATH}"
EOF

chmod +x /etc/profile.d/1c-enterprise.sh

# Итоговая информация
echo ""
echo "=============================================="
print_info "✓ Установка сервера 1С:Предприятие завершена!"
echo "=============================================="
echo ""
print_info "Версия платформы: $INSTALLED_VERSION"
print_info "Путь к платформе: $BIN_PATH"
echo ""
print_info "Сетевые порты:"
print_info "  Агент сервера (ragent):         $RAGENT_PORT"
print_info "  Менеджер кластера:              $CLUSTER_PORT"
print_info "  Сервер администрирования (RAS): $RAS_PORT"
print_info "  Рабочие процессы:               1560-1591"
echo ""
print_info "Управление сервером:"
print_info "  systemctl status srv1cv8   - статус сервера"
print_info "  systemctl restart srv1cv8  - перезапуск"
print_info "  systemctl stop srv1cv8     - остановка"
print_info "  journalctl -u srv1cv8 -f   - логи"
echo ""
print_info "Управление RAS:"
print_info "  systemctl status ras       - статус"
print_info "  systemctl restart ras      - перезапуск"
echo ""
print_info "Утилиты администрирования:"
print_info "  rac cluster list                    - список кластеров"
print_info "  rac infobase summary list           - список баз данных"
print_info "  rac session list --cluster=<ID>     - список сеансов"
echo ""
print_info "Конфигурация: /etc/default/srv1cv8"
print_info "Данные кластера: /home/usr1cv8/.1cv8/"
print_info "Логи: /var/log/1C/"
echo ""

if [ "$INSTALL_CRS" = true ]; then
    print_info "Сервер хранилища конфигураций:"
    print_info "  systemctl status crs1cv8   - статус"
    print_info "  Порт по умолчанию: 1542"
    echo ""
fi

if [ "$INSTALL_WS" = true ]; then
    print_info "Веб-расширения установлены."
    print_info "Для публикации баз данных используйте webinst:"
    print_info "  ${BIN_PATH}/webinst -help"
    echo ""
fi

print_warn "ВАЖНО:"
print_warn "  1. Для работы с базами PostgreSQL установите PostgreSQL для 1С"
print_warn "     (используйте ../postgres/install.sh)"
print_warn "  2. Откройте порты в firewall: $RAGENT_PORT, $CLUSTER_PORT, $RAS_PORT, 1560-1591"
print_warn "  3. Для подключения используйте: <IP>:$CLUSTER_PORT"
echo ""

