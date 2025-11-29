#!/bin/bash

#############################################
# MotionEye Installation Script for LXC
# Установка MotionEye в LXC контейнерах
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
PORT=8765
DATA_DIR="/var/lib/motioneye"
CONF_DIR="/etc/motioneye"
TIMEZONE=""
NFS_MOUNT=""
NFS_MOUNT_POINT="/mnt/recordings"
CHECK_ONLY=false
SKIP_START=false

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

Опции:
  --port PORT               Порт веб-интерфейса (по умолчанию: 8765)
  --data-dir DIR            Каталог для данных (по умолчанию: /var/lib/motioneye)
  --timezone TZ             Часовой пояс (например: Europe/Moscow)
  --nfs-mount SERVER:PATH   NFS-шара для записей (например: 192.168.1.100:/recordings)
  --nfs-mount-point DIR     Точка монтирования NFS (по умолчанию: /mnt/recordings)
  --check                   Только проверка совместимости (без установки)
  --skip-start              Не запускать сервис после установки
  --help                    Показать эту справку

Примеры:
  # Базовая установка
  $0

  # С кастомным портом и часовым поясом
  $0 --port 8080 --timezone Europe/Moscow

  # С NFS-хранилищем для записей
  $0 --nfs-mount 192.168.1.100:/camera-recordings

  # Только проверка
  $0 --check

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        --nfs-mount)
            NFS_MOUNT="$2"
            shift 2
            ;;
        --nfs-mount-point)
            NFS_MOUNT_POINT="$2"
            shift 2
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --skip-start)
            SKIP_START=true
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

# Определение дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    CODENAME=$VERSION_CODENAME
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

print_info "Обнаружена ОС: $OS $VERSION ($CODENAME)"

# Проверка поддерживаемой ОС
case $OS in
    debian|ubuntu)
        print_info "ОС поддерживается"
        ;;
    *)
        print_error "Неподдерживаемая ОС: $OS"
        print_error "Поддерживаются: debian, ubuntu"
        exit 1
        ;;
esac

# Проверка совместимости LXC
check_lxc_compatibility() {
    print_info "Проверка совместимости с LXC..."
    
    local issues=0
    
    # Проверка, что мы в LXC контейнере
    if [ -f /proc/1/environ ] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        print_info "✓ Обнаружен LXC контейнер"
    elif [ -d /proc/1/ns ]; then
        print_info "✓ Пространства имён доступны"
    fi
    
    # Проверка /dev/video* для USB камер
    if ls /dev/video* &>/dev/null; then
        print_info "✓ Обнаружены видеоустройства: $(ls /dev/video* | tr '\n' ' ')"
    else
        print_warn "⚠ Видеоустройства не обнаружены"
        print_warn "  Для USB-камер требуется проброс устройств в LXC"
    fi
    
    # Проверка памяти
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_mem" -ge 2048 ]; then
        print_info "✓ Достаточно памяти: ${total_mem}MB"
    elif [ "$total_mem" -ge 1024 ]; then
        print_warn "⚠ Мало памяти: ${total_mem}MB (рекомендуется 2GB+)"
    else
        print_error "✗ Недостаточно памяти: ${total_mem}MB (минимум 1GB)"
        ((issues++))
    fi
    
    # Проверка CPU
    local cpu_count=$(nproc)
    if [ "$cpu_count" -ge 2 ]; then
        print_info "✓ CPU: ${cpu_count} ядер"
    else
        print_warn "⚠ Мало ядер CPU: ${cpu_count} (рекомендуется 2+)"
    fi
    
    if [ $issues -gt 0 ]; then
        return 1
    fi
    
    print_info "✓ Все проверки пройдены"
    return 0
}

# Запуск проверки
if ! check_lxc_compatibility; then
    if [ "$CHECK_ONLY" = true ]; then
        exit 1
    fi
    print_warn "Продолжаем установку несмотря на предупреждения..."
fi

if [ "$CHECK_ONLY" = true ]; then
    print_info "Режим проверки завершён"
    exit 0
fi

# Проверка, установлен ли уже MotionEye
if command -v motioneye &> /dev/null; then
    ME_VERSION=$(motioneye --version 2>/dev/null || echo "неизвестно")
    print_info "MotionEye уже установлен: $ME_VERSION"
    
    if systemctl is-active --quiet motioneye 2>/dev/null; then
        print_info "MotionEye работает"
        print_info "Веб-интерфейс: http://$(hostname -I | awk '{print $1}'):$PORT"
        exit 0
    else
        print_warn "MotionEye установлен, но не запущен"
    fi
fi

print_info "Начало установки MotionEye..."

# Установка часового пояса
if [ -n "$TIMEZONE" ]; then
    print_step "Установка часового пояса: $TIMEZONE"
    timedatectl set-timezone "$TIMEZONE" 2>/dev/null || \
        ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
fi

# Обновление системы и установка зависимостей
print_step "Установка зависимостей..."
apt-get update

apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    python3-venv \
    pipx \
    curl \
    motion \
    ffmpeg \
    v4l-utils \
    libcurl4-openssl-dev \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev

# Настройка pipx path
export PIPX_HOME=/opt/pipx
export PIPX_BIN_DIR=/usr/local/bin
pipx ensurepath

# Установка MotionEye через pipx
print_step "Установка MotionEye..."
pipx install --system-site-packages motioneye

# Создание директорий
print_step "Создание директорий..."
mkdir -p "$CONF_DIR"
mkdir -p "$DATA_DIR"
mkdir -p /var/log/motioneye

