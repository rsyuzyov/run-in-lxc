# RabbitMQ для LXC контейнеров

Скрипт установки RabbitMQ — надёжного брокера сообщений с поддержкой множества протоколов (AMQP, MQTT, STOMP).

## Возможности

- **AMQP 0-9-1** — основной протокол с exchanges, queues, bindings
- **Management UI** — веб-интерфейс для администрирования
- **Кластеризация** — высокая доступность и масштабирование
- **Quorum Queues** — надёжные реплицируемые очереди
- **TLS/SSL** — шифрование соединений
- **MQTT** — для IoT устройств
- **STOMP** — для веб-клиентов
- **Federation/Shovel** — географически распределённые системы
- **Prometheus** — встроенные метрики

## Быстрый старт

```bash
# Базовая установка
./install.sh

# С Prometheus мониторингом
./install.sh --prometheus

# С указанным паролем
./install.sh --admin-user admin --admin-password SecurePass123
```

## Опции

### Основные

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--version VERSION` | Версия RabbitMQ | latest |
| `--port PORT` | AMQP порт | 5672 |
| `--management-port PORT` | Порт Management UI | 15672 |
| `--data-dir PATH` | Директория данных | /var/lib/rabbitmq |
| `--check` | Только проверка требований | - |

### Администратор

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--admin-user USER` | Имя администратора | admin |
| `--admin-password PASS` | Пароль (генерируется если не указан) | - |
| `--vhost VHOST` | Virtual host | / |

### Кластеризация

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--cluster` | Включить кластерный режим | - |
| `--cluster-name NAME` | Имя кластера | rabbit |
| `--cluster-nodes NODES` | Узлы (через запятую) | - |
| `--erlang-cookie COOKIE` | Erlang cookie | (генерируется) |

### TLS/SSL

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--tls` | Включить TLS | - |
| `--tls-cert PATH` | Путь к сертификату | - |
| `--tls-key PATH` | Путь к приватному ключу | - |
| `--tls-ca PATH` | Путь к CA сертификату | - |
| `--tls-verify` | Требовать клиентские сертификаты | - |

### Плагины

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--no-management` | Отключить Management UI | - |
| `--prometheus` | Включить Prometheus (порт 15692) | - |
| `--mqtt` | Включить MQTT plugin | - |
| `--mqtt-port PORT` | Порт MQTT | 1883 |
| `--stomp` | Включить STOMP plugin | - |
| `--stomp-port PORT` | Порт STOMP | 61613 |
| `--shovel` | Включить Shovel plugin | - |
| `--federation` | Включить Federation plugin | - |

### Лимиты

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--disk-free-limit SIZE` | Минимум свободного места | 1GB |
| `--memory-limit RATIO` | Лимит памяти 0.0-1.0 | 0.4 |
| `--channel-max N` | Максимум каналов | 2047 |
| `--connection-max N` | Максимум соединений | без лимита |

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

### С Prometheus и MQTT

```bash
./install.sh --prometheus --mqtt
```

### С указанным паролем

```bash
./install.sh --admin-user admin --admin-password SecurePass123
```

### С TLS

```bash
./install.sh \
  --tls \
  --tls-cert /etc/ssl/certs/rabbitmq.crt \
  --tls-key /etc/ssl/private/rabbitmq.key \
  --tls-ca /etc/ssl/certs/ca.crt
```

### Кластер из 3 узлов

**Важно:** Используйте одинаковый `--erlang-cookie` на всех узлах!

На узле 1 (rabbit1, 192.168.1.10):
```bash
./install.sh \
  --cluster \
  --cluster-name production \
  --erlang-cookie "MYSECRETCOOKIE" \
  --cluster-nodes "rabbit@rabbit1,rabbit@rabbit2,rabbit@rabbit3" \
  --prometheus
```

На узле 2 (rabbit2, 192.168.1.11):
```bash
./install.sh \
  --cluster \
  --cluster-name production \
  --erlang-cookie "MYSECRETCOOKIE" \
  --cluster-nodes "rabbit@rabbit1,rabbit@rabbit2,rabbit@rabbit3" \
  --prometheus
```

На узле 3 (rabbit3, 192.168.1.12):
```bash
./install.sh \
  --cluster \
  --cluster-name production \
  --erlang-cookie "MYSECRETCOOKIE" \
  --cluster-nodes "rabbit@rabbit1,rabbit@rabbit2,rabbit@rabbit3" \
  --prometheus
```

### С Nginx и Let's Encrypt

```bash
./install.sh \
  --prometheus \
  --with-nginx \
  --domain rabbitmq.example.com \
  --letsencrypt \
  --email admin@example.com
```

### Полная установка со всеми протоколами

