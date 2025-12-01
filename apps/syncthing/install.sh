#!/bin/bash

#############################################
# Syncthing Installation Script for LXC
# Установка Syncthing с опциональной настройкой
# веб-интерфейса, reverse proxy, мониторинга
#############################################

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Значения по умолчанию
SYNCTHING_USER="syncthing"
DATA_DIR="/var/lib/syncthing"
GUI_ADDRESS="0.0.0.0:8384"
GUI_PASSWORD=""
DISABLE_GUI=false
ENABLE_RELAY=false
ENABLE_DISCOVERY=false
ENABLE_PROMETHEUS=false
ENABLE_NGINX=false
ENABLE_SSL=false
SSL_DOMAIN=""
SSL_EMAIL=""
LOW_RESOURCES=false
MAX_FOLDER_CONCURRENCY=""
MAX_RECV_KBPS=""
MAX_SEND_KBPS=""

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

Скрипт установки Syncthing для LXC контейнеров.

Основные опции:
  --user USER             Пользователь для запуска (по умолчанию: syncthing)
  --data-dir PATH         Директория для данных (по умолчанию: /var/lib/syncthing)
  --gui-address ADDR      Адрес веб-интерфейса (по умолчанию: 0.0.0.0:8384)
  --gui-password PASS     Пароль для веб-интерфейса (рекомендуется!)
  --no-gui                Отключить веб-интерфейс (headless режим)

Режимы работы:
  --relay                 Установить как relay-сервер (помощь NAT traversal)
  --discovery             Установить как discovery-сервер

Интеграции:
  --prometheus            Включить Prometheus exporter (порт 8384/metrics)
  --nginx                 Настроить nginx как reverse proxy
  --ssl                   Включить SSL через Let's Encrypt (требует --nginx)
  --domain DOMAIN         Домен для nginx/SSL
  --email EMAIL           Email для Let's Encrypt

Оптимизация ресурсов:
  --low-resources         Режим минимального потребления ресурсов
  --max-folder-concurrency N  Макс. параллельных синхронизаций папок (по умолчанию: 1)
  --max-recv-kbps N       Ограничение скорости приёма (КБ/с)
  --max-send-kbps N       Ограничение скорости отправки (КБ/с)

Прочее:
  --check                 Только проверить совместимость системы
  --help                  Показать эту справку

Примеры:
  # Базовая установка (личный сервер)
  $0

  # С паролем на веб-интерфейс
  $0 --gui-password "MySecurePassword123"

  # Для слабого ПК (минимум ресурсов)
  $0 --low-resources --max-recv-kbps 5000 --max-send-kbps 5000

  # Корпоративный сервер с мониторингом и SSL
  $0 --gui-password "SecurePass" --prometheus --nginx --ssl \\
     --domain sync.company.local --email admin@company.local

  # Headless сервер (без GUI)
  $0 --no-gui --data-dir /mnt/storage/syncthing

  # Relay-сервер для инфраструктуры
  $0 --relay

  # Discovery-сервер
  $0 --discovery

EOF
    exit 0
}

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            SYNCTHING_USER="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --gui-address)
            GUI_ADDRESS="$2"
            shift 2
            ;;
        --gui-password)
            GUI_PASSWORD="$2"
            shift 2
            ;;
        --no-gui)
            DISABLE_GUI=true
            shift
            ;;
        --relay)
            ENABLE_RELAY=true
            shift
            ;;
        --discovery)
            ENABLE_DISCOVERY=true
            shift
            ;;
        --prometheus)
            ENABLE_PROMETHEUS=true
            shift
            ;;
        --nginx)
            ENABLE_NGINX=true
            shift
            ;;
        --ssl)
            ENABLE_SSL=true
            shift
            ;;
        --domain)
            SSL_DOMAIN="$2"
            shift 2
            ;;
        --email)
            SSL_EMAIL="$2"
            shift 2
            ;;
        --low-resources)
            LOW_RESOURCES=true
            shift
            ;;
        --max-folder-concurrency)
            MAX_FOLDER_CONCURRENCY="$2"
            shift 2
            ;;
        --max-recv-kbps)
            MAX_RECV_KBPS="$2"
            shift 2
            ;;
        --max-send-kbps)
            MAX_SEND_KBPS="$2"
            shift 2
            ;;
        --check)
            CHECK_ONLY=true
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

