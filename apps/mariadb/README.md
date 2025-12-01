# MariaDB для LXC контейнеров

Скрипт установки MariaDB с поддержкой:
- **Профилей конфигурации** — оптимизация под разные сценарии использования
- **Galera Cluster** — multi-master репликация для высокой доступности
- **Prometheus exporter** — мониторинг метрик базы данных

## Быстрый старт

```bash
# Базовая установка
./install.sh --root-password MySecurePass123

# Для веб-приложений с созданием БД
./install.sh --profile web \
  --root-password SecurePass \
  --db-name wordpress \
  --db-user wpuser \
  --db-password WpPass123
```

## Профили конфигурации

Профили позволяют оптимизировать MariaDB под конкретный сценарий использования.

### default — базовая конфигурация

```bash
./install.sh --profile default
```

Сбалансированные настройки для общего использования:
- `innodb_buffer_pool_size = 256M`
- `max_connections = 150`
- Включено логирование медленных запросов

### web — для веб-приложений

```bash
./install.sh --profile web
```

Оптимизация для WordPress, Drupal, Joomla и подобных CMS:
- Много коротких запросов
- Частые соединения
- Thread pool для эффективной обработки
- `innodb_buffer_pool_size = 512M`
- `max_connections = 300`
- `thread_handling = pool-of-threads`

### analytics — для аналитики и OLAP

```bash
./install.sh --profile analytics
```

Оптимизация для сложных аналитических запросов:
- Большие буферы для JOIN и сортировки
- Увеличенные I/O потоки
- `innodb_buffer_pool_size = 1G`
- `join_buffer_size = 16M`
- `sort_buffer_size = 16M`

### minimal — минимальные ресурсы

```bash
./install.sh --profile minimal
```

Для разработки и тестирования на ограниченных ресурсах:
- `innodb_buffer_pool_size = 64M`
- `max_connections = 50`
- `performance_schema = OFF`

## Опции

### Основные опции

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--version VERSION` | Версия MariaDB | 11.4 |
| `--distro` | Использовать пакеты из репозитория дистрибутива | - |
| `--root-password PASS` | Пароль root для MariaDB | генерируется |
| `--db-name NAME` | Создать базу данных | - |
| `--db-user USER` | Создать пользователя БД | - |
| `--db-password PASS` | Пароль для пользователя БД | - |
| `--allow-remote` | Разрешить удалённые подключения | - |
| `--charset CHARSET` | Кодировка | utf8mb4 |
| `--collation COLLATION` | Сортировка | utf8mb4_unicode_ci |
| `--profile PROFILE` | Профиль конфигурации | default |
| `--prometheus` | Установить mysqld_exporter | - |

### Опции Galera Cluster

| Опция | Описание |
|-------|----------|
| `--galera` | Включить Galera Cluster |
| `--cluster-name NAME` | Имя кластера (обязательно) |
| `--node-name NAME` | Имя текущего узла |
| `--node-address IP` | IP-адрес текущего узла |
| `--cluster-nodes NODES` | Список узлов (IP1,IP2,IP3) |
| `--bootstrap` | Инициализировать новый кластер |

## Примеры использования

### Базовая установка

```bash
./install.sh --root-password MySecurePassword123
```

### Установка для WordPress

```bash
./install.sh \
  --profile web \
  --root-password SecureRootPass \
  --db-name wordpress \
  --db-user wp_user \
  --db-password WpSecurePass123 \
  --allow-remote
```

### Установка с мониторингом

```bash
./install.sh \
  --root-password SecurePass \
  --db-name myapp \
  --db-user myuser \
  --db-password MyPass123 \
  --prometheus
```

После установки Prometheus метрики доступны на порту `9104`:
```
http://<IP>:9104/metrics
```

### Аналитический сервер

```bash
./install.sh \
  --profile analytics \
  --root-password SecurePass \
  --db-name analytics_db \
  --db-user analyst \
  --db-password AnalystPass123 \
  --allow-remote
```

### Минимальная установка для разработки

```bash
./install.sh \
  --profile minimal \
  --root-password devpass \
  --db-name devdb \
  --db-user developer \
  --db-password dev123
```

## Galera Cluster

Galera обеспечивает синхронную multi-master репликацию для высокой доступности.

### Архитектура кластера

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Node 1    │────▶│   Node 2    │────▶│   Node 3    │
│ 192.168.1.10│◀────│ 192.168.1.11│◀────│ 192.168.1.12│
└─────────────┘     └─────────────┘     └─────────────┘
      ▲                                        │
      └────────────────────────────────────────┘
```

### Развёртывание кластера

#### Шаг 1: Первый узел (bootstrap)

```bash
./install.sh \
  --galera \
  --cluster-name production_cluster \
  --bootstrap \
  --node-name node1 \
  --node-address 192.168.1.10 \
  --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12 \
  --root-password ClusterSecurePass
```

#### Шаг 2: Второй и третий узлы

На каждом дополнительном узле:

```bash
# Node 2
./install.sh \
  --galera \
  --cluster-name production_cluster \
  --node-name node2 \
  --node-address 192.168.1.11 \
  --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12 \
  --root-password ClusterSecurePass

# Node 3
./install.sh \
  --galera \
  --cluster-name production_cluster \
  --node-name node3 \
  --node-address 192.168.1.12 \
  --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12 \
  --root-password ClusterSecurePass
```

### Проверка статуса кластера

