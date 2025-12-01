#!/bin/bash

#############################################
# Jenkins Agent Installation Script for LXC
# Установка агента Jenkins в LXC контейнер
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
JENKINS_URL=""
AGENT_NAME=""
AGENT_SECRET=""
AGENT_WORKDIR="/var/lib/jenkins-agent"
JAVA_VERSION="17"
AGENT_USER="jenkins"
AGENT_LABELS=""
EXECUTORS=2
INSTALL_DOCKER=false
INSTALL_GIT=true
MODE="inbound"  # inbound или ssh

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

Установка агента Jenkins (slave) в LXC контейнер.

Режимы подключения:
  inbound (JNLP) - агент подключается к контроллеру (рекомендуется)
  ssh            - контроллер подключается к агенту по SSH

Опции (inbound режим):
  --url URL               URL Jenkins контроллера (обязательно)
  --name NAME             Имя агента (обязательно)
  --secret SECRET         Секрет агента из Jenkins (обязательно)
  --workdir DIR           Рабочая директория (по умолчанию: /var/lib/jenkins-agent)

Опции (ssh режим):
  --mode ssh              Режим SSH агента
  --ssh-user USER         Пользователь для SSH (по умолчанию: jenkins)
  --ssh-key               Сгенерировать SSH ключ

Общие опции:
  --java-version VER      Версия OpenJDK: 11, 17, 21 (по умолчанию: 17)
  --labels LABELS         Метки агента через запятую
  --executors NUM         Количество executor'ов (по умолчанию: 2)
  --install-docker        Установить Docker
  --no-git                Не устанавливать Git
  --help                  Показать эту справку

Примеры:
  # Inbound (JNLP) агент
  $0 --url https://jenkins.example.com \\
     --name agent-01 \\
     --secret xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  # С Docker и метками
  $0 --url https://jenkins.example.com \\
     --name docker-agent \\
     --secret xxxxxxxx \\
     --install-docker \\
     --labels "docker,linux,build"

  # SSH агент
  $0 --mode ssh --ssh-key

Где взять секрет агента:
  1. Jenkins → Manage Jenkins → Nodes
  2. Создайте новый node (Permanent Agent)
  3. Launch method: Launch agent by connecting it to the controller
  4. Скопируйте секрет из команды запуска

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            JENKINS_URL="$2"
            shift 2
            ;;
        --name)
            AGENT_NAME="$2"
            shift 2
            ;;
        --secret)
            AGENT_SECRET="$2"
            shift 2
            ;;
        --workdir)
            AGENT_WORKDIR="$2"
            shift 2
            ;;
        --java-version)
            JAVA_VERSION="$2"
            shift 2
            ;;
        --labels)
            AGENT_LABELS="$2"
            shift 2
            ;;
        --executors)
            EXECUTORS="$2"
            shift 2
            ;;
        --install-docker)
            INSTALL_DOCKER=true
            shift
            ;;
        --no-git)
            INSTALL_GIT=false
            shift
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --ssh-user)
            AGENT_USER="$2"
            shift 2
            ;;
        --ssh-key)
            GENERATE_SSH_KEY=true
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

# Проверка обязательных параметров для inbound режима
if [ "$MODE" = "inbound" ]; then
    if [ -z "$JENKINS_URL" ]; then
        print_error "URL Jenkins контроллера обязателен!"
        print_error "Используйте --url https://jenkins.example.com"
        exit 1
    fi
    
    if [ -z "$AGENT_NAME" ]; then
        print_error "Имя агента обязательно!"
        print_error "Используйте --name agent-01"
        exit 1
    fi
    
    if [ -z "$AGENT_SECRET" ]; then
        print_error "Секрет агента обязателен!"
        print_error "Используйте --secret xxxxxxxxxxxxxxxx"
        exit 1
    fi
fi

# Определение дистрибутива
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        CODENAME=$VERSION_CODENAME
    else
        print_error "Не удалось определить дистрибутив"
        exit 1
    fi
    
    print_info "Обнаружена ОС: $OS $VERSION"
}

# Установка зависимостей
install_dependencies() {
    print_step "Установка зависимостей..."
    
    apt-get update
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        wget \
        fontconfig
    
    if [ "$INSTALL_GIT" = true ]; then
        apt-get install -y git
        print_info "✓ Git установлен"
    fi
}

