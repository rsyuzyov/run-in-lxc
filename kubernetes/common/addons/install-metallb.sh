#!/bin/bash

#############################################
# MetalLB Installation Script
# Установка MetalLB — LoadBalancer для bare-metal
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
METALLB_VERSION="v0.14.8"
ADDRESS_POOL=""
POOL_NAME="default"
MODE="layer2"  # layer2 или bgp
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

Установка MetalLB — реализации LoadBalancer для bare-metal Kubernetes.

Опции:
  --version VERSION        Версия MetalLB (по умолчанию: $METALLB_VERSION)
  --address-pool RANGE     Диапазон IP адресов (например: 192.168.1.200-192.168.1.220)
  --pool-name NAME         Имя пула адресов (по умолчанию: default)
  --mode MODE              Режим работы: layer2 или bgp (по умолчанию: layer2)
  --uninstall              Удалить MetalLB
  --dry-run                Показать команды без выполнения
  --help                   Показать эту справку

Примеры:
  # Установка с пулом адресов
  $0 --address-pool 192.168.1.200-192.168.1.220

  # CIDR нотация
  $0 --address-pool 192.168.1.200/28

  # Несколько диапазонов (через запятую)
  $0 --address-pool "192.168.1.200-192.168.1.210,192.168.2.100-192.168.2.110"

  # Без пула (настроить позже)
  $0

После установки:
  kubectl get pods -n metallb-system
  kubectl get ipaddresspool -n metallb-system

Создание сервиса с LoadBalancer:
  kubectl expose deployment nginx --type=LoadBalancer --port=80

EOF
    exit 0
}

# Проверка требований
check_requirements() {
    print_step "Проверка требований..."
    
    # Проверка kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl не найден. Установите Kubernetes сначала."
        exit 1
    fi
    
    # Проверка подключения к кластеру
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удаётся подключиться к Kubernetes кластеру"
        exit 1
    fi
}

# Подготовка кластера
prepare_cluster() {
    print_step "Подготовка кластера для MetalLB..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск подготовки кластера"
        return
    fi
    
    # Включение strict ARP для kube-proxy (если используется IPVS)
    if kubectl get configmap kube-proxy -n kube-system &> /dev/null; then
        print_info "Проверка настроек kube-proxy..."
        
        # Получение текущей конфигурации
        local current_mode
        current_mode=$(kubectl get configmap kube-proxy -n kube-system -o jsonpath='{.data.config\.conf}' 2>/dev/null | grep -o 'mode: "[^"]*"' | cut -d'"' -f2 || echo "")
        
        if [[ "$current_mode" == "ipvs" ]]; then
            print_info "Обнаружен IPVS режим, включение strictARP..."
            kubectl get configmap kube-proxy -n kube-system -o yaml | \
                sed -e "s/strictARP: false/strictARP: true/" | \
                kubectl apply -f - 2>/dev/null || true
        fi
    fi
}

# Установка MetalLB
install_metallb() {
    print_step "Установка MetalLB $METALLB_VERSION..."
    
    local manifest_url="https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
    
    print_info "Манифест: $manifest_url"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки MetalLB"
        return
    fi
    
    # Создание namespace (если не существует)
    kubectl create namespace metallb-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Установка MetalLB
    kubectl apply -f "$manifest_url"
    
    # Ожидание готовности
    print_info "Ожидание готовности MetalLB..."
    kubectl wait --namespace metallb-system \
        --for=condition=ready pod \
        --selector=app=metallb \
        --timeout=120s 2>/dev/null || print_warn "Таймаут ожидания подов"
    
    print_info "MetalLB установлен"
}

# Настройка пула адресов
configure_pool() {
    if [[ -z "$ADDRESS_POOL" ]]; then
        print_warn "Пул адресов не указан. Настройте позже с помощью:"
        echo "  kubectl apply -f ipaddresspool.yaml"
        return
    fi
    
    print_step "Настройка пула адресов..."
    
    # Парсинг адресов (поддержка нескольких диапазонов)
    local addresses=""
    IFS=',' read -ra ADDR_ARRAY <<< "$ADDRESS_POOL"
    for addr in "${ADDR_ARRAY[@]}"; do
        addresses+="    - $addr"$'\n'
    done
    
    # Создание IPAddressPool
    local pool_manifest=$(cat << EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: $POOL_NAME
  namespace: metallb-system
spec:
  addresses:
${addresses}
EOF
)
    
    print_info "IPAddressPool:"
    echo "$pool_manifest"
    echo ""
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск создания пула"
        return
    fi
    
    # Применение
    echo "$pool_manifest" | kubectl apply -f -
    
    # Создание L2Advertisement (для Layer2 режима)
    if [[ "$MODE" == "layer2" ]]; then
        local l2_manifest=$(cat << EOF
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: $POOL_NAME
  namespace: metallb-system
spec:
  ipAddressPools:
    - $POOL_NAME
EOF
)
        
        print_info "L2Advertisement:"
        echo "$l2_manifest"
        echo ""
        
        echo "$l2_manifest" | kubectl apply -f -
    fi
    
    print_info "Пул адресов настроен"
}

# Удаление MetalLB
uninstall_metallb() {
    print_step "Удаление MetalLB..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск удаления"
        return
    fi
    
    # Удаление ресурсов
    local manifest_url="https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
    kubectl delete -f "$manifest_url" --ignore-not-found=true
    
    # Удаление namespace
    kubectl delete namespace metallb-system --ignore-not-found=true
    
    print_info "MetalLB удалён"
    exit 0
}

# Вывод итоговой информации
print_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}MetalLB установлен успешно${NC}"
    echo "============================================"
    echo ""
    echo "Версия: $METALLB_VERSION"
    echo "Режим: $MODE"
    
    if [[ -n "$ADDRESS_POOL" ]]; then
        echo "Пул адресов: $ADDRESS_POOL"
    fi
    echo ""
    
    echo "Проверка статуса:"
    echo "  kubectl get pods -n metallb-system"
    echo "  kubectl get ipaddresspool -n metallb-system"
    echo ""
    
    echo "Создание сервиса с LoadBalancer:"
    echo "  kubectl expose deployment <name> --type=LoadBalancer --port=<port>"
    echo ""
    
    echo "Проверка IP:"
    echo "  kubectl get svc"
    echo ""
    
    if [[ -z "$ADDRESS_POOL" ]]; then
        echo "ВАЖНО: Настройте пул адресов!"
        echo "Пример:"
        cat << 'EOF'
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
    - 192.168.1.200-192.168.1.220
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default
EOF
    fi
    
    echo ""
    echo "============================================"
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            METALLB_VERSION="$2"
            shift 2
            ;;
        --address-pool)
            ADDRESS_POOL="$2"
            shift 2
            ;;
        --pool-name)
            POOL_NAME="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            if [[ ! "$MODE" =~ ^(layer2|bgp)$ ]]; then
                print_error "Неверный режим: $MODE. Допустимые: layer2, bgp"
                exit 1
            fi
            shift 2
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
            exit 1
            ;;
    esac
done

# Основной процесс
check_requirements

if [[ "$UNINSTALL" == "1" ]]; then
    uninstall_metallb
fi

prepare_cluster
install_metallb
configure_pool

if [[ "$DRY_RUN" != "1" ]]; then
    print_summary
fi

