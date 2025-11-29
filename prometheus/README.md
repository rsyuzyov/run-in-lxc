# Prometheus Stack для LXC контейнеров

Скрипт установки полноценного стека мониторинга на базе Prometheus.

## Компоненты

| Компонент | Описание | Порт | Установка |
|-----------|----------|------|-----------|
| **Prometheus** | Сервер сбора и хранения метрик | 9090 | Всегда |
| **Node Exporter** | Метрики хоста (CPU, RAM, диск, сеть) | 9100 | Всегда |
| **Blackbox Exporter** | Проверка HTTP/TCP/ICMP endpoint'ов | 9115 | Всегда |
| **Alertmanager** | Обработка и маршрутизация алертов | 9093 | `--alertmanager` |
| **Postgres Exporter** | Метрики PostgreSQL | 9187 | `--postgres-exporter` |
| **PVE Exporter** | Метрики Proxmox VE | 9221 | `--proxmox` |

## Требования к ресурсам

| Ресурс | Минимум | Рекомендуется |
|--------|---------|---------------|
| CPU | 1 | 2 |
| RAM | 2 GB | 4 GB |
| Диск | 10 GB | 20 GB |

## Быстрый старт

```bash
# Базовая установка
./install.sh

# С Alertmanager и удалённым доступом (для Grafana)
./install.sh --alertmanager --allow-remote

# Полная установка с мониторингом Proxmox
./install.sh --alertmanager --allow-remote --proxmox \
  --proxmox-host 192.168.1.100:8006 \
  --proxmox-user prometheus@pve \
  --proxmox-token-id monitoring \
  --proxmox-token-secret xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

## Опции установки

### Основные опции

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--version VERSION` | Версия Prometheus | latest |
| `--alertmanager` | Установить Alertmanager | - |
| `--postgres-exporter` | Установить Postgres Exporter | - |
| `--proxmox` | Настроить мониторинг Proxmox VE | - |
| `--allow-remote` | Разрешить удалённые подключения | - |

### Настройки хранения

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--retention TIME` | Время хранения метрик | 15d |
| `--scrape-interval TIME` | Интервал сбора метрик | 15s |
| `--storage-path PATH` | Путь хранения данных | /var/lib/prometheus |

### Настройки Proxmox VE

| Опция | Описание |
|-------|----------|
| `--proxmox-host HOST` | Адрес Proxmox VE (IP:PORT) |
| `--proxmox-user USER` | Пользователь API (например: prometheus@pve) |
| `--proxmox-token-id ID` | ID токена API |
| `--proxmox-token-secret SECRET` | Секрет токена API |

### Настройки Postgres Exporter

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--pg-host HOST` | Хост PostgreSQL | localhost |
| `--pg-port PORT` | Порт PostgreSQL | 5432 |
| `--pg-user USER` | Пользователь PostgreSQL | postgres_exporter |
| `--pg-password PASS` | Пароль пользователя | - |
| `--pg-database DB` | База данных | postgres |

## Примеры использования

### Базовая установка

```bash
./install.sh
```

Устанавливает Prometheus, Node Exporter и Blackbox Exporter. Доступ только с localhost.

### Установка с алертами

```bash
./install.sh --alertmanager --allow-remote
```

### Мониторинг Proxmox VE

```bash
./install.sh --proxmox \
  --proxmox-host 192.168.1.100:8006 \
  --proxmox-user prometheus@pve \
  --proxmox-token-id monitoring \
  --proxmox-token-secret xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Подготовка в Proxmox VE:**

1. Создайте пользователя: Datacenter → Permissions → Users → Add
   - User name: `prometheus`
   - Realm: `pve`

2. Создайте API токен: Datacenter → Permissions → API Tokens → Add
   - User: `prometheus@pve`
   - Token ID: `monitoring`
   - Privilege Separation: ✓

3. Назначьте права: Datacenter → Permissions → Add
   - Path: `/`
   - User/Token: `prometheus@pve!monitoring`
   - Role: `PVEAuditor`

### Мониторинг PostgreSQL

```bash
./install.sh --postgres-exporter \
  --pg-host 192.168.1.50 \
  --pg-user prometheus \
  --pg-password SecurePass123