# Установка Java
install_java() {
    print_step "Установка OpenJDK ${JAVA_VERSION}..."
    
    apt-get install -y "openjdk-${JAVA_VERSION}-jdk-headless"
    
    local java_ver=$(java -version 2>&1 | head -n1)
    print_info "Установлена Java: $java_ver"
}

# Установка Docker (опционально)
install_docker() {
    if [ "$INSTALL_DOCKER" != true ]; then
        return 0
    fi
    
    print_step "Установка Docker..."
    
    if command -v docker &> /dev/null; then
        print_info "Docker уже установлен"
        return 0
    fi
    
    # Удаление старых версий
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Добавление GPG ключа Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$OS/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Добавление репозитория
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
        $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Установка Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Запуск Docker
    systemctl enable docker
    systemctl start docker
    
    # Добавление пользователя в группу docker
    usermod -aG docker "$AGENT_USER" 2>/dev/null || true
    
    print_info "✓ Docker установлен"
}

# Создание пользователя
create_user() {
    print_step "Создание пользователя $AGENT_USER..."
    
    if id "$AGENT_USER" &>/dev/null; then
        print_info "Пользователь $AGENT_USER уже существует"
    else
        useradd -r -m -d "/home/$AGENT_USER" -s /bin/bash "$AGENT_USER"
        print_info "Создан пользователь: $AGENT_USER"
    fi
    
    # Создание рабочей директории
    mkdir -p "$AGENT_WORKDIR"
    chown -R "$AGENT_USER:$AGENT_USER" "$AGENT_WORKDIR"
    
    print_info "Рабочая директория: $AGENT_WORKDIR"
}

# Загрузка agent.jar
download_agent_jar() {
    print_step "Загрузка agent.jar..."
    
    local agent_jar="$AGENT_WORKDIR/agent.jar"
    
    # Пробуем загрузить с Jenkins сервера
    if [ -n "$JENKINS_URL" ]; then
        wget -q "${JENKINS_URL}/jnlpJars/agent.jar" -O "$agent_jar" || {
            print_warn "Не удалось загрузить agent.jar с $JENKINS_URL"
            print_info "Попытка загрузки с repo.jenkins-ci.org..."
            wget -q "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/remoting/latest/remoting-latest.jar" -O "$agent_jar"
        }
    else
        wget -q "https://repo.jenkins-ci.org/releases/org/jenkins-ci/main/remoting/latest/remoting-latest.jar" -O "$agent_jar"
    fi
    
    chown "$AGENT_USER:$AGENT_USER" "$agent_jar"
    chmod 644 "$agent_jar"
    
    print_info "✓ agent.jar загружен: $agent_jar"
}

# Настройка SSH агента
setup_ssh_agent() {
    if [ "$MODE" != "ssh" ]; then
        return 0
    fi
    
    print_step "Настройка SSH агента..."
    
    # Установка SSH сервера
    apt-get install -y openssh-server
    
    # Создание директории .ssh
    local ssh_dir="/home/$AGENT_USER/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    if [ "$GENERATE_SSH_KEY" = true ]; then
        print_info "Генерация SSH ключа..."
        
        ssh-keygen -t ed25519 -f "$ssh_dir/id_ed25519" -N "" -C "jenkins-agent@$(hostname)"
        
        # Копируем публичный ключ в authorized_keys
        cp "$ssh_dir/id_ed25519.pub" "$ssh_dir/authorized_keys"
        chmod 600 "$ssh_dir/authorized_keys"
        
        print_info "SSH ключ создан"
        print_info "Добавьте этот публичный ключ в Jenkins:"
        echo ""
        cat "$ssh_dir/id_ed25519.pub"
        echo ""
    fi
    
    chown -R "$AGENT_USER:$AGENT_USER" "$ssh_dir"
    
    # Запуск SSH сервера
    systemctl enable ssh
    systemctl start ssh
    
    print_info "✓ SSH агент настроен"
    
    # Сохранение информации
    mkdir -p /root/jenkins-agent-credentials
    cat > /root/jenkins-agent-credentials/ssh-info.txt << EOF
Jenkins SSH Agent Information
==============================
Host: $(hostname -I | awk '{print $1}')
Port: 22
User: $AGENT_USER
Work Directory: $AGENT_WORKDIR
Java Path: $(which java)

$(if [ "$GENERATE_SSH_KEY" = true ]; then
echo "SSH Public Key:"
cat "$ssh_dir/id_ed25519.pub"
fi)

Generated: $(date)
EOF
    chmod 600 /root/jenkins-agent-credentials/ssh-info.txt
}

