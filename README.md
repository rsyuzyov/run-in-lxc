# run-in-lxc

Этот репозиторий содержит скрипты и инструкции по установке и настройке различного программного обеспечения в LXC контейнерах.

## Структура проекта

Для каждой программы в репозитории выделен отдельный каталог:

### Приложения для установки в LXC

*   **`apache/`** - веб-сервер Apache HTTP Server
*   **`docker/`** - Docker CE с поддержкой зеркал и проверкой совместимости LXC
*   **`nginx/`** - веб-сервер Nginx
*   **`forgejo/`** - легковесный git-сервис (форк Gitea)
*   **`gitlab/`** - GitLab CE (Omnibus) — полноценный DevOps-сервис
*   **`gitlab-runner/`** - агент для выполнения CI/CD задач GitLab
*   **`jenkins/`** - Jenkins CI/CD сервер (контроллер + агенты, JCasC, интеграции)
*   **`foreman/`** - управление жизненным циклом хостов
*   **`1c/`** - сервер 1С:Предприятие 8
*   **`postgres/`** - база данных PostgreSQL
*   **`mariadb/`** - база данных MariaDB с поддержкой Galera Cluster
*   **`mongodb/`** - база данных MongoDB (NoSQL, документо-ориентированная)
*   **`prometheus/`** - система мониторинга и алертинга (Prometheus + Node Exporter + Blackbox Exporter)
*   **`kafka/`** - Apache Kafka (брокер сообщений с KRaft/ZooKeeper, Schema Registry, Connect)
*   **`nats/`** - NATS Server (высокопроизводительный брокер сообщений, JetStream, кластер)
*   **`rabbitmq/`** - RabbitMQ (брокер сообщений AMQP, MQTT, STOMP, Management UI, кластер)
*   **`motioneye/`** - веб-система видеонаблюдения MotionEye
*   **`shinobi/`** - система видеонаблюдения Shinobi CE (NVR) с поддержкой GPU
*   **`zoneminder/`** - система видеонаблюдения ZoneMinder (детекция движения, ML)
*   **`syncthing/`** - децентрализованная синхронизация файлов (P2P, без облака)

### Kubernetes (в LXC/VM)

*   **`kubernetes/`** - развёртывание Kubernetes кластеров
    * **`k3s/`** - легковесный Kubernetes от Rancher (рекомендуется для dev/test)
    * **`k0s/`** - Zero Friction Kubernetes от Mirantis (рекомендуется для production)
    * **`common/`** - общие утилиты (подготовка LXC, addons: Helm, MetalLB, Longhorn)

### Утилиты управления

*   **`proxmox/`** - скрипты для создания и управления LXC контейнерами в Proxmox VE

## Быстрый старт

### 1. Создание LXC контейнера в Proxmox

```bash
cd proxmox
sudo ./create-lxc.sh --name my-container --bootstrap
```

Скрипт автоматически:
- Создаст контейнер
- Выполнит базовую настройку (обновление, локали, SSH)
- Сохранит пароль root в `proxmox/credentials/`

Подробнее: [proxmox/README.md](proxmox/README.md)

### 2. Установка приложения в контейнер

Например, установка Forgejo:

```bash
# Подключитесь к контейнеру
ssh root@<IP>
# или
pct enter <ID>

# Клонируйте репозиторий
git clone <repo-url> run-in-lxc
cd run-in-lxc/forgejo

# Запустите установку
./install.sh
```

Подробнее: [forgejo/README.md](forgejo/README.md)

### 3. Пример: Установка GitLab CE

```bash
# В контейнере (мин. 4GB RAM, рекомендуется 8GB)
cd run-in-lxc/gitlab

# Минимальная установка (встроенные PostgreSQL и Redis)
sudo ./install.sh --domain gitlab.example.com

# Или с внешней базой данных
sudo ./install.sh \
  --domain gitlab.example.com \
  --db-host 192.168.1.100 \
  --db-name gitlabhq_production \
  --db-user gitlab \
  --db-password SecurePass123
```

Подробнее: [gitlab/README.md](gitlab/README.md)

### 4. Пример: Установка GitLab Runner

```bash
cd run-in-lxc/gitlab-runner

# Shell executor
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor shell

# Docker executor
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor docker \
  --install-docker
```

Подробнее: [gitlab-runner/README.md](gitlab-runner/README.md)

### 5. Пример: Установка Jenkins

