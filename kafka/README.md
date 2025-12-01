# Apache Kafka для LXC контейнеров

Скрипт установки Apache Kafka с поддержкой KRaft mode (без ZooKeeper) и опциональными компонентами.

## Компоненты

| Компонент | Описание | Порт | Установка |
|-----------|----------|------|-----------|
| **Apache Kafka** | Брокер сообщений | 9092 | Всегда |
| **KRaft Controller** | Встроенный контроллер (без ZooKeeper) | 9093 | По умолчанию |
| **ZooKeeper** | Внешний координатор (legacy) | 2181 | `--with-zookeeper` |
| **Kafka UI** | Веб-интерфейс управления | 8080 | `--with-ui` |
| **Schema Registry** | Реестр схем Avro/JSON/Protobuf | 8081 | `--with-schema-registry` |
| **Kafka Connect** | Интеграция с внешними системами | 8083 | `--with-connect` |
| **Kafka Exporter** | Метрики для Prometheus | 9308 | `--prometheus` |

## Требования к ресурсам

| Ресурс | Минимум | Рекомендуется | Production |
|--------|---------|---------------|------------|
| CPU | 2 | 4 | 8+ |
| RAM | 4 GB | 8 GB | 16+ GB |
| Диск | 20 GB | 50 GB | 100+ GB SSD |

> **Важно**: Kafka интенсивно использует диск. Для production рекомендуется SSD с низкой латентностью.

## Быстрый старт

```bash
# Single-node (KRaft mode, без ZooKeeper)
./install.sh

# С веб-интерфейсом и Schema Registry
./install.sh --with-ui --with-schema-registry

# Полный стек
./install.sh --with-ui --with-schema-registry --with-connect --prometheus
```

## Режимы координации

### KRaft mode (рекомендуется)

KRaft (Kafka Raft) — встроенный механизм консенсуса, доступный с Kafka 3.x. Устраняет зависимость от ZooKeeper.

**Преимущества:**
- Упрощённая архитектура
- Быстрее восстановление после сбоев
- Меньше компонентов для обслуживания
- Лучшая масштабируемость

```bash
# Single-node KRaft (по умолчанию)
./install.sh

# Кластер KRaft (3 ноды)
# Нода 1:
./install.sh --mode cluster --node-id 1 \
  --controller-quorum "1@node1:9093,2@node2:9093,3@node3:9093" \
  --bootstrap-servers "node1:9092,node2:9092,node3:9092" \
  --advertised-host node1
```

### ZooKeeper mode (legacy)

Для совместимости со старыми версиями или специфическими требованиями.

```bash
# С встроенным ZooKeeper
./install.sh --with-zookeeper

# С внешним ZooKeeper кластером
./install.sh --with-zookeeper --zookeeper-connect "zk1:2181,zk2:2181,zk3:2181"
```

## Опции установки

### Основные опции

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--version VERSION` | Версия Kafka | 3.7.0 |
| `--mode single\|cluster` | Режим установки | single |
| `--with-zookeeper` | Использовать ZooKeeper | - |
| `--node-id ID` | ID ноды в кластере | 1 |

### Настройки сети

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--advertised-host HOST` | Внешний адрес для клиентов | auto |
| `--kafka-port PORT` | Порт Kafka | 9092 |

### Настройки хранения

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--data-dir PATH` | Путь к данным | /var/lib/kafka |
| `--retention-hours HOURS` | Время хранения сообщений | 168 (7 дней) |
| `--retention-bytes SIZE` | Макс. размер на partition | -1 (без лимита) |

### Настройки JVM

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--heap-size SIZE` | Размер Java heap | 2g |
| `--jvm-opts "OPTS"` | Дополнительные JVM опции | - |

