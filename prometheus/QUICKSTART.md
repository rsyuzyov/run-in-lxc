# Prometheus — Быстрый старт

## Требования LXC

- **CPU:** 2 ядра
- **RAM:** 4 GB
- **Диск:** 20 GB

## Установка

```bash
# Базовая (Prometheus + Node Exporter + Blackbox Exporter)
./install.sh

# С алертами и удалённым доступом
./install.sh --alertmanager --allow-remote

# Полная установка с Proxmox
./install.sh --alertmanager --allow-remote --proxmox \
  --proxmox-host 192.168.1.100:8006 \
  --proxmox-user prometheus@pve \
  --proxmox-token-id monitoring \
  --proxmox-token-secret <token>
```

## Порты

| Сервис | Порт |
|--------|------|
| Prometheus | 9090 |
| Node Exporter | 9100 |
| Blackbox Exporter | 9115 |
| Alertmanager | 9093 |
| Postgres Exporter | 9187 |
| PVE Exporter | 9221 |

## Управление

```bash
# Статус всех сервисов
systemctl status prometheus node_exporter blackbox_exporter

# Перезапуск
systemctl restart prometheus

# Reload конфигурации (без перезапуска)
systemctl reload prometheus

# Логи
journalctl -u prometheus -f
```

## Конфигурация

| Файл | Назначение |
|------|------------|
| `/etc/prometheus/prometheus.yml` | Основная конфигурация |
| `/etc/prometheus/rules/alerts.yml` | Правила алертов |
| `/etc/prometheus/targets/nodes.yml` | Дополнительные Node Exporters |
| `/etc/prometheus/targets/blackbox-http.yml` | HTTP endpoints |
| `/etc/prometheus/targets/blackbox-icmp.yml` | Хосты для ping |

## Добавить серверы для мониторинга

```bash
cat >> /etc/prometheus/targets/nodes.yml << 'EOF'
- targets:
    - '192.168.1.10:9100'
    - '192.168.1.11:9100'
  labels:
    env: 'production'
EOF
```

## Добавить HTTP endpoints

```bash
cat >> /etc/prometheus/targets/blackbox-http.yml << 'EOF'
- targets:
    - 'https://example.com'
    - 'https://api.example.com/health'
  labels:
    env: 'production'
EOF
```

## Добавить ping мониторинг

```bash
cat >> /etc/prometheus/targets/blackbox-icmp.yml << 'EOF'
- targets:
    - '192.168.1.1'
    - '8.8.8.8'
  labels:
    type: 'network'
EOF
```

## Проверка конфигурации

```bash
promtool check config /etc/prometheus/prometheus.yml
```

## Grafana

Добавьте Data Source:
- Type: **Prometheus**
- URL: `http://<prometheus-ip>:9090`

Рекомендуемые дашборды:
- **1860** — Node Exporter Full
- **7587** — Blackbox Exporter
- **9628** — PostgreSQL

## Подготовка Proxmox VE

1. Создать пользователя `prometheus@pve`
2. Создать API Token с Privilege Separation
3. Назначить роль `PVEAuditor` на `/`

## Подготовка PostgreSQL

```sql
CREATE USER prometheus WITH PASSWORD 'password';
GRANT pg_monitor TO prometheus;
```

## Полезные PromQL запросы

```promql
# CPU usage %
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage %
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage %
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# HTTP probe success
probe_success{job="blackbox-http"}

# SSL days until expiry
(probe_ssl_earliest_cert_expiry - time()) / 86400
```

