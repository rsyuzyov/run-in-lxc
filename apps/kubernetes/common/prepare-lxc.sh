#!/bin/bash

#############################################
# Prepare LXC Container for Kubernetes
# Подготовка LXC контейнера для запуска K3s/k0s
# Запускается на хосте Proxmox VE
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
CT_ID=""
CT_NAME=""
CREATE_NEW="0"
CT_CORES="2"
CT_MEMORY="4096"
CT_DISK="40"
CT_STORAGE=""
CT_TEMPLATE="debian-12-standard"
CT_IP=""
CT_GATEWAY=""
CT_NAMESERVER=""
CT_BRIDGE="vmbr0"
CT_PASSWORD=""
CT_SSH_KEY=""
CT_START="1"
DRY_RUN="0"
SKIP_BACKUP="0"

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

Скрипт подготовки LXC контейнера для запуска Kubernetes (K3s/k0s).
Запускается на хосте Proxmox VE.

ВАЖНО: Для Kubernetes требуется privileged контейнер с дополнительными
возможностями. Это снижает изоляцию. Для production рекомендуется VM.

Режимы работы:
  --ctid ID                 Подготовить существующий контейнер
  --create                  Создать новый контейнер

Параметры существующего контейнера (--ctid):
  --ctid ID                 ID контейнера для подготовки
  --skip-backup             Не создавать backup перед изменениями

Параметры нового контейнера (--create):
  --name NAME               Имя контейнера (обязательно)
  --id ID                   ID контейнера (по умолчанию: автоматически)
  --cores N                 Количество CPU ядер (по умолчанию: 2)
  --memory MB               Память в MB (по умолчанию: 4096)
  --disk GB                 Размер диска в GB (по умолчанию: 40)
  --storage NAME            Хранилище (по умолчанию: автоматически)
  --template NAME           Шаблон контейнера (по умолчанию: debian-12-standard)
  
Сетевые параметры (для --create):
  --ip IP/MASK              IP адрес с маской (по умолчанию: DHCP)
  --gateway IP              Шлюз по умолчанию
  --nameserver IP           DNS сервер
  --bridge NAME             Сетевой мост (по умолчанию: vmbr0)
  
Безопасность (для --create):
  --password PASS           Пароль root (по умолчанию: генерируется)
  --ssh-key PATH            Путь к публичному SSH ключу
  
Дополнительно:
  --no-start                Не запускать контейнер после подготовки
  --dry-run                 Показать команды без выполнения
  --help                    Показать эту справку

Примеры:
  # Подготовить существующий контейнер
  $0 --ctid 200

  # Создать новый контейнер для K8s
  $0 --create --name k8s-master --memory 8192 --cores 4

  # С статическим IP
  $0 --create --name k8s-worker1 \\
     --ip 192.168.1.101/24 --gateway 192.168.1.1

  # Только показать команды
  $0 --ctid 200 --dry-run

Необходимые настройки LXC для Kubernetes:
  - privileged: 1 (привилегированный контейнер)
  - features: nesting=1,keyctl=1,fuse=1
  - lxc.apparmor.profile: unconfined
  - lxc.cgroup2.devices.allow: a
  - lxc.cap.drop: (пустой — все capabilities)
  - lxc.mount.auto: proc:rw sys:rw

EOF
    exit 0
}

# Проверка запуска на Proxmox
check_proxmox() {
    if ! command -v pct &> /dev/null; then
        print_error "Команда 'pct' не найдена. Скрипт должен запускаться на хосте Proxmox VE."
        exit 1
    fi
    
    if ! command -v pvesh &> /dev/null; then
        print_error "Команда 'pvesh' не найдена. Скрипт должен запускаться на хосте Proxmox VE."
        exit 1
    fi
}

# Проверка существования контейнера
check_container_exists() {
    local ctid=$1
    if ! pct status "$ctid" &> /dev/null; then
        print_error "Контейнер $ctid не найден"
        exit 1
    fi
}

# Получить следующий свободный VMID
get_next_vmid() {
    pvesh get /cluster/nextid 2>/dev/null || echo "100"
}

# Получить хранилище по умолчанию
get_default_storage() {
    pvesm status -content rootdir 2>/dev/null | awk 'NR>1 {print $1; exit}'
}

