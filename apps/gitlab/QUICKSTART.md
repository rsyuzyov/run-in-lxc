# Шпаргалка по установке GitLab CE

## Быстрая установка

### Вариант 1: Всё встроенное (рекомендуется для начала)

```bash
cd /root/run-in-lxc/gitlab
sudo ./install.sh --domain gitlab.example.com
```

**Что произойдет:**
- ✅ Установится GitLab CE (Omnibus)
- ✅ Встроенный PostgreSQL и Redis
- ✅ Nginx настроится автоматически
- ✅ Сгенерируется начальный пароль root

**После установки:**
```bash
# Получите пароль root
sudo cat /etc/gitlab/initial_root_password

# Откройте браузер
http://gitlab.example.com
```

---

### Вариант 2: С внешней базой данных

**Подготовка (на сервере PostgreSQL):**
```sql
CREATE USER gitlab WITH PASSWORD 'SecurePass123';
CREATE DATABASE gitlabhq_production OWNER gitlab;
\c gitlabhq_production
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
GRANT ALL PRIVILEGES ON DATABASE gitlabhq_production TO gitlab;
GRANT ALL ON SCHEMA public TO gitlab;
```

**Установка:**
```bash
sudo ./install.sh \
  --domain gitlab.example.com \
  --db-host 192.168.1.100 \
  --db-name gitlabhq_production \
  --db-user gitlab \
  --db-password SecurePass123
```

---

### Вариант 3: Внешние PostgreSQL + Redis

```bash
sudo ./install.sh \
  --domain gitlab.example.com \
  --db-host 192.168.1.100 \
  --db-name gitlabhq_production \
  --db-user gitlab \
  --db-password SecurePass123 \
  --redis-host 192.168.1.101 \
  --redis-password RedisPass123
```

---

### Вариант 4: HTTPS с Let's Encrypt

```bash
sudo ./install.sh \
  --external-url https://gitlab.example.com \
  --letsencrypt \
  --letsencrypt-email admin@example.com
```

---

## Управление после установки

### Проверка статуса

```bash
sudo gitlab-ctl status
```

### Перезапуск

```bash
sudo gitlab-ctl restart
```

### Просмотр логов

```bash
# Все логи
sudo gitlab-ctl tail

# Конкретный компонент
sudo gitlab-ctl tail puma
sudo gitlab-ctl tail sidekiq
```

### Применить изменения конфигурации

```bash
sudo gitlab-ctl reconfigure
```

---

## Важные пути

| Что | Где |
|-----|-----|
| Конфигурация | `/etc/gitlab/gitlab.rb` |
| Начальный пароль | `/etc/gitlab/initial_root_password` |
| Данные | `/var/opt/gitlab/` |
| Репозитории | `/var/opt/gitlab/git-data/repositories/` |
| Бэкапы | `/var/opt/gitlab/backups/` |
| Логи | `/var/log/gitlab/` |

---

## Первый вход

1. Откройте `http://gitlab.example.com`
2. Логин: `root`
3. Пароль: `sudo cat /etc/gitlab/initial_root_password`
4. **Смените пароль сразу!**

---

## Настройка HTTPS

### Let's Encrypt

```ruby
# /etc/gitlab/gitlab.rb
external_url 'https://gitlab.example.com'
letsencrypt['enable'] = true
letsencrypt['contact_emails'] = ['admin@example.com']
```

```bash
sudo gitlab-ctl reconfigure
```

### Свой сертификат

```ruby
# /etc/gitlab/gitlab.rb
external_url 'https://gitlab.example.com'
nginx['ssl_certificate'] = '/etc/gitlab/ssl/gitlab.crt'
nginx['ssl_certificate_key'] = '/etc/gitlab/ssl/gitlab.key'
```

```bash
sudo gitlab-ctl reconfigure
```

---

## Бэкап и восстановление

### Создать бэкап

```bash
sudo gitlab-backup create
```

### Восстановить

```bash
sudo gitlab-ctl stop puma
sudo gitlab-ctl stop sidekiq
sudo gitlab-backup restore BACKUP=<timestamp>
sudo gitlab-ctl start
```

---

## Регистрация Runner'а

После установки GitLab, зарегистрируйте Runner для CI/CD:

```bash
# На сервере GitLab получите токен:
# Admin → CI/CD → Runners → Register an instance runner

# На сервере с Runner:
sudo gitlab-runner register \
  --url https://gitlab.example.com \
  --token <RUNNER_TOKEN>
```

Подробнее: [gitlab-runner/QUICKSTART.md](../gitlab-runner/QUICKSTART.md)

---

## Решение проблем

### 502 Bad Gateway

```bash
# Puma ещё стартует или упал
sudo gitlab-ctl tail puma
sudo gitlab-ctl restart puma
```

### Не хватает памяти

```bash
# Уменьшите воркеры
sudo nano /etc/gitlab/gitlab.rb
```

```ruby
puma['worker_processes'] = 2
sidekiq['concurrency'] = 10
```

```bash
sudo gitlab-ctl reconfigure
```

### Забыли пароль root

```bash
sudo gitlab-rake "gitlab:password:reset[root]"
```

### Проверка здоровья системы

```bash
sudo gitlab-rake gitlab:check
sudo gitlab-rake gitlab:doctor:secrets
```

---

## Удаление

```bash
# Остановить
sudo gitlab-ctl stop

# Удалить пакет
sudo apt-get remove --purge gitlab-ce

# Удалить данные (ОСТОРОЖНО!)
sudo rm -rf /var/opt/gitlab
sudo rm -rf /var/log/gitlab
sudo rm -rf /etc/gitlab
```