# Проверка параметров SSL
if [ "$ENABLE_SSL" = true ]; then
    if [ "$ENABLE_NGINX" != true ]; then
        print_error "Для SSL необходимо указать --nginx"
        exit 1
    fi
    if [ -z "$SSL_DOMAIN" ]; then
        print_error "Для SSL необходимо указать --domain"
        exit 1
    fi
    if [ -z "$SSL_EMAIL" ]; then
        print_error "Для SSL необходимо указать --email"
        exit 1
    fi
fi

# Проверка параметров nginx
if [ "$ENABLE_NGINX" = true ] && [ -z "$SSL_DOMAIN" ]; then
    print_error "Для nginx необходимо указать --domain"
    exit 1
fi

# Режим минимальных ресурсов
if [ "$LOW_RESOURCES" = true ]; then
    [ -z "$MAX_FOLDER_CONCURRENCY" ] && MAX_FOLDER_CONCURRENCY=1
fi

# Определение дистрибутива
print_step "Определение дистрибутива..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_CODENAME
else
    print_error "Не удалось определить дистрибутив"
    exit 1
fi

print_info "Обнаружен: $OS $VERSION"

# Проверка совместимости
check_compatibility() {
    print_step "Проверка совместимости системы..."
    
    local errors=0
    
    # Проверка архитектуры
    ARCH=$(dpkg --print-architecture)
    case $ARCH in
        amd64|arm64|armhf)
            print_info "✓ Архитектура: $ARCH (поддерживается)"
            ;;
        *)
            print_error "✗ Архитектура $ARCH не поддерживается"
            errors=$((errors + 1))
            ;;
    esac
    
    # Проверка памяти
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
    if [ "$TOTAL_MEM" -lt 256 ]; then
        print_error "✗ Недостаточно памяти: ${TOTAL_MEM}MB (минимум 256MB)"
        errors=$((errors + 1))
    elif [ "$TOTAL_MEM" -lt 512 ]; then
        print_warn "⚠ Мало памяти: ${TOTAL_MEM}MB (рекомендуется 512MB+)"
        print_warn "  Рекомендуется использовать --low-resources"
    else
        print_info "✓ Память: ${TOTAL_MEM}MB"
    fi
    
    # Проверка диска
    DISK_FREE=$(df -BM "$DATA_DIR" 2>/dev/null | tail -1 | awk '{print int($4)}' || echo "0")
    if [ "$DISK_FREE" -lt 100 ]; then
        print_warn "⚠ Мало свободного места: ${DISK_FREE}MB"
    else
        print_info "✓ Свободное место: ${DISK_FREE}MB"
    fi
    
    # Проверка systemd
    if command -v systemctl &> /dev/null; then
        print_info "✓ systemd доступен"
    else
        print_error "✗ systemd не найден"
        errors=$((errors + 1))
    fi
    
    return $errors
}

if [ "$CHECK_ONLY" = true ]; then
    check_compatibility
    exit $?
fi

# Вывод информации об установке
echo ""
echo "=============================================="
print_info "Установка Syncthing"
print_info "Пользователь: $SYNCTHING_USER"
print_info "Директория данных: $DATA_DIR"
if [ "$DISABLE_GUI" = true ]; then
    print_info "Веб-интерфейс: отключён"
else
    print_info "Веб-интерфейс: $GUI_ADDRESS"
fi
if [ -n "$GUI_PASSWORD" ]; then
    print_info "Пароль GUI: установлен"
fi
if [ "$ENABLE_RELAY" = true ]; then
    print_info "Режим: Relay-сервер"
fi
if [ "$ENABLE_DISCOVERY" = true ]; then
    print_info "Режим: Discovery-сервер"
fi
if [ "$ENABLE_PROMETHEUS" = true ]; then
    print_info "Prometheus: включён"
fi
if [ "$ENABLE_NGINX" = true ]; then
    print_info "Nginx reverse proxy: $SSL_DOMAIN"
