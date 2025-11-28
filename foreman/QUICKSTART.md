# Шпаргалка по установке Foreman

## Быстрая установка

### Вариант 1: Всё встроенное (рекомендуется для начала)

```bash
cd /root/run-in-lxc/foreman
sudo ./install.sh
```

**Что произойдет:**
- ✅ Установится Foreman 3.17
- ✅ Встроенный PostgreSQL и Redis
- ✅ Puppet Server настроится автоматически
- ✅ HTTPS с самоподписанным сертификатом

**После установки:**
```bash
# Откройте браузер
https://<hostname>

# Логин: admin
# Пароль: changeme
```

---

### Вариант 2: С проверками

```bash
sudo ./install.sh --check
```

---

### Вариант 3: Конкретная версия

```bash
sudo ./install.sh --version 3.16
```

---

### Вариант 4: С внешней базой данных

**Подготовка (на сервере PostgreSQL):**
```sql
CREATE USER foreman WITH PASSWORD 'SecurePass123';
CREATE DATABASE foreman OWNER foreman;
GRANT ALL PRIVILEGES ON DATABASE foreman TO foreman;
```

**Установка:**
```bash
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-user foreman \
  --db-password SecurePass123
```

---

### Вариант 5: Внешние PostgreSQL + Redis

```bash
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-user foreman \
  --db-password SecurePass123 \
  --redis-host 192.168.1.101 \
  --redis-password RedisPass123
```

---

### Вариант 6: При проблемах со скачиванием puppet

```bash
# Скачайте пакеты вручную
wget https://apt.puppet.com/pool/bookworm/puppet8/p/puppet-agent/puppet-agent_8.10.0-1bookworm_amd64.deb
wget https://apt.puppet.com/pool/bookworm/puppet8/p/puppetserver/puppetserver_8.7.0-1bookworm_all.deb

# Положите в assets/
mv *.deb assets/

# Установка с локальными пакетами
sudo ./install.sh --use-local-assets
```

---

## Управление после установки

### Проверка статуса

```bash
foreman-maintain service status
```

### Перезапуск

```bash
foreman-maintain service restart
```

### Просмотр логов

```bash
# Foreman
tail -f /var/log/foreman/production.log

# Puppet Server
tail -f /var/log/puppetlabs/puppetserver/puppetserver.log
```

---

## Важные пути

| Что | Где |
|-----|-----|
| Конфигурация | `/etc/foreman/` |
| Логи Foreman | `/var/log/foreman/` |
| Puppet | `/etc/puppetlabs/` |
| Логи Puppet | `/var/log/puppetlabs/` |

---

## Первый вход

1. Откройте `https://<hostname>`
2. Логин: `admin`
3. Пароль: `changeme`
4. **Смените пароль сразу!**

---

## Настройка Puppet Agent

На клиентских машинах:

```bash
# Установка агента
apt-get install puppet-agent

# Настройка сервера
puppet config set server foreman.example.com --section main

# Первый запуск
puppet agent -t
```

---

## Резервное копирование

### Создать бэкап

```bash
foreman-maintain backup offline /backup/foreman-$(date +%Y%m%d)
```

### Восстановить

```bash
foreman-maintain restore /backup/foreman-20231215
```

---

## Решение проблем

### Сервисы не запускаются

```bash
foreman-maintain service status
tail -100 /var/log/foreman/production.log
foreman-maintain service restart
```

### Забыли пароль admin

```bash
foreman-rake permissions:reset
# Новый пароль: changeme
```

### Проверка здоровья

```bash
foreman-maintain health check
```

---

## Обновление

```bash
# Проверка
foreman-maintain upgrade check --target-version 3.18

# Обновление
foreman-maintain upgrade run --target-version 3.18
```

---

## Удаление

```bash
foreman-maintain service stop
apt-get remove --purge foreman* puppet*
rm -rf /etc/foreman /etc/puppetlabs /var/lib/foreman /var/log/foreman
```

