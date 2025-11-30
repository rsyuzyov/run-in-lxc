#!/bin/bash

#############################################
# Docker Installation Script for LXC
# Установка Docker CE в LXC контейнерах
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Значения по умолчанию
MIRROR=""
INSECURE_REGISTRIES=""
CHECK_ONLY=false
SKIP_TEST=false

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
  --mirror URL                Зеркало Docker Hub (например: mirror.gcr.io)
  --insecure-registries LIST  Insecure registries через запятую
  --check                     Только проверка совместимости (без установки)
  --skip-test                 Пропустить тест hello-world после установки
  --help                      Показать эту справку

Примеры:
  # Базовая установка
  $0

  # С зеркалом Docker Hub
  $0 --mirror https://mirror.gcr.io

  # С приватным registry без SSL
  $0 --insecure-registries registry.local:5000,192.168.1.100:5000

  # Только проверка совместимости LXC
  $0 --check

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --mirror)
            MIRROR="$2"
            shift 2
            ;;
        --insecure-registries)
            INSECURE_REGISTRIES="$2"
            shift 2
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --skip-test)
            SKIP_TEST=true
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
    
    # Проверка cgroups
    if [ -d /sys/fs/cgroup ]; then
        print_info "✓ cgroups доступны"
        
        # cgroups v2 или v1
        if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
            print_info "  Используется cgroups v2"
        else
            print_info "  Используется cgroups v1"
        fi
    else
        print_warn "⚠ cgroups не найдены"
        ((issues++))
    fi
    
    # Проверка возможности монтирования overlay
    if grep -q overlay /proc/filesystems 2>/dev/null; then
        print_info "✓ Overlay filesystem поддерживается"
    else
        print_warn "⚠ Overlay filesystem не обнаружен"
        print_warn "  Docker может использовать vfs storage driver (медленнее)"
    fi
    
    # Проверка AppArmor
    if [ -d /sys/kernel/security/apparmor ]; then
        print_info "✓ AppArmor доступен"
    fi
    
    # Проверка возможности создания сетевых интерфейсов
    if ip link add dummy0 type dummy 2>/dev/null; then
        ip link delete dummy0 2>/dev/null
        print_info "✓ Создание сетевых интерфейсов разрешено"
    else
        print_warn "⚠ Ограничены права на создание сетевых интерфейсов"
        ((issues++))
    fi
    
    # Проверка nesting
    if [ -f /proc/self/status ]; then
        if grep -q "CapBnd.*0000003fffffffff" /proc/self/status 2>/dev/null; then
            print_info "✓ Полные capabilities (nesting включён)"
        fi
    fi
    
    if [ $issues -gt 0 ]; then
        print_warn ""
        print_warn "Обнаружены потенциальные проблемы совместимости."
        print_warn "Убедитесь, что контейнер создан с опциями:"
        print_warn "  --features nesting=1,keyctl=1"
        print_warn ""
        print_warn "В Proxmox: Опции → Возможности → nesting, keyctl"
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

# Проверка, установлен ли уже Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | head -n1)
    print_info "Docker уже установлен: $DOCKER_VERSION"
    
    if docker info &>/dev/null; then
        print_info "Docker работает корректно"
        exit 0
    else
        print_warn "Docker установлен, но не работает. Попробуем переустановить..."
    fi
fi

print_info "Начало установки Docker..."

# Удаление старых версий
print_info "Удаление старых версий Docker..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Установка зависимостей
print_info "Установка зависимостей..."
apt-get update
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Добавление GPG ключа Docker
print_info "Добавление GPG ключа Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$OS/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Добавление репозитория
print_info "Добавление репозитория Docker..."
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
    $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Установка Docker
