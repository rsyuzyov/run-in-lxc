#!/bin/bash

#############################################
# Proxmox LXC Container Creation Script
# Автоматическое создание LXC контейнеров
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
CT_NAME=""
CT_ID=""
CT_CORES="1"
CT_MEMORY="2048"
CT_DISK="8"
CT_STORAGE=""
CT_TEMPLATE="debian-13-standard"
CT_IP=""
CT_GATEWAY=""
CT_NAMESERVER=""
CT_IPV6="auto"
CT_BRIDGE="vmbr0"
CT_PASSWORD=""
CT_SSH_KEY=""
CT_UNPRIVILEGED="1"
CT_FEATURES="nesting=1,keyctl=1"
CT_START="0"
DRY_RUN="0"

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

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Функция помощи
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Обязательные параметры:
  --name NAME             Имя контейнера

Опциональные параметры:
  --id ID                 ID контейнера (VMID), по умолчанию: автоматически
  --cores N               Количество CPU ядер (по умолчанию: 1)
  --memory MB             Память в MB (по умолчанию: 2048)
  --disk GB               Размер диска в GB (по умолчанию: 8)
  --storage NAME          Хранилище (по умолчанию: автоматически)
  --template NAME         Шаблон контейнера (по умолчанию: debian-13-standard)
  
Сетевые параметры:
  --ip IP/MASK            IP адрес с маской, например: 192.168.1.100/24
  --gateway IP            Шлюз по умолчанию
  --nameserver IP         DNS сервер
  --ipv6 IP/MASK          IPv6 адрес (по умолчанию: auto)
  --bridge NAME           Сетевой мост (по умолчанию: vmbr0)
  
Безопасность:
  --password PASS         Пароль root (по умолчанию: генерируется)
  --ssh-key PATH          Путь к публичному SSH ключу
  
Дополнительно:
  --unprivileged 0|1      Непривилегированный контейнер (по умолчанию: 1)
  --features FEATURES     Возможности (по умолчанию: nesting=1,keyctl=1)
  --start                 Запустить контейнер после создания
  --dry-run               Показать команды без выполнения
  --help                  Показать эту справку

Примеры:
  # Минимальная команда
  $0 --name my-container

  # С статическим IP
  $0 --name forgejo --ip 192.168.1.100/24 --gateway 192.168.1.1

  # Полная настройка
  $0 --name forgejo --cores 4 --memory 4096 --disk 20 \\
     --ip 192.168.1.100/24 --gateway 192.168.1.1 \\
     --ssh-key ~/.ssh/id_rsa.pub --start

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            CT_NAME="$2"
            shift 2
            ;;
        --id)
            CT_ID="$2"
            shift 2
            ;;
        --cores)
            CT_CORES="$2"
            shift 2
            ;;
        --memory)
            CT_MEMORY="$2"
            shift 2
            ;;
        --disk)
            CT_DISK="$2"
            shift 2
            ;;
        --storage)
            CT_STORAGE="$2"
            shift 2
            ;;
        --template)
            CT_TEMPLATE="$2"
            shift 2
            ;;
        --ip)
            CT_IP="$2"
            shift 2
            ;;
        --gateway)
            CT_GATEWAY="$2"
            shift 2
            ;;
        --nameserver)
            CT_NAMESERVER="$2"
            shift 2
            ;;
        --ipv6)
            CT_IPV6="$2"
            shift 2
            ;;
        --bridge)
            CT_BRIDGE="$2"
            shift 2
            ;;
        --password)
            CT_PASSWORD="$2"
            shift 2
            ;;
        --ssh-key)
            CT_SSH_KEY="$2"
            shift 2
            ;;
        --unprivileged)
            CT_UNPRIVILEGED="$2"
            shift 2
            ;;
        --features)
            CT_FEATURES="$2"
            shift 2
            ;;
        --start)
            CT_START="1"
            shift
            ;;
        --dry-run)
            DRY_RUN="1"
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

# Проверка обязательных параметров
if [ -z "$CT_NAME" ]; then
    print_error "Имя контейнера обязательно! Используйте --name"
    exit 1
fi

# Проверка прав root
if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" -eq 0 ]; then
    print_error "Этот скрипт должен быть запущен с правами root"
    exit 1
fi

print_info "=== Создание LXC контейнера в Proxmox ==="
echo ""