```

**Подготовка в PostgreSQL:**

```sql
CREATE USER prometheus WITH PASSWORD 'SecurePass123';
GRANT pg_monitor TO prometheus;
```

### Длительное хранение метрик

```bash
./install.sh --retention 90d --storage-path /mnt/prometheus-data
```

## Структура файлов

```
/etc/prometheus/
├── prometheus.yml          # Основная конфигурация
├── rules/
│   └── alerts.yml          # Правила алертинга
├── targets/
│   ├── nodes.yml           # Дополнительные Node Exporters
│   ├── blackbox-http.yml   # HTTP endpoints для мониторинга
│   └── blackbox-icmp.yml   # Хосты для ping
├── consoles/               # Web-консоли
└── console_libraries/      # Библиотеки консолей

/etc/blackbox_exporter/
└── blackbox.yml            # Конфигурация проверок

/etc/alertmanager/
└── alertmanager.yml        # Конфигурация алертов

/var/lib/prometheus/        # Данные Prometheus (TSDB)
```

## Добавление целей мониторинга

### Дополнительные серверы (Node Exporter)

Редактируйте `/etc/prometheus/targets/nodes.yml`:

```yaml
- targets:
    - '192.168.1.10:9100'
    - '192.168.1.11:9100'
    - '192.168.1.12:9100'
  labels:
    env: 'production'
    datacenter: 'dc1'

- targets:
    - '192.168.2.10:9100'
  labels:
    env: 'staging'
```

### HTTP мониторинг

Редактируйте `/etc/prometheus/targets/blackbox-http.yml`:

```yaml
- targets:
    - 'https://example.com'
    - 'https://api.example.com/health'
    - 'https://grafana.example.com'
  labels:
    env: 'production'

- targets:
    - 'http://internal-app:8080/healthz'
  labels:
    env: 'internal'
```

### Ping мониторинг

Редактируйте `/etc/prometheus/targets/blackbox-icmp.yml`:

```yaml
- targets:
    - '192.168.1.1'    # роутер
    - '8.8.8.8'        # Google DNS
    - '1.1.1.1'        # Cloudflare DNS
  labels:
    type: 'network'
```

Prometheus автоматически подхватит изменения через file_sd.

## Управление сервисами

### Prometheus

```bash
# Статус
systemctl status prometheus

# Перезапуск
systemctl restart prometheus

# Перечитать конфигурацию без перезапуска
systemctl reload prometheus
# или
curl -X POST http://localhost:9090/-/reload

# Логи
journalctl -u prometheus -f
```

### Node Exporter

```bash
systemctl status node_exporter
systemctl restart node_exporter
journalctl -u node_exporter -f
```

### Blackbox Exporter

```bash
systemctl status blackbox_exporter
systemctl restart blackbox_exporter
journalctl -u blackbox_exporter -f
```

### Alertmanager

```bash
systemctl status alertmanager
systemctl restart alertmanager
journalctl -u alertmanager -f
```

## Встроенные алерты

Скрипт создаёт базовые правила алертинга:

| Алерт | Условие | Severity |
|-------|---------|----------|
| InstanceDown | target недоступен 5 минут | critical |
| HighCPUUsage | CPU > 80% в течение 10 минут | warning |
| HighMemoryUsage | RAM > 85% в течение 10 минут | warning |
| DiskSpaceLow | Диск < 15% в течение 10 минут | warning |
| DiskSpaceCritical | Диск < 5% в течение 5 минут | critical |
| EndpointDown | HTTP endpoint недоступен 2 минуты | critical |
| SSLCertExpiringSoon | SSL истекает < 14 дней | warning |
| SSLCertExpiryCritical | SSL истекает < 7 дней | critical |

Правила находятся в `/etc/prometheus/rules/alerts.yml`.

## Настройка Alertmanager

Редактируйте `/etc/alertmanager/alertmanager.yml`:

### Email уведомления

```yaml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'alertmanager@example.com'
  smtp_auth_password: 'password'

receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
```

### Telegram уведомления

```yaml
receivers:
  - name: 'telegram'
    telegram_configs:
      - bot_token: '123456789:ABCdefGHIjklMNOpqrsTUVwxyz'
        chat_id: -1001234567890
        send_resolved: true
```

### Webhook

```yaml
receivers:
  - name: 'webhook'
    webhook_configs:
      - url: 'http://alertmanager-webhook:5001/alert'
        send_resolved: true
```

## Интеграция с Grafana

### Добавление источника данных

1. Configuration → Data Sources → Add data source
2. Выберите **Prometheus**
3. URL: `http://<prometheus-ip>:9090`
4. Нажмите **Save & Test**

### Рекомендуемые дашборды

Импортируйте из [Grafana Dashboards](https://grafana.com/grafana/dashboards/):

| ID | Название | Описание |
|----|----------|----------|
| 1860 | Node Exporter Full | Полный дашборд Node Exporter |
| 9628 | PostgreSQL Database | Метрики PostgreSQL |
| 10347 | Proxmox | Мониторинг Proxmox VE |
| 7587 | Blackbox Exporter | HTTP/ICMP проверки |
| 11074 | Alertmanager | Статус алертов |

## Безопасность

### Ограничение доступа

По умолчанию все компоненты слушают только `127.0.0.1`. Для удалённого доступа:

```bash
./install.sh --allow-remote
```

### Рекомендации

1. **Используйте firewall** для ограничения доступа к портам
2. **Настройте reverse proxy** (nginx/apache) с аутентификацией
3. **Используйте TLS** для шифрования трафика
4. **Ограничьте права** API токенов Proxmox

### Пример nginx с базовой аутентификацией

```nginx
server {
    listen 443 ssl;
    server_name prometheus.example.com;

    ssl_certificate /etc/ssl/certs/prometheus.crt;
    ssl_certificate_key /etc/ssl/private/prometheus.key;

    auth_basic "Prometheus";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:9090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Решение проблем

### Prometheus не запускается

```bash
# Проверить логи
journalctl -u prometheus -n 100

# Проверить конфигурацию
promtool check config /etc/prometheus/prometheus.yml

# Проверить права
ls -la /var/lib/prometheus/
ls -la /etc/prometheus/
```

### Target в состоянии DOWN

```bash
# Проверить доступность
curl http://target:9100/metrics

# Проверить firewall
iptables -L -n

# Проверить, слушает ли exporter
ss -tlnp | grep 9100
```

### Blackbox не может пинговать

```bash
# Проверить capabilities
getcap /usr/local/bin/blackbox_exporter

# Должно быть: cap_net_raw=ep
# Если нет, исправить:
setcap cap_net_raw=ep /usr/local/bin/blackbox_exporter
```

### Высокое потребление памяти

```bash
# Уменьшить retention
systemctl edit prometheus

# Добавить:
[Service]
ExecStart=
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=7d \
  --storage.tsdb.retention.size=5GB
```

## Обновление

```bash
# Скачать новую версию
VERSION=2.50.0
wget https://github.com/prometheus/prometheus/releases/download/v${VERSION}/prometheus-${VERSION}.linux-amd64.tar.gz

# Остановить сервис
systemctl stop prometheus

# Заменить бинарник
tar -xzf prometheus-${VERSION}.linux-amd64.tar.gz
cp prometheus-${VERSION}.linux-amd64/prometheus /usr/local/bin/

# Запустить сервис
systemctl start prometheus
```

## Полезные ссылки

- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Awesome Prometheus Alerts](https://awesome-prometheus-alerts.grep.to/)