```bash
./install.sh \
  --admin-user admin \
  --admin-password SecurePass123 \
  --prometheus \
  --mqtt \
  --stomp \
  --shovel \
  --federation
```

## Пути установки

| Компонент | Путь |
|-----------|------|
| Конфигурация | `/etc/rabbitmq/rabbitmq.conf` |
| Environment | `/etc/rabbitmq/rabbitmq-env.conf` |
| Данные (Mnesia) | `/var/lib/rabbitmq/mnesia` |
| Логи | `/var/log/rabbitmq/` |
| Учётные данные | `/root/rabbitmq-credentials/info.txt` |
| Erlang cookie | `/var/lib/rabbitmq/.erlang.cookie` |
| Systemd сервис | `rabbitmq-server` |

## Порты

| Порт | Протокол | Описание |
|------|----------|----------|
| 5672 | AMQP | Основной порт |
| 5671 | AMQPS | AMQP с TLS |
| 15672 | HTTP | Management UI |
| 15692 | HTTP | Prometheus метрики |
| 25672 | Erlang | Кластерная коммуникация |
| 4369 | EPMD | Erlang Port Mapper |
| 1883 | MQTT | MQTT без TLS |
| 8883 | MQTTS | MQTT с TLS |
| 61613 | STOMP | STOMP без TLS |

## Управление сервисом

```bash
# Статус
systemctl status rabbitmq-server

# Запуск
systemctl start rabbitmq-server

# Остановка
systemctl stop rabbitmq-server

# Перезапуск
systemctl restart rabbitmq-server

# Логи
journalctl -u rabbitmq-server -f

# Логи (файл)
tail -f /var/log/rabbitmq/rabbit@*.log
```

## Команды rabbitmqctl

### Информация о сервере

```bash
# Статус сервера
rabbitmqctl status

# Версия
rabbitmqctl version

# Информация о ноде
rabbitmqctl node_health_check

# Статус кластера
rabbitmqctl cluster_status
```

### Управление пользователями

```bash
# Список пользователей
rabbitmqctl list_users

# Добавить пользователя
rabbitmqctl add_user username password

# Удалить пользователя
rabbitmqctl delete_user username

# Изменить пароль
rabbitmqctl change_password username newpassword

# Назначить роль
rabbitmqctl set_user_tags username administrator

# Права доступа
rabbitmqctl set_permissions -p / username ".*" ".*" ".*"
```

### Управление очередями

```bash
# Список очередей
rabbitmqctl list_queues

# Подробная информация
rabbitmqctl list_queues name messages consumers memory

# Очистить очередь
rabbitmqctl purge_queue queue_name

# Удалить очередь
rabbitmqctl delete_queue queue_name
```

### Управление exchanges

```bash
# Список exchanges
rabbitmqctl list_exchanges

# С подробностями
rabbitmqctl list_exchanges name type durable auto_delete
```

### Управление соединениями

```bash
# Список соединений
rabbitmqctl list_connections

# Подробная информация
rabbitmqctl list_connections user peer_host peer_port state

# Закрыть соединение
rabbitmqctl close_connection <connection_pid> "reason"

# Список каналов
rabbitmqctl list_channels
```

### Virtual hosts

```bash
# Список vhosts
rabbitmqctl list_vhosts

# Создать vhost
rabbitmqctl add_vhost my_vhost

# Удалить vhost
rabbitmqctl delete_vhost my_vhost

# Права для vhost
rabbitmqctl set_permissions -p my_vhost username ".*" ".*" ".*"
```

## Management UI

После установки Management UI доступен по адресу: `http://<ip>:15672`

### Возможности

- Обзор узлов, соединений, каналов
- Управление очередями и exchanges
- Мониторинг сообщений
- Управление пользователями и правами
- Экспорт/импорт конфигурации (definitions)
- Просмотр и отправка сообщений

### HTTP API

```bash
# Обзор
curl -u admin:password http://localhost:15672/api/overview

# Список очередей
curl -u admin:password http://localhost:15672/api/queues

# Список соединений
curl -u admin:password http://localhost:15672/api/connections

# Публикация сообщения
curl -u admin:password -X POST \
  -H "Content-Type: application/json" \
  -d '{"properties":{},"routing_key":"my.routing.key","payload":"Hello","payload_encoding":"string"}' \
  http://localhost:15672/api/exchanges/%2F/amq.default/publish
```

## Prometheus мониторинг

При включении `--prometheus` метрики доступны на порту 15692:

```bash
curl http://localhost:15692/metrics
```