### Дополнительные компоненты

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--with-ui [TYPE]` | Web UI (kafka-ui, akhq, kafdrop) | kafka-ui |
| `--ui-port PORT` | Порт Web UI | 8080 |
| `--with-schema-registry` | Confluent Schema Registry | - |
| `--schema-registry-port PORT` | Порт Schema Registry | 8081 |
| `--with-connect` | Kafka Connect | - |
| `--connect-port PORT` | Порт Kafka Connect | 8083 |
| `--prometheus` | Kafka Exporter для Prometheus | - |

### Безопасность

| Опция | Описание |
|-------|----------|
| `--ssl` | Включить SSL/TLS |
| `--ssl-keystore PATH` | Путь к keystore |
| `--ssl-keystore-pass PASS` | Пароль keystore |
| `--ssl-truststore PATH` | Путь к truststore |
| `--ssl-truststore-pass PASS` | Пароль truststore |
| `--sasl` | Включить SASL аутентификацию |
| `--sasl-mechanism MECH` | Механизм (PLAIN, SCRAM-SHA-256, SCRAM-SHA-512) |
| `--sasl-users USER:PASS` | Пользователи (user1:pass1,user2:pass2) |

## Примеры использования

### Single-node для разработки

```bash
./install.sh --with-ui
```

### Production single-node

```bash
./install.sh \
  --heap-size 4g \
  --retention-hours 336 \
  --data-dir /mnt/kafka-data \
  --with-ui \
  --with-schema-registry \
  --prometheus
```

### Кластер из 3 нод

На каждой ноде выполните (подставьте правильные адреса):

```bash
# Node 1
./install.sh --mode cluster --node-id 1 \
  --controller-quorum "1@kafka1.local:9093,2@kafka2.local:9093,3@kafka3.local:9093" \
  --bootstrap-servers "kafka1.local:9092,kafka2.local:9092,kafka3.local:9092" \
  --advertised-host kafka1.local \
  --heap-size 8g

# Node 2
./install.sh --mode cluster --node-id 2 \
  --cluster-id <CLUSTER_ID_FROM_NODE_1> \
  --controller-quorum "1@kafka1.local:9093,2@kafka2.local:9093,3@kafka3.local:9093" \
  --bootstrap-servers "kafka1.local:9092,kafka2.local:9092,kafka3.local:9092" \
  --advertised-host kafka2.local \
  --heap-size 8g

# Node 3
./install.sh --mode cluster --node-id 3 \
  --cluster-id <CLUSTER_ID_FROM_NODE_1> \
  --controller-quorum "1@kafka1.local:9093,2@kafka2.local:9093,3@kafka3.local:9093" \
  --bootstrap-servers "kafka1.local:9092,kafka2.local:9092,kafka3.local:9092" \
  --advertised-host kafka3.local \
  --heap-size 8g
```

> **Важно**: `--cluster-id` должен быть одинаковым на всех нодах. Первая нода генерирует его автоматически, сохраняется в `/etc/kafka/cluster-id`.

### С SSL шифрованием

```bash
# С self-signed сертификатом (создастся автоматически)
./install.sh --ssl

# С существующими сертификатами
./install.sh --ssl \
  --ssl-keystore /path/to/kafka.keystore.jks \
  --ssl-keystore-pass mypassword \
  --ssl-truststore /path/to/kafka.truststore.jks \
  --ssl-truststore-pass mypassword
```

### С SASL аутентификацией

```bash
./install.sh --sasl \
  --sasl-mechanism SCRAM-SHA-256 \
  --sasl-users "producer:producer-secret,consumer:consumer-secret"
```

### Полная production установка

```bash
./install.sh \
  --version 3.7.0 \
  --heap-size 8g \
  --data-dir /mnt/kafka-data \
  --retention-hours 168 \
  --ssl \
  --sasl --sasl-mechanism SCRAM-SHA-512 \
  --sasl-users "app1:secret1,app2:secret2" \
  --with-ui \
  --with-schema-registry \
  --with-connect \
  --prometheus
```

## Структура файлов

```
/opt/kafka/                    # Kafka installation
├── bin/                       # Kafka scripts
├── config/                    # Default configs
└── libs/                      # Java libraries

