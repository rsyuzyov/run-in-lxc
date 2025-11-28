# run-in-lxc

Этот репозиторий содержит скрипты и инструкции по установке и настройке различного программного обеспечения в LXC контейнерах.

## Структура проекта

Для каждой программы в репозитории выделен отдельный каталог:

### Приложения для установки в LXC

*   **`apache/`** - веб-сервер Apache HTTP Server
*   **`forgejo/`** - легковесный git-сервис (форк Gitea)
*   **`gitlab/`** - GitLab CE (Omnibus) — полноценный DevOps-сервис
*   **`gitlab-runner/`** - агент для выполнения CI/CD задач GitLab
*   **`foreman/`** - управление жизненным циклом хостов
*   **`1c/`** - сервер 1С:Предприятие 8
*   **`postgres/`** - база данных PostgreSQL
*   ... и другие.

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

### 5. Пример: Установка сервера 1С:Предприятие 8

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

### 6. Пример: Установка Foreman

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

### 7. Пример: Установка Apache

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

## Документация

Каждый каталог содержит:
- **README.md** - подробная документация
- **QUICKSTART.md** - шпаргалка для быстрого старта
- **install.sh** - скрипт установки (для приложений)
- **config/** - примеры конфигурационных файлов