```bash
cd run-in-lxc/jenkins

# Базовая установка
sudo ./install.sh

# С Nginx и Let's Encrypt
sudo ./install.sh \
  --with-nginx \
  --domain jenkins.example.com \
  --letsencrypt \
  --email admin@example.com

# Полная установка с JCasC и плагинами
sudo ./install.sh \
  --with-nginx \
  --domain jenkins.example.com \
  --letsencrypt \
  --email admin@example.com \
  --jcasc \
  --jcasc-file config/jenkins.yaml \
  --plugins config/plugins.txt \
  --prometheus

# Установка агента (inbound)
cd run-in-lxc/jenkins
sudo ./install-agent.sh \
  --url https://jenkins.example.com \
  --name agent-01 \
  --secret СЕКРЕТ_ИЗ_JENKINS \
  --install-docker \
  --labels "docker,linux"
```

После установки:
- Веб-интерфейс: `http://<IP>:8080`
- Initial Admin Password: `/var/lib/jenkins/secrets/initialAdminPassword`
- Учётные данные: `/root/jenkins-credentials/admin.txt`

Рекомендуемые ресурсы LXC: 4 CPU, 4 GB RAM, 20 GB диска.

Подробнее: [jenkins/README.md](jenkins/README.md)

### 7. Пример: Установка сервера 1С:Предприятие 8

```bash
cd run-in-lxc/1c

# Скачивание с releases.1c.ru
sudo ./install.sh \
  --version 8.3.25.1257 \
  --its-login user@example.com \
  --its-password YourPassword

# Или из локального каталога с дистрибутивами
sudo ./install.sh --distrib-dir /opt/distrib/1c

# Полная установка с сервером хранилища и веб-расширениями
sudo ./install.sh \
  --version 8.3.25.1257 \
  --its-login user@example.com \
  --its-password YourPassword \
  --with-crs --with-ws
```

Подробнее: [1c/README.md](1c/README.md)

### 8. Пример: Установка Foreman

```bash
cd run-in-lxc/foreman

# Минимальная установка (встроенные PostgreSQL и Redis)
sudo ./install.sh

# С проверками и конкретной версией
sudo ./install.sh --version 3.16 --check

# С внешней базой данных
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-user foreman \
  --db-password SecurePass123
```

Подробнее: [foreman/README.md](foreman/README.md)

### 9. Пример: Установка Apache

```bash
cd run-in-lxc/apache

# Базовая установка
sudo ./install.sh

# С виртуальным хостом и SSL
sudo ./install.sh --domain example.com --ssl

# С Let's Encrypt и PHP
sudo ./install.sh \
  --domain example.com \
  --email admin@example.com \
  --letsencrypt \
  --php

# Как обратный прокси
sudo ./install.sh \
  --domain app.example.com \
  --proxy-pass http://localhost:3000 \
  --ssl
```

Подробнее: [apache/README.md](apache/README.md)

### 10. Пример: Установка Docker

```bash
cd run-in-lxc/docker

# Базовая установка
sudo ./install.sh

# С зеркалом Docker Hub (быстрее)
sudo ./install.sh --mirror https://mirror.gcr.io

# С приватным registry без SSL
sudo ./install.sh --insecure-registries registry.local:5000

# Только проверка совместимости LXC
sudo ./install.sh --check
```

Подробнее: [docker/README.md](docker/README.md)

### 11. Пример: Установка Prometheus Stack

```bash
cd run-in-lxc/prometheus

# Базовая установка (Prometheus + Node Exporter + Blackbox Exporter)
sudo ./install.sh

# С Alertmanager и удалённым доступом (для Grafana)
sudo ./install.sh --alertmanager --allow-remote

# Полная установка с мониторингом Proxmox VE
sudo ./install.sh --alertmanager --allow-remote --proxmox \
  --proxmox-host 192.168.1.100:8006 \
  --proxmox-user prometheus@pve \
  --proxmox-token-id monitoring \
  --proxmox-token-secret xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# С мониторингом PostgreSQL
sudo ./install.sh --postgres-exporter \
  --pg-host 192.168.1.50 \
  --pg-user prometheus \
  --pg-password SecurePass123
```

Рекомендуемые ресурсы LXC: 2 CPU, 4 GB RAM, 20 GB диска.

Подробнее: [prometheus/README.md](prometheus/README.md)

### 12. Пример: Установка MotionEye

```bash
cd run-in-lxc/motioneye

# Базовая установка
sudo ./install.sh

# С часовым поясом и NFS-хранилищем
sudo ./install.sh \
  --timezone Europe/Moscow \
  --nfs-mount 192.168.1.100:/recordings

# Веб-интерфейс: http://<IP>:8765
# Логин: admin, пароль: (пустой)
```

Рекомендуемые ресурсы LXC: 2 CPU, 2 GB RAM, 8 GB диска.

