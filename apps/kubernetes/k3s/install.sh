#!/bin/bash

#############################################
# K3s Installation Script for LXC/VM
# Установка легковесного Kubernetes (K3s)
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
K3S_VERSION=""  # Пустая строка = latest
MODE="single"   # single, server, agent
CLUSTER_INIT="0"
SERVER_URL=""
TOKEN=""
TOKEN_FILE=""
NODE_NAME=""
NODE_IP=""
FLANNEL_BACKEND="vxlan"  # vxlan, host-gw, wireguard-native
DISABLE_TRAEFIK="0"
DISABLE_SERVICELB="0"
DISABLE_LOCAL_STORAGE="0"
DISABLE_METRICS_SERVER="0"
TLS_SAN=""
DATA_DIR="/var/lib/rancher/k3s"
KUBECONFIG_MODE="644"
INSTALL_KUBECTL="1"
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

Скрипт установки K3s — легковесного сертифицированного Kubernetes.

Режимы установки:
  --mode single             Single-node кластер (control plane + worker)
  --mode server             Только control plane (server node)
  --mode agent              Только worker (agent node)

Параметры кластера:
  --version VERSION         Версия K3s (по умолчанию: latest)
  --cluster-init            Инициализация HA кластера (etcd)
  --server URL              URL сервера для agent (https://IP:6443)
  --token TOKEN             Токен для подключения к кластеру
  --token-file PATH         Путь к файлу с токеном
  --node-name NAME          Имя узла в кластере
  --node-ip IP              IP адрес узла (для multi-homed хостов)
  --tls-san NAMES           Дополнительные SAN для TLS (через запятую)

Сетевые настройки:
  --flannel-backend TYPE    Backend для Flannel: vxlan, host-gw, wireguard-native
                            (по умолчанию: vxlan)

Отключение компонентов:
  --disable-traefik         Не устанавливать Traefik ingress
  --disable-servicelb       Не устанавливать ServiceLB (Klipper)
  --disable-local-storage   Не устанавливать Local Path Provisioner
  --disable-metrics-server  Не устанавливать Metrics Server

Дополнительно:
  --data-dir PATH           Каталог данных (по умолчанию: /var/lib/rancher/k3s)
  --no-kubectl              Не устанавливать kubectl отдельно
  --uninstall               Удалить K3s
  --dry-run                 Показать команды без выполнения
  --help                    Показать эту справку

Примеры:
  # Single-node кластер (всё включено)
  $0 --mode single

  # Single-node без Traefik (для установки своего Ingress)
  $0 --mode single --disable-traefik

  # Первый server node для HA кластера
  $0 --mode server --cluster-init --tls-san k8s.example.com

  # Дополнительный server node
  $0 --mode server \\
     --server https://192.168.1.100:6443 \\
     --token <TOKEN>

  # Worker node
  $0 --mode agent \\
     --server https://192.168.1.100:6443 \\
     --token <TOKEN>

  # Удаление K3s
  $0 --uninstall

После установки:
  - Конфигурация kubectl: /etc/rancher/k3s/k3s.yaml
  - Токен для worker: /var/lib/rancher/k3s/server/node-token
  - Логи: journalctl -u k3s

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
    
    # Проверка необходимых модулей ядра
    local modules=("overlay" "br_netfilter")
    for mod in "${modules[@]}"; do
        if ! lsmod | grep -q "^$mod"; then
            print_info "Загрузка модуля: $mod"
            modprobe "$mod" 2>/dev/null || print_warn "Не удалось загрузить модуль $mod"
        fi
    done
    
    # Проверка curl/wget
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        print_info "Установка curl..."
        apt-get update && apt-get install -y curl
    fi
}

# Проверка настроек LXC
check_lxc_settings() {
    print_info "Проверка настроек LXC для Kubernetes..."
    
    local warnings=0
    
    # Проверка privileged режима (через /dev)
    if [[ ! -e /dev/kmsg ]]; then
        print_warn "Отсутствует /dev/kmsg — возможно, контейнер непривилегированный"
        warnings=$((warnings + 1))
    fi
    
    # Проверка cgroups
    if [[ ! -d /sys/fs/cgroup ]]; then
        print_error "Отсутствует /sys/fs/cgroup — cgroups недоступны"
        exit 1
    fi
    
    # Проверка nesting
    if [[ ! -f /sys/fs/cgroup/cgroup.controllers ]]; then
        print_warn "cgroup v2 controllers могут быть недоступны"
        warnings=$((warnings + 1))
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

# Conntrack
net.netfilter.nf_conntrack_max = 1048576
EOF
    
    sysctl --system > /dev/null 2>&1 || true
    
    # Создание /dev/kmsg если отсутствует (для LXC)
    if [[ ! -e /dev/kmsg ]]; then
        print_info "Создание /dev/kmsg..."
        mknod /dev/kmsg c 1 11 2>/dev/null || true
    fi
}

