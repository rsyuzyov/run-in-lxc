# NATS Server — Быстрый старт

## Установка

```bash
# Базовая
./install.sh

# С JetStream
./install.sh --jetstream

# С JetStream + мониторинг
./install.sh --jetstream --prometheus

# С аутентификацией
./install.sh --jetstream --auth-user nats --auth-password MyPass123
```

## Порты

| Порт | Назначение |
|------|------------|
| 4222 | Клиентские соединения |
| 8222 | HTTP мониторинг |
| 6222 | Кластер |
| 7422 | Leaf Nodes |
| 8080 | WebSocket |
| 1883 | MQTT |

## Управление

```bash
systemctl status nats-server      # статус
systemctl restart nats-server     # перезапуск
systemctl stop nats-server        # остановка
journalctl -u nats-server -f      # логи
```

## NATS CLI

```bash
# Информация
nats server info

# Pub/Sub
nats sub "orders.>"              # подписка
nats pub orders.new '{"id":1}'   # публикация

# JetStream
nats stream ls                   # стримы
nats stream add ORDERS --subjects "orders.>" --storage file
nats consumer ls ORDERS          # консьюмеры
```

## Мониторинг

```bash
curl http://localhost:8222/healthz   # здоровье
curl http://localhost:8222/varz      # статистика
curl http://localhost:8222/jsz       # JetStream
curl http://localhost:8222/metrics   # Prometheus
```

## Подключение

```
# Без аутентификации
nats://192.168.1.10:4222

# С токеном
nats://TOKEN@192.168.1.10:4222

# С логином/паролем
nats://user:pass@192.168.1.10:4222

# WebSocket
ws://192.168.1.10:8080
```

## Кластер (3 узла)

```bash
# Узел 1
./install.sh --jetstream --cluster --server-name n1 \
  --routes "nats://192.168.1.11:6222,nats://192.168.1.12:6222"

# Узел 2
./install.sh --jetstream --cluster --server-name n2 \
  --routes "nats://192.168.1.10:6222,nats://192.168.1.12:6222"

# Узел 3
./install.sh --jetstream --cluster --server-name n3 \
  --routes "nats://192.168.1.10:6222,nats://192.168.1.11:6222"
```

## Файлы

| Путь | Описание |
|------|----------|
| `/etc/nats/nats-server.conf` | Конфигурация |
| `/var/lib/nats-server` | Данные |
| `/var/log/nats/` | Логи |
| `/root/nats-credentials/info.txt` | Учётные данные |

## Документация

- [README.md](README.md) — полная документация
- [NATS Docs](https://docs.nats.io/)

