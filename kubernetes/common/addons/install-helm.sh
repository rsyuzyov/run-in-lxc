#!/bin/bash

#############################################
# Helm Installation Script
# Установка Helm — менеджера пакетов Kubernetes
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
HELM_VERSION=""  # Пустая строка = latest
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Функция помощи
show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Установка Helm — менеджера пакетов для Kubernetes.

Опции:
  --version VERSION    Версия Helm (по умолчанию: latest)
  --dry-run            Показать команды без выполнения
  --help               Показать эту справку

Примеры:
  # Установка последней версии
  $0

  # Установка конкретной версии
  $0 --version v3.14.0

После установки:
  helm version          # Проверка версии
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm search repo nginx
  helm install my-nginx bitnami/nginx

EOF
    exit 0
}

# Проверка требований
check_requirements() {
    print_step "Проверка требований..."
    
    # Проверка root
    if [[ $EUID -ne 0 ]]; then
        print_error "Скрипт должен запускаться с правами root"
        exit 1
    fi
    
    # Проверка kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl не найден. Установите Kubernetes сначала."
        exit 1
    fi
    
    # Проверка curl
    if ! command -v curl &> /dev/null; then
        print_info "Установка curl..."
        apt-get update && apt-get install -y curl
    fi
}

# Установка Helm
install_helm() {
    print_step "Установка Helm..."
    
    # Проверка, установлен ли уже
    if command -v helm &> /dev/null; then
        local current_version
        current_version=$(helm version --short 2>/dev/null || echo "unknown")
        print_warn "Helm уже установлен: $current_version"
        read -p "Переустановить? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    local cmd="curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    
    if [[ -n "$HELM_VERSION" ]]; then
        cmd="curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION=$HELM_VERSION bash"
    fi
    
    print_info "Команда установки:"
    echo "  $cmd"
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск установки"
        return
    fi
    
    # Установка
    if [[ -n "$HELM_VERSION" ]]; then
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | DESIRED_VERSION="$HELM_VERSION" bash
    else
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
    
    # Автодополнение
    helm completion bash > /etc/bash_completion.d/helm 2>/dev/null || true
    
    # Вывод версии
    print_info "Helm установлен: $(helm version --short 2>/dev/null || echo 'unknown')"
}

# Добавление популярных репозиториев
add_repos() {
    print_step "Добавление популярных репозиториев..."
    
    if [[ "$DRY_RUN" == "1" ]]; then
        print_warn "[DRY-RUN] Пропуск добавления репозиториев"
        return
    fi
    
    # Bitnami
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    
    # Ingress-nginx
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    
    # Jetstack (cert-manager)
    helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
    
    # Prometheus community
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    
    # Обновление репозиториев
    helm repo update
    
    print_info "Добавленные репозитории:"
    helm repo list
}

# Вывод итоговой информации
print_summary() {
    echo ""
    echo "============================================"
    echo -e "${GREEN}Helm установлен успешно${NC}"
    echo "============================================"
    echo ""
    echo "Версия: $(helm version --short 2>/dev/null)"
    echo ""
    echo "Примеры использования:"
    echo "  helm search repo nginx           # Поиск чартов"
    echo "  helm install my-app bitnami/nginx  # Установка"
    echo "  helm list                        # Список релизов"
    echo "  helm uninstall my-app            # Удаление"
    echo ""
    echo "Добавить репозиторий:"
    echo "  helm repo add <name> <url>"
    echo "  helm repo update"
    echo ""
    echo "============================================"
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            HELM_VERSION="$2"
            shift 2
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
install_helm
add_repos

if [[ "$DRY_RUN" != "1" ]]; then
    print_summary
fi

