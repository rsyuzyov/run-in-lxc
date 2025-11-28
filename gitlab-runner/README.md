# GitLab Runner в LXC контейнере

Скрипты и инструкции для установки GitLab Runner в LXC контейнер.

## Что такое GitLab Runner?

GitLab Runner — это агент, который выполняет задачи CI/CD пайплайнов. Runner получает задачи от GitLab сервера, выполняет их и отправляет результаты обратно.

### Типы executor'ов

| Executor | Описание | Изоляция | Использование |
|----------|----------|----------|---------------|
| `shell` | Выполняет команды напрямую в системе | Нет | Простые задачи, скрипты |
| `docker` | Каждый job в отдельном контейнере | Да | Сборка приложений, тестирование |
| `docker+machine` | Автомасштабирование Docker-машин | Да | Облачные среды, большие нагрузки |
| `kubernetes` | Выполнение в Kubernetes подах | Да | Kubernetes-кластеры |
| `ssh` | Выполнение на удалённом сервере по SSH | Нет | Legacy-системы |

## Системные требования

### Минимальные требования
- **ОС**: Debian 12 (Bookworm) или Ubuntu 22.04/24.04
- **RAM**: 512MB (зависит от выполняемых задач)
- **CPU**: 1 core (зависит от задач)
- **Диск**: 10GB свободного места
- **Архитектура**: amd64 (x86_64) или arm64

### Для Docker executor
- Docker Engine установлен и запущен
- Для LXC: контейнер должен быть **непривилегированным с nesting** или **привилегированным**

## Установка

### Быстрый старт

```bash
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token YOUR_RUNNER_TOKEN \
  --executor shell
```

### Параметры установки

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--url` | URL GitLab сервера | обязателен |
| `--token` | Токен регистрации Runner | обязателен |
| `--executor` | Тип executor'а | shell |
| `--description` | Описание Runner'а | hostname |
| `--tags` | Теги через запятую | не указаны |
| `--docker-image` | Docker образ по умолчанию (для docker executor) | alpine:latest |
| `--locked` | Привязать к проекту | false |
| `--run-untagged` | Выполнять задачи без тегов | true |
| `--install-docker` | Установить Docker (для docker executor) | false |

### Где взять токен?

#### Instance Runner (для всех проектов)
1. GitLab → Admin Area → CI/CD → Runners
2. Нажмите "Register an instance runner"
3. Скопируйте токен

#### Group Runner (для группы проектов)
1. GitLab → Ваша группа → Settings → CI/CD → Runners
2. Expand "Runners"
3. Нажмите "New group runner" или скопируйте токен

#### Project Runner (для одного проекта)
1. GitLab → Ваш проект → Settings → CI/CD → Runners
2. Expand "Runners"
3. Нажмите "New project runner" или скопируйте токен

## Примеры установки

### Shell executor

Простейший вариант, команды выполняются в системе:

```bash
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor shell \
  --description "Shell Runner on $(hostname)" \
  --tags "shell,linux"
```

### Docker executor

Каждый job в изолированном контейнере:

```bash
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor docker \
  --docker-image alpine:latest \
  --description "Docker Runner" \
  --tags "docker,linux" \
  --install-docker
```

### Docker-in-Docker (для сборки образов)

Для CI/CD с `docker build`:

```bash
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor docker \
  --docker-image docker:latest \
  --docker-privileged \
  --description "DinD Runner" \
  --tags "docker,dind"
```

### Несколько Runner'ов на одной машине

Можно зарегистрировать несколько Runner'ов:

```bash
# Первый Runner для сборки
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor docker \
  --tags "build"

# Второй Runner для деплоя
sudo gitlab-runner register \
  --url https://gitlab.example.com \
  --token glrt-YYYYYYYYYYYYYYYYYYYY \
  --executor shell \
  --tag-list "deploy"
```

## Docker в LXC контейнере

Для работы Docker executor в LXC контейнере требуется специальная настройка.

### Вариант 1: Непривилегированный контейнер с nesting

В конфигурации Proxmox (`/etc/pve/lxc/<ID>.conf`):

```conf
unprivileged: 1
features: nesting=1
```

### Вариант 2: Привилегированный контейнер

```conf
unprivileged: 0
features: nesting=1
```

> ⚠️ Привилегированные контейнеры менее безопасны

### Проверка работы Docker

```bash
docker run --rm hello-world
```

## После установки

### Проверка статуса

```bash
sudo gitlab-runner status
sudo gitlab-runner verify
```

### Просмотр зарегистрированных Runner'ов

```bash
sudo gitlab-runner list
```

### Логи

```bash
# Логи сервиса
sudo journalctl -u gitlab-runner -f