Подробнее: [motioneye/README.md](motioneye/README.md)

### 13. Пример: Установка Shinobi CE (видеонаблюдение)

```bash
cd run-in-lxc/shinobi

# Минимальная установка (SQLite)
sudo ./install.sh

# С встроенным PostgreSQL
sudo ./install.sh --with-postgres

# С GPU ускорением (Intel VAAPI) и мониторингом
sudo ./install.sh --with-postgres --gpu intel --prometheus

# Полная production установка
sudo ./install.sh \
  --with-postgres \
  --gpu intel \
  --prometheus \
  --storage-path /mnt/recordings \
  --retention-days 60 \
  --admin-email admin@example.com

# С внешним PostgreSQL
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-name shinobi \
  --db-user shinobi \
  --db-password SecurePass123
```

После установки:
- Супер-админ: `http://<IP>:8080/super`
- Учётные данные: `/opt/shinobi/credentials/admin.txt`

Рекомендуемые ресурсы LXC: 4 CPU, 8 GB RAM, 40 GB диска + отдельное хранилище для записей.

Подробнее: [shinobi/README.md](shinobi/README.md)

### 14. Пример: Установка ZoneMinder

```bash
cd run-in-lxc/zoneminder

# Базовая установка
sudo ./install.sh --domain cameras.example.com

# С Let's Encrypt SSL
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt

# Полная установка с ML детекцией объектов
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt \
  --with-event-notification \
  --with-ml \
  --prometheus-exporter

# С внешней БД
sudo ./install.sh \
  --domain cameras.example.com \
  --db-host 192.168.1.100 \
  --db-name zm \
  --db-user zmuser \
  --db-password SecurePass123
```

После установки:
- Веб-интерфейс: `https://cameras.example.com/zm`
- Логин: `admin`, пароль: `admin`
- Учётные данные: `/root/zoneminder-credentials.txt`

Рекомендуемые ресурсы LXC: 2+ CPU, 4+ GB RAM, 50+ GB диска.

Подробнее: [zoneminder/README.md](zoneminder/README.md)

### 15. Пример: Установка Kubernetes (K3s)

```bash
# 1. На хосте Proxmox: создание LXC с настройками для K8s
cd run-in-lxc/kubernetes/common
sudo ./prepare-lxc.sh --create --name k8s --memory 4096 --cores 2

# 2. В контейнере: установка K3s (single-node)
cd run-in-lxc/kubernetes/k3s
sudo ./install.sh --mode single

# 3. Проверка
kubectl get nodes
kubectl get pods -A

# Multi-node кластер:
# Master
sudo ./install.sh --mode server --cluster-init

# Workers (на других узлах)
sudo ./install.sh --mode agent \
  --server https://<MASTER_IP>:6443 \
  --token <TOKEN>
```

**Альтернатива: k0s** (для production):

```bash
cd run-in-lxc/kubernetes/k0s
sudo ./install.sh --role single
```

**Дополнительные компоненты:**

```bash
cd run-in-lxc/kubernetes/common/addons

# Helm (менеджер пакетов)
./install-helm.sh

# MetalLB (LoadBalancer для bare-metal)
./install-metallb.sh --address-pool 192.168.1.200-192.168.1.220

# Longhorn (распределённое хранилище)
./install-longhorn.sh
```

Рекомендуемые ресурсы: 2+ CPU, 4+ GB RAM, 40+ GB диска.

Подробнее: [kubernetes/README.md](kubernetes/README.md)

### 16. Пример: Установка Syncthing

```bash
cd run-in-lxc/syncthing

# Базовая установка с паролем
sudo ./install.sh --gui-password "MySecurePassword"

# Для слабого ПК (Raspberry Pi и т.п.)
sudo ./install.sh \
  --low-resources \
  --max-recv-kbps 5000 \
  --max-send-kbps 5000 \
  --gui-password "MyPassword"

# Корпоративный сервер с SSL и мониторингом
sudo ./install.sh \
  --gui-password "$(openssl rand -base64 16)" \
  --prometheus \
  --nginx --ssl \
  --domain sync.company.local \
  --email admin@company.local

# Relay-сервер для NAT traversal
sudo ./install.sh --relay
```

После установки:
- Веб-интерфейс: `http://<IP>:8384`
- Учётные данные: `/var/lib/syncthing/credentials/info.txt`

Рекомендуемые ресурсы LXC: 1 CPU, 512 MB RAM (минимум), 8 GB диска.

Подробнее: [syncthing/README.md](syncthing/README.md)

### 17. Пример: Установка MongoDB