# Автоопределение ID если не указан
if [ -z "$CT_ID" ]; then
    print_info "Определение свободного ID..."
    
    # Получаем список всех ID (VM + CT)
    ALL_IDS=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | grep -oP '"vmid":\s*\K\d+' | sort -n || echo "")
    
    if [ -z "$ALL_IDS" ]; then
        CT_ID=100
        print_info "Кластер пуст, используем ID: $CT_ID"
    else
        # Находим максимальный ID и добавляем 1
        MAX_ID=$(echo "$ALL_IDS" | tail -1)
        if [ "$MAX_ID" -lt 100 ]; then
            CT_ID=100
        else
            CT_ID=$((MAX_ID + 1))
        fi
        print_info "Максимальный используемый ID: $MAX_ID, новый ID: $CT_ID"
    fi
else
    # Проверка существования указанного ID
    print_info "Проверка доступности ID $CT_ID..."
    if pvesh get /cluster/resources --type vm --output-format json 2>/dev/null | grep -q "\"vmid\":$CT_ID"; then
        print_error "ID $CT_ID уже используется!"
        exit 1
    fi
    print_info "ID $CT_ID свободен"
fi

# Автоопределение хранилища если не указано
if [ -z "$CT_STORAGE" ]; then
    print_info "Определение доступного хранилища..."
    CT_STORAGE=$(pvesm status -content rootdir | awk 'NR==2 {print $1}')
    
    if [ -z "$CT_STORAGE" ]; then
        print_error "Не найдено доступное хранилище для контейнеров!"
        exit 1
    fi
    print_info "Используется хранилище: $CT_STORAGE"
fi

# Генерация пароля если не указан
if [ -z "$CT_PASSWORD" ]; then
    CT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
    print_info "Сгенерирован пароль root"
fi

# Проверка и загрузка шаблона
print_info "Проверка наличия шаблона $CT_TEMPLATE..."

# Определяем полное имя шаблона
TEMPLATE_FULL="${CT_TEMPLATE}_*.tar.*"
TEMPLATE_PATH=$(pveam list $CT_STORAGE 2>/dev/null | grep -i "$CT_TEMPLATE" | awk '{print $1}' | head -1 || echo "")

if [ -z "$TEMPLATE_PATH" ]; then
    print_warn "Шаблон $CT_TEMPLATE не найден в хранилище $CT_STORAGE"
    print_info "Обновление списка доступных шаблонов..."
    
    if [ "$DRY_RUN" -eq 0 ]; then
        pveam update
    else
        print_debug "DRY-RUN: pveam update"
    fi
    
    # Поиск шаблона в доступных
    AVAILABLE_TEMPLATE=$(pveam available | grep -i "$CT_TEMPLATE" | awk '{print $2}' | head -1 || echo "")
    
    if [ -z "$AVAILABLE_TEMPLATE" ]; then
        print_error "Шаблон $CT_TEMPLATE не найден в репозитории!"
        print_info "Доступные шаблоны Debian:"
        pveam available | grep debian
        exit 1
    fi
    
    print_info "Загрузка шаблона $AVAILABLE_TEMPLATE..."
    if [ "$DRY_RUN" -eq 0 ]; then
        pveam download $CT_STORAGE $AVAILABLE_TEMPLATE
    else
        print_debug "DRY-RUN: pveam download $CT_STORAGE $AVAILABLE_TEMPLATE"
    fi
    
    TEMPLATE_PATH="$CT_STORAGE:vztmpl/$AVAILABLE_TEMPLATE"
else
    print_info "Шаблон найден: $TEMPLATE_PATH"
fi

# Проверка доступности IP если указан
if [ -n "$CT_IP" ]; then
    IP_ADDR=$(echo "$CT_IP" | cut -d'/' -f1)
    print_info "Проверка доступности IP $IP_ADDR..."
    
    if ping -c 1 -W 1 "$IP_ADDR" &>/dev/null; then
        print_warn "IP адрес $IP_ADDR отвечает на ping! Возможно уже используется."
        read -p "Продолжить? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_info "IP адрес $IP_ADDR свободен"
    fi
fi

# Формирование команды создания контейнера
print_info "Формирование команды создания контейнера..."
echo ""

CMD="pct create $CT_ID $TEMPLATE_PATH"
CMD="$CMD --hostname $CT_NAME"
CMD="$CMD --cores $CT_CORES"
CMD="$CMD --memory $CT_MEMORY"
CMD="$CMD --rootfs $CT_STORAGE:$CT_DISK"
CMD="$CMD --unprivileged $CT_UNPRIVILEGED"
CMD="$CMD --features $CT_FEATURES"
CMD="$CMD --password '$CT_PASSWORD'"

# Настройка сети
if [ -n "$CT_IP" ]; then
    NET_CONFIG="name=eth0,bridge=$CT_BRIDGE,ip=$CT_IP"
    
    if [ -n "$CT_GATEWAY" ]; then
        NET_CONFIG="$NET_CONFIG,gw=$CT_GATEWAY"
    fi
    
    if [ -n "$CT_IPV6" ]; then
        NET_CONFIG="$NET_CONFIG,ip6=$CT_IPV6"
    fi
    
    CMD="$CMD --net0 $NET_CONFIG"
