# NATS Server для LXC контейнеров

Скрипт установки NATS Server — высокопроизводительной системы обмена сообщениями для облачных и микросервисных приложений.

## Возможности

- **NATS Core** — pub/sub, request/reply, queue groups
- **JetStream** — персистентность, стримы, консьюмеры
- **Кластеризация** — отказоустойчивость и масштабирование
- **Leaf Nodes** — иерархическая топология
- **WebSocket** — подключение из браузера
- **MQTT Bridge** — совместимость с MQTT клиентами
- **TLS/SSL** — шифрование соединений
- **Аутентификация** — токены, пользователи, аккаунты
- **Prometheus** — метрики для мониторинга

## Быстрый старт

```bash
# Базовая установка
./install.sh

# С JetStream (персистентность)
./install.sh --jetstream

# С JetStream и мониторингом
./install.sh --jetstream --prometheus
```

## Опции

### Основные

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--version VERSION` | Версия NATS Server | latest |
| `--port PORT` | Клиентский порт | 4222 |
| `--http-port PORT` | HTTP мониторинг | 8222 |
| `--data-dir PATH` | Директория данных | /var/lib/nats-server |
| `--no-cli` | Не устанавливать NATS CLI | - |
| `--check` | Только проверка требований | - |

### JetStream (персистентность)

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--jetstream` | Включить JetStream | - |
| `--js-max-mem SIZE` | Лимит памяти | 1G |
| `--js-max-file SIZE` | Лимит файлового хранилища | 10G |

### Кластеризация

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--cluster` | Включить кластерный режим | - |
| `--cluster-name NAME` | Имя кластера | nats-cluster |
| `--cluster-port PORT` | Порт кластера | 6222 |
| `--routes ROUTES` | Маршруты (через запятую) | - |
| `--server-name NAME` | Имя сервера | hostname |

### Leaf Nodes

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--leafnodes` | Включить leaf node listener | - |
| `--leafnode-port PORT` | Порт для leaf nodes | 7422 |
| `--leafnode-remotes URLS` | Удалённые серверы | - |

### TLS/SSL

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--tls` | Включить TLS | - |
| `--tls-cert PATH` | Путь к сертификату | - |
| `--tls-key PATH` | Путь к приватному ключу | - |
| `--tls-ca PATH` | Путь к CA (для mTLS) | - |
| `--tls-verify` | Требовать клиентские сертификаты | - |

### Аутентификация

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--auth-token TOKEN` | Простой токен | - |
| `--auth-user USER` | Имя пользователя | - |
| `--auth-password PASS` | Пароль | - |
| `--accounts-file FILE` | Файл конфигурации аккаунтов | - |

### WebSocket

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--websocket` | Включить WebSocket | - |
| `--ws-port PORT` | Порт WebSocket | 8080 |
| `--ws-no-tls` | WebSocket без TLS | - |

### MQTT Bridge

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--mqtt` | Включить MQTT | - |
| `--mqtt-port PORT` | Порт MQTT | 1883 |

### Лимиты

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--max-connections N` | Максимум соединений | 64K |
| `--max-payload SIZE` | Макс. размер сообщения | 1MB |

### Мониторинг

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--prometheus` | Prometheus endpoint | - |

### Nginx (reverse proxy)

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--with-nginx` | Установить Nginx | - |
| `--domain DOMAIN` | Доменное имя | - |
| `--ssl` | SSL (самоподписанный) | - |
| `--letsencrypt` | Let's Encrypt | - |
| `--email EMAIL` | Email для Let's Encrypt | - |

## Примеры использования

### Базовая установка

```bash
./install.sh
```

### С JetStream и мониторингом

```bash
./install.sh --jetstream --prometheus
```

### С аутентификацией по токену

```bash
./install.sh --jetstream --auth-token "MySecretToken123"
```

### С аутентификацией по логину/паролю

```bash
./install.sh --jetstream --auth-user nats --auth-password SecurePass123
```

### С TLS

```bash
./install.sh \
  --jetstream \
  --tls \
  --tls-cert /etc/ssl/certs/nats.crt \
  --tls-key /etc/ssl/private/nats.key
