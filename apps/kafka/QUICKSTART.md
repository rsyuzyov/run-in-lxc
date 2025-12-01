# Kafka — Быстрый старт

## Установка

```bash
# Минимальная (single-node KRaft)
./install.sh

# С веб-интерфейсом
./install.sh --with-ui

# Полный стек
./install.sh --with-ui --with-schema-registry --with-connect --prometheus
```

## Порты

| Сервис | Порт |
|--------|------|
| Kafka | 9092 |
| Controller (KRaft) | 9093 |
| ZooKeeper | 2181 |
| Web UI | 8080 |
| Schema Registry | 8081 |
| Kafka Connect | 8083 |
| Kafka Exporter | 9308 |
| JMX | 9999 |

## Управление сервисами

```bash
# Статус
systemctl status kafka
systemctl status kafka-ui
systemctl status confluent-schema-registry
systemctl status kafka-connect

# Перезапуск
systemctl restart kafka

# Логи
journalctl -u kafka -f
```

## Работа с топиками

```bash
# Список топиков
kafka-topics --list --bootstrap-server localhost:9092

# Создание топика
kafka-topics --create --topic my-topic --partitions 3 --replication-factor 1 --bootstrap-server localhost:9092

# Информация о топике
kafka-topics --describe --topic my-topic --bootstrap-server localhost:9092

# Удаление топика
kafka-topics --delete --topic my-topic --bootstrap-server localhost:9092
```

## Отправка/чтение сообщений

```bash
# Отправка (интерактивно)
kafka-console-producer --topic my-topic --bootstrap-server localhost:9092

# Отправка из файла
cat data.txt | kafka-console-producer --topic my-topic --bootstrap-server localhost:9092

# Чтение с начала
kafka-console-consumer --topic my-topic --from-beginning --bootstrap-server localhost:9092

# Чтение последних 10 сообщений
kafka-console-consumer --topic my-topic --max-messages 10 --bootstrap-server localhost:9092
```

## Consumer Groups

```bash
# Список групп
kafka-consumer-groups --list --bootstrap-server localhost:9092

# Детали группы (lag)
kafka-consumer-groups --describe --group my-group --bootstrap-server localhost:9092

# Сброс offset к началу
kafka-consumer-groups --reset-offsets --group my-group --topic my-topic --to-earliest --execute --bootstrap-server localhost:9092
```

## Schema Registry

```bash
# Список схем
curl http://localhost:8081/subjects

# Получить последнюю версию
curl http://localhost:8081/subjects/my-topic-value/versions/latest
```

## Kafka Connect

```bash
# Список коннекторов
curl http://localhost:8083/connectors

# Статус коннектора
curl http://localhost:8083/connectors/my-connector/status

# Плагины размещать в:
/opt/kafka-connect/plugins/
```

## Кластер (3 ноды)

```bash
# Нода 1
./install.sh --mode cluster --node-id 1 \
  --controller-quorum "1@n1:9093,2@n2:9093,3@n3:9093" \
  --bootstrap-servers "n1:9092,n2:9092,n3:9092" \
  --advertised-host n1

# Нода 2 (использовать cluster-id с ноды 1)
./install.sh --mode cluster --node-id 2 \
  --cluster-id $(ssh n1 cat /etc/kafka/cluster-id) \
  --controller-quorum "1@n1:9093,2@n2:9093,3@n3:9093" \
  --bootstrap-servers "n1:9092,n2:9092,n3:9092" \
  --advertised-host n2

# Нода 3
./install.sh --mode cluster --node-id 3 \
  --cluster-id $(ssh n1 cat /etc/kafka/cluster-id) \
  --controller-quorum "1@n1:9093,2@n2:9093,3@n3:9093" \
  --bootstrap-servers "n1:9092,n2:9092,n3:9092" \
  --advertised-host n3
```

## Конфигурация

| Файл | Описание |
|------|----------|
| `/etc/kafka/server.properties` | Основная конфигурация Kafka |
| `/etc/kafka/connect-distributed.properties` | Kafka Connect |
| `/etc/schema-registry/schema-registry.properties` | Schema Registry |
| `/etc/kafka/credentials/info.txt` | Информация об установке |

## Диагностика

```bash
# Проверка брокера
kafka-broker-api-versions --bootstrap-server localhost:9092

# Проверка репликации
kafka-topics --describe --under-replicated-partitions --bootstrap-server localhost:9092

# Проверка портов
ss -tlnp | grep -E '9092|9093|8080|8081|8083'
```

