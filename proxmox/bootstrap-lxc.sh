#!/bin/bash

#############################################
# Proxmox LXC Bootstrap Wrapper
# Запуск базовой настройки в контейнере
#############################################

set -e

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ -z "$1" ]; then
    echo "Использование: $0 <CT_ID>"
    exit 1
fi

CT_ID=$1
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT=$(dirname "$SCRIPT_DIR")
SETUP_SCRIPT="$PROJECT_ROOT/bootstrap/setup.sh"

# Проверка существования контейнера
if ! pct status $CT_ID &>/dev/null; then
    print_error "Контейнер $CT_ID не найден!"
    exit 1
fi

# Проверка статуса (должен быть запущен)
STATUS=$(pct status $CT_ID)
if [[ "$STATUS" != *"running"* ]]; then
    print_error "Контейнер $CT_ID не запущен! Запустите его перед настройкой."
    exit 1
fi

# Проверка наличия скрипта настройки
if [ ! -f "$SETUP_SCRIPT" ]; then
    print_error "Скрипт настройки не найден: $SETUP_SCRIPT"
    exit 1
fi

print_info "Настройка контейнера $CT_ID..."

# Копирование скрипта
print_info "Копирование скрипта настройки..."
pct push $CT_ID "$SETUP_SCRIPT" /tmp/setup.sh
pct exec $CT_ID -- chmod +x /tmp/setup.sh

# Запуск скрипта
print_info "Запуск настройки внутри контейнера (это может занять время)..."
pct exec $CT_ID -- /tmp/setup.sh

# Удаление скрипта
pct exec $CT_ID -- rm /tmp/setup.sh

print_info "✓ Настройка контейнера $CT_ID завершена!"
