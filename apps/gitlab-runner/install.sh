#!/bin/bash

#############################################
# GitLab Runner Installation Script for LXC
# Поддерживает shell и docker executor'ы
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Значения по умолчанию
GITLAB_URL=""
RUNNER_TOKEN=""
EXECUTOR="shell"
DESCRIPTION=""
TAGS=""
DOCKER_IMAGE="alpine:latest"
DOCKER_PRIVILEGED=false
LOCKED=false
RUN_UNTAGGED=true
INSTALL_DOCKER=false

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
  --url URL                 URL GitLab сервера (обязательно)
  --token TOKEN             Токен регистрации Runner (обязательно)
  --executor EXECUTOR       Тип executor'а: shell, docker (по умолчанию: shell)
  --description DESC        Описание Runner'а (по умолчанию: hostname)
  --tags TAGS               Теги через запятую
  --docker-image IMAGE      Docker образ по умолчанию (по умолчанию: alpine:latest)
  --docker-privileged       Разрешить privileged режим для Docker
  --locked                  Привязать Runner к проекту
  --run-untagged            Выполнять задачи без тегов (по умолчанию: true)
  --install-docker          Установить Docker (для docker executor)
  --help                    Показать эту справку

Примеры:
  # Shell executor
  $0 --url https://gitlab.example.com --token glrt-XXXX --executor shell

  # Docker executor
  $0 --url https://gitlab.example.com --token glrt-XXXX --executor docker --install-docker

  # С тегами
  $0 --url https://gitlab.example.com --token glrt-XXXX --executor docker --tags "docker,linux,build"

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            GITLAB_URL="$2"
            shift 2
            ;;
        --token)
            RUNNER_TOKEN="$2"
            shift 2
            ;;
        --executor)
            EXECUTOR="$2"
            shift 2
            ;;
        --description)
            DESCRIPTION="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --docker-image)
            DOCKER_IMAGE="$2"
            shift 2
            ;;
        --docker-privileged)
            DOCKER_PRIVILEGED=true
            shift
            ;;
        --locked)
            LOCKED=true
            shift
            ;;
        --run-untagged)
            RUN_UNTAGGED=true
            shift
            ;;
        --no-run-untagged)
            RUN_UNTAGGED=false
            shift
            ;;
        --install-docker)
            INSTALL_DOCKER=true
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

# Проверка обязательных параметров
if [ -z "$GITLAB_URL" ]; then
    print_error "URL GitLab сервера обязателен!"
    print_error "Используйте --url https://gitlab.example.com"
    exit 1
fi

if [ -z "$RUNNER_TOKEN" ]; then
    print_error "Токен регистрации обязателен!"
    print_error "Используйте --token glrt-XXXXXXXXXXXXXXXXXXXX"
    exit 1
fi

# Проверка executor'а
if [ "$EXECUTOR" != "shell" ] && [ "$EXECUTOR" != "docker" ]; then
    print_error "Неподдерживаемый executor: $EXECUTOR"
    print_error "Доступные варианты: shell, docker"
    exit 1
fi

# Установка описания по умолчанию
if [ -z "$DESCRIPTION" ]; then
    DESCRIPTION="GitLab Runner on $(hostname)"
fi

print_info "Начало установки GitLab Runner..."
print_info "GitLab URL: $GITLAB_URL"
print_info "Executor: $EXECUTOR"
print_info "Описание: $DESCRIPTION"

if [ -n "$TAGS" ]; then
    print_info "Теги: $TAGS"
fi

# Определение дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

print_info "Обнаружена ОС: $OS $VERSION"

# Определение архитектуры
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        RUNNER_ARCH="amd64"
        ;;
    aarch64)
        RUNNER_ARCH="arm64"
        ;;
    *)
        print_error "Неподдерживаемая архитектура: $ARCH"
        exit 1
        ;;
esac

print_info "Архитектура: $RUNNER_ARCH"

# Установка Docker если требуется
if [ "$INSTALL_DOCKER" = true ] || [ "$EXECUTOR" = "docker" ]; then
    if ! command -v docker &> /dev/null; then
        print_info "Установка Docker..."
        
        # Удаление старых версий
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Установка зависимостей
        apt-get update
        apt-get install -y \
            ca-certificates \
            curl \
            gnupg \
            lsb-release
        
        # Добавление GPG ключа Docker
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        
        # Добавление репозитория
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
            $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
            tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Установка Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Запуск Docker
        systemctl enable docker
        systemctl start docker
        
        # Проверка
        if docker run --rm hello-world &>/dev/null; then
            print_info "✓ Docker успешно установлен"
        else
            print_warn "Docker установлен, но тест не прошёл"
            print_warn "Возможно, требуется настройка LXC контейнера (nesting=1)"
        fi
    else
        print_info "Docker уже установлен"
    fi
fi