```bash
# Размер кластера
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"

# Полный статус Galera
mysql -e "SHOW STATUS LIKE 'wsrep_%';"

# Состояние узла
mysql -e "SHOW STATUS LIKE 'wsrep_local_state_comment';"
```

### Восстановление кластера после сбоя

Если все узлы остановлены, нужно определить узел с самыми свежими данными:

```bash
# На каждом узле проверить seqno
cat /var/lib/mysql/grastate.dat
```

На узле с наибольшим `seqno`:
```bash
galera_new_cluster
```

На остальных узлах:
```bash
systemctl start mariadb
```

## Управление сервисом

```bash
# Статус
systemctl status mariadb

# Перезапуск
systemctl restart mariadb

# Остановка
systemctl stop mariadb

# Логи
journalctl -u mariadb -f
```

## Подключение к MariaDB

### Локальное подключение

```bash
# Использует /root/.my.cnf (не требует пароля)
mysql

# Явное указание пароля
mysql -u root -p

# Подключение к конкретной базе
mysql -u username -p database_name
```

### Удалённое подключение

```bash
mysql -h <IP_ADDRESS> -u username -p database_name
```

### Строка подключения

```
mysql://user:password@host:3306/database
```

## Пути и файлы

| Компонент | Путь |
|-----------|------|
| Данные | `/var/lib/mysql` |
| Конфигурация | `/etc/mysql/mariadb.conf.d/` |
| Логи | `/var/log/mysql/` |
| Socket | `/run/mysqld/mysqld.sock` |
| Credentials | `/root/mariadb-credentials/` |

### Файлы конфигурации

- `50-server.cnf` — основная конфигурация сервера
- `60-galera.cnf` — настройки Galera (если включен)
- `98-remote-access.cnf` — удалённый доступ (если включен)
- `99-profile-*.cnf` — настройки профиля

## Prometheus мониторинг

При установке с `--prometheus` создаётся экспортер метрик.

### Endpoint

```
http://<IP>:9104/metrics
```

### Prometheus конфигурация

```yaml
scrape_configs:
  - job_name: 'mariadb'
    static_configs:
      - targets: ['192.168.1.100:9104']
```

### Основные метрики

| Метрика | Описание |
|---------|----------|
| `mysql_up` | Доступность MariaDB |
| `mysql_global_status_threads_connected` | Активные соединения |
| `mysql_global_status_queries` | Количество запросов |
| `mysql_global_status_innodb_buffer_pool_bytes_data` | Использование buffer pool |
| `mysql_global_status_slow_queries` | Медленные запросы |

### Управление экспортером

```bash
systemctl status mysqld_exporter
systemctl restart mysqld_exporter
journalctl -u mysqld_exporter -f
```

## Безопасность

### Рекомендации

1. **Всегда устанавливайте пароль root** — используйте `--root-password`
2. **Ограничивайте удалённый доступ** — используйте firewall
3. **Создавайте отдельных пользователей** для каждого приложения
4. **Регулярно обновляйте** MariaDB

### Firewall (UFW)

```bash
# Разрешить MySQL только из локальной сети
ufw allow from 192.168.1.0/24 to any port 3306

# Galera порты (для кластера)
ufw allow from 192.168.1.0/24 to any port 4567  # Galera replication
ufw allow from 192.168.1.0/24 to any port 4568  # IST
ufw allow from 192.168.1.0/24 to any port 4444  # SST
```

### Резервное копирование

```bash
# Полный бэкап
mariadb-dump --all-databases --single-transaction > backup.sql

# Конкретная база
mariadb-dump database_name > database_backup.sql

# С mariabackup (для больших БД)
mariabackup --backup --target-dir=/backup/full
```

## Решение проблем

### MariaDB не запускается

```bash
# Проверить логи
journalctl -u mariadb -n 100

# Проверить права на директорию данных
ls -la /var/lib/mysql/

# Проверить конфигурацию
mariadbd --help --verbose 2>&1 | head -50
```

### Ошибка подключения

```bash
# Проверить, слушает ли MariaDB
ss -tlnp | grep 3306

# Проверить пользователей
mysql -e "SELECT user, host FROM mysql.user;"

# Сбросить пароль root (если забыт)
systemctl stop mariadb
mysqld_safe --skip-grant-tables &
mysql -u root
# ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
# FLUSH PRIVILEGES;
```

### Galera: узел не присоединяется

```bash
# Проверить статус
mysql -e "SHOW STATUS LIKE 'wsrep_%';"

# Проверить доступность других узлов
nc -zv 192.168.1.10 4567

# Проверить логи
journalctl -u mariadb -n 100 | grep -i galera
```

### Медленные запросы

```bash
# Включить slow query log
mysql -e "SET GLOBAL slow_query_log = 'ON';"
mysql -e "SET GLOBAL long_query_time = 1;"

# Анализ slow log
mysqldumpslow /var/log/mysql/slow.log
```

## Версии MariaDB

| Версия | Статус | EOL |
|--------|--------|-----|
| 11.4 | LTS | 2029 |
| 11.2 | STS | 2024 |
| 10.11 | LTS | 2028 |
| 10.6 | LTS | 2026 |

Рекомендуется использовать LTS версии для production.

## Ссылки

- [Документация MariaDB](https://mariadb.com/kb/en/)
- [Galera Cluster](https://mariadb.com/kb/en/galera-cluster/)
- [MariaDB Server System Variables](https://mariadb.com/kb/en/server-system-variables/)
- [mysqld_exporter](https://github.com/prometheus/mysqld_exporter)