fi
if [ "$ENABLE_SSL" = true ]; then
    print_info "SSL: Let's Encrypt"
fi
if [ "$LOW_RESOURCES" = true ]; then
    print_info "Режим: минимальные ресурсы"
fi
echo "=============================================="
echo ""

# Проверка совместимости
check_compatibility || {
    print_error "Проверка совместимости не пройдена"
    exit 1
}

# Установка зависимостей
print_step "Установка базовых зависимостей..."
apt-get update
apt-get install -y curl gnupg2 ca-certificates apt-transport-https

# Добавление репозитория Syncthing
print_step "Добавление официального репозитория Syncthing..."

# Создание директории для ключей
mkdir -p /usr/share/keyrings

# Скачивание ключа
curl -fsSL https://syncthing.net/release-key.gpg | gpg --dearmor -o /usr/share/keyrings/syncthing-archive-keyring.gpg

# Добавление репозитория
echo "deb [signed-by=/usr/share/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" > /etc/apt/sources.list.d/syncthing.list

# Установка Syncthing
print_step "Установка Syncthing..."
apt-get update
apt-get install -y syncthing

# Получение версии
SYNCTHING_VERSION=$(syncthing --version | head -1 | awk '{print $2}')
print_info "✓ Syncthing $SYNCTHING_VERSION установлен"

# Создание пользователя
if [ "$SYNCTHING_USER" != "root" ]; then
    print_step "Создание пользователя $SYNCTHING_USER..."
    if ! id "$SYNCTHING_USER" &>/dev/null; then
        useradd -r -m -d "$DATA_DIR" -s /bin/bash "$SYNCTHING_USER"
        print_info "✓ Пользователь $SYNCTHING_USER создан"
    else
        print_info "✓ Пользователь $SYNCTHING_USER уже существует"
    fi
fi

# Создание директории данных
print_step "Настройка директории данных..."
mkdir -p "$DATA_DIR"
chown -R "$SYNCTHING_USER:$SYNCTHING_USER" "$DATA_DIR"
chmod 750 "$DATA_DIR"

# Генерация начальной конфигурации
print_step "Генерация начальной конфигурации..."
sudo -u "$SYNCTHING_USER" syncthing generate --config="$DATA_DIR" --skip-port-probing

CONFIG_FILE="$DATA_DIR/config.xml"

# Ожидание создания конфигурации
sleep 2

# Настройка GUI
if [ "$DISABLE_GUI" = true ]; then
    print_step "Отключение веб-интерфейса..."
    sed -i 's|<gui enabled="true"|<gui enabled="false"|g' "$CONFIG_FILE"
else
    print_step "Настройка веб-интерфейса..."
    # Установка адреса GUI
    sed -i "s|<address>127.0.0.1:8384</address>|<address>$GUI_ADDRESS</address>|g" "$CONFIG_FILE"
    
    # Установка пароля GUI
    if [ -n "$GUI_PASSWORD" ]; then
        # Генерация bcrypt хеша пароля
        HASHED_PASSWORD=$(syncthing generate --config="$DATA_DIR" --gui-password="$GUI_PASSWORD" 2>&1 | grep -oP '(?<=password=")[^"]+' || echo "")
        
        if [ -z "$HASHED_PASSWORD" ]; then
            # Альтернативный способ - через API после первого запуска
            print_warn "Пароль будет установлен после первого запуска"
            NEED_SET_PASSWORD=true
        fi
    fi
fi

# Настройка для минимальных ресурсов
if [ "$LOW_RESOURCES" = true ] || [ -n "$MAX_FOLDER_CONCURRENCY" ]; then
    print_step "Применение настроек для экономии ресурсов..."
    
    # Устанавливаем параметры в options секции
    if [ -n "$MAX_FOLDER_CONCURRENCY" ]; then
        if grep -q "<maxFolderConcurrency>" "$CONFIG_FILE"; then
            sed -i "s|<maxFolderConcurrency>[^<]*</maxFolderConcurrency>|<maxFolderConcurrency>$MAX_FOLDER_CONCURRENCY</maxFolderConcurrency>|g" "$CONFIG_FILE"
        else
            sed -i "s|</options>|    <maxFolderConcurrency>$MAX_FOLDER_CONCURRENCY</maxFolderConcurrency>\n    </options>|" "$CONFIG_FILE"
        fi
        print_info "  maxFolderConcurrency: $MAX_FOLDER_CONCURRENCY"
    fi
