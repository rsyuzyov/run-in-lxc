#!/bin/bash

#############################################
# k0s Installation Script for LXC/VM
# Установка Zero Friction Kubernetes (k0s)
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
K0S_VERSION=""  # Пустая строка = latest
ROLE="single"   # single, controller, worker, controller+worker
CONTROLLER_URL=""
TOKEN=""
TOKEN_FILE=""
ENABLE_WORKER="0"
DATA_DIR="/var/lib/k0s"
CONFIG_FILE=""
NO_TAINTS="0"
INSTALL_K0SCTL="0"
INSTALL_KUBECTL="1"
DEBUG="0"
DRY_RUN="0"
UNINSTALL="0"

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

Скрипт установки k0s — Zero Friction Kubernetes от Mirantis.

Режимы установки (--role):
  single              Single-node (controller + worker в одном)
  controller          Только control plane
  controller+worker   Control plane с рабочими нагрузками
  worker              Только worker node

Параметры кластера:
  --version VERSION         Версия k0s (по умолчанию: latest)
  --controller URL          URL контроллера для worker (https://IP:6443)
  --token TOKEN             Токен для подключения (join token)
  --token-file PATH         Путь к файлу с токеном
  --config PATH             Путь к k0s.yaml конфигурации
  --no-taints               Не применять taints к controller (разрешить workloads)

Дополнительно:
  --data-dir PATH           Каталог данных (по умолчанию: /var/lib/k0s)
  --with-k0sctl             Установить k0sctl (инструмент управления кластером)
  --no-kubectl              Не создавать симлинк kubectl
  --debug                   Включить отладочный вывод
  --uninstall               Удалить k0s
  --dry-run                 Показать команды без выполнения
  --help                    Показать эту справку

Примеры:
  # Single-node кластер
  $0 --role single

  # Controller без workloads
  $0 --role controller

  # Controller с workloads
  $0 --role controller+worker

  # Первый controller для HA кластера
  $0 --role controller --with-k0sctl

  # Worker node
  $0 --role worker \\
     --controller https://192.168.1.100:6443 \\
     --token <JOIN_TOKEN>

  # С кастомной конфигурацией
  $0 --role single --config /path/to/k0s.yaml

  # Удаление k0s
  $0 --uninstall

Управление кластером:
  k0s kubectl get nodes     # Список узлов
  k0s status               # Статус k0s
  k0s token create --role worker    # Создать токен для worker
  k0s token create --role controller   # Создать токен для controller
  k0sctl apply -c k0sctl.yaml       # Развернуть кластер (с k0sctl)

Файлы:
  - Конфигурация: /etc/k0s/k0s.yaml
  - Kubeconfig: /var/lib/k0s/pki/admin.conf
  - Данные: /var/lib/k0s

EOF
    exit 0
}

# Проверка системных требований
check_requirements() {
    print_step "Проверка системных требований..."
    
    # Проверка root
    if [[ $EUID -ne 0 ]]; then
        print_error "Скрипт должен запускаться с правами root"
        exit 1
    fi
    
    # Проверка архитектуры
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            print_info "Архитектура: x86_64"
            ;;
        aarch64|arm64)
            print_info "Архитектура: arm64"
            ;;
        armv7l)
            print_info "Архитектура: armv7"
            ;;
        *)
            print_error "Неподдерживаемая архитектура: $arch"
            exit 1
            ;;
    esac
    
    # Проверка памяти
    local mem_total
    mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    if [[ $mem_total -lt 1024 ]]; then
        print_warn "Мало памяти: ${mem_total}MB. Рекомендуется минимум 2GB."
    else
        print_info "Память: ${mem_total}MB"
    fi
    
    # Проверка LXC
    if [[ -f /proc/1/environ ]] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        print_warn "Обнаружен LXC контейнер"
        check_lxc_settings
    fi
    
    # Проверка curl
    if ! command -v curl &> /dev/null; then
        print_info "Установка curl..."
        apt-get update && apt-get install -y curl
    fi
}

