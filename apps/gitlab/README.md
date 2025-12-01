# GitLab CE в LXC контейнере

Скрипты и инструкции для установки GitLab Community Edition (Omnibus) в LXC контейнер.

## Системные требования

### Минимальные требования
- **ОС**: Debian 12 (Bookworm) или Ubuntu 22.04/24.04
- **RAM**: 4GB (рекомендуется 8GB)
- **CPU**: 4 cores (рекомендуется 8 cores)
- **Диск**: 50GB свободного места (рекомендуется SSD)
- **Архитектура**: amd64 (x86_64)

### Важно
GitLab — ресурсоёмкое приложение. При недостатке RAM возможны:
- Медленная работа веб-интерфейса
- Таймауты при операциях с репозиториями
- Падение сервисов

## Компоненты

Omnibus GitLab включает:
- **GitLab Rails** — основное приложение
- **Gitaly** — сервис для работы с Git репозиториями
- **PostgreSQL** — база данных (можно использовать внешнюю)
- **Redis** — кэш и очереди (можно использовать внешний)
- **Puma** — веб-сервер
- **Sidekiq** — обработчик фоновых задач
- **Nginx** — reverse proxy
- **GitLab CI/CD** — встроенная система CI/CD

## База данных

Скрипт поддерживает два режима работы с PostgreSQL:

### 1. Встроенный PostgreSQL (по умолчанию)

Если параметр `--db-host` **не указан**, используется PostgreSQL из состава Omnibus.

**Пример:**
```bash
sudo ./install.sh --domain gitlab.example.com
```

### 2. Внешний PostgreSQL

Если параметр `--db-host` **указан**, встроенный PostgreSQL отключается.

**Требования к внешнему PostgreSQL:**
- PostgreSQL 13, 14, 15 или 16
- Расширения: `pg_trgm`, `btree_gist`, `plpgsql`
- База данных и пользователь созданы заранее

**Подготовка внешней БД:**
```sql
CREATE USER gitlab WITH PASSWORD 'SecurePass123';
CREATE DATABASE gitlabhq_production OWNER gitlab;

-- Подключитесь к созданной базе
\c gitlabhq_production

-- Создайте расширения
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS plpgsql;

-- Выдайте права
GRANT ALL PRIVILEGES ON DATABASE gitlabhq_production TO gitlab;
GRANT ALL ON SCHEMA public TO gitlab;
```

**Пример установки:**
```bash
sudo ./install.sh \
  --domain gitlab.example.com \
  --db-host 192.168.1.100 \
  --db-name gitlabhq_production \
  --db-user gitlab \
  --db-password SecurePass123
```

## Redis

### 1. Встроенный Redis (по умолчанию)

Если параметр `--redis-host` **не указан**, используется Redis из состава Omnibus.

### 2. Внешний Redis

Если параметр `--redis-host` **указан**, встроенный Redis отключается.

**Требования:**
- Redis 6.x или 7.x
- Опционально: пароль для аутентификации

**Пример:**
```bash
sudo ./install.sh \
  --domain gitlab.example.com \
  --redis-host 192.168.1.101 \
  --redis-password RedisPass123
```

## Установка

### Быстрый старт

**Минимальная установка (всё встроенное):**
```bash
sudo ./install.sh --domain gitlab.example.com
```

**С внешней базой данных:**
```bash
sudo ./install.sh \
  --domain gitlab.example.com \
  --db-host 192.168.1.100 \
  --db-name gitlabhq_production \
  --db-user gitlab \
  --db-password SecurePass123
```

**Полная кастомизация:**
```bash
sudo ./install.sh \
  --domain gitlab.example.com \
  --external-url https://gitlab.example.com \
  --db-host 192.168.1.100 \
  --db-name gitlabhq_production \
  --db-user gitlab \
  --db-password SecurePass123 \
  --redis-host 192.168.1.101 \
  --redis-password RedisPass123
```

### Параметры установки

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--domain` | Доменное имя сервера | localhost |
| `--external-url` | Полный URL для доступа | http://{domain} |
| `--db-host` | Адрес PostgreSQL (если не указан — встроенный) | не указан |
| `--db-port` | Порт PostgreSQL | 5432 |
| `--db-name` | Имя базы данных | gitlabhq_production |
| `--db-user` | Пользователь БД | gitlab |
| `--db-password` | Пароль пользователя БД | обязателен для внешней БД |
| `--redis-host` | Адрес Redis (если не указан — встроенный) | не указан |
| `--redis-port` | Порт Redis | 6379 |
| `--redis-password` | Пароль Redis | не указан |
| `--skip-reconfigure` | Не запускать gitlab-ctl reconfigure | false |

## После установки

### Первый вход

1. Откройте браузер: `http://gitlab.example.com`
2. Начальный пароль root находится в файле:
   ```bash
   sudo cat /etc/gitlab/initial_root_password
   ```