### Конфигурация Prometheus

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15692']
```

### Основные метрики

- `rabbitmq_connections` — количество соединений
- `rabbitmq_channels` — количество каналов
- `rabbitmq_consumers` — количество консьюмеров
- `rabbitmq_queues` — количество очередей
- `rabbitmq_queue_messages` — сообщения в очередях
- `rabbitmq_queue_messages_ready` — готовые к доставке
- `rabbitmq_queue_messages_unacked` — неподтверждённые
- `rabbitmq_disk_space_available_bytes` — свободное место
- `rabbitmq_resident_memory_limit_bytes` — лимит памяти

### Grafana Dashboard

Рекомендуемые дашборды:
- [RabbitMQ Overview](https://grafana.com/grafana/dashboards/10991)
- [RabbitMQ Cluster](https://grafana.com/grafana/dashboards/4279)

## Интеграция с клиентами

### Python (pika)

```python
import pika

# Подключение
credentials = pika.PlainCredentials('admin', 'password')
connection = pika.BlockingConnection(
    pika.ConnectionParameters('localhost', 5672, '/', credentials)
)
channel = connection.channel()

# Создание очереди
channel.queue_declare(queue='hello', durable=True)

# Публикация
channel.basic_publish(
    exchange='',
    routing_key='hello',
    body='Hello World!',
    properties=pika.BasicProperties(delivery_mode=2)  # persistent
)

# Подписка
def callback(ch, method, properties, body):
    print(f"Received: {body}")
    ch.basic_ack(delivery_tag=method.delivery_tag)

channel.basic_consume(queue='hello', on_message_callback=callback)
channel.start_consuming()
```

### Go (amqp091-go)

```go
package main

import (
    "log"
    amqp "github.com/rabbitmq/amqp091-go"
)

func main() {
    conn, _ := amqp.Dial("amqp://admin:password@localhost:5672/")
    defer conn.Close()

    ch, _ := conn.Channel()
    defer ch.Close()

    // Создание очереди
    q, _ := ch.QueueDeclare("hello", true, false, false, false, nil)

    // Публикация
    ch.Publish("", q.Name, false, false, amqp.Publishing{
        DeliveryMode: amqp.Persistent,
        ContentType:  "text/plain",
        Body:         []byte("Hello World!"),
    })

    // Подписка
    msgs, _ := ch.Consume(q.Name, "", false, false, false, false, nil)
    for msg := range msgs {
        log.Printf("Received: %s", msg.Body)
        msg.Ack(false)
    }
}
```

### JavaScript (amqplib)

```javascript
const amqp = require('amqplib');

async function main() {
    const conn = await amqp.connect('amqp://admin:password@localhost:5672');
    const ch = await conn.createChannel();
    
    const queue = 'hello';
    await ch.assertQueue(queue, { durable: true });
    
    // Публикация
    ch.sendToQueue(queue, Buffer.from('Hello World!'), { persistent: true });
    
    // Подписка
    ch.consume(queue, (msg) => {
        console.log(`Received: ${msg.content.toString()}`);
        ch.ack(msg);
    });
}

main();
```

### Java (RabbitMQ Java Client)

```java
import com.rabbitmq.client.*;

public class Example {
    public static void main(String[] args) throws Exception {
        ConnectionFactory factory = new ConnectionFactory();
        factory.setUri("amqp://admin:password@localhost:5672/");
        
        try (Connection conn = factory.newConnection();
             Channel ch = conn.createChannel()) {
            
            String queue = "hello";
            ch.queueDeclare(queue, true, false, false, null);
            
            // Публикация
            ch.basicPublish("", queue, 
                MessageProperties.PERSISTENT_TEXT_PLAIN,
                "Hello World!".getBytes());
            
            // Подписка
            ch.basicConsume(queue, false, (tag, msg) -> {
                System.out.println("Received: " + new String(msg.getBody()));
                ch.basicAck(msg.getEnvelope().getDeliveryTag(), false);
            }, tag -> {});
        }
    }
}
```

## Архитектура кластера

### Single Node

```
┌─────────────────┐
│   RabbitMQ      │
│   ┌─────────┐   │
│   │ Queue A │   │
│   │ Queue B │   │
│   └─────────┘   │
└─────────────────┘
```

### Cluster (3 nodes)

```
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   rabbit@node1  │←→│   rabbit@node2  │←→│   rabbit@node3  │
│   ┌─────────┐   │   │   ┌─────────┐   │   │   ┌─────────┐   │
│   │ Queue A │   │   │   │ Queue A │   │   │   │ Queue A │   │
│   │ (leader)│   │   │   │(replica)│   │   │   │(replica)│   │
│   └─────────┘   │   │   └─────────┘   │   │   └─────────┘   │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

### Quorum Queues

Для высокой доступности используйте Quorum Queues:

```bash
# CLI
rabbitmqctl set_policy ha-queues "^ha\." \
  '{"queue-mode":"quorum"}' \
  --apply-to queues
```