# Проверка настроек LXC
check_lxc_settings() {
    print_info "Проверка настроек LXC для Kubernetes..."
    
    local warnings=0
    
    # Проверка privileged режима
    if [[ ! -e /dev/kmsg ]]; then
        print_warn "Отсутствует /dev/kmsg — возможно, контейнер непривилегированный"
        warnings=$((warnings + 1))
    fi
    
    # Проверка cgroups
    if [[ ! -d /sys/fs/cgroup ]]; then
        print_error "Отсутствует /sys/fs/cgroup — cgroups недоступны"
        exit 1
    fi
    
    if [[ $warnings -gt 0 ]]; then
        echo ""
        print_warn "Обнаружены потенциальные проблемы с настройками LXC"
        print_info "Убедитесь, что контейнер подготовлен с помощью:"
        print_info "  kubernetes/common/prepare-lxc.sh --ctid <ID>"
        echo ""
        read -p "Продолжить установку? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Подготовка системы
prepare_system() {
    print_step "Подготовка системы..."
    
    # Отключение swap
    if [[ -n $(swapon --show) ]]; then
        print_info "Отключение swap..."
        swapoff -a
        sed -i '/swap/d' /etc/fstab
    fi
    
    # Настройка sysctl
    print_info "Настройка sysctl параметров..."
    cat > /etc/sysctl.d/99-kubernetes.conf << EOF
# Kubernetes sysctl settings
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# Улучшение производительности
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 32768
vm.max_map_count = 262144
EOF
    
    # Загрузка модулей
    modprobe overlay 2>/dev/null || true
    modprobe br_netfilter 2>/dev/null || true
    
    sysctl --system > /dev/null 2>&1 || true
    
    # Создание /dev/kmsg если отсутствует (для LXC)
    if [[ ! -e /dev/kmsg ]]; then
        print_info "Создание /dev/kmsg..."
        mknod /dev/kmsg c 1 11 2>/dev/null || true
    fi
    
    # Создание каталога конфигурации
    mkdir -p /etc/k0s
}

# Загрузка k0s
download_k0s() {
    print_step "Загрузка k0s..."
    
    local version_arg=""
    if [[ -n "$K0S_VERSION" ]]; then
        version_arg="--k0s-version $K0S_VERSION"
    fi
    
    local cmd="curl -sSLf https://get.k0s.sh | sh $version_arg"
    
    print_info "Команда загрузки:"
    echo "  $cmd"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск загрузки k0s"
        return
    fi
    
    # Загрузка через официальный скрипт
    curl -sSLf https://get.k0s.sh | sh
    
    # Проверка установки
    if ! command -v k0s &> /dev/null; then
        print_error "k0s не найден после установки"
        exit 1
    fi
    
    local installed_version
    installed_version=$(k0s version 2>/dev/null || echo "unknown")
    print_info "Установлена версия: $installed_version"
}

# Генерация конфигурации
generate_config() {
    if [[ -n "$CONFIG_FILE" ]] && [[ -f "$CONFIG_FILE" ]]; then
        print_info "Используется конфигурация: $CONFIG_FILE"
        cp "$CONFIG_FILE" /etc/k0s/k0s.yaml
        return
    fi
    
    print_step "Генерация конфигурации k0s..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск генерации конфигурации"
        return
    fi
    
    # Генерация дефолтной конфигурации
    k0s config create > /etc/k0s/k0s.yaml
    
    print_info "Конфигурация сохранена: /etc/k0s/k0s.yaml"
}

# Установка k0s
install_k0s() {
    print_step "Установка k0s..."
    
    local install_cmd="k0s install"
    local k0s_args=""
    
    case $ROLE in
        single)
            print_info "Режим: single-node (controller + worker)"
            install_cmd+=" controller --enable-worker"
            k0s_args+=" --no-taints"
            ;;
        controller)
            print_info "Режим: controller (control plane only)"
            install_cmd+=" controller"
            ;;
        controller+worker)
            print_info "Режим: controller+worker"
            install_cmd+=" controller --enable-worker"
            if [[ "$NO_TAINTS" == "1" ]]; then
                k0s_args+=" --no-taints"
            fi
            ;;
        worker)
            print_info "Режим: worker"
            install_cmd+=" worker"
            
            if [[ -z "$TOKEN" ]] && [[ -z "$TOKEN_FILE" ]]; then
                print_error "Для worker требуется --token или --token-file"
                exit 1
            fi
            
            if [[ -n "$TOKEN" ]]; then
                k0s_args+=" --token-file /etc/k0s/join-token"
                # Сохранение токена в файл
                if [[ "$DRY_RUN" != "1" ]]; then
                    echo "$TOKEN" > /etc/k0s/join-token
                    chmod 600 /etc/k0s/join-token
                fi
            elif [[ -n "$TOKEN_FILE" ]]; then
                k0s_args+=" --token-file $TOKEN_FILE"
            fi
            ;;
    esac
    
    # Конфигурация для controller
    if [[ "$ROLE" != "worker" ]] && [[ -f /etc/k0s/k0s.yaml ]]; then
        k0s_args+=" -c /etc/k0s/k0s.yaml"
    fi
    
    # Data directory
    if [[ "$DATA_DIR" != "/var/lib/k0s" ]]; then
        k0s_args+=" --data-dir $DATA_DIR"
    fi
    
    # Debug
    if [[ "$DEBUG" == "1" ]]; then
        k0s_args+=" --debug"
    fi
    
    local full_cmd="$install_cmd$k0s_args"
    
    print_info "Команда установки:"
    echo "  $full_cmd"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки k0s"
        return
    fi
    
    # Выполнение установки
    eval "$full_cmd"
    
    # Запуск сервиса
    print_info "Запуск k0s..."
    systemctl daemon-reload
    systemctl enable k0s
    systemctl start k0s
    
    # Ожидание готовности
    print_info "Ожидание готовности k0s..."
    local attempts=0
    local max_attempts=60
    
    while [[ $attempts -lt $max_attempts ]]; do
        if k0s status &> /dev/null; then
            print_info "k0s запущен"
            break
        fi
        attempts=$((attempts + 1))
        sleep 2
    done
    
    if [[ $attempts -ge $max_attempts ]]; then
        print_warn "Таймаут ожидания готовности k0s"
        print_info "Проверьте логи: journalctl -u k0s"
    fi
    
    # Дополнительное ожидание для API
    if [[ "$ROLE" != "worker" ]]; then
        print_info "Ожидание готовности Kubernetes API..."
        attempts=0
        while [[ $attempts -lt $max_attempts ]]; do
            if k0s kubectl get nodes &> /dev/null; then
                break
            fi
            attempts=$((attempts + 1))
            sleep 2
        done
    fi
}