```

### Полный кластер из 3 узлов

На узле 1 (192.168.1.10):
```bash
./install.sh \
  --jetstream \
  --cluster \
  --cluster-name production \
  --server-name nats-1 \
  --routes "nats://192.168.1.11:6222,nats://192.168.1.12:6222" \
  --prometheus
```

На узле 2 (192.168.1.11):
```bash
./install.sh \
  --jetstream \
  --cluster \
  --cluster-name production \
  --server-name nats-2 \
  --routes "nats://192.168.1.10:6222,nats://192.168.1.12:6222" \
  --prometheus
```

На узле 3 (192.168.1.12):
```bash
./install.sh \
  --jetstream \
  --cluster \
  --cluster-name production \
  --server-name nats-3 \
  --routes "nats://192.168.1.10:6222,nats://192.168.1.11:6222" \
  --prometheus
```

### С WebSocket и MQTT

```bash
./install.sh \
  --jetstream \
  --websocket \
  --mqtt \
  --prometheus
```

### Leaf Node (подключение к hub)

```bash
./install.sh \
  --jetstream \
  --leafnodes \
  --leafnode-remotes "nats://hub.example.com:7422"
```

### Hub для Leaf Nodes

```bash
./install.sh \
  --jetstream \
  --leafnodes \
  --leafnode-port 7422
```

### С Nginx и Let's Encrypt

```bash
./install.sh \
  --jetstream \
  --websocket \
  --with-nginx \
  --domain nats.example.com \
  --letsencrypt \
  --email admin@example.com
```

## Пути установки

| Компонент | Путь |
|-----------|------|
| Бинарник сервера | `/usr/local/bin/nats-server` |
| NATS CLI | `/usr/local/bin/nats` |
| Конфигурация | `/etc/nats/nats-server.conf` |
| Данные | `/var/lib/nats-server` |
| JetStream | `/var/lib/nats-server/jetstream` |
| Логи | `/var/log/nats/nats-server.log` |
| Учётные данные | `/root/nats-credentials/info.txt` |
| Systemd сервис | `nats-server` |

## Управление сервисом

```bash
# Статус
systemctl status nats-server

# Запуск
systemctl start nats-server

# Остановка
systemctl stop nats-server

# Перезапуск
systemctl restart nats-server

# Перезагрузка конфигурации (без остановки)
systemctl reload nats-server

# Логи
journalctl -u nats-server -f

# Логи (файл)
tail -f /var/log/nats/nats-server.log
```

## NATS CLI

После установки доступна утилита `nats` для администрирования.

### Информация о сервере

```bash
# Информация о сервере
nats server info

# С аутентификацией
nats server info --user nats --password SecurePass123

# Список всех серверов в кластере
nats server list

# Проверка здоровья
nats server ping
```

### Публикация и подписка

```bash
# Подписка на топик
nats sub "orders.>"

# Публикация сообщения
nats pub orders.new '{"id": 123, "item": "book"}'

# Request/Reply
nats request orders.process '{"id": 123}'
```

### JetStream

```bash
# Создание стрима
nats stream add ORDERS \
  --subjects "orders.>" \
  --storage file \
  --replicas 3 \
  --retention limits \
  --max-msgs 1000000 \
  --max-bytes 1GB

# Список стримов
nats stream ls

# Информация о стриме
nats stream info ORDERS

# Создание консьюмера
nats consumer add ORDERS processor \
  --filter "orders.new" \
  --ack explicit \
  --deliver all \
  --replay instant

# Список консьюмеров
nats consumer ls ORDERS

# Чтение сообщений
nats consumer next ORDERS processor --count 10
```

### Мониторинг

```bash
# Статистика в реальном времени
nats server report connections
nats server report accounts
nats server report jetstream

