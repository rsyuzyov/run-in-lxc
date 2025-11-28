# run-in-lxc

Этот репозиторий содержит скрипты и инструкции по установке и настройке различного программного обеспечения в LXC контейнерах.

## Структура проекта

Для каждой программы в репозитории выделен отдельный каталог:

### Приложения для установки в LXC

*   **`forgejo/`** - легковесный git-сервис (форк Gitea)
*   **`gitlab/`** - GitLab CE (Omnibus) — полноценный DevOps-сервис
*   **`gitlab-runner/`** - агент для выполнения CI/CD задач GitLab
*   **`foreman/`** - управление жизненным циклом хостов
*   **`1c/`** - платформа 1С:Предприятие
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

## Документация

Каждый каталог содержит:
- **README.md** - подробная документация
- **QUICKSTART.md** - шпаргалка для быстрого старта
- **install.sh** - скрипт установки (для приложений)
- **config/** - примеры конфигурационных файлов