fi

# Настройка ограничений скорости
if [ -n "$MAX_RECV_KBPS" ] || [ -n "$MAX_SEND_KBPS" ]; then
    print_step "Настройка ограничений скорости..."
    
    if [ -n "$MAX_RECV_KBPS" ]; then
        if grep -q "<maxRecvKbps>" "$CONFIG_FILE"; then
            sed -i "s|<maxRecvKbps>[^<]*</maxRecvKbps>|<maxRecvKbps>$MAX_RECV_KBPS</maxRecvKbps>|g" "$CONFIG_FILE"
        else
            sed -i "s|</options>|    <maxRecvKbps>$MAX_RECV_KBPS</maxRecvKbps>\n    </options>|" "$CONFIG_FILE"
        fi
        print_info "  Макс. приём: ${MAX_RECV_KBPS} КБ/с"
    fi
    
    if [ -n "$MAX_SEND_KBPS" ]; then
        if grep -q "<maxSendKbps>" "$CONFIG_FILE"; then
            sed -i "s|<maxSendKbps>[^<]*</maxSendKbps>|<maxSendKbps>$MAX_SEND_KBPS</maxSendKbps>|g" "$CONFIG_FILE"
        else
            sed -i "s|</options>|    <maxSendKbps>$MAX_SEND_KBPS</maxSendKbps>\n    </options>|" "$CONFIG_FILE"
        fi
        print_info "  Макс. отправка: ${MAX_SEND_KBPS} КБ/с"
    fi
fi

# Настройка Prometheus
if [ "$ENABLE_PROMETHEUS" = true ]; then
    print_step "Включение Prometheus exporter..."
    # Prometheus метрики доступны на /metrics при включённом GUI
    if [ "$DISABLE_GUI" = true ]; then
        print_warn "Prometheus требует включённый GUI для экспорта метрик"
    else
        print_info "✓ Метрики доступны на http://$GUI_ADDRESS/metrics"
    fi
fi

# Создание systemd unit файла
print_step "Создание systemd сервиса..."

cat > /etc/systemd/system/syncthing.service << EOF
[Unit]
Description=Syncthing - Open Source Continuous File Synchronization
Documentation=man:syncthing(1)
After=network.target

[Service]
User=$SYNCTHING_USER
Group=$SYNCTHING_USER
ExecStart=/usr/bin/syncthing serve --no-browser --no-restart --config=$DATA_DIR --data=$DATA_DIR
Restart=on-failure
RestartSec=5
SuccessExitStatus=3 4
RestartForceExitStatus=3 4

# Безопасность
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=$DATA_DIR

# Ограничения ресурсов для low-resources режима
$(if [ "$LOW_RESOURCES" = true ]; then
    echo "MemoryMax=512M"
    echo "CPUQuota=50%"
fi)

[Install]
WantedBy=multi-user.target
EOF

# Установка Relay-сервера
if [ "$ENABLE_RELAY" = true ]; then
    print_step "Установка Syncthing Relay Server..."
    apt-get install -y syncthing-relaysrv
    
    cat > /etc/systemd/system/syncthing-relay.service << EOF
[Unit]
Description=Syncthing Relay Server
After=network.target

[Service]
User=$SYNCTHING_USER
Group=$SYNCTHING_USER
ExecStart=/usr/bin/relaysrv -pools="" -listen=":22067"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable syncthing-relay
    systemctl start syncthing-relay
    
    print_info "✓ Relay-сервер запущен на порту 22067"
fi

# Установка Discovery-сервера
if [ "$ENABLE_DISCOVERY" = true ]; then
    print_step "Установка Syncthing Discovery Server..."
    apt-get install -y syncthing-discosrv
    
    cat > /etc/systemd/system/syncthing-discovery.service << EOF
[Unit]
Description=Syncthing Discovery Server
After=network.target