# Настройка NFS если указано
if [ -n "$NFS_MOUNT" ]; then
    print_step "Настройка NFS..."
    
    # Установка NFS клиента
    apt-get install -y nfs-common
    
    # Создание точки монтирования
    mkdir -p "$NFS_MOUNT_POINT"
    
    # Проверка доступности NFS
    NFS_SERVER=$(echo "$NFS_MOUNT" | cut -d: -f1)
    NFS_PATH=$(echo "$NFS_MOUNT" | cut -d: -f2)
    
    print_info "Проверка NFS: $NFS_SERVER:$NFS_PATH"
    
    if showmount -e "$NFS_SERVER" &>/dev/null; then
        print_info "✓ NFS сервер доступен"
        
        # Монтирование
        if mount -t nfs "$NFS_MOUNT" "$NFS_MOUNT_POINT"; then
            print_info "✓ NFS смонтирован в $NFS_MOUNT_POINT"
            
            # Добавление в fstab
            if ! grep -q "$NFS_MOUNT" /etc/fstab; then
                echo "$NFS_MOUNT $NFS_MOUNT_POINT nfs defaults,_netdev 0 0" >> /etc/fstab
                print_info "✓ Добавлено в /etc/fstab для автомонтирования"
            fi
        else
            print_warn "⚠ Не удалось смонтировать NFS"
            print_warn "  Проверьте права доступа на NFS сервере"
        fi
    else
        print_warn "⚠ NFS сервер недоступен: $NFS_SERVER"
        print_warn "  NFS будет настроен, но требует ручной проверки"
        
        # Всё равно добавляем в fstab
        if ! grep -q "$NFS_MOUNT" /etc/fstab; then
            echo "$NFS_MOUNT $NFS_MOUNT_POINT nfs defaults,_netdev 0 0" >> /etc/fstab
        fi
    fi
fi

# Создание конфигурационного файла
print_step "Создание конфигурации..."

# Определяем путь для медиафайлов
if [ -n "$NFS_MOUNT" ] && mountpoint -q "$NFS_MOUNT_POINT" 2>/dev/null; then
    MEDIA_DIR="$NFS_MOUNT_POINT"
else
    MEDIA_DIR="$DATA_DIR/media"
    mkdir -p "$MEDIA_DIR"
fi

cat > "$CONF_DIR/motioneye.conf" << EOF
# MotionEye Configuration
# Сгенерировано: $(date)

# Порт веб-интерфейса
port $PORT

# Директория данных
conf_path $CONF_DIR
run_path /var/run/motioneye
log_path /var/log/motioneye
media_path $MEDIA_DIR

# Motion daemon
motion_binary /usr/bin/motion

# Логирование
log_level info
EOF

print_info "Конфигурация сохранена: $CONF_DIR/motioneye.conf"

# Создание systemd сервиса
print_step "Создание systemd сервиса..."

cat > /etc/systemd/system/motioneye.service << EOF
[Unit]
Description=MotionEye - Video Surveillance System
Documentation=https://github.com/motioneye-project/motioneye
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/motioneye -c $CONF_DIR/motioneye.conf
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
User=root
Environment=PIPX_HOME=/opt/pipx
Environment=PIPX_BIN_DIR=/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd
systemctl daemon-reload

# Запуск сервиса
if [ "$SKIP_START" = false ]; then
    print_step "Запуск MotionEye..."
    systemctl enable motioneye
    systemctl start motioneye
    
    # Ожидание запуска
    sleep 3
    
    if systemctl is-active --quiet motioneye; then
        print_info "✓ MotionEye запущен"
    else
        print_error "MotionEye не запустился!"
        print_error "Проверьте логи: journalctl -u motioneye -n 50"
        exit 1
    fi
fi

# Получение IP адреса
IP_ADDR=$(hostname -I | awk '{print $1}')

# Вывод информации
echo ""
echo "=============================================="
print_info "MotionEye успешно установлен!"
echo "=============================================="
echo ""
print_info "Веб-интерфейс:"
echo "  URL:      http://${IP_ADDR}:${PORT}"
echo "  Логин:    admin"
echo "  Пароль:   (пустой - установите при первом входе!)"
echo ""
print_info "Пути:"
echo "  Конфигурация:   $CONF_DIR/motioneye.conf"
echo "  Данные камер:   $CONF_DIR"
echo "  Медиафайлы:     $MEDIA_DIR"
echo "  Логи:           /var/log/motioneye/"
echo ""

if [ -n "$NFS_MOUNT" ]; then
    print_info "NFS хранилище:"
    echo "  Сервер:         $NFS_MOUNT"
    echo "  Точка монтирования: $NFS_MOUNT_POINT"
    if mountpoint -q "$NFS_MOUNT_POINT" 2>/dev/null; then
        echo "  Статус:         смонтировано"
    else
        echo "  Статус:         требует проверки"
    fi
    echo ""
fi

print_info "Управление сервисом:"
echo "  systemctl status motioneye    # статус"
echo "  systemctl restart motioneye   # перезапуск"
echo "  journalctl -u motioneye -f    # логи в реальном времени"
echo ""
print_info "Обновление:"
echo "  pipx upgrade motioneye"
echo ""

if ! ls /dev/video* &>/dev/null; then
    print_warn "Локальные камеры (USB) не обнаружены."
    print_warn "Для проброса USB в LXC добавьте в конфиг контейнера:"
    echo "  lxc.cgroup2.devices.allow: c 81:* rwm"
    echo "  lxc.mount.entry: /dev/video0 dev/video0 none bind,optional,create=file"
    echo ""
fi

print_info "✓ Готово!"

