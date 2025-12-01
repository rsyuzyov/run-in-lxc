#!/bin/bash

#############################################
# LXC Container Bootstrap Script
# Базовая настройка контейнера
#############################################

set -e

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

show_help() {
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -tz, --timezone ZONE   Часовой пояс (по умолчанию: Europe/Moscow)"
    echo "  -h, --help             Показать справку"
    echo ""
    echo "Примеры:"
    echo "  $0                          # GMT+3 (Europe/Moscow)"
    echo "  $0 --timezone Europe/Kiev   # GMT+2"
    echo "  $0 -tz UTC                  # UTC"
}

# Параметры по умолчанию
TIMEZONE="Europe/Moscow"

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        -tz|--timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Неизвестный параметр: $1"
            show_help
            exit 1
            ;;
    esac
done

# Проверка существования часового пояса
if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    print_warn "Часовой пояс '$TIMEZONE' не найден, будет проверен после установки tzdata"
fi

# Настройка неинтерактивного режима
export DEBIAN_FRONTEND=noninteractive

print_info "=== Начало базовой настройки контейнера ==="

# 1. Настройка локалей
print_info "Настройка локалей (RU + EN)..."
apt-get update -qq
apt-get install -y -qq locales

# Раскомментируем локали
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
sed -i '/ru_RU.UTF-8/s/^# //g' /etc/locale.gen

# Генерируем
locale-gen

# Устанавливаем русскую локаль по умолчанию
print_info "Установка локали ru_RU.UTF-8 по умолчанию..."
update-locale LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8
export LANG=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8

# 2. Настройка часового пояса
print_info "Настройка часового пояса ($TIMEZONE)..."
if [ -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
    ln -fs "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    dpkg-reconfigure -f noninteractive tzdata
else
    print_warn "Часовой пояс '$TIMEZONE' не найден! Пропускаем настройку."
fi

# 3. Обновление системы
print_info "Обновление системы..."
apt-get update -qq
apt-get dist-upgrade -y -qq

# 4. Установка утилит
print_info "Установка базовых утилит (mc, atop, htop, curl, wget, git)..."
apt-get install -y -qq mc atop htop curl wget git openssh-server

# 5. Настройка SSH
print_info "Настройка SSH (разрешение входа root)..."
if [ -f /etc/ssh/sshd_config ]; then
    # Разрешаем вход root с паролем
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    
    # Включаем аутентификацию по паролю (на всякий случай)
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    
    # Перезапуск SSH
    if systemctl is-active --quiet ssh; then
        systemctl restart ssh
    fi
else
    print_warn "Конфиг SSH не найден!"
fi

# Очистка
print_info "Очистка кэша apt..."
apt-get autoremove -y -qq
apt-get clean

print_info "=== Базовая настройка завершена! ==="
print_info "Локаль: ru_RU.UTF-8"
print_info "Timezone: $TIMEZONE"
print_info "SSH: Root login enabled"