/etc/kafka/                    # Configuration
├── server.properties          # Main Kafka config
├── zookeeper.properties       # ZooKeeper config (if enabled)
├── connect-distributed.properties  # Connect config (if enabled)
├── credentials/
│   └── info.txt               # Installation info
├── ssl/                       # SSL certificates (if enabled)
│   ├── kafka.keystore.jks
│   └── kafka.truststore.jks
└── sasl/                      # SASL config (if enabled)
    └── kafka_server_jaas.conf

/var/lib/kafka/                # Data directory
└── kraft-combined-logs/       # Kafka logs (KRaft mode)

/var/log/kafka/                # Application logs

/opt/kafka-ui/                 # Kafka UI (if installed)
/opt/kafka-connect/plugins/    # Connect plugins (if installed)
```

## Управление сервисами

### Kafka

```bash
# Статус
systemctl status kafka

# Запуск/остановка/перезапуск
systemctl start kafka
systemctl stop kafka
systemctl restart kafka

# Логи
journalctl -u kafka -f
```

### ZooKeeper (если установлен)

```bash
systemctl status zookeeper
systemctl restart zookeeper
journalctl -u zookeeper -f
```

### Дополнительные сервисы

```bash
# Web UI
systemctl status kafka-ui
systemctl restart kafka-ui

# Schema Registry
systemctl status confluent-schema-registry
systemctl restart confluent-schema-registry

# Kafka Connect
systemctl status kafka-connect
systemctl restart kafka-connect

# Kafka Exporter
systemctl status kafka-exporter
systemctl restart kafka-exporter
```

## Работа с топиками

### Создание топика

```bash
kafka-topics --create \
  --topic my-topic \
  --partitions 6 \
  --replication-factor 1 \
  --bootstrap-server localhost:9092
```

### Список топиков

```bash
kafka-topics --list --bootstrap-server localhost:9092
```

### Информация о топике

```bash
kafka-topics --describe --topic my-topic --bootstrap-server localhost:9092
```

### Изменение топика

```bash
# Увеличение партиций
kafka-topics --alter --topic my-topic --partitions 12 --bootstrap-server localhost:9092

# Изменение retention
kafka-configs --alter --entity-type topics --entity-name my-topic \
  --add-config retention.ms=86400000 \
  --bootstrap-server localhost:9092
```

### Удаление топика

```bash
kafka-topics --delete --topic my-topic --bootstrap-server localhost:9092
```

## Работа с сообщениями

### Отправка сообщений

```bash
# Интерактивный режим
kafka-console-producer --topic my-topic --bootstrap-server localhost:9092

# Из файла
cat messages.txt | kafka-console-producer --topic my-topic --bootstrap-server localhost:9092

# С ключами
kafka-console-producer --topic my-topic \
  --property "parse.key=true" \
  --property "key.separator=:" \
  --bootstrap-server localhost:9092
# Формат ввода: key:value
```

### Чтение сообщений

```bash
# С начала
kafka-console-consumer --topic my-topic --from-beginning --bootstrap-server localhost:9092

# Последние N сообщений
kafka-console-consumer --topic my-topic --max-messages 10 --bootstrap-server localhost:9092

# С ключами
kafka-console-consumer --topic my-topic --from-beginning \
  --property print.key=true \
  --property key.separator=": " \
  --bootstrap-server localhost:9092

# Конкретная партиция
kafka-console-consumer --topic my-topic --partition 0 --offset 100 --bootstrap-server localhost:9092
```

## Consumer Groups

### Список групп

```bash
kafka-consumer-groups --list --bootstrap-server localhost:9092
```

### Информация о группе

```bash
kafka-consumer-groups --describe --group my-group --bootstrap-server localhost:9092
```

### Сброс offset

```bash
# К началу
kafka-consumer-groups --reset-offsets --group my-group --topic my-topic \
  --to-earliest --execute --bootstrap-server localhost:9092

# К концу
kafka-consumer-groups --reset-offsets --group my-group --topic my-topic \
  --to-latest --execute --bootstrap-server localhost:9092

# К конкретному offset
kafka-consumer-groups --reset-offsets --group my-group --topic my-topic \
  --to-offset 1000 --execute --bootstrap-server localhost:9092

# Сдвиг назад
kafka-consumer-groups --reset-offsets --group my-group --topic my-topic \
  --shift-by -100 --execute --bootstrap-server localhost:9092