```python
# Python
channel.queue_declare(
    queue='ha.orders',
    durable=True,
    arguments={'x-queue-type': 'quorum'}
)
```

## Безопасность

### TLS/SSL

```bash
./install.sh \
  --tls \
  --tls-cert /path/to/server.crt \
  --tls-key /path/to/server.key \
  --tls-ca /path/to/ca.crt \
  --tls-verify
```

### Firewall (UFW)

```bash
# AMQP
ufw allow 5672/tcp comment "RabbitMQ AMQP"
ufw allow 5671/tcp comment "RabbitMQ AMQPS"

# Management
ufw allow 15672/tcp comment "RabbitMQ Management"

# Prometheus (только для мониторинга)
ufw allow from 10.0.0.0/8 to any port 15692 comment "RabbitMQ Prometheus"

# Cluster (только между узлами)
ufw allow from 192.168.1.0/24 to any port 25672 comment "RabbitMQ Cluster"
ufw allow from 192.168.1.0/24 to any port 4369 comment "RabbitMQ EPMD"
```

### Рекомендации

1. **Удалите guest** — скрипт делает это автоматически
2. **Используйте TLS** в production
3. **Ограничьте права** — давайте минимально необходимые permissions
4. **Используйте vhosts** — для изоляции приложений
5. **Мониторьте соединения** — отслеживайте аномалии

## Производительность

### Рекомендации

1. **Используйте SSD** для данных
2. **Настройте memory watermark** в зависимости от нагрузки
3. **Используйте persistent messages** только когда нужно
4. **Prefetch count** — настройте для равномерной нагрузки
5. **Lazy queues** — для очередей с большим backlog

### Настройка лимитов

```bash
./install.sh \
  --memory-limit 0.6 \
  --disk-free-limit "2GB" \
  --channel-max 4096 \
  --connection-max 10000
```

### Типичная производительность

- **Throughput**: 20K-50K msg/sec (зависит от persistence)
- **Latency**: < 1ms (без persistence)
- **Connections**: 100K+ на узел

## Решение проблем

### Сервис не запускается

```bash
# Проверить логи
journalctl -u rabbitmq-server -n 100

# Проверить конфигурацию
rabbitmq-diagnostics check_running

# Проверить права
ls -la /var/lib/rabbitmq
```

### Проблемы с памятью

```bash
# Проверить статус памяти
rabbitmqctl status | grep -A 20 memory

# Memory alarm
rabbitmqctl set_vm_memory_high_watermark 0.6
```

### Проблемы с кластером

```bash
# Статус кластера
rabbitmqctl cluster_status

# Проверить cookie
cat /var/lib/rabbitmq/.erlang.cookie

# Проверить network partitions
rabbitmqctl list_partitions

# Переприсоединение к кластеру
rabbitmqctl stop_app
rabbitmqctl reset
rabbitmqctl join_cluster rabbit@node1
rabbitmqctl start_app
```

### Очередь переполнена

```bash
# Проверить очереди
rabbitmqctl list_queues name messages consumers

# Очистить очередь
rabbitmqctl purge_queue queue_name

# Проверить консьюмеры
rabbitmqctl list_consumers
```

## Резервное копирование

### Definitions (конфигурация)

```bash
# Экспорт через Management API
curl -u admin:password \
  http://localhost:15672/api/definitions > definitions.json

# Импорт
curl -u admin:password -X POST \
  -H "Content-Type: application/json" \
  -d @definitions.json \
  http://localhost:15672/api/definitions
```

### Mnesia (данные)

```bash
# Остановить сервис
systemctl stop rabbitmq-server

# Создать бэкап
tar -czvf rabbitmq-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/rabbitmq/mnesia

# Запустить сервис
systemctl start rabbitmq-server
```

## Системные требования

| Конфигурация | CPU | RAM | Диск |
|--------------|-----|-----|------|
| Минимальная | 2 | 2 GB | 10 GB |
| Рекомендуемая | 4 | 4 GB | 40 GB |
| Кластер (на узел) | 4 | 8 GB | 100 GB SSD |
| High-load | 8+ | 16+ GB | 500+ GB NVMe |

## Ссылки

- [RabbitMQ Documentation](https://www.rabbitmq.com/documentation.html)
- [RabbitMQ GitHub](https://github.com/rabbitmq/rabbitmq-server)
- [RabbitMQ Tutorials](https://www.rabbitmq.com/getstarted.html)
- [Clustering Guide](https://www.rabbitmq.com/clustering.html)
- [Production Checklist](https://www.rabbitmq.com/production-checklist.html)
- [Monitoring Guide](https://www.rabbitmq.com/monitoring.html)

