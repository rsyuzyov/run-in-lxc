# PostgreSQL — Шпаргалка

## Установка

```bash
# PostgreSQL для 1С (по умолчанию)
./install.sh

# Ванильный PostgreSQL
./install.sh --vanilla

# С созданием базы и пользователя
./install.sh --db-name mydb --db-user myuser --db-password MyPass123

# С удалённым доступом
./install.sh --allow-remote
```

## Управление сервисом

### PostgreSQL для 1С

```bash
systemctl status postgrespro-1c-18
systemctl restart postgrespro-1c-18
systemctl stop postgrespro-1c-18
```

### Ванильный PostgreSQL

```bash
systemctl status postgresql
systemctl restart postgresql
systemctl stop postgresql
```

## Подключение

### PostgreSQL для 1С

```bash
/opt/pgpro/1c-18/bin/psql -U postgres
```

### Ванильный

```bash
sudo -u postgres psql
```

## Частые команды SQL

```sql
-- Список баз данных
\l

-- Подключиться к базе
\c database_name

-- Список таблиц
\dt

-- Создать базу
CREATE DATABASE mydb;

-- Создать пользователя
CREATE USER myuser WITH PASSWORD 'password';

-- Выдать права
GRANT ALL PRIVILEGES ON DATABASE mydb TO myuser;

-- Выход
\q
```

## Пути

| Вариант | Данные | Утилиты |
|---------|--------|---------|
| Для 1С | `/var/lib/pgpro/1c-18/data` | `/opt/pgpro/1c-18/bin` |
| Ванильный | `/var/lib/postgresql/16/main` | `/usr/bin` |

## Строка подключения

```
postgresql://user:password@host:5432/database
```