# Топ соединений
nats server top
```

## HTTP мониторинг

NATS Server предоставляет HTTP API для мониторинга:

| Endpoint | Описание |
|----------|----------|
| `/healthz` | Проверка здоровья |
| `/varz` | Общая информация о сервере |
| `/connz` | Информация о соединениях |
| `/routez` | Информация о маршрутах кластера |
| `/subsz` | Информация о подписках |
| `/jsz` | Информация о JetStream |
| `/leafz` | Информация о leaf nodes |
| `/gatewayz` | Информация о супер-кластере |
| `/metrics` | Prometheus метрики |

Примеры:

```bash
# Здоровье сервера
curl http://localhost:8222/healthz

# Информация о сервере
curl http://localhost:8222/varz

# Соединения
curl http://localhost:8222/connz

# JetStream статистика
curl http://localhost:8222/jsz

# Prometheus метрики
curl http://localhost:8222/metrics
```

## Prometheus мониторинг

При включении `--prometheus` метрики доступны на `/metrics`:

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'nats'
    static_configs:
      - targets: ['nats-server:8222']
```

### Основные метрики

- `nats_server_info` — информация о сервере
- `nats_server_connections` — количество соединений
- `nats_server_subscriptions` — количество подписок
- `nats_server_bytes_in/out` — байты in/out
- `nats_server_msgs_in/out` — сообщения in/out
- `nats_jetstream_streams` — количество стримов
- `nats_jetstream_consumers` — количество консьюмеров
- `nats_jetstream_messages` — сообщения в JetStream

## Интеграция с клиентами

### Go

```go
import "github.com/nats-io/nats.go"

// Подключение
nc, _ := nats.Connect("nats://localhost:4222")

// С аутентификацией
nc, _ := nats.Connect("nats://user:pass@localhost:4222")

// Публикация
nc.Publish("orders.new", []byte(`{"id": 1}`))

// Подписка
nc.Subscribe("orders.>", func(m *nats.Msg) {
    fmt.Printf("Received: %s\n", string(m.Data))
})

// JetStream
js, _ := nc.JetStream()
js.Publish("orders.new", []byte(`{"id": 1}`))
```

### Python

```python
import nats
import asyncio

async def main():
    nc = await nats.connect("nats://localhost:4222")
    
    # Публикация
    await nc.publish("orders.new", b'{"id": 1}')
    
    # Подписка
    async def handler(msg):
        print(f"Received: {msg.data.decode()}")
    
    await nc.subscribe("orders.>", cb=handler)
    
    # JetStream
    js = nc.jetstream()
    await js.publish("orders.new", b'{"id": 1}')

asyncio.run(main())
```

### JavaScript/TypeScript

```typescript
import { connect, StringCodec } from "nats";

const nc = await connect({ servers: "nats://localhost:4222" });
const sc = StringCodec();

// Публикация
nc.publish("orders.new", sc.encode('{"id": 1}'));

// Подписка
const sub = nc.subscribe("orders.>");
for await (const m of sub) {
    console.log(`Received: ${sc.decode(m.data)}`);
}

// JetStream
const js = nc.jetstream();
await js.publish("orders.new", sc.encode('{"id": 1}'));
```

### WebSocket (браузер)

```javascript
import { connect } from "nats.ws";

const nc = await connect({ servers: "ws://localhost:8080" });

nc.publish("orders.new", '{"id": 1}');

const sub = nc.subscribe("orders.>");
for await (const m of sub) {
    console.log(`Received: ${m.data}`);
}
```

## Архитектура кластера

### Full Mesh (рекомендуется для 3-5 узлов)

```
    nats-1 ←→ nats-2
      ↕         ↕
        nats-3
```

Все узлы соединены друг с другом.

### Hub-Spoke (Leaf Nodes)

