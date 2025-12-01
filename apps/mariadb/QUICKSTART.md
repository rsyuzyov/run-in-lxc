# MariaDB — Шпаргалка

## Установка

```bash
# Базовая установка
./install.sh --root-password MySecurePass123

# Для веб-приложений
./install.sh --profile web \
  --root-password SecurePass \
  --db-name myapp \
  --db-user myuser \
  --db-password MyPass123

# С удалённым доступом и мониторингом
./install.sh --profile web \
  --root-password SecurePass \
  --db-name mydb \
  --db-user dbuser \
  --db-password DbPass123 \
  --allow-remote \
  --prometheus
```

## Профили

| Профиль | Использование | RAM |
|---------|---------------|-----|
| `default` | Общее | 256M buffer |
| `web` | WordPress, CMS | 512M buffer |
| `analytics` | OLAP, отчёты | 1G buffer |
| `minimal` | Dev/test | 64M buffer |

## Управление сервисом

```bash
systemctl status mariadb
systemctl restart mariadb
systemctl stop mariadb
journalctl -u mariadb -f
```

## Подключение

```bash
# Локально (использует /root/.my.cnf)
mysql

# Явно
mysql -u root -p

# К базе
mysql -u user -p database
```

## Частые команды SQL

```sql
-- Список баз данных
SHOW DATABASES;

-- Создать базу
CREATE DATABASE mydb CHARACTER SET utf8mb4;

-- Создать пользователя
CREATE USER 'user'@'localhost' IDENTIFIED BY 'password';
CREATE USER 'user'@'%' IDENTIFIED BY 'password';  -- удалённый доступ

-- Выдать права
GRANT ALL PRIVILEGES ON mydb.* TO 'user'@'localhost';
FLUSH PRIVILEGES;

-- Список пользователей
SELECT user, host FROM mysql.user;

-- Список таблиц
USE mydb;
SHOW TABLES;

-- Выход
EXIT;
```

## Galera Cluster

### Bootstrap (первый узел)

```bash
./install.sh --galera --bootstrap \
  --cluster-name mycluster \
  --node-name node1 \
  --node-address 192.168.1.10 \
  --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12 \
  --root-password ClusterPass
```

### Присоединение (остальные узлы)

```bash
./install.sh --galera \
  --cluster-name mycluster \
  --node-name node2 \
  --node-address 192.168.1.11 \
  --cluster-nodes 192.168.1.10,192.168.1.11,192.168.1.12 \
  --root-password ClusterPass
```

### Проверка кластера

```bash
mysql -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
mysql -e "SHOW STATUS LIKE 'wsrep_local_state_comment';"
```

## Prometheus

```bash
# Установка
./install.sh --prometheus ...

# Endpoint
http://<IP>:9104/metrics

# Статус
systemctl status mysqld_exporter
```

## Бэкап

```bash
# Все базы
mariadb-dump --all-databases --single-transaction > backup.sql

# Одна база
mariadb-dump dbname > dbname.sql

# Восстановление
mysql < backup.sql
mysql dbname < dbname.sql
```

## Пути

| Что | Где |
|-----|-----|
| Данные | `/var/lib/mysql` |
| Конфиг | `/etc/mysql/mariadb.conf.d/` |
| Логи | `/var/log/mysql/` |
| Credentials | `/root/mariadb-credentials/` |

## Строка подключения

```
mysql://user:password@host:3306/database
```

## Отладка

```bash
# Логи
journalctl -u mariadb -n 100

# Проверить порт
ss -tlnp | grep 3306

# Медленные запросы
mysqldumpslow /var/log/mysql/slow.log
```

