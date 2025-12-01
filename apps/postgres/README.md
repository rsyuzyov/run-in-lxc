# PostgreSQL для LXC контейнеров

Скрипт установки PostgreSQL с поддержкой двух вариантов:
- **PostgreSQL для 1С** (Postgres Professional) — по умолчанию
- **Ванильный PostgreSQL** — стандартная версия из официального репозитория

## Быстрый старт

```bash
# Установка PostgreSQL для 1С (рекомендуется для работы с 1С:Предприятие)
./install.sh

# Установка ванильного PostgreSQL
./install.sh --vanilla
```

## Варианты установки

### PostgreSQL для 1С (по умолчанию)

Устанавливает сборку PostgreSQL от Postgres Professional, оптимизированную для работы с 1С:Предприятие:

```bash
./install.sh
```

Эта сборка включает:
- Патчи для корректной работы с кириллицей и сортировкой
- Оптимизации для типичных нагрузок 1С
- Совместимость с платформой 1С:Предприятие

### Ванильный PostgreSQL

Для проектов, не связанных с 1С:

```bash
./install.sh --vanilla
```

## Опции

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--vanilla` | Установить ванильный PostgreSQL вместо версии для 1С | - |
| `--1c-version VERSION` | Версия PostgresPro для 1С | 18 |
| `--vanilla-version VERSION` | Версия ванильного PostgreSQL | 16 |
| `--parallel` | Параллельная установка (не заменяет существующий Postgres) | - |
| `--db-name NAME` | Создать базу данных с указанным именем | - |
| `--db-user USER` | Создать пользователя БД | - |
| `--db-password PASS` | Пароль для пользователя БД | - |
| `--allow-remote` | Разрешить удалённые подключения | - |

## Примеры использования

### Базовая установка для 1С

```bash
./install.sh
```

### Установка с созданием базы данных

```bash
./install.sh --db-name erp --db-user erp_user --db-password MySecurePassword123
```

### Установка с удалённым доступом

```bash
./install.sh --allow-remote --db-name mydb --db-user myuser --db-password Password123
```

### Параллельная установка (если уже есть другой PostgreSQL)

```bash
./install.sh --parallel
```

Используется когда:
- На машине уже установлен другой PostgreSQL
- Нужно обновить с более старой major-версии
- Требуется несколько версий PostgreSQL одновременно

### Ванильный PostgreSQL для разработки

```bash
./install.sh --vanilla --db-name devdb --db-user developer --db-password dev123
```

## Пути установки

### PostgreSQL для 1С (postgrespro-1c-18)

| Компонент | Путь |
|-----------|------|
| Данные | `/var/lib/pgpro/1c-18/data` |
| Утилиты | `/opt/pgpro/1c-18/bin` |
| Сервис | `postgrespro-1c-18` |

Подключение:
```bash
/opt/pgpro/1c-18/bin/psql -U postgres
```

### Ванильный PostgreSQL

| Компонент | Путь |
|-----------|------|
| Данные | `/var/lib/postgresql/16/main` |
| Конфигурация | `/etc/postgresql/16/main` |
| Сервис | `postgresql` |

Подключение:
```bash
sudo -u postgres psql
```

## Управление сервисом

### PostgreSQL для 1С

```bash
# Статус
systemctl status postgrespro-1c-18

# Перезапуск
systemctl restart postgrespro-1c-18

# Остановка
systemctl stop postgrespro-1c-18

# Логи
journalctl -u postgrespro-1c-18 -f
```

### Ванильный PostgreSQL

```bash
# Статус
systemctl status postgresql

# Перезапуск
systemctl restart postgresql

# Остановка
systemctl stop postgresql

# Логи
journalctl -u postgresql -f
```

## Настройка для 1С:Предприятие

После установки PostgreSQL для 1С необходимо:

1. **Установить сервер 1С:Предприятие** (см. `../1c/`)

2. **Создать базу данных для 1С**:
   ```bash
   /opt/pgpro/1c-18/bin/psql -U postgres -c "CREATE DATABASE my1cbase;"
   ```

3. **Настроить подключение в 1С**:
   - Сервер: `localhost` или IP контейнера
   - Порт: `5432`
   - База данных: имя созданной базы
   - Пользователь: `postgres` или созданный пользователь

## Настройка удалённого доступа

При использовании флага `--allow-remote` скрипт автоматически:

1. Устанавливает `listen_addresses = '*'` в `postgresql.conf`
2. Добавляет правило в `pg_hba.conf` для подключений по паролю

Для ручной настройки:

```bash
# postgresql.conf
listen_addresses = '*'

# pg_hba.conf
host    all             all             0.0.0.0/0               scram-sha-256
```

После изменений:
```bash
systemctl restart postgrespro-1c-18  # или postgresql
```

## Безопасность

- По умолчанию PostgreSQL слушает только `localhost`
- При `--allow-remote` разрешены подключения со всех адресов — используйте firewall
- Рекомендуется использовать сложные пароли для пользователей БД
- Для продакшена настройте SSL/TLS соединения

## Решение проблем

### Сервис не запускается

```bash
# Проверить логи
journalctl -u postgrespro-1c-18 -n 100

# Проверить права на директорию данных
ls -la /var/lib/pgpro/1c-18/
```

### Ошибка подключения

```bash
# Проверить, слушает ли PostgreSQL
ss -tlnp | grep 5432

# Проверить pg_hba.conf
cat /var/lib/pgpro/1c-18/data/pg_hba.conf
```

### Конфликт с существующим PostgreSQL

Используйте параллельную установку:
```bash
./install.sh --parallel
```

## Ссылки

- [PostgresPro для 1С](https://1c.postgres.ru/)
- [Документация PostgreSQL](https://www.postgresql.org/docs/)
- [Руководство по настройке 1С с PostgreSQL](https://its.1c.ru/)

