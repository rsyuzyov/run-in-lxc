# Foreman в LXC контейнере

Скрипты и инструкции для установки [Foreman](https://theforeman.org/) — системы управления жизненным циклом серверов — в LXC контейнер.

## Что такое Foreman?

Foreman — это инструмент для управления физическими и виртуальными серверами. Он позволяет:
- Автоматизировать provisioning серверов
- Управлять конфигурацией через Puppet, Ansible, Salt
- Отслеживать состояние инфраструктуры
- Управлять жизненным циклом хостов

## Системные требования

### Требования к LXC контейнеру

| Параметр | Минимум | Рекомендуется |
|----------|---------|---------------|
| **ОС** | Debian 12 (Bookworm) | Debian 12 |
| **RAM** | 4 GB | 8 GB |
| **CPU** | 2 ядра | 4 ядра |
| **Диск** | 20 GB | 50 GB |

### Важные настройки LXC

Контейнер должен быть **привилегированным** ИЛИ иметь включённую опцию `keyctl`.

**Необходимые опции:**
- `keyctl` — для работы systemd
- `nesting` — для вложенных namespace

**Создание контейнера в Proxmox:**
```bash
# Из директории proxmox/
sudo ./create-lxc.sh \
  --name foreman \
  --memory 8192 \
  --cores 4 \
  --disk 50 \
  --privileged \
  --features keyctl=1,nesting=1 \
  --bootstrap
```

> ⚠️ **Важно**: Debian 13 не поддерживается из-за несовместимости версии Ruby.

## Компоненты

Foreman включает:
- **Foreman** — основное веб-приложение
- **Puppet Server** — сервер конфигурации
- **PostgreSQL** — база данных (можно использовать внешнюю)
- **Redis** — кэш (можно использовать внешний)
- **Apache/Passenger** — веб-сервер

## Установка

### Быстрый старт

**Минимальная установка (всё встроенное):**
```bash
sudo ./install.sh
```

**С проверками перед установкой:**
```bash
sudo ./install.sh --check
```

**Установка конкретной версии:**
```bash
sudo ./install.sh --version 3.16
```

### С внешней базой данных PostgreSQL

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

### С внешним Redis

```bash
sudo ./install.sh \
  --redis-host 192.168.1.101 \
  --redis-password RedisPass123
```

### Полная кастомизация

```bash
sudo ./install.sh \
  --version 3.17 \
  --check \
  --db-host 192.168.1.100 \
  --db-user foreman \
  --db-password SecurePass123 \
  --redis-host 192.168.1.101 \
  --redis-password RedisPass123
```

## Параметры установки

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--version` | Версия Foreman | 3.17 |
| `--check` | Выполнить проверки перед установкой | false |
| `--db-host` | Адрес PostgreSQL (если не указан — встроенный) | не указан |
| `--db-user` | Пользователь БД | postgres |
| `--db-password` | Пароль пользователя БД | не указан |
| `--redis-host` | Адрес Redis (если не указан — встроенный) | не указан |
| `--redis-password` | Пароль Redis | не указан |
| `--use-local-assets` | Использовать локальные .deb пакеты puppet | false |

## После установки

### Первый вход

1. Откройте браузер: `https://<hostname>`
2. Логин: `admin`
3. Пароль: `changeme`
4. **Смените пароль сразу после входа!**

### Управление сервисами

```bash
# Статус всех компонентов
foreman-maintain service status

# Перезапуск всех компонентов
foreman-maintain service restart

# Остановка
foreman-maintain service stop

# Запуск
foreman-maintain service start
```

### Логи

```bash
# Логи Foreman
tail -f /var/log/foreman/production.log

# Логи Puppet Server
tail -f /var/log/puppetlabs/puppetserver/puppetserver.log

# Логи Apache
tail -f /var/log/httpd/foreman-ssl_access_ssl.log
tail -f /var/log/httpd/foreman-ssl_error_ssl.log
```

### Важные пути

| Что | Где |
|-----|-----|
| Конфигурация Foreman | `/etc/foreman/` |
| Настройки установщика | `/etc/foreman-installer/` |
| Логи Foreman | `/var/log/foreman/` |
| Данные Puppet | `/etc/puppetlabs/` |
| Логи Puppet | `/var/log/puppetlabs/` |

## Настройка HTTPS

Foreman автоматически настраивается с самоподписанным сертификатом.

### Использование своего сертификата

```bash
foreman-installer \
  --certs-server-cert /path/to/server.crt \
  --certs-server-key /path/to/server.key \
  --certs-server-ca-cert /path/to/ca.crt
```

## Интеграция с Puppet

### Добавление модулей

```bash
# Установка модуля из Puppet Forge
puppet module install puppetlabs-apache

# Просмотр установленных модулей
puppet module list
```

### Настройка агентов

На клиентских машинах:
```bash
# Установка puppet-agent
apt-get install puppet-agent

# Настройка сервера
puppet config set server foreman.example.com --section main

# Запуск агента
puppet agent -t
```

## Плагины Foreman

### Установка плагина

```bash
foreman-installer --enable-foreman-plugin-<plugin_name>
```

### Популярные плагины

- `foreman-plugin-ansible` — интеграция с Ansible
- `foreman-plugin-remote-execution` — удалённое выполнение команд
- `foreman-plugin-templates` — синхронизация шаблонов
- `foreman-plugin-discovery` — автоматическое обнаружение хостов

## Решение проблем

### Медленная установка puppet

При установке пакетов puppet скорость может падать ниже 1 КБ/с и установка прерывается.

**Решение:** Скачайте пакеты вручную и используйте локальные assets:

```bash
# Скачайте пакеты
wget https://apt.puppet.com/pool/bookworm/puppet8/p/puppet-agent/puppet-agent_8.10.0-1bookworm_amd64.deb
wget https://apt.puppet.com/pool/bookworm/puppet8/p/puppetserver/puppetserver_8.7.0-1bookworm_all.deb

# Поместите в assets/
mv *.deb /path/to/run-in-lxc/foreman/assets/

# Запустите установку с локальными assets
sudo ./install.sh --use-local-assets
```

### Foreman не запускается

```bash
# Проверьте статус сервисов
foreman-maintain service status

# Проверьте логи
tail -100 /var/log/foreman/production.log

# Перезапустите
foreman-maintain service restart
```

### Проблемы с памятью

Если мало RAM, Foreman может работать медленно или падать:

```bash
# Проверьте использование памяти
free -h

# Проверьте OOM killer
dmesg | grep -i oom
```

### Не подключается к внешней БД

```bash
# Проверьте доступность
psql -h <db_host> -U foreman -d foreman -c "SELECT 1;"

# Проверьте настройки pg_hba.conf на сервере PostgreSQL
```

### Сброс пароля admin

```bash
foreman-rake permissions:reset
# Создаст нового admin с паролем changeme
```

## Обновление

```bash
# Обновление Foreman
foreman-maintain upgrade run --target-version <version>

# Проверка перед обновлением
foreman-maintain upgrade check --target-version <version>
```

## Резервное копирование

### Создание бэкапа

```bash
foreman-maintain backup offline /backup/foreman-$(date +%Y%m%d)
```

### Восстановление

```bash
foreman-maintain restore /backup/foreman-20231215
```

## Удаление

```bash
# Остановите сервисы
foreman-maintain service stop

# Удалите пакеты
apt-get remove --purge foreman* puppet*

# Удалите данные (ОСТОРОЖНО!)
rm -rf /etc/foreman
rm -rf /etc/puppetlabs
rm -rf /var/lib/foreman
rm -rf /var/log/foreman
```

## Поддержка

- [Официальная документация Foreman](https://theforeman.org/documentation.html)
- [Foreman Manual](https://theforeman.org/manuals/latest/index.html)
- [Foreman Community](https://community.theforeman.org/)
- [GitHub репозиторий установщика](https://github.com/rsyuzyov/foreman-setup)

