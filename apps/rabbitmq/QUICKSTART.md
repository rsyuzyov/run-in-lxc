# RabbitMQ Quick Start

## Требования

- Debian 11+ / Ubuntu 20.04+
- 2+ CPU, 2+ GB RAM, 10+ GB диска
- Права root

## Установка за 1 минуту

```bash
# Базовая установка
./install.sh

# ИЛИ с мониторингом
./install.sh --prometheus
```

## После установки

### Учётные данные

```bash
cat /root/rabbitmq-credentials/info.txt
```

### Management UI

Откройте в браузере: `http://<IP>:15672`

Логин и пароль — в файле учётных данных.

### Проверка статуса

```bash
# Статус сервиса
systemctl status rabbitmq-server

# Статус RabbitMQ
rabbitmqctl status

# Список очередей
rabbitmqctl list_queues
```

## Быстрый тест

### Из командной строки (rabbitmqadmin)

```bash
# Установка rabbitmqadmin
wget http://localhost:15672/cli/rabbitmqadmin
chmod +x rabbitmqadmin

# Создать очередь
./rabbitmqadmin declare queue name=test durable=true

# Опубликовать сообщение
./rabbitmqadmin publish routing_key=test payload="Hello RabbitMQ!"

# Получить сообщение
./rabbitmqadmin get queue=test
```

### Python

```bash
pip install pika
```

```python
import pika

# Подключение
conn = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
ch = conn.channel()

# Создать очередь
ch.queue_declare(queue='hello')

# Отправить сообщение
ch.basic_publish(exchange='', routing_key='hello', body='Hello World!')
print("Sent!")

conn.close()
```

## Частые сценарии

### С TLS

```bash
./install.sh \
  --tls \
  --tls-cert /path/to/cert.pem \
  --tls-key /path/to/key.pem
```

### С MQTT для IoT

```bash
./install.sh --mqtt --prometheus
```

### Кластер (на каждом узле)

```bash
./install.sh \
  --cluster \
  --cluster-name myrabbit \
  --erlang-cookie "SECRETCOOKIE123" \
  --cluster-nodes "rabbit@node1,rabbit@node2,rabbit@node3"
```

**Важно:** Erlang cookie должен быть одинаковым на всех узлах!

## Полезные команды

```bash
# Список пользователей
rabbitmqctl list_users

# Добавить пользователя
rabbitmqctl add_user myuser mypassword
rabbitmqctl set_user_tags myuser administrator
rabbitmqctl set_permissions -p / myuser ".*" ".*" ".*"

# Список очередей с сообщениями
rabbitmqctl list_queues name messages consumers

# Статус кластера
rabbitmqctl cluster_status

# Логи
journalctl -u rabbitmq-server -f
```

## Порты

| Порт | Назначение |
|------|------------|
| 5672 | AMQP |
| 15672 | Management UI |
| 15692 | Prometheus |
| 1883 | MQTT |

## Проблемы?

```bash
# Проверить логи
journalctl -u rabbitmq-server -n 50

# Проверить конфигурацию
cat /etc/rabbitmq/rabbitmq.conf

# Перезапустить
systemctl restart rabbitmq-server
```

## Документация

Полная документация: [README.md](README.md)