```bash
cd run-in-lxc/mongodb

# Базовая установка (dev/test, без авторизации)
sudo ./install.sh

# С авторизацией (рекомендуется)
sudo ./install.sh --auth --admin-password SecureAdminPass123

# Полная установка с базой, пользователем и мониторингом
sudo ./install.sh \
  --auth --admin-password AdminPass123 \
  --db-name myapp \
  --db-user myapp \
  --db-password AppPass123 \
  --allow-remote \
  --prometheus

# Подготовка для Replica Set
sudo ./install.sh \
  --auth --admin-password AdminPass123 \
  --replica-set rs0 \
  --allow-remote
```

После установки:
- Подключение: `mongosh -u root -p 'AdminPass123' --authenticationDatabase admin`
- Учётные данные: `/root/mongodb-credentials/credentials.txt`

Рекомендуемые ресурсы LXC: 2 CPU, 4 GB RAM, 20 GB диска.

Подробнее: [mongodb/README.md](mongodb/README.md)

### 18. Пример: Установка MariaDB

```bash
cd run-in-lxc/mariadb

# Базовая установка
sudo ./install.sh --root-password MySecurePass123

# Для веб-приложений (WordPress, Drupal)
sudo ./install.sh \
  --profile web \
  --root-password SecurePass \
  --db-name wordpress \
  --db-user wpuser \
  --db-password WpPass123 \
  --allow-remote

# С мониторингом Prometheus
sudo ./install.sh \
  --profile web \
  --root-password SecurePass \
  --db-name myapp \
  --db-user appuser \
  --db-password AppPass123 \
  --prometheus

# Galera Cluster (первый узел)
sudo ./install.sh --galera --bootstrap \
  --cluster-name production \
  --node-name node1 \
  --node-address 192.168.1.10 \
  --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12 \
  --root-password ClusterPass
```

Профили конфигурации:
- `default` — базовая конфигурация
- `web` — для веб-приложений (WordPress, CMS)
- `analytics` — для аналитики и OLAP
- `minimal` — минимальные ресурсы (dev/test)

После установки:
- Подключение: `mysql` (использует `/root/.my.cnf`)
- Учётные данные: `/root/mariadb-credentials/`

Рекомендуемые ресурсы LXC: 2 CPU, 2 GB RAM, 20 GB диска.

Подробнее: [mariadb/README.md](mariadb/README.md)

### 19. Пример: Установка Apache Kafka

```bash
cd run-in-lxc/kafka

# Базовая установка (single-node, KRaft mode)
sudo ./install.sh

# С веб-интерфейсом
sudo ./install.sh --with-ui

# Полный стек (UI + Schema Registry + Connect + мониторинг)
sudo ./install.sh \
  --with-ui \
  --with-schema-registry \
  --with-connect \
  --prometheus

# С увеличенными ресурсами и хранилищем
sudo ./install.sh \
  --heap-size 4g \
  --data-dir /mnt/kafka-data \
  --retention-hours 336 \
  --with-ui --with-schema-registry --prometheus

# Кластер из 3 нод (запустить на каждой ноде)
# Нода 1:
sudo ./install.sh --mode cluster --node-id 1 \
  --controller-quorum "1@kafka1:9093,2@kafka2:9093,3@kafka3:9093" \
  --bootstrap-servers "kafka1:9092,kafka2:9092,kafka3:9092" \
  --advertised-host kafka1

# Нода 2 (использовать cluster-id с первой ноды):
sudo ./install.sh --mode cluster --node-id 2 \
  --cluster-id $(cat /etc/kafka/cluster-id) \
  --controller-quorum "1@kafka1:9093,2@kafka2:9093,3@kafka3:9093" \
  --bootstrap-servers "kafka1:9092,kafka2:9092,kafka3:9092" \
  --advertised-host kafka2

# С ZooKeeper (legacy mode)
sudo ./install.sh --with-zookeeper
```

После установки:
- Kafka: `localhost:9092`
- Web UI: `http://<IP>:8080`
- Schema Registry: `http://<IP>:8081`
- Kafka Connect: `http://<IP>:8083`
- Credentials: `/etc/kafka/credentials/info.txt`

Полезные команды:
```bash
# Список топиков
kafka-topics --list --bootstrap-server localhost:9092

# Создание топика
kafka-topics --create --topic my-topic --partitions 3 --bootstrap-server localhost:9092

# Отправка сообщений
echo "Hello Kafka" | kafka-console-producer --topic my-topic --bootstrap-server localhost:9092

# Чтение сообщений
kafka-console-consumer --topic my-topic --from-beginning --bootstrap-server localhost:9092
```

Рекомендуемые ресурсы LXC: 4 CPU, 8 GB RAM, 50+ GB SSD.