```
         Hub Cluster
    [nats-1] [nats-2] [nats-3]
         ↑       ↑       ↑
    ┌────┴───┐   │   ┌───┴────┐
    │        │   │   │        │
  leaf-1  leaf-2 │ leaf-3  leaf-4
                 │
              leaf-5
```

Для географически распределённых систем.

### Super Cluster (Gateways)

```
    Cluster A          Cluster B
  [a1] [a2] [a3]  ←→  [b1] [b2] [b3]
```

Для глобального масштабирования.

## Безопасность

### TLS

Для production обязательно используйте TLS:

```bash
./install.sh \
  --jetstream \
  --tls \
  --tls-cert /etc/ssl/certs/nats.crt \
  --tls-key /etc/ssl/private/nats.key \
  --tls-ca /etc/ssl/certs/ca.crt \
  --tls-verify
```

### Аутентификация

Рекомендуется использовать:
- **Токены** — для простых случаев
- **User/Password** — для небольших команд
- **NKeys** — для production (криптографические ключи)
- **JWT/Accounts** — для multi-tenant систем

### Firewall

Откройте только необходимые порты:

```bash
# UFW
ufw allow 4222/tcp comment "NATS Client"
ufw allow 8222/tcp comment "NATS HTTP"
ufw allow 6222/tcp comment "NATS Cluster"  # только между узлами кластера
ufw allow 7422/tcp comment "NATS Leaf"     # если используете leaf nodes
```

## Производительность

### Рекомендации

1. **Используйте SSD** для JetStream
2. **Настройте лимиты ОС**:
   ```bash
   # /etc/security/limits.conf
   nats soft nofile 65536
   nats hard nofile 65536
   ```
3. **Отключите swap** для критичных нагрузок
4. **Используйте отдельную сеть** для кластера

### Типичная производительность

- **Throughput**: 10M+ msg/sec (small messages)
- **Latency**: < 1ms (same datacenter)
- **Connections**: 100K+ на узел

## Решение проблем

### Сервис не запускается

```bash
# Проверить логи
journalctl -u nats-server -n 100

# Проверить конфигурацию
nats-server -c /etc/nats/nats-server.conf --debug

# Проверить права
ls -la /var/lib/nats-server
```

### Проблемы с подключением

```bash
# Проверить, слушает ли порт
ss -tlnp | grep 4222

# Проверить firewall
ufw status

# Тест подключения
nats server ping
```

### JetStream не работает

```bash
# Проверить статус
curl http://localhost:8222/jsz

# Проверить хранилище
df -h /var/lib/nats-server

# Проверить права
ls -la /var/lib/nats-server/jetstream
```

### Проблемы с кластером

```bash
# Проверить маршруты
curl http://localhost:8222/routez

# Проверить связность
nats server list

# Проверить логи на всех узлах
journalctl -u nats-server | grep -i cluster
```

## Резервное копирование

### JetStream данные

```bash
# Остановить сервис
systemctl stop nats-server

# Создать резервную копию
tar -czvf nats-backup-$(date +%Y%m%d).tar.gz /var/lib/nats-server/jetstream

# Запустить сервис
systemctl start nats-server
```

### Конфигурация

```bash
cp /etc/nats/nats-server.conf /backup/nats-server.conf.bak
```

## Системные требования

| Конфигурация | CPU | RAM | Диск |
|--------------|-----|-----|------|
| Минимальная (без JetStream) | 1 | 512 MB | 2 GB |
| С JetStream | 2 | 2 GB | 20 GB |
| Кластер (на узел) | 2 | 4 GB | 40 GB |
| Production | 4+ | 8+ GB | 100+ GB SSD |

## Ссылки

- [NATS Documentation](https://docs.nats.io/)
- [NATS GitHub](https://github.com/nats-io/nats-server)
- [NATS CLI](https://github.com/nats-io/natscli)
- [JetStream Documentation](https://docs.nats.io/nats-concepts/jetstream)
- [NATS by Example](https://natsbyexample.com/)