# Найти шаблон контейнера
find_template() {
    local template_name=$1
    local storage
    
    # Поиск шаблона в доступных хранилищах
    for storage in $(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 {print $1}'); do
        local template_path
        template_path=$(pvesm list "$storage" 2>/dev/null | grep "$template_name" | awk '{print $1}' | head -1)
        if [[ -n "$template_path" ]]; then
            echo "$template_path"
            return 0
        fi
    done
    
    return 1
}

# Генерация пароля
generate_password() {
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | head -c 16
}

# Создание нового контейнера
create_container() {
    print_step "Создание нового LXC контейнера для Kubernetes..."
    
    # Проверка обязательных параметров
    if [[ -z "$CT_NAME" ]]; then
        print_error "Не указано имя контейнера (--name)"
        exit 1
    fi
    
    # Получение VMID
    if [[ -z "$CT_ID" ]]; then
        CT_ID=$(get_next_vmid)
        print_info "Автоматически выбран VMID: $CT_ID"
    fi
    
    # Получение хранилища
    if [[ -z "$CT_STORAGE" ]]; then
        CT_STORAGE=$(get_default_storage)
        if [[ -z "$CT_STORAGE" ]]; then
            print_error "Не удалось определить хранилище. Укажите --storage"
            exit 1
        fi
        print_info "Используется хранилище: $CT_STORAGE"
    fi
    
    # Поиск шаблона
    local template_path
    template_path=$(find_template "$CT_TEMPLATE")
    if [[ -z "$template_path" ]]; then
        print_error "Шаблон '$CT_TEMPLATE' не найден"
        print_info "Доступные шаблоны:"
        for storage in $(pvesm status -content vztmpl 2>/dev/null | awk 'NR>1 {print $1}'); do
            pvesm list "$storage" 2>/dev/null | awk 'NR>1 {print "  " $1}'
        done
        exit 1
    fi
    print_info "Найден шаблон: $template_path"
    
    # Генерация пароля
    if [[ -z "$CT_PASSWORD" ]]; then
        CT_PASSWORD=$(generate_password)
        print_info "Сгенерирован пароль: $CT_PASSWORD"
    fi
    
    # Формирование команды создания
    local cmd="pct create $CT_ID $template_path"
    cmd+=" --hostname $CT_NAME"
    cmd+=" --cores $CT_CORES"
    cmd+=" --memory $CT_MEMORY"
    cmd+=" --rootfs $CT_STORAGE:$CT_DISK"
    cmd+=" --password $CT_PASSWORD"
    cmd+=" --unprivileged 0"  # Privileged контейнер
    cmd+=" --features nesting=1,keyctl=1,fuse=1"
    
    # Сетевые настройки
    if [[ -n "$CT_IP" ]]; then
        cmd+=" --net0 name=eth0,bridge=$CT_BRIDGE,ip=$CT_IP"
        if [[ -n "$CT_GATEWAY" ]]; then
            cmd+=",gw=$CT_GATEWAY"
        fi
    else
        cmd+=" --net0 name=eth0,bridge=$CT_BRIDGE,ip=dhcp"
    fi
    
    if [[ -n "$CT_NAMESERVER" ]]; then
        cmd+=" --nameserver $CT_NAMESERVER"
    fi
    
    # SSH ключ
    if [[ -n "$CT_SSH_KEY" ]] && [[ -f "$CT_SSH_KEY" ]]; then
        cmd+=" --ssh-public-keys $CT_SSH_KEY"
    fi
    
    print_info "Команда создания контейнера:"
    echo "  $cmd"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск создания контейнера"
    else
        eval "$cmd"
        print_info "Контейнер $CT_ID создан"
    fi
    
    # Применение настроек для K8s
    apply_k8s_settings "$CT_ID"
    
    # Сохранение пароля
    if [[ "$DRY_RUN" != "1" ]]; then
        local creds_dir="/root/run-in-lxc/proxmox/credentials"
        mkdir -p "$creds_dir"
        echo "CTID: $CT_ID" > "$creds_dir/$CT_NAME.txt"
        echo "Hostname: $CT_NAME" >> "$creds_dir/$CT_NAME.txt"
        echo "Password: $CT_PASSWORD" >> "$creds_dir/$CT_NAME.txt"
        echo "Created: $(date)" >> "$creds_dir/$CT_NAME.txt"
        chmod 600 "$creds_dir/$CT_NAME.txt"
        print_info "Учётные данные сохранены в: $creds_dir/$CT_NAME.txt"
    fi
}

# Применение настроек K8s к контейнеру
apply_k8s_settings() {
    local ctid=$1
    local conf_file="/etc/pve/lxc/${ctid}.conf"
    
    print_step "Применение настроек Kubernetes к контейнеру $ctid..."
    
    # Проверка статуса контейнера
    local status
    status=$(pct status "$ctid" 2>/dev/null | awk '{print $2}')
    
    if [[ "$status" == "running" ]]; then
        print_warn "Контейнер запущен. Остановка для применения настроек..."
        if [[ "$DRY_RUN" != "1" ]]; then
            pct stop "$ctid"
            sleep 2
        fi
    fi
    
    # Создание backup конфигурации
    if [[ "$SKIP_BACKUP" != "1" ]] && [[ "$DRY_RUN" != "1" ]]; then
        local backup_file="${conf_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$conf_file" "$backup_file"
        print_info "Backup конфигурации: $backup_file"
    fi
    
    print_info "Настройки для Kubernetes:"
    
    # Список настроек для добавления
    local settings=(
        "lxc.apparmor.profile: unconfined"
        "lxc.cgroup2.devices.allow: a"
        "lxc.cap.drop:"
        "lxc.mount.auto: proc:rw sys:rw"
    )
    
    for setting in "${settings[@]}"; do
        echo "  + $setting"
    done
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск изменения конфигурации"
    else
        # Удаление старых настроек (если есть)
        sed -i '/^lxc.apparmor.profile:/d' "$conf_file"
        sed -i '/^lxc.cgroup2.devices.allow:/d' "$conf_file"
        sed -i '/^lxc.cap.drop:/d' "$conf_file"
        sed -i '/^lxc.mount.auto:/d' "$conf_file"
        
        # Добавление новых настроек
        echo "" >> "$conf_file"
        echo "# Kubernetes settings" >> "$conf_file"
        for setting in "${settings[@]}"; do
            echo "$setting" >> "$conf_file"
        done
        
        # Обновление features если нужно
        if grep -q "^features:" "$conf_file"; then
            # Проверка наличия нужных features
            local current_features
            current_features=$(grep "^features:" "$conf_file" | cut -d: -f2 | tr -d ' ')
            
            local need_update=0
            for feature in nesting keyctl fuse; do
                if ! echo "$current_features" | grep -q "$feature=1"; then
                    need_update=1
                    break
                fi
            done
            
            if [[ "$need_update" == "1" ]]; then
                sed -i 's/^features:.*/features: nesting=1,keyctl=1,fuse=1/' "$conf_file"
                print_info "Обновлены features: nesting=1,keyctl=1,fuse=1"
            fi
        else
            echo "features: nesting=1,keyctl=1,fuse=1" >> "$conf_file"
            print_info "Добавлены features: nesting=1,keyctl=1,fuse=1"
        fi
        
        # Проверка privileged режима
        if grep -q "^unprivileged: 1" "$conf_file"; then
            print_warn "Контейнер непривилегированный. Изменение на privileged..."
            sed -i 's/^unprivileged: 1/unprivileged: 0/' "$conf_file"
        fi
        
        print_info "Настройки Kubernetes применены"
    fi
    
    # Запуск контейнера
    if [[ "$CT_START" == "1" ]]; then
        print_step "Запуск контейнера..."
        if [[ "$DRY_RUN" != "1" ]]; then
            pct start "$ctid"
            sleep 3
            
            # Получение IP адреса
            local ip
            ip=$(pct exec "$ctid" -- hostname -I 2>/dev/null | awk '{print $1}' || echo "")
            if [[ -n "$ip" ]]; then
                print_info "IP адрес контейнера: $ip"
            fi
        else
            print_warn "[DRY-RUN] Пропуск запуска контейнера"
        fi
    fi
}

# Подготовка существующего контейнера
prepare_existing() {
    print_step "Подготовка существующего контейнера $CT_ID для Kubernetes..."
    
    check_container_exists "$CT_ID"
    
    # Получение информации о контейнере
    local hostname
    hostname=$(pct config "$CT_ID" | grep "^hostname:" | cut -d: -f2 | tr -d ' ')
    print_info "Hostname: $hostname"
    
    # Применение настроек
    apply_k8s_settings "$CT_ID"
}

# Вывод итоговой информации
print_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}Контейнер подготовлен для Kubernetes${NC}"
    echo "============================================"
    echo ""
    echo "CTID: $CT_ID"
    if [[ -n "$CT_NAME" ]]; then
        echo "Имя: $CT_NAME"
    fi
    echo ""
    echo "Следующие шаги:"
    echo ""
    echo "1. Подключитесь к контейнеру:"
    echo "   pct enter $CT_ID"
    echo "   # или"
    echo "   ssh root@<IP>"
    echo ""
    echo "2. Клонируйте репозиторий:"
    echo "   git clone <repo-url> run-in-lxc"
    echo ""
    echo "3. Установите K3s или k0s:"
    echo "   # K3s:"
    echo "   cd run-in-lxc/kubernetes/k3s"
    echo "   ./install.sh --mode single"
    echo ""
    echo "   # k0s:"
    echo "   cd run-in-lxc/kubernetes/k0s"
    echo "   ./install.sh --role single"
    echo ""
    echo "============================================"
    echo -e "${YELLOW}ПРЕДУПРЕЖДЕНИЕ:${NC}"
    echo "Контейнер работает в privileged режиме с отключённым"
    echo "AppArmor. Это снижает изоляцию и безопасность."
    echo "Для production рекомендуется использовать VM."
    echo "============================================"
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --ctid)
            CT_ID="$2"
            shift 2
            ;;
        --create)
            CREATE_NEW="1"
            shift
            ;;
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
        --no-start)
            CT_START="0"
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP="1"
            shift
            ;;
        --dry-run)
            DRY_RUN="1"
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Неизвестный параметр: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

# Проверка Proxmox
check_proxmox

# Проверка режима работы
if [[ "$CREATE_NEW" == "1" ]]; then
    create_container
elif [[ -n "$CT_ID" ]]; then
    prepare_existing
else
    print_error "Укажите --ctid для подготовки существующего контейнера или --create для создания нового"
    echo "Используйте --help для справки"
    exit 1
fi

# Вывод итоговой информации
if [[ "$DRY_RUN" != "1" ]]; then
    print_summary
fi