3. Логин: `root`, пароль: из файла выше
4. **Смените пароль сразу после входа!**

> ⚠️ Файл с паролем автоматически удаляется через 24 часа после установки

### Управление сервисом

```bash
# Статус всех компонентов
sudo gitlab-ctl status

# Перезапуск всех компонентов
sudo gitlab-ctl restart

# Остановка
sudo gitlab-ctl stop

# Запуск
sudo gitlab-ctl start

# Применение изменений конфигурации
sudo gitlab-ctl reconfigure
```

### Логи

```bash
# Все логи в реальном времени
sudo gitlab-ctl tail

# Логи конкретного компонента
sudo gitlab-ctl tail nginx
sudo gitlab-ctl tail puma
sudo gitlab-ctl tail sidekiq
sudo gitlab-ctl tail gitaly
sudo gitlab-ctl tail postgresql
sudo gitlab-ctl tail redis
```

### Важные пути

| Что | Где |
|-----|-----|
| Конфигурация | `/etc/gitlab/gitlab.rb` |
| Данные | `/var/opt/gitlab/` |
| Репозитории | `/var/opt/gitlab/git-data/repositories/` |
| Логи | `/var/log/gitlab/` |
| Бэкапы | `/var/opt/gitlab/backups/` |

## Настройка HTTPS

### Вариант 1: Let's Encrypt (автоматически)

```ruby
# /etc/gitlab/gitlab.rb
external_url 'https://gitlab.example.com'
letsencrypt['enable'] = true
letsencrypt['contact_emails'] = ['admin@example.com']
```

```bash
sudo gitlab-ctl reconfigure
```

### Вариант 2: Свои сертификаты

```ruby
# /etc/gitlab/gitlab.rb
external_url 'https://gitlab.example.com'
nginx['ssl_certificate'] = '/etc/gitlab/ssl/gitlab.crt'
nginx['ssl_certificate_key'] = '/etc/gitlab/ssl/gitlab.key'
```

```bash
sudo gitlab-ctl reconfigure
```

## Резервное копирование

### Создание бэкапа

```bash
sudo gitlab-backup create
```

Бэкап сохраняется в `/var/opt/gitlab/backups/`

### Восстановление

```bash
# Остановите сервисы, подключающиеся к БД
sudo gitlab-ctl stop puma
sudo gitlab-ctl stop sidekiq

# Восстановите
sudo gitlab-backup restore BACKUP=timestamp_of_backup

# Запустите сервисы
sudo gitlab-ctl start
```

> ⚠️ Бэкап не включает `/etc/gitlab/` — сохраняйте его отдельно!

## Обновление

```bash
# Обновите пакеты
sudo apt-get update
sudo apt-get install gitlab-ce

# Изменения применятся автоматически
```

## Мониторинг

GitLab включает встроенные метрики Prometheus:

```ruby
# /etc/gitlab/gitlab.rb
prometheus_monitoring['enable'] = true
```

Метрики доступны: `http://gitlab.example.com/-/metrics`

## Интеграция с GitLab Runner

После установки GitLab, для запуска CI/CD пайплайнов нужен GitLab Runner.

См. [gitlab-runner/README.md](../gitlab-runner/README.md)

## Решение проблем

### GitLab не запускается

```bash
# Проверьте статус
sudo gitlab-ctl status

# Посмотрите логи проблемного компонента
sudo gitlab-ctl tail <component>

# Проверьте конфигурацию
sudo gitlab-rake gitlab:check
```

### 502 Bad Gateway

Обычно означает, что Puma ещё не запустился или упал:

```bash
sudo gitlab-ctl tail puma
sudo gitlab-ctl restart puma
```

### Проблемы с памятью

Если мало RAM, уменьшите количество воркеров:

```ruby
# /etc/gitlab/gitlab.rb
puma['worker_processes'] = 2
sidekiq['concurrency'] = 10
```

```bash
sudo gitlab-ctl reconfigure
```

### Не подключается к внешней БД

```bash
# Проверьте доступность
psql -h <db_host> -U gitlab -d gitlabhq_production -c "SELECT 1;"

# Проверьте расширения
psql -h <db_host> -U gitlab -d gitlabhq_production -c "\dx"
```

## Удаление

```bash
# Остановите GitLab
sudo gitlab-ctl stop

# Удалите пакет
sudo apt-get remove --purge gitlab-ce

# Удалите данные (ОСТОРОЖНО!)
sudo rm -rf /var/opt/gitlab
sudo rm -rf /var/log/gitlab
sudo rm -rf /etc/gitlab
```

## Поддержка

- [Официальная документация GitLab](https://docs.gitlab.com/)
- [GitLab Omnibus Settings](https://docs.gitlab.com/omnibus/settings/)
- [GitLab Community Forum](https://forum.gitlab.com/)