# Настройка kubectl
setup_kubectl() {
    if [[ "$ROLE" == "worker" ]]; then
        return
    fi
    
    if [[ "$INSTALL_KUBECTL" != "1" ]]; then
        return
    fi
    
    print_step "Настройка kubectl..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск настройки kubectl"
        return
    fi
    
    # Создание симлинка для kubectl
    if [[ ! -f /usr/local/bin/kubectl ]]; then
        cat > /usr/local/bin/kubectl << 'EOF'
#!/bin/bash
exec k0s kubectl "$@"
EOF
        chmod +x /usr/local/bin/kubectl
        print_info "Создан симлинк kubectl"
    fi
    
    # Экспорт kubeconfig
    local kubeconfig="$DATA_DIR/pki/admin.conf"
    
    if [[ -f "$kubeconfig" ]]; then
        # Копирование в стандартное место
        mkdir -p /root/.kube
        cp "$kubeconfig" /root/.kube/config
        chmod 600 /root/.kube/config
        
        # Добавление в профиль
        if ! grep -q "KUBECONFIG" /root/.bashrc; then
            echo "" >> /root/.bashrc
            echo "# Kubernetes" >> /root/.bashrc
            echo "export KUBECONFIG=/root/.kube/config" >> /root/.bashrc
        fi
        
        print_info "Kubeconfig скопирован в /root/.kube/config"
    fi
    
    # Автодополнение
    k0s completion bash > /etc/bash_completion.d/k0s 2>/dev/null || true
    if command -v kubectl &> /dev/null; then
        kubectl completion bash > /etc/bash_completion.d/kubectl 2>/dev/null || true
    fi
}

# Установка k0sctl
install_k0sctl() {
    if [[ "$INSTALL_K0SCTL" != "1" ]]; then
        return
    fi
    
    print_step "Установка k0sctl..."
    
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            print_warn "k0sctl не поддерживает архитектуру $arch"
            return
            ;;
    esac
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки k0sctl"
        return
    fi
    
    # Получение последней версии
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/k0sproject/k0sctl/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
    
    if [[ -z "$latest_version" ]]; then
        print_warn "Не удалось определить последнюю версию k0sctl"
        return
    fi
    
    print_info "Загрузка k0sctl $latest_version..."
    
    local download_url="https://github.com/k0sproject/k0sctl/releases/download/${latest_version}/k0sctl-linux-${arch}"
    curl -sSLf "$download_url" -o /usr/local/bin/k0sctl
    chmod +x /usr/local/bin/k0sctl
    
    # Автодополнение
    k0sctl completion bash > /etc/bash_completion.d/k0sctl 2>/dev/null || true
    
    print_info "k0sctl установлен: $(k0sctl version 2>/dev/null || echo 'unknown')"
}