Подробнее: [kafka/README.md](kafka/README.md)

### 20. Пример: Установка NATS Server

```bash
cd run-in-lxc/nats

# Базовая установка
sudo ./install.sh

# С JetStream (персистентность)
sudo ./install.sh --jetstream

# С JetStream и мониторингом
sudo ./install.sh --jetstream --prometheus

# С аутентификацией
sudo ./install.sh --jetstream --auth-user nats --auth-password SecurePass123

# С WebSocket и MQTT
sudo ./install.sh --jetstream --websocket --mqtt --prometheus

# Кластер из 3 узлов
# Узел 1:
sudo ./install.sh --jetstream --cluster --server-name nats-1 \
  --routes "nats://192.168.1.11:6222,nats://192.168.1.12:6222" \
  --prometheus

# Узел 2:
sudo ./install.sh --jetstream --cluster --server-name nats-2 \
  --routes "nats://192.168.1.10:6222,nats://192.168.1.12:6222" \
  --prometheus

# С TLS
sudo ./install.sh --jetstream --tls \
  --tls-cert /etc/ssl/certs/nats.crt \
  --tls-key /etc/ssl/private/nats.key

# Leaf Node (подключение к hub)
sudo ./install.sh --jetstream --leafnodes \
  --leafnode-remotes "nats://hub.example.com:7422"
```

После установки:
- Клиентский порт: `4222`
- HTTP мониторинг: `http://<IP>:8222`
- Prometheus метрики: `http://<IP>:8222/metrics`
- Учётные данные: `/root/nats-credentials/info.txt`

Полезные команды:
```bash
# Информация о сервере
nats server info

# Pub/Sub
nats sub "orders.>"
nats pub orders.new '{"id": 1}'

# JetStream
nats stream ls
nats stream add ORDERS --subjects "orders.>" --storage file
nats consumer ls ORDERS
```

Рекомендуемые ресурсы LXC: 1 CPU, 512 MB RAM (без JetStream), 2 CPU, 2 GB RAM (с JetStream).

Подробнее: [nats/README.md](nats/README.md)

### 21. Пример: Установка RabbitMQ

```bash
cd run-in-lxc/rabbitmq

# Базовая установка
sudo ./install.sh

# С Prometheus мониторингом
sudo ./install.sh --prometheus

# С указанным паролем администратора
sudo ./install.sh --admin-user admin --admin-password SecurePass123

# С MQTT и STOMP протоколами
sudo ./install.sh --mqtt --stomp --prometheus

# С TLS
sudo ./install.sh --tls \
  --tls-cert /etc/ssl/certs/rabbitmq.crt \
  --tls-key /etc/ssl/private/rabbitmq.key

# Кластер из 3 узлов (одинаковый cookie на всех!)
# Узел 1:
sudo ./install.sh --cluster --cluster-name production \
  --erlang-cookie "MYSECRETCOOKIE" \
  --cluster-nodes "rabbit@rabbit1,rabbit@rabbit2,rabbit@rabbit3" \
  --prometheus

# Узел 2:
sudo ./install.sh --cluster --cluster-name production \
  --erlang-cookie "MYSECRETCOOKIE" \
  --cluster-nodes "rabbit@rabbit1,rabbit@rabbit2,rabbit@rabbit3" \
  --prometheus

# С Nginx и Let's Encrypt
sudo ./install.sh --prometheus \
  --with-nginx --domain rabbitmq.example.com \
  --letsencrypt --email admin@example.com
```

После установки:
- Management UI: `http://<IP>:15672`
- AMQP: `amqp://<IP>:5672`
- Prometheus метрики: `http://<IP>:15692/metrics`
- Учётные данные: `/root/rabbitmq-credentials/info.txt`

Полезные команды:
```bash
# Статус сервера
rabbitmqctl status

# Список очередей
rabbitmqctl list_queues name messages consumers

# Список соединений
rabbitmqctl list_connections

# Статус кластера
rabbitmqctl cluster_status

# Добавить пользователя
rabbitmqctl add_user myuser mypassword
rabbitmqctl set_user_tags myuser administrator
rabbitmqctl set_permissions -p / myuser ".*" ".*" ".*"
```

Рекомендуемые ресурсы LXC: 2 CPU, 2 GB RAM, 10 GB диска.

Подробнее: [rabbitmq/README.md](rabbitmq/README.md)

## Документация

Каждый каталог содержит:
- **README.md** - подробная документация
- **QUICKSTART.md** - шпаргалка для быстрого старта
- **install.sh** - скрипт установки (для приложений)
- **config/** - примеры конфигурационных файлов