# Установка K3s
install_k3s() {
    print_step "Установка K3s..."
    
    # Формирование переменных окружения
    local install_env=""
    
    if [[ -n "$K3S_VERSION" ]]; then
        install_env+="INSTALL_K3S_VERSION=$K3S_VERSION "
    fi
    
    # Формирование аргументов K3s
    local k3s_args=""
    
    case $MODE in
        single)
            print_info "Режим: single-node (control plane + worker)"
            ;;
        server)
            print_info "Режим: server (control plane only)"
            if [[ "$CLUSTER_INIT" == "1" ]]; then
                k3s_args+=" --cluster-init"
                print_info "Инициализация HA кластера с etcd"
            fi
            if [[ -n "$SERVER_URL" ]]; then
                k3s_args+=" --server $SERVER_URL"
            fi
            ;;
        agent)
            print_info "Режим: agent (worker only)"
            install_env+="INSTALL_K3S_EXEC=agent "
            if [[ -z "$SERVER_URL" ]]; then
                print_error "Для agent требуется --server URL"
                exit 1
            fi
            k3s_args+=" --server $SERVER_URL"
            ;;
    esac
    
    # Токен
    if [[ -n "$TOKEN" ]]; then
        k3s_args+=" --token $TOKEN"
    elif [[ -n "$TOKEN_FILE" ]]; then
        k3s_args+=" --token-file $TOKEN_FILE"
    elif [[ "$MODE" == "agent" ]]; then
        print_error "Для agent требуется --token или --token-file"
        exit 1
    fi
    
    # Имя узла
    if [[ -n "$NODE_NAME" ]]; then
        k3s_args+=" --node-name $NODE_NAME"
    fi
    
    # IP узла
    if [[ -n "$NODE_IP" ]]; then
        k3s_args+=" --node-ip $NODE_IP"
        k3s_args+=" --node-external-ip $NODE_IP"
    fi
    
    # TLS SAN
    if [[ -n "$TLS_SAN" ]]; then
        for san in $(echo "$TLS_SAN" | tr ',' ' '); do
            k3s_args+=" --tls-san $san"
        done
    fi
    
    # Flannel backend
    if [[ "$MODE" != "agent" ]]; then
        k3s_args+=" --flannel-backend $FLANNEL_BACKEND"
    fi
    
    # Отключение компонентов
    if [[ "$DISABLE_TRAEFIK" == "1" && "$MODE" != "agent" ]]; then
        k3s_args+=" --disable traefik"
        print_info "Traefik отключён"
    fi
    
    if [[ "$DISABLE_SERVICELB" == "1" && "$MODE" != "agent" ]]; then
        k3s_args+=" --disable servicelb"
        print_info "ServiceLB отключён"
    fi
    
    if [[ "$DISABLE_LOCAL_STORAGE" == "1" && "$MODE" != "agent" ]]; then
        k3s_args+=" --disable local-storage"
        print_info "Local Path Provisioner отключён"
    fi
    
    if [[ "$DISABLE_METRICS_SERVER" == "1" && "$MODE" != "agent" ]]; then
        k3s_args+=" --disable metrics-server"
        print_info "Metrics Server отключён"
    fi
    
    # Data directory
    if [[ "$DATA_DIR" != "/var/lib/rancher/k3s" ]]; then
        k3s_args+=" --data-dir $DATA_DIR"
    fi
    
    # Kubeconfig mode
    k3s_args+=" --write-kubeconfig-mode $KUBECONFIG_MODE"
    
    # Формирование команды установки
    local install_cmd="curl -sfL https://get.k3s.io | ${install_env}sh -s - $k3s_args"
    
    print_info "Команда установки:"
    echo "  $install_cmd"
    echo ""
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки K3s"
        return
    fi
    
    # Выполнение установки
    eval "$install_cmd"
    
    # Ожидание готовности
    print_info "Ожидание готовности K3s..."
    local attempts=0
    local max_attempts=60
    
    while [[ $attempts -lt $max_attempts ]]; do
        if [[ "$MODE" == "agent" ]]; then
            if systemctl is-active --quiet k3s-agent; then
                print_info "K3s agent запущен"
                break
            fi
        else
            if kubectl get nodes &> /dev/null; then
                print_info "K3s готов"
                break
            fi
        fi
        
        attempts=$((attempts + 1))
        sleep 2
    done
    
    if [[ $attempts -ge $max_attempts ]]; then
        print_warn "Таймаут ожидания готовности K3s"
        print_info "Проверьте логи: journalctl -u k3s"
    fi
}