# Вывод итоговой информации
print_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}k0s установлен успешно${NC}"
    echo "============================================"
    echo ""
    
    echo "Версия: $(k0s version 2>/dev/null || echo 'unknown')"
    echo "Режим: $ROLE"
    echo ""
    
    if [[ "$ROLE" == "worker" ]]; then
        echo "Проверка статуса:"
        echo "  k0s status"
        echo "  systemctl status k0s"
        echo ""
        echo "Логи:"
        echo "  journalctl -u k0s -f"
    else
        # Вывод узлов
        if k0s kubectl get nodes &> /dev/null; then
            echo "Узлы кластера:"
            k0s kubectl get nodes
            echo ""
        fi
        
        echo "Файлы конфигурации:"
        echo "  k0s config:  /etc/k0s/k0s.yaml"
        echo "  kubeconfig:  /root/.kube/config"
        echo ""
        
        echo "Создание токенов для подключения:"
        echo "  # Для worker node:"
        echo "  k0s token create --role worker"
        echo ""
        echo "  # Для controller node (HA):"
        echo "  k0s token create --role controller"
        echo ""
        
        local server_ip
        server_ip=$(hostname -I | awk '{print $1}')
        echo "Команда для worker node:"
        echo "  ./install.sh --role worker \\"
        echo "    --controller https://${server_ip}:6443 \\"
        echo "    --token <JOIN_TOKEN>"
        echo ""
        
        echo "Полезные команды:"
        echo "  k0s kubectl get nodes     # Список узлов"
        echo "  k0s kubectl get pods -A   # Все поды"
        echo "  k0s status               # Статус k0s"
        echo "  k0s etcd member-list     # Участники etcd (HA)"
        echo ""
        echo "Логи:"
        echo "  journalctl -u k0s -f"
    fi
    
    if [[ "$INSTALL_K0SCTL" == "1" ]]; then
        echo ""
        echo "k0sctl установлен. Пример k0sctl.yaml:"
        echo "  kubernetes/k0s/config/k0sctl.yaml.example"
    fi
    
    echo ""
    echo "============================================"
}

# Удаление k0s
uninstall_k0s() {
    print_step "Удаление k0s..."
    
    # Остановка сервиса
    if systemctl is-active --quiet k0s; then
        print_info "Остановка k0s..."
        systemctl stop k0s
    fi
    
    # Удаление сервиса
    if [[ -f /etc/systemd/system/k0s.service ]]; then
        print_info "Удаление сервиса..."
        systemctl disable k0s 2>/dev/null || true
        rm -f /etc/systemd/system/k0s.service
        systemctl daemon-reload
    fi
    
    # Сброс k0s
    if command -v k0s &> /dev/null; then
        print_info "Сброс k0s..."
        k0s reset --debug 2>/dev/null || true
    fi
    
    # Удаление файлов
    print_info "Удаление файлов..."
    rm -rf /var/lib/k0s
    rm -rf /etc/k0s
    rm -rf /run/k0s
    rm -f /usr/local/bin/k0s
    rm -f /usr/local/bin/k0sctl
    rm -f /usr/local/bin/kubectl
    rm -rf /root/.kube
    
    print_info "k0s удалён"
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --role)
            ROLE="$2"
            if [[ ! "$ROLE" =~ ^(single|controller|controller\+worker|worker)$ ]]; then
                print_error "Неверная роль: $ROLE"
                echo "Допустимые: single, controller, controller+worker, worker"
                exit 1
            fi
            shift 2
            ;;
        --version)
            K0S_VERSION="$2"
            shift 2
            ;;
        --controller)
            CONTROLLER_URL="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --token-file)
            TOKEN_FILE="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --no-taints)
            NO_TAINTS="1"
            shift
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --with-k0sctl)
            INSTALL_K0SCTL="1"
            shift
            ;;
        --no-kubectl)
            INSTALL_KUBECTL="0"
            shift
            ;;
        --debug)
            DEBUG="1"
            shift
            ;;
        --uninstall)
            UNINSTALL="1"
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

# Основной процесс
if [[ "$UNINSTALL" == "1" ]]; then
    uninstall_k0s
fi

check_requirements

if [[ "$DRY_RUN" != "1" ]]; then
    prepare_system
fi

download_k0s

if [[ "$ROLE" != "worker" ]]; then
    generate_config
fi

install_k0s

if [[ "$DRY_RUN" != "1" ]]; then
    setup_kubectl
    install_k0sctl
    print_summary
fi

