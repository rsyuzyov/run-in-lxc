# Docker в LXC контейнерах

Установка Docker CE в LXC контейнерах с поддержкой зеркал и проверкой совместимости.

## Требования

### Настройки LXC контейнера

Docker требует включённых опций в LXC контейнере:

| Опция | Значение | Описание |
|-------|----------|----------|
| `nesting` | 1 | Разрешает запуск контейнеров внутри контейнера |
| `keyctl` | 1 | Необходимо для некоторых операций с ключами |

> **Примечание:** При создании контейнера через `proxmox/create-lxc.sh` эти опции устанавливаются автоматически (`--features nesting=1,keyctl=1`).

#### Ручная настройка в Proxmox

**Через UI:**
- Datacenter → Node → CT → Options → Features
- Включить: `nesting`, `keyctl`

**Через конфигурацию:**
```bash
# /etc/pve/lxc/<ID>.conf
features: nesting=1,keyctl=1
```

### Поддерживаемые ОС

- Debian 11 (Bullseye)
- Debian 12 (Bookworm)
- Debian 13 (Trixie)
- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

## Установка

### Базовая установка

```bash
cd run-in-lxc/docker
sudo ./install.sh
```

### Проверка совместимости (без установки)

```bash
sudo ./install.sh --check
```

### С зеркалом Docker Hub

Для ускорения скачивания образов можно использовать зеркало:

```bash
# Google Container Registry Mirror
sudo ./install.sh --mirror https://mirror.gcr.io

# Яндекс (Россия)
sudo ./install.sh --mirror https://cr.yandex

# Другие зеркала
sudo ./install.sh --mirror https://dockerhub.timeweb.cloud
```

### С приватными registries

Для работы с registry без SSL:

```bash
sudo ./install.sh --insecure-registries registry.local:5000

# Несколько registry
sudo ./install.sh --insecure-registries "registry.local:5000,192.168.1.100:5000"
```

### Комбинированная установка

```bash
sudo ./install.sh \
  --mirror https://mirror.gcr.io \
  --insecure-registries registry.local:5000
```

## Опции скрипта

| Опция | Описание |
|-------|----------|
| `--mirror URL` | Зеркало Docker Hub для ускорения скачивания |
| `--insecure-registries LIST` | Список registries без SSL через запятую |
| `--check` | Только проверка совместимости LXC |
| `--skip-test` | Пропустить тест hello-world |
| `--help` | Показать справку |

## После установки

### Проверка работы

```bash
# Статус службы
systemctl status docker

# Тест
docker run --rm hello-world

# Информация
docker info
```

### Основные команды

```bash
# Запуск контейнера
docker run -d --name nginx -p 80:80 nginx

# Список контейнеров
docker ps -a

# Логи
docker logs nginx

# Остановка
docker stop nginx

# Docker Compose
docker compose up -d
```

## Конфигурация

Файл конфигурации: `/etc/docker/daemon.json`

### Пример с зеркалом и логированием

```json
{
  "registry-mirrors": ["https://mirror.gcr.io"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### Пример с приватным registry

```json
{
  "insecure-registries": ["registry.local:5000"],
  "registry-mirrors": ["https://mirror.gcr.io"]
}
```

После изменения конфигурации:
```bash
sudo systemctl restart docker
```

## Интеграция с другими модулями

### GitLab Runner

Скрипт `gitlab-runner/install.sh` может использовать этот модуль для установки Docker. В будущем планируется рефакторинг для переиспользования:

```bash
# Текущий способ (встроенная установка)
cd gitlab-runner
sudo ./install.sh --executor docker --install-docker

# Рекомендуемый способ (с использованием docker модуля)
cd docker
sudo ./install.sh --mirror https://mirror.gcr.io
cd ../gitlab-runner
sudo ./install.sh --executor docker
```

> **TODO:** Рефакторинг `gitlab-runner/install.sh` для использования `docker/install.sh` как внешнего модуля.

## Решение проблем

### Docker не запускается

```bash
# Проверка логов
journalctl -u docker -n 50

# Проверка cgroups
cat /proc/cgroups

# Проверка features контейнера (на хосте Proxmox)
cat /etc/pve/lxc/<ID>.conf | grep features
```

### Ошибка: permission denied

```bash
# Docker требует root или членства в группе docker
sudo usermod -aG docker $USER
# Перелогиньтесь
```

### Overlay filesystem недоступен

Docker автоматически переключится на `vfs` storage driver. Это работает, но медленнее.

Проверка текущего driver:
```bash
docker info | grep "Storage Driver"
```

### Сеть не работает

```bash
# Проверка iptables
iptables -L -n

# Перезапуск Docker с очисткой сети
systemctl stop docker
rm -rf /var/lib/docker/network
systemctl start docker
```

## Структура файлов

```
docker/
├── install.sh          # Скрипт установки
├── README.md           # Документация
├── QUICKSTART.md       # Краткая шпаргалка
└── config/
    └── daemon.json     # Пример конфигурации
```

## Ссылки

- [Официальная документация Docker](https://docs.docker.com/)
- [Docker в LXC](https://docs.docker.com/engine/install/debian/)
- [Proxmox LXC](https://pve.proxmox.com/wiki/Linux_Container)