[Service]
User=$SYNCTHING_USER
Group=$SYNCTHING_USER
ExecStart=/usr/bin/discosrv -listen=":8443"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable syncthing-discovery
    systemctl start syncthing-discovery
    
    print_info "✓ Discovery-сервер запущен на порту 8443"
fi

# Запуск основного сервиса
print_step "Запуск Syncthing..."
systemctl daemon-reload
systemctl enable syncthing
systemctl start syncthing

# Ожидание запуска
sleep 3

# Проверка статуса
if systemctl is-active --quiet syncthing; then
    print_info "✓ Syncthing успешно запущен"
else
    print_error "Не удалось запустить Syncthing!"
    print_error "Проверьте логи: journalctl -u syncthing -n 50"
    exit 1
fi

# Установка пароля через API (если нужно)
if [ "$NEED_SET_PASSWORD" = true ] && [ -n "$GUI_PASSWORD" ]; then
    print_step "Установка пароля GUI..."
    sleep 5  # Ждём полного запуска
    
    # Получаем API-ключ из конфигурации
    API_KEY=$(grep -oP '(?<=<apikey>)[^<]+' "$CONFIG_FILE")
    
    if [ -n "$API_KEY" ]; then
        # Устанавливаем пароль через REST API
        curl -s -X PATCH \
            -H "X-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"gui\":{\"user\":\"admin\",\"password\":\"$GUI_PASSWORD\"}}" \
            "http://127.0.0.1:8384/rest/config" > /dev/null 2>&1 && \
            print_info "✓ Пароль GUI установлен (пользователь: admin)" || \
            print_warn "Не удалось установить пароль через API, установите вручную"
    fi
fi

# Настройка Nginx (если запрошено)
if [ "$ENABLE_NGINX" = true ]; then
    print_step "Настройка Nginx reverse proxy..."
    
    # Проверка/установка nginx
    if ! command -v nginx &> /dev/null; then
        apt-get install -y nginx
    fi
    
    # Создание конфигурации
    cat > /etc/nginx/sites-available/syncthing.conf << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $SSL_DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8384;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
EOF

    # Включение сайта
    mkdir -p /etc/nginx/sites-enabled
    ln -sf /etc/nginx/sites-available/syncthing.conf /etc/nginx/sites-enabled/
    
    # Проверка наличия include в nginx.conf
    if ! grep -q "include /etc/nginx/sites-enabled" /etc/nginx/nginx.conf; then
        sed -i '/include \/etc\/nginx\/conf\.d\/\*\.conf;/a\    include /etc/nginx/sites-enabled/*.conf;' /etc/nginx/nginx.conf
    fi
    
    nginx -t && systemctl reload nginx
    print_info "✓ Nginx настроен для $SSL_DOMAIN"
    
    # SSL через Let's Encrypt
    if [ "$ENABLE_SSL" = true ]; then
        print_step "Получение SSL-сертификата..."
        apt-get install -y certbot python3-certbot-nginx
        
        certbot --nginx -d "$SSL_DOMAIN" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect
        
        if [ $? -eq 0 ]; then
            print_info "✓ SSL-сертификат установлен"
        else
            print_warn "Ошибка получения SSL-сертификата"
        fi
    fi
fi

# Получение Device ID
print_step "Получение Device ID..."
sleep 2
DEVICE_ID=$(sudo -u "$SYNCTHING_USER" syncthing --config="$DATA_DIR" --device-id 2>/dev/null || echo "")

# Сохранение учётных данных
CREDENTIALS_DIR="$DATA_DIR/credentials"
mkdir -p "$CREDENTIALS_DIR"
chmod 700 "$CREDENTIALS_DIR"

cat > "$CREDENTIALS_DIR/info.txt" << EOF
Syncthing Installation Info
============================
Date: $(date)
Version: $SYNCTHING_VERSION
Device ID: $DEVICE_ID

Web GUI:
  URL: http://$(hostname -I | awk '{print $1}'):8384
  User: admin
  Password: ${GUI_PASSWORD:-"(not set)"}

API Key: $(grep -oP '(?<=<apikey>)[^<]+' "$CONFIG_FILE" 2>/dev/null || echo "see config.xml")

Config: $CONFIG_FILE
Data: $DATA_DIR

