#!/bin/bash

#############################################
# Longhorn Installation Script
# Установка Longhorn — распределённого хранилища для Kubernetes
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
LONGHORN_VERSION="v1.7.2"
USE_HELM="0"
DATA_PATH="/var/lib/longhorn"
REPLICA_COUNT="3"
SET_DEFAULT_SC="1"
ENABLE_UI="1"
DRY_RUN="0"
UNINSTALL="0"
CHECK_ONLY="0"

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

Установка Longhorn — распределённого блочного хранилища для Kubernetes.

Опции:
  --version VERSION        Версия Longhorn (по умолчанию: $LONGHORN_VERSION)
  --helm                   Использовать Helm для установки
  --data-path PATH         Путь для данных (по умолчанию: /var/lib/longhorn)
  --replicas N             Количество реплик (по умолчанию: 3)
  --no-default-sc          Не делать Longhorn StorageClass по умолчанию
  --no-ui                  Не устанавливать веб-интерфейс
  --check                  Только проверить требования
  --uninstall              Удалить Longhorn
  --dry-run                Показать команды без выполнения
  --help                   Показать эту справку

Требования к узлам:
  - open-iscsi (iscsiadm)
  - NFSv4 client (для RWX volumes)
  - curl, findmnt, grep, awk, blkid, lsblk

Примеры:
  # Проверка требований
  $0 --check

  # Базовая установка
  $0

  # С кастомным путём данных
  $0 --data-path /mnt/storage/longhorn

  # Для single-node (1 реплика)
  $0 --replicas 1

После установки:
  kubectl get pods -n longhorn-system
  kubectl get sc     # StorageClass

Создание PVC:
  kubectl apply -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: my-pvc
  spec:
    accessModes:
      - ReadWriteOnce
    storageClassName: longhorn
    resources:
      requests:
        storage: 5Gi
  EOF

EOF
    exit 0
}

# Проверка требований на узле
check_node_requirements() {
    print_step "Проверка требований на узле..."
    
    local errors=0
    local warnings=0
    
    # Проверка open-iscsi
    if command -v iscsiadm &> /dev/null; then
        print_info "✓ iscsiadm найден"
    else
        print_error "✗ iscsiadm не найден (установите open-iscsi)"
        errors=$((errors + 1))
    fi
    
    # Проверка iscsid сервиса
    if systemctl is-active --quiet iscsid 2>/dev/null; then
        print_info "✓ iscsid сервис активен"
    elif systemctl is-enabled --quiet iscsid 2>/dev/null; then
        print_warn "⚠ iscsid сервис не запущен"
        warnings=$((warnings + 1))
    else
        print_error "✗ iscsid сервис не настроен"
        errors=$((errors + 1))
    fi
    
    # Проверка NFS client (для RWX)
    if command -v mount.nfs4 &> /dev/null || [[ -f /sbin/mount.nfs4 ]]; then
        print_info "✓ NFS client найден"
    else
        print_warn "⚠ NFS client не найден (нужен для RWX volumes)"
        warnings=$((warnings + 1))
    fi
    
    # Проверка утилит
    local utils=("curl" "findmnt" "grep" "awk" "blkid" "lsblk")
    for util in "${utils[@]}"; do
        if command -v "$util" &> /dev/null; then
            print_info "✓ $util найден"
        else
            print_error "✗ $util не найден"
            errors=$((errors + 1))
        fi
    done
    
    # Проверка каталога данных
    local data_dir=$(dirname "$DATA_PATH")
    if [[ -d "$data_dir" ]]; then
        local free_space
        free_space=$(df -BG "$data_dir" | awk 'NR==2 {print $4}' | tr -d 'G')
        if [[ $free_space -lt 10 ]]; then
            print_warn "⚠ Мало свободного места в $data_dir: ${free_space}GB"
            warnings=$((warnings + 1))
        else
            print_info "✓ Свободное место в $data_dir: ${free_space}GB"
        fi
    fi
    
    # Проверка multipathd (может конфликтовать)
    if systemctl is-active --quiet multipathd 2>/dev/null; then
        print_warn "⚠ multipathd активен — может конфликтовать с Longhorn"
        print_info "  Рекомендуется добавить blacklist в /etc/multipath.conf"
        warnings=$((warnings + 1))
    fi
    
    echo ""
    if [[ $errors -gt 0 ]]; then
        print_error "Обнаружено $errors ошибок. Исправьте перед установкой."
        echo ""
        echo "Установка зависимостей (Debian/Ubuntu):"
        echo "  apt-get update && apt-get install -y open-iscsi nfs-common"
        echo "  systemctl enable --now iscsid"
        return 1
    elif [[ $warnings -gt 0 ]]; then
        print_warn "Обнаружено $warnings предупреждений."
        return 0
    else
        print_info "Все требования выполнены"
        return 0
    fi
}