# Или через gitlab-runner
sudo gitlab-runner --debug run
```

### Управление сервисом

```bash
sudo systemctl status gitlab-runner
sudo systemctl restart gitlab-runner
sudo systemctl stop gitlab-runner
```

## Конфигурация

### Расположение файлов

| Что | Где |
|-----|-----|
| Конфигурация | `/etc/gitlab-runner/config.toml` |
| Бинарник | `/usr/bin/gitlab-runner` |
| Рабочая директория | `/home/gitlab-runner/` |

### Ручное редактирование config.toml

```toml
concurrent = 4  # Максимум параллельных задач
check_interval = 0

[session_server]
  session_timeout = 1800

[[runners]]
  name = "My Runner"
  url = "https://gitlab.example.com"
  token = "RUNNER_TOKEN"
  executor = "docker"
  
  [runners.docker]
    image = "alpine:latest"
    privileged = false
    disable_entrypoint_overwrite = false
    oom_kill_disable = false
    disable_cache = false
    volumes = ["/cache"]
    shm_size = 0
```

После изменения:
```bash
sudo systemctl restart gitlab-runner
```

## Теги и ограничения

### Теги

Теги позволяют направлять задачи на конкретные Runner'ы:

```yaml
# .gitlab-ci.yml
build:
  tags:
    - docker
    - linux
  script:
    - make build
```

### Ограничение по проектам

```bash
# При регистрации
sudo gitlab-runner register --locked

# Или в config.toml
[[runners]]
  locked = true
```

## Кэширование

### Локальный кэш

```toml
[[runners]]
  [runners.cache]
    Type = "local"
    Path = "/cache"
```

### S3-совместимый кэш

```toml
[[runners]]
  [runners.cache]
    Type = "s3"
    Shared = true
    [runners.cache.s3]
      ServerAddress = "s3.example.com"
      AccessKey = "access_key"
      SecretKey = "secret_key"
      BucketName = "gitlab-runner-cache"
```

## Масштабирование

### Увеличение параллельных задач

```toml
# /etc/gitlab-runner/config.toml
concurrent = 10  # Было 1
```

### Несколько Runner'ов

Для разных типов задач рекомендуется несколько Runner'ов:
- Быстрые задачи (линтинг, тесты) — больше concurrent
- Тяжёлые задачи (сборка) — мощные машины

## Отмена регистрации

```bash
# Удалить конкретный Runner
sudo gitlab-runner unregister --name "Runner Name"

# Удалить все Runner'ы
sudo gitlab-runner unregister --all-runners
```

## Обновление

```bash
# Обновите пакет
sudo apt-get update
sudo apt-get install gitlab-runner

# Проверьте версию
gitlab-runner --version
```

## Удаление

```bash
# Отмена регистрации
sudo gitlab-runner unregister --all-runners

# Остановка сервиса
sudo systemctl stop gitlab-runner

# Удаление пакета
sudo apt-get remove --purge gitlab-runner

# Удаление конфигурации
sudo rm -rf /etc/gitlab-runner
```

## Решение проблем

### Runner не появляется в GitLab

```bash
# Проверьте регистрацию
sudo gitlab-runner verify

# Проверьте токен и URL
sudo cat /etc/gitlab-runner/config.toml
```

### Job зависает

```bash
# Проверьте логи
sudo gitlab-runner --debug run

# Проверьте ресурсы
htop
df -h
```

### Docker executor не работает

```bash
# Проверьте Docker
sudo systemctl status docker
docker run --rm hello-world

# Проверьте права пользователя gitlab-runner
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
```

### Permission denied при доступе к файлам

Для Docker executor проверьте volumes и права:

```toml
[[runners]]
  [runners.docker]
    volumes = ["/cache", "/var/run/docker.sock:/var/run/docker.sock"]
```

## Поддержка

- [Официальная документация GitLab Runner](https://docs.gitlab.com/runner/)
- [Executors документация](https://docs.gitlab.com/runner/executors/)
- [Настройка Docker executor](https://docs.gitlab.com/runner/executors/docker.html)