# Установка GitLab Runner
print_info "Установка GitLab Runner..."

# Добавление репозитория GitLab Runner
curl -fsSL https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash

# Установка
apt-get install -y gitlab-runner

# Проверка установки
if ! command -v gitlab-runner &> /dev/null; then
    print_error "Не удалось установить GitLab Runner"
    exit 1
fi

RUNNER_VERSION=$(gitlab-runner --version | head -n1)
print_info "Установлен: $RUNNER_VERSION"

# Добавление gitlab-runner в группу docker (если Docker установлен)
if [ "$EXECUTOR" = "docker" ] && getent group docker &>/dev/null; then
    usermod -aG docker gitlab-runner
    print_info "Пользователь gitlab-runner добавлен в группу docker"
fi

# Формирование команды регистрации
print_info "Регистрация Runner..."

REGISTER_CMD="gitlab-runner register --non-interactive"
REGISTER_CMD+=" --url $GITLAB_URL"
REGISTER_CMD+=" --token $RUNNER_TOKEN"
REGISTER_CMD+=" --executor $EXECUTOR"
REGISTER_CMD+=" --description \"$DESCRIPTION\""

if [ -n "$TAGS" ]; then
    REGISTER_CMD+=" --tag-list \"$TAGS\""
fi

if [ "$LOCKED" = true ]; then
    REGISTER_CMD+=" --locked"
fi

if [ "$RUN_UNTAGGED" = true ]; then
    REGISTER_CMD+=" --run-untagged"
fi

# Параметры для Docker executor
if [ "$EXECUTOR" = "docker" ]; then
    REGISTER_CMD+=" --docker-image $DOCKER_IMAGE"
    
    if [ "$DOCKER_PRIVILEGED" = true ]; then
        REGISTER_CMD+=" --docker-privileged"
    fi
    
    REGISTER_CMD+=" --docker-volumes /cache"
fi

# Выполнение регистрации
eval $REGISTER_CMD

if [ $? -eq 0 ]; then
    print_info "✓ Runner успешно зарегистрирован"
else
    print_error "Ошибка регистрации Runner"
    print_error "Проверьте URL и токен"
    exit 1
fi

# Перезапуск сервиса
print_info "Перезапуск сервиса..."
systemctl restart gitlab-runner

# Проверка статуса
sleep 2

if systemctl is-active --quiet gitlab-runner; then
    print_info "✓ GitLab Runner запущен"
else
    print_error "Не удалось запустить GitLab Runner"
    print_error "Проверьте: sudo journalctl -u gitlab-runner -n 50"
    exit 1
fi

# Проверка связи с GitLab
print_info "Проверка связи с GitLab..."
if gitlab-runner verify 2>&1 | grep -q "is alive"; then
    print_info "✓ Связь с GitLab установлена"
else
    print_warn "Не удалось проверить связь с GitLab"
    print_warn "Runner может заработать после некоторого времени"
fi

# Вывод информации
echo ""
echo "=============================================="
print_info "GitLab Runner установлен!"
echo "=============================================="
echo ""
print_info "URL: $GITLAB_URL"
print_info "Executor: $EXECUTOR"
print_info "Описание: $DESCRIPTION"

if [ -n "$TAGS" ]; then
    print_info "Теги: $TAGS"
fi

echo ""
print_info "Управление:"
echo "  gitlab-runner status    - статус"
echo "  gitlab-runner list      - список Runner'ов"
echo "  gitlab-runner verify    - проверка связи"
echo "  systemctl restart gitlab-runner - перезапуск"
echo "  journalctl -u gitlab-runner -f  - логи"
echo ""
print_info "Конфигурация: /etc/gitlab-runner/config.toml"
echo ""

if [ "$EXECUTOR" = "docker" ]; then
    print_info "Docker образ по умолчанию: $DOCKER_IMAGE"
    if [ "$DOCKER_PRIVILEGED" = true ]; then
        print_warn "Privileged режим включён"
    fi
fi

echo ""
print_info "Пример .gitlab-ci.yml:"
echo ""
cat << 'EOF'
stages:
  - build
  - test

build:
EOF

if [ -n "$TAGS" ]; then
    FIRST_TAG=$(echo "$TAGS" | cut -d',' -f1)
    echo "  tags:"
    echo "    - $FIRST_TAG"
fi

if [ "$EXECUTOR" = "docker" ]; then
    echo "  image: $DOCKER_IMAGE"
fi

cat << 'EOF'
  script:
    - echo "Building..."

test:
EOF

if [ -n "$TAGS" ]; then
    echo "  tags:"
    echo "    - $FIRST_TAG"
fi

if [ "$EXECUTOR" = "docker" ]; then
    echo "  image: $DOCKER_IMAGE"
fi

cat << 'EOF'
  script:
    - echo "Testing..."
EOF

echo ""