# Установка зависимостей на узле
install_dependencies() {
    print_step "Установка зависимостей..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки зависимостей"
        return
    fi
    
    # Определение дистрибутива
    if [[ -f /etc/debian_version ]]; then
        apt-get update
        apt-get install -y open-iscsi nfs-common
    elif [[ -f /etc/redhat-release ]]; then
        yum install -y iscsi-initiator-utils nfs-utils
    else
        print_warn "Неизвестный дистрибутив. Установите open-iscsi и nfs-common вручную."
        return
    fi
    
    # Запуск iscsid
    systemctl enable --now iscsid
    
    print_info "Зависимости установлены"
}

# Проверка требований кластера
check_cluster_requirements() {
    print_step "Проверка требований кластера..."
    
    # Проверка kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl не найден"
        return 1
    fi
    
    # Проверка подключения к кластеру
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Не удаётся подключиться к Kubernetes кластеру"
        return 1
    fi
    
    # Количество узлов
    local node_count
    node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    print_info "Количество узлов: $node_count"
    
    if [[ $node_count -lt $REPLICA_COUNT ]]; then
        print_warn "Узлов ($node_count) меньше чем реплик ($REPLICA_COUNT)"
        print_info "Рекомендуется: --replicas $node_count"
    fi
    
    return 0
}

# Установка через kubectl
install_kubectl() {
    print_step "Установка Longhorn через kubectl..."
    
    local manifest_url="https://raw.githubusercontent.com/longhorn/longhorn/${LONGHORN_VERSION}/deploy/longhorn.yaml"
    
    print_info "Манифест: $manifest_url"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки"
        return
    fi
    
    # Применение манифеста
    kubectl apply -f "$manifest_url"
    
    # Ожидание готовности
    print_info "Ожидание готовности Longhorn (это может занять несколько минут)..."
    kubectl wait --namespace longhorn-system \
        --for=condition=ready pod \
        --selector=app=longhorn-manager \
        --timeout=300s 2>/dev/null || print_warn "Таймаут ожидания longhorn-manager"
    
    print_info "Longhorn установлен"
}

# Установка через Helm
install_helm() {
    print_step "Установка Longhorn через Helm..."
    
    if ! command -v helm &> /dev/null; then
        print_error "Helm не найден. Установите Helm или используйте установку без --helm"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки через Helm"
        return
    fi
    
    # Добавление репозитория
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    
    # Установка
    helm install longhorn longhorn/longhorn \
        --namespace longhorn-system \
        --create-namespace \
        --version "${LONGHORN_VERSION#v}" \
        --set defaultSettings.defaultDataPath="$DATA_PATH" \
        --set defaultSettings.defaultReplicaCount="$REPLICA_COUNT" \
        --set defaultSettings.createDefaultDiskLabeledNodes=true
    
    # Ожидание готовности
    print_info "Ожидание готовности Longhorn..."
    kubectl wait --namespace longhorn-system \
        --for=condition=ready pod \
        --selector=app=longhorn-manager \
        --timeout=300s 2>/dev/null || print_warn "Таймаут ожидания"
    
    print_info "Longhorn установлен через Helm"
}