```

## Schema Registry

### Список схем

```bash
curl http://localhost:8081/subjects
```

### Регистрация схемы

```bash
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema": "{\"type\":\"record\",\"name\":\"User\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"age\",\"type\":\"int\"}]}"}' \
  http://localhost:8081/subjects/users-value/versions
```

### Получение схемы

```bash
curl http://localhost:8081/subjects/users-value/versions/latest
```

## Kafka Connect

### Список коннекторов

```bash
curl http://localhost:8083/connectors
```

### Создание коннектора

```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{
    "name": "my-file-source",
    "config": {
      "connector.class": "FileStreamSource",
      "tasks.max": "1",
      "file": "/tmp/test.txt",
      "topic": "file-topic"
    }
  }' \
  http://localhost:8083/connectors
```

### Статус коннектора

```bash
curl http://localhost:8083/connectors/my-file-source/status
```

### Установка плагинов

```bash
# Скачайте плагин и распакуйте в /opt/kafka-connect/plugins/
cd /opt/kafka-connect/plugins/
wget https://example.com/connector.zip
unzip connector.zip

# Перезапустите Connect
systemctl restart kafka-connect
```

## Мониторинг

### JMX метрики

Kafka экспортирует JMX метрики на порту 9999:

```bash
# Подключение через jconsole
jconsole localhost:9999
```

### Prometheus

При установке с `--prometheus` Kafka Exporter экспортирует метрики на порту 9308.

**Конфигурация Prometheus:**

```yaml
scrape_configs:
  - job_name: 'kafka'
    static_configs:
      - targets: ['kafka-host:9308']
```

**Рекомендуемые Grafana дашборды:**

| ID | Название | Описание |
|----|----------|----------|
| 7589 | Kafka Exporter Overview | Основные метрики Kafka |
| 12460 | Kafka Cluster Overview | Метрики кластера |
| 14012 | Kafka Connect | Метрики коннекторов |

### Проверка здоровья

```bash
# Проверка брокера
kafka-broker-api-versions --bootstrap-server localhost:9092

# Проверка кластера (KRaft)
kafka-metadata --snapshot /var/lib/kafka/kraft-combined-logs/__cluster_metadata-0/00000000000000000000.log --command "print"

# Проверка репликации
kafka-topics --describe --under-replicated-partitions --bootstrap-server localhost:9092
```

## Безопасность

### SSL/TLS

При использовании `--ssl` создаются self-signed сертификаты. Для production используйте собственные сертификаты.

**Создание keystore и truststore:**

```bash
# Создание CA
openssl req -new -x509 -keyout ca-key -out ca-cert -days 365

# Создание keystore для брокера
keytool -keystore kafka.keystore.jks -alias kafka -validity 365 -genkey -keyalg RSA

# Экспорт сертификата
keytool -keystore kafka.keystore.jks -alias kafka -certreq -file cert-file

# Подпись CA
openssl x509 -req -CA ca-cert -CAkey ca-key -in cert-file -out cert-signed -days 365 -CAcreateserial

# Импорт CA в keystore
keytool -keystore kafka.keystore.jks -alias CARoot -import -file ca-cert

# Импорт подписанного сертификата
keytool -keystore kafka.keystore.jks -alias kafka -import -file cert-signed

# Создание truststore
keytool -keystore kafka.truststore.jks -alias CARoot -import -file ca-cert
```

### SASL

Поддерживаемые механизмы:

| Механизм | Описание | Рекомендация |
|----------|----------|--------------|
| PLAIN | Простой логин/пароль | Только с SSL |
| SCRAM-SHA-256 | Challenge-response | Production |
| SCRAM-SHA-512 | Challenge-response (сильнее) | Production |

**Подключение клиента с SASL:**

```properties
# client.properties
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="myuser" \
  password="mypassword";
```

```bash
kafka-console-producer --topic my-topic \
  --bootstrap-server localhost:9092 \
  --producer.config client.properties