$(if [ "$ENABLE_NGINX" = true ]; then
    if [ "$ENABLE_SSL" = true ]; then
        echo "Nginx URL: https://$SSL_DOMAIN"
    else
        echo "Nginx URL: http://$SSL_DOMAIN"
    fi
fi)

$(if [ "$ENABLE_RELAY" = true ]; then
    echo "Relay Server: relay://$(hostname -I | awk '{print $1}'):22067"
fi)

$(if [ "$ENABLE_DISCOVERY" = true ]; then
    echo "Discovery Server: https://$(hostname -I | awk '{print $1}'):8443"
fi)
EOF

chown -R "$SYNCTHING_USER:$SYNCTHING_USER" "$CREDENTIALS_DIR"
chmod 600 "$CREDENTIALS_DIR/info.txt"

# Настройка файрвола (если ufw установлен)
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    print_step "Настройка файрвола..."
    ufw allow 8384/tcp comment "Syncthing GUI"
    ufw allow 22000/tcp comment "Syncthing TCP"
    ufw allow 22000/udp comment "Syncthing QUIC"
    ufw allow 21027/udp comment "Syncthing Discovery"
    
    if [ "$ENABLE_RELAY" = true ]; then
        ufw allow 22067/tcp comment "Syncthing Relay"
    fi
    if [ "$ENABLE_DISCOVERY" = true ]; then
        ufw allow 8443/tcp comment "Syncthing Discovery Server"
    fi
    
    print_info "✓ Правила файрвола добавлены"
fi

# Итоговая информация
echo ""
echo "=============================================="
print_info "✓ Установка Syncthing завершена успешно!"
echo "=============================================="
echo ""

IP_ADDR=$(hostname -I | awk '{print $1}')

print_info "Веб-интерфейс:"
if [ "$DISABLE_GUI" = true ]; then
    print_info "  Отключён (headless режим)"
else
    if [ "$ENABLE_NGINX" = true ] && [ "$ENABLE_SSL" = true ]; then
        print_info "  https://$SSL_DOMAIN"
    elif [ "$ENABLE_NGINX" = true ]; then
        print_info "  http://$SSL_DOMAIN"
    else
        print_info "  http://${IP_ADDR}:8384"
    fi
    if [ -n "$GUI_PASSWORD" ]; then
        print_info "  Пользователь: admin"
        print_info "  Пароль: $GUI_PASSWORD"
    else
        print_warn "  Пароль не установлен! Рекомендуется установить"
    fi
fi
echo ""

print_info "Device ID:"
print_info "  $DEVICE_ID"
echo ""

print_info "Управление сервисом:"
print_info "  systemctl status syncthing"
print_info "  systemctl restart syncthing"
print_info "  journalctl -u syncthing -f"
echo ""

print_info "Порты:"
print_info "  8384/tcp  - Веб-интерфейс и API"
print_info "  22000/tcp - Синхронизация (TCP)"
print_info "  22000/udp - Синхронизация (QUIC)"
print_info "  21027/udp - Локальное обнаружение"
if [ "$ENABLE_RELAY" = true ]; then
    print_info "  22067/tcp - Relay-сервер"
fi
if [ "$ENABLE_DISCOVERY" = true ]; then
    print_info "  8443/tcp  - Discovery-сервер"
fi
echo ""

print_info "Файлы:"
print_info "  Конфигурация: $CONFIG_FILE"
print_info "  Данные: $DATA_DIR"
print_info "  Учётные данные: $CREDENTIALS_DIR/info.txt"
echo ""

if [ "$LOW_RESOURCES" = true ]; then
    print_info "Режим экономии ресурсов:"
    print_info "  Лимит памяти: 512MB"
    print_info "  Лимит CPU: 50%"
    print_info "  Параллельные папки: ${MAX_FOLDER_CONCURRENCY:-1}"
    echo ""
fi

print_info "Следующие шаги:"
print_info "  1. Откройте веб-интерфейс"
print_info "  2. Добавьте удалённые устройства по Device ID"
print_info "  3. Создайте папки для синхронизации"
print_info "  4. Поделитесь папками с другими устройствами"
echo ""