# Настройка kubectl
setup_kubectl() {
    if [[ "$MODE" == "agent" ]]; then
        return
    fi
    
    print_step "Настройка kubectl..."
    
    # Создание симлинка для kubectl
    if [[ ! -f /usr/local/bin/kubectl ]]; then
        ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
    fi
    
    # Настройка KUBECONFIG для root
    local kubeconfig="/etc/rancher/k3s/k3s.yaml"
    
    if [[ -f "$kubeconfig" ]]; then
        # Добавление в профиль
        if ! grep -q "KUBECONFIG" /root/.bashrc; then
            echo "" >> /root/.bashrc
            echo "# Kubernetes" >> /root/.bashrc
            echo "export KUBECONFIG=$kubeconfig" >> /root/.bashrc
        fi
        
        export KUBECONFIG="$kubeconfig"
        print_info "KUBECONFIG настроен: $kubeconfig"
    fi
    
    # Автодополнение
    if command -v kubectl &> /dev/null; then
        kubectl completion bash > /etc/bash_completion.d/kubectl 2>/dev/null || true
    fi
}

# Вывод итоговой информации
print_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}K3s установлен успешно${NC}"
    echo "============================================"
    echo ""
    
    if [[ "$MODE" == "agent" ]]; then
        echo "Режим: Agent (Worker)"
        echo ""
        echo "Проверка статуса:"
        echo "  systemctl status k3s-agent"
        echo ""
        echo "Логи:"
        echo "  journalctl -u k3s-agent -f"
    else
        echo "Режим: $([ "$MODE" == "single" ] && echo "Single-node" || echo "Server")"
        echo ""
        
        # Вывод узлов
        if kubectl get nodes &> /dev/null; then
            echo "Узлы кластера:"
            kubectl get nodes
            echo ""
        fi
        
        echo "Конфигурация kubectl:"
        echo "  /etc/rancher/k3s/k3s.yaml"
        echo ""
        
        if [[ "$CLUSTER_INIT" == "1" ]] || [[ "$MODE" == "server" ]]; then
            echo "Токен для подключения worker nodes:"
            if [[ -f /var/lib/rancher/k3s/server/node-token ]]; then
                echo "  $(cat /var/lib/rancher/k3s/server/node-token)"
            fi
            echo ""
            echo "Команда для worker node:"
            local server_ip
            server_ip=$(hostname -I | awk '{print $1}')
            echo "  ./install.sh --mode agent \\"
            echo "    --server https://${server_ip}:6443 \\"
            echo "    --token <TOKEN>"
        fi
        
        echo ""
        echo "Полезные команды:"
        echo "  kubectl get nodes        # Список узлов"
        echo "  kubectl get pods -A      # Все поды"
        echo "  kubectl get svc -A       # Все сервисы"
        echo "  k3s check-config         # Проверка конфигурации"
        echo ""
        echo "Логи:"
        echo "  journalctl -u k3s -f"
    fi
    
    echo ""
    echo "============================================"
}

# Удаление K3s
uninstall_k3s() {
    print_step "Удаление K3s..."
    
    if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
        print_info "Запуск k3s-uninstall.sh..."
        /usr/local/bin/k3s-uninstall.sh
    elif [[ -f /usr/local/bin/k3s-agent-uninstall.sh ]]; then
        print_info "Запуск k3s-agent-uninstall.sh..."
        /usr/local/bin/k3s-agent-uninstall.sh
    else
        print_warn "Скрипты удаления не найдены. K3s возможно не установлен."
    fi
    
    print_info "K3s удалён"
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            if [[ ! "$MODE" =~ ^(single|server|agent)$ ]]; then
                print_error "Неверный режим: $MODE. Допустимые: single, server, agent"
                exit 1
            fi
            shift 2
            ;;
        --version)
            K3S_VERSION="$2"
            shift 2
            ;;
        --cluster-init)
            CLUSTER_INIT="1"
            shift
            ;;
        --server)
            SERVER_URL="$2"
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
        --node-name)
            NODE_NAME="$2"
            shift 2
            ;;
        --node-ip)
            NODE_IP="$2"
            shift 2
            ;;
        --tls-san)
            TLS_SAN="$2"
            shift 2
            ;;
        --flannel-backend)
            FLANNEL_BACKEND="$2"
            shift 2
            ;;
        --disable-traefik)
            DISABLE_TRAEFIK="1"
            shift
            ;;
        --disable-servicelb)
            DISABLE_SERVICELB="1"
            shift
            ;;
        --disable-local-storage)
            DISABLE_LOCAL_STORAGE="1"
            shift
            ;;
        --disable-metrics-server)
            DISABLE_METRICS_SERVER="1"
            shift
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --no-kubectl)
            INSTALL_KUBECTL="0"
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
    uninstall_k3s
fi

check_requirements

if [[ "$DRY_RUN" != "1" ]]; then
    prepare_system
fi

install_k3s

if [[ "$DRY_RUN" != "1" ]]; then
    setup_kubectl
    print_summary
fi