else
    # DHCP
    CMD="$CMD --net0 name=eth0,bridge=$CT_BRIDGE,ip=dhcp"
    if [ -n "$CT_IPV6" ]; then
        CMD="$CMD,ip6=$CT_IPV6"
    fi
fi

# DNS сервер
if [ -n "$CT_NAMESERVER" ]; then
    CMD="$CMD --nameserver $CT_NAMESERVER"
fi

# SSH ключ
if [ -n "$CT_SSH_KEY" ]; then
    if [ -f "$CT_SSH_KEY" ]; then
        SSH_KEY_CONTENT=$(cat "$CT_SSH_KEY")
        CMD="$CMD --ssh-public-keys '$CT_SSH_KEY'"
    else
        print_warn "SSH ключ не найден: $CT_SSH_KEY"
    fi
fi

# Вывод информации
print_info "Параметры контейнера:"
echo "  ID:              $CT_ID"
echo "  Имя:             $CT_NAME"
echo "  CPU:             $CT_CORES ядер"
echo "  Память:          $CT_MEMORY MB"
echo "  Диск:            $CT_DISK GB"
echo "  Хранилище:       $CT_STORAGE"
echo "  Шаблон:          $CT_TEMPLATE"
echo "  IP:              ${CT_IP:-DHCP}"
[ -n "$CT_GATEWAY" ] && echo "  Шлюз:            $CT_GATEWAY"
[ -n "$CT_NAMESERVER" ] && echo "  DNS:             $CT_NAMESERVER"
echo "  IPv6:            $CT_IPV6"
echo "  Мост:            $CT_BRIDGE"
echo "  Непривилег.:     $CT_UNPRIVILEGED"
echo "  Возможности:     $CT_FEATURES"
echo "  Пароль root:     $CT_PASSWORD"
[ -n "$CT_SSH_KEY" ] && echo "  SSH ключ:        $CT_SSH_KEY"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    print_info "=== DRY-RUN MODE ==="
    print_debug "Команда создания:"
    echo "$CMD"
    echo ""
    
    if [ "$CT_START" -eq 1 ]; then
        print_debug "Команда запуска:"
        echo "pct start $CT_ID"
    fi
    
    print_info "Для выполнения запустите без --dry-run"
    exit 0
fi

# Создание контейнера
print_info "Создание контейнера..."
eval "$CMD"

if [ $? -eq 0 ]; then
    print_info "✓ Контейнер успешно создан!"
else
    print_error "Ошибка при создании контейнера!"
    exit 1
fi

# Запуск контейнера если указано
if [ "$CT_START" -eq 1 ]; then
    print_info "Запуск контейнера..."
    pct start $CT_ID
    
    if [ $? -eq 0 ]; then
        print_info "✓ Контейнер запущен"
        
        # Ожидание получения IP если DHCP
        if [ -z "$CT_IP" ]; then
            print_info "Ожидание получения IP адреса..."
            sleep 5
            DHCP_IP=$(pct exec $CT_ID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
            if [ -n "$DHCP_IP" ]; then
                print_info "Получен IP: $DHCP_IP"
            fi
        fi
    else
        print_warn "Не удалось запустить контейнер"
    fi
fi

# Итоговая информация
echo ""
print_info "=== Контейнер готов к использованию ==="
echo ""
print_info "Информация для подключения:"
echo "  ID:              $CT_ID"
echo "  Имя:             $CT_NAME"
if [ -n "$CT_IP" ]; then
    echo "  IP:              ${CT_IP%/*}"
elif [ -n "$DHCP_IP" ]; then
    echo "  IP:              $DHCP_IP (DHCP)"
else
    echo "  IP:              DHCP (используйте 'pct enter $CT_ID')"
fi
echo "  Пользователь:    root"
echo "  Пароль:          $CT_PASSWORD"
echo ""

print_warn "ВАЖНО: Сохраните пароль в безопасном месте!"
echo ""

print_info "Управление контейнером:"
echo "  pct start $CT_ID       # запустить"
echo "  pct stop $CT_ID        # остановить"
echo "  pct status $CT_ID      # статус"
echo "  pct enter $CT_ID       # войти в консоль"
echo "  pct destroy $CT_ID     # удалить"
echo ""

if [ -n "$CT_IP" ]; then
    print_info "Подключение по SSH:"
    echo "  ssh root@${CT_IP%/*}"
    echo ""
fi

print_info "✓ Готово!"