```

### ACL (Access Control Lists)

```bash
# Разрешить producer
kafka-acls --add --allow-principal User:producer \
  --operation Write --topic my-topic \
  --bootstrap-server localhost:9092

# Разрешить consumer
kafka-acls --add --allow-principal User:consumer \
  --operation Read --topic my-topic \
  --operation Read --group my-group \
  --bootstrap-server localhost:9092

# Список ACL
kafka-acls --list --bootstrap-server localhost:9092
```

## Производительность

### Tuning рекомендации

**server.properties:**

```properties
# Увеличение throughput
num.network.threads=8
num.io.threads=16
socket.send.buffer.bytes=1048576
socket.receive.buffer.bytes=1048576

# Компрессия
compression.type=lz4

# Batch settings
linger.ms=5
batch.size=65536
```

**JVM настройки (/etc/default/kafka):**

```bash
KAFKA_HEAP_OPTS="-Xmx8g -Xms8g"
KAFKA_JVM_PERFORMANCE_OPTS="-server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35"
```

### Benchmark

```bash
# Producer benchmark
kafka-producer-perf-test \
  --topic test-topic \
  --num-records 1000000 \
  --record-size 1000 \
  --throughput -1 \
  --producer-props bootstrap.servers=localhost:9092

# Consumer benchmark
kafka-consumer-perf-test \
  --topic test-topic \
  --messages 1000000 \
  --bootstrap-server localhost:9092
```

## Решение проблем

### Kafka не запускается

```bash
# Проверить логи
journalctl -u kafka -n 100

# Проверить конфигурацию
cat /etc/kafka/server.properties

# Проверить права
ls -la /var/lib/kafka/
ls -la /etc/kafka/

# Проверить порты
ss -tlnp | grep -E '9092|9093'
```

### KRaft проблемы

```bash
# Проверить metadata log
kafka-metadata --snapshot /var/lib/kafka/kraft-combined-logs/__cluster_metadata-0/00000000000000000000.log

# Переформатировать storage (ВНИМАНИЕ: удалит данные!)
kafka-storage format -t $(cat /etc/kafka/cluster-id) -c /etc/kafka/server.properties
```

### Проблемы с consumer lag

```bash
# Проверить lag
kafka-consumer-groups --describe --group my-group --bootstrap-server localhost:9092

# Причины:
# 1. Медленная обработка — увеличьте число consumers
# 2. Перебалансировка — проверьте session.timeout.ms
# 3. Сетевые проблемы — проверьте latency
```

### Out of Memory

```bash
# Увеличить heap
sudo systemctl edit kafka
# Добавить:
[Service]
Environment="KAFKA_HEAP_OPTS=-Xmx8g -Xms8g"

sudo systemctl restart kafka
```

### Disk full

```bash
# Уменьшить retention
kafka-configs --alter --entity-type topics --entity-name my-topic \
  --add-config retention.ms=3600000 \
  --bootstrap-server localhost:9092

# Удалить старые сегменты
kafka-delete-records --offset-json-file offsets.json --bootstrap-server localhost:9092
```

## Обновление

### Minor версии

```bash
# Остановить Kafka
systemctl stop kafka

# Скачать новую версию
cd /opt
wget https://downloads.apache.org/kafka/3.8.0/kafka_2.13-3.8.0.tgz
tar -xzf kafka_2.13-3.8.0.tgz

# Обновить символическую ссылку
rm /opt/kafka
ln -s /opt/kafka_2.13-3.8.0 /opt/kafka

# Запустить
systemctl start kafka
```

### Major версии

Требуется rolling upgrade с учётом inter.broker.protocol.version. См. [официальную документацию](https://kafka.apache.org/documentation/#upgrade).

## Полезные ссылки

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [KRaft Documentation](https://kafka.apache.org/documentation/#kraft)
- [Confluent Documentation](https://docs.confluent.io/)
- [Kafka UI GitHub](https://github.com/provectus/kafka-ui)
- [Schema Registry Documentation](https://docs.confluent.io/platform/current/schema-registry/index.html)
- [Kafka Connect Documentation](https://kafka.apache.org/documentation/#connect)