# Настройка после установки
configure_longhorn() {
    print_step "Настройка Longhorn..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск настройки"
        return
    fi
    
    # Ожидание появления CRD
    local attempts=0
    while [[ $attempts -lt 30 ]]; do
        if kubectl get crd settings.longhorn.io &> /dev/null; then
            break
        fi
        attempts=$((attempts + 1))
        sleep 2
    done
    
    # Настройка количества реплик
    if kubectl get settings.longhorn.io -n longhorn-system &> /dev/null; then
        kubectl patch settings.longhorn.io default-replica-count -n longhorn-system \
            --type=merge -p "{\"value\": \"$REPLICA_COUNT\"}" 2>/dev/null || true
        print_info "Установлено реплик: $REPLICA_COUNT"
    fi
    
    # Установка default StorageClass
    if [[ "$SET_DEFAULT_SC" == "1" ]]; then
        # Снятие default с других SC
        for sc in $(kubectl get sc -o jsonpath='{.items[*].metadata.name}'); do
            if [[ "$sc" != "longhorn" ]]; then
                kubectl patch sc "$sc" -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' 2>/dev/null || true
            fi
        done
        
        # Установка longhorn как default
        kubectl patch sc longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || true
        print_info "Longhorn установлен как default StorageClass"
    fi
}

# Удаление Longhorn
uninstall_longhorn() {
    print_step "Удаление Longhorn..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск удаления"
        return
    fi
    
    # Удаление через Helm (если установлен через Helm)
    if helm list -n longhorn-system 2>/dev/null | grep -q longhorn; then
        print_info "Удаление через Helm..."
        helm uninstall longhorn -n longhorn-system
    else
        print_info "Удаление через kubectl..."
        local manifest_url="https://raw.githubusercontent.com/longhorn/longhorn/${LONGHORN_VERSION}/deploy/longhorn.yaml"
        kubectl delete -f "$manifest_url" --ignore-not-found=true
    fi
    
    # Удаление namespace
    kubectl delete namespace longhorn-system --ignore-not-found=true
    
    # Удаление CRD
    for crd in $(kubectl get crd -o name | grep longhorn); do
        kubectl delete "$crd" --ignore-not-found=true
    done
    
    print_info "Longhorn удалён"
    print_warn "Данные в $DATA_PATH не удалены. Удалите вручную при необходимости."
    exit 0
}

# Вывод итоговой информации
print_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}Longhorn установлен успешно${NC}"
    echo "============================================"
    echo ""
    echo "Версия: $LONGHORN_VERSION"
    echo "Путь данных: $DATA_PATH"
    echo "Реплик по умолчанию: $REPLICA_COUNT"
    echo ""
    
    echo "Проверка статуса:"
    echo "  kubectl get pods -n longhorn-system"
    echo "  kubectl get nodes -n longhorn-system"
    echo "  kubectl get sc"
    echo ""
    
    if [[ "$ENABLE_UI" == "1" ]]; then
        echo "Веб-интерфейс Longhorn:"
        echo "  kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
        echo "  Открыть: http://localhost:8080"
        echo ""
    fi
    
    echo "Создание PVC:"
    cat << 'EOF'
  kubectl apply -f - <<YAML
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: my-pvc
  spec:
    accessModes:
      - ReadWriteOnce
    storageClassName: longhorn
    resources:
      requests:
        storage: 5Gi
  YAML
EOF
    echo ""
    echo "============================================"
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            LONGHORN_VERSION="$2"
            shift 2
            ;;
        --helm)
            USE_HELM="1"
            shift
            ;;
        --data-path)
            DATA_PATH="$2"
            shift 2
            ;;
        --replicas)
            REPLICA_COUNT="$2"
            shift 2
            ;;
        --no-default-sc)
            SET_DEFAULT_SC="0"
            shift
            ;;
        --no-ui)
            ENABLE_UI="0"
            shift
            ;;
        --check)
            CHECK_ONLY="1"
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
            exit 1
            ;;
    esac
done

# Основной процесс
if [[ "$CHECK_ONLY" == "1" ]]; then
    check_node_requirements
    check_cluster_requirements
    exit $?
fi

if [[ "$UNINSTALL" == "1" ]]; then
    uninstall_longhorn
fi

# Проверка требований
if ! check_node_requirements; then
    read -p "Установить зависимости? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_dependencies
    else
        exit 1
    fi
fi

check_cluster_requirements || exit 1

# Установка
if [[ "$USE_HELM" == "1" ]]; then
    install_helm
else
    install_kubectl
fi

configure_longhorn

if [[ "$DRY_RUN" != "1" ]]; then
    print_summary
fi