# Создание systemd сервиса для inbound агента
create_inbound_service() {
    if [ "$MODE" != "inbound" ]; then
        return 0
    fi
    
    print_step "Создание systemd сервиса..."
    
    cat > /etc/systemd/system/jenkins-agent.service << EOF
[Unit]
Description=Jenkins Agent
After=network.target

[Service]
Type=simple
User=$AGENT_USER
Group=$AGENT_USER
WorkingDirectory=$AGENT_WORKDIR
ExecStart=/usr/bin/java -jar $AGENT_WORKDIR/agent.jar \\
    -url $JENKINS_URL \\
    -secret $AGENT_SECRET \\
    -name $AGENT_NAME \\
    -workDir $AGENT_WORKDIR
Restart=always
RestartSec=10

# Безопасность
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$AGENT_WORKDIR
$(if [ "$INSTALL_DOCKER" = true ]; then echo "SupplementaryGroups=docker"; fi)

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_info "✓ Systemd сервис создан"
}

# Запуск агента
start_agent() {
    if [ "$MODE" != "inbound" ]; then
        return 0
    fi
    
    print_step "Запуск Jenkins агента..."
    
    systemctl enable jenkins-agent
    systemctl start jenkins-agent
    
    sleep 3
    
    if systemctl is-active --quiet jenkins-agent; then
        print_info "✓ Jenkins агент запущен"
    else
        print_error "Не удалось запустить агент"
        print_error "Проверьте логи: journalctl -u jenkins-agent -n 50"
        exit 1
    fi
}

# Вывод итоговой информации
print_summary() {
    local ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=============================================="
    print_info "Jenkins Agent успешно установлен!"
    echo "=============================================="
    echo ""
    
    if [ "$MODE" = "inbound" ]; then
        print_info "Режим: Inbound (JNLP)"
        print_info "Jenkins URL: $JENKINS_URL"
        print_info "Имя агента: $AGENT_NAME"
        print_info "Рабочая директория: $AGENT_WORKDIR"
        
        echo ""
        print_info "Управление сервисом:"
        echo "  systemctl status jenkins-agent   - статус"
        echo "  systemctl restart jenkins-agent  - перезапуск"
        echo "  journalctl -u jenkins-agent -f   - логи"
    else
        print_info "Режим: SSH"
        print_info "SSH хост: $ip"
        print_info "SSH пользователь: $AGENT_USER"
        print_info "Рабочая директория: $AGENT_WORKDIR"
        print_info "Java path: $(which java)"
        
        echo ""
        print_info "Настройка в Jenkins:"
        echo "  1. Manage Jenkins → Nodes → New Node"
        echo "  2. Launch method: Launch agents via SSH"
        echo "  3. Host: $ip"
        echo "  4. Credentials: SSH Username with private key"
        echo "  5. Remote root directory: $AGENT_WORKDIR"
        echo "  6. Java Path: $(which java)"
        
        if [ -f /root/jenkins-agent-credentials/ssh-info.txt ]; then
            echo ""
            print_info "SSH информация: /root/jenkins-agent-credentials/ssh-info.txt"
        fi
    fi
    
    if [ -n "$AGENT_LABELS" ]; then
        echo ""
        print_info "Метки: $AGENT_LABELS"
    fi
    
    if [ "$INSTALL_DOCKER" = true ]; then
        echo ""
        print_info "Docker установлен и доступен для сборок"
    fi
    
    echo ""
}

# Основная функция
main() {
    echo ""
    echo "=============================================="
    echo "   Jenkins Agent Installation Script"
    echo "=============================================="
    echo ""
    
    detect_os
    install_dependencies
    install_java
    create_user
    download_agent_jar
    install_docker
    
    if [ "$MODE" = "inbound" ]; then
        create_inbound_service
        start_agent
    else
        setup_ssh_agent
    fi
    
    print_summary
}

# Запуск
main