print_info "Установка Docker CE..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Создание конфигурации daemon.json если нужно
if [ -n "$MIRROR" ] || [ -n "$INSECURE_REGISTRIES" ]; then
    print_info "Настройка /etc/docker/daemon.json..."
    
    mkdir -p /etc/docker
    
    # Начинаем JSON
    echo "{" > /etc/docker/daemon.json
    
    local need_comma=false
    
    # Добавляем зеркало
    if [ -n "$MIRROR" ]; then
        echo "  \"registry-mirrors\": [\"$MIRROR\"]" >> /etc/docker/daemon.json
        need_comma=true
    fi
    
    # Добавляем insecure registries
    if [ -n "$INSECURE_REGISTRIES" ]; then
        if [ "$need_comma" = true ]; then
            # Заменяем последнюю строку, добавляя запятую
            sed -i '$ s/$/,/' /etc/docker/daemon.json
        fi
        
        # Преобразуем список в JSON массив
        IFS=',' read -ra REGISTRIES <<< "$INSECURE_REGISTRIES"
        echo -n "  \"insecure-registries\": [" >> /etc/docker/daemon.json
        first=true
        for reg in "${REGISTRIES[@]}"; do
            if [ "$first" = true ]; then
                echo -n "\"$reg\"" >> /etc/docker/daemon.json
                first=false
            else
                echo -n ", \"$reg\"" >> /etc/docker/daemon.json
            fi
        done
        echo "]" >> /etc/docker/daemon.json
    fi
    
    echo "}" >> /etc/docker/daemon.json
    
    print_info "Конфигурация сохранена:"
    cat /etc/docker/daemon.json
fi

# Запуск Docker
print_info "Запуск Docker..."
systemctl enable docker
systemctl start docker

# Проверка статуса
sleep 2
if ! systemctl is-active --quiet docker; then
    print_error "Docker не запустился!"
    print_error "Проверьте логи: journalctl -u docker -n 50"
    exit 1
fi

print_info "✓ Docker запущен"

# Тест Docker
if [ "$SKIP_TEST" = false ]; then
    print_info "Тестирование Docker..."
    
    if docker run --rm hello-world &>/dev/null; then
        print_info "✓ Docker работает корректно"
    else
        print_warn "Тест hello-world не прошёл"
        print_warn "Возможные причины:"
        print_warn "  - Нет доступа к Docker Hub"
        print_warn "  - Требуется настройка прокси"
        print_warn "  - Неправильные права в LXC"
        print_warn ""
        print_warn "Проверьте: docker run --rm hello-world"
    fi
fi

# Установка lazydocker
print_info "Установка lazydocker..."
if curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash; then
    # Добавляем ~/.local/bin в PATH если его там нет
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Добавляем в /etc/profile.d для всех пользователей
    if [ ! -f /etc/profile.d/lazydocker.sh ]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' > /etc/profile.d/lazydocker.sh
        chmod +x /etc/profile.d/lazydocker.sh
    fi
    
    if command -v lazydocker &>/dev/null; then
        LAZYDOCKER_VERSION=$(lazydocker --version 2>/dev/null | head -n1 || echo "установлен")
        print_info "✓ lazydocker установлен: $LAZYDOCKER_VERSION"
    else
        print_info "✓ lazydocker установлен в ~/.local/bin"
        print_warn "  Перезайдите в систему или выполните: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
else
    print_warn "Не удалось установить lazydocker"
    print_warn "Можно установить вручную: https://github.com/jesseduffield/lazydocker#installation"
fi

# Версии
DOCKER_VERSION=$(docker --version)
COMPOSE_VERSION=$(docker compose version 2>/dev/null || echo "не установлен")

# Вывод информации
echo ""
echo "=============================================="
print_info "Docker успешно установлен!"
echo "=============================================="
echo ""
print_info "Версии:"
echo "  Docker:         $DOCKER_VERSION"
echo "  Docker Compose: $COMPOSE_VERSION"
if [ -n "$LAZYDOCKER_VERSION" ]; then
echo "  lazydocker:     $LAZYDOCKER_VERSION"
fi
echo ""

if [ -n "$MIRROR" ]; then
    print_info "Зеркало Docker Hub: $MIRROR"
fi

if [ -n "$INSECURE_REGISTRIES" ]; then
    print_info "Insecure registries: $INSECURE_REGISTRIES"
fi

echo ""
print_info "Основные команды:"
echo "  docker run hello-world              # тест"
echo "  docker ps                           # список контейнеров"
echo "  docker images                       # список образов"
echo "  docker compose up -d                # запуск из docker-compose.yml"
echo "  systemctl status docker             # статус службы"
echo "  lazydocker                          # TUI для управления Docker"
echo ""
print_info "Конфигурация: /etc/docker/daemon.json"
echo ""
print_info "✓ Готово!"

