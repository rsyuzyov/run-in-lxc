# run-in-lxc

Скрипты и инструкции по установке и настройке программного обеспечения в LXC контейнерах Proxmox VE.

## Быстрый старт

```bash
# 1. Создание LXC контейнера (на хосте Proxmox)
cd proxmox && sudo ./create-lxc.sh --name my-container --bootstrap

# 2. Установка приложения (в контейнере, на примере 1С)
git clone <repo-url> run-in-lxc && cd run-in-lxc/apps/1c
sudo ./install.sh --version 8.3.25.1257 --its-login user@example.com --its-password YourPassword
```

## Структура проекта

```
run-in-lxc/
├── proxmox/                  # Управление LXC контейнерами
├── bootstrap/                # Базовая настройка контейнеров
└── apps/                     # Приложения для установки в LXC
    ├── ERP
    │   └── 1c/
    ├── СУБД
    │   ├── postgres/
    │   ├── mariadb/
    │   └── mongodb/
    ├── Веб-серверы
    │   ├── apache/
    │   └── nginx/
    ├── CI/CD и DevOps
    │   ├── gitlab/
    │   ├── gitlab-runner/
    │   ├── jenkins/
    │   ├── forgejo/
    │   └── foreman/
    ├── Брокеры сообщений
    │   ├── kafka/
    │   ├── nats/
    │   └── rabbitmq/
    ├── Видеонаблюдение
    │   ├── motioneye/
    │   ├── shinobi/
    │   └── zoneminder/
    ├── Контейнеризация
    │   ├── docker/
    │   └── kubernetes/
    ├── Мониторинг
    │   └── prometheus/
    └── Синхронизация
        └── syncthing/
```

## Документация

Каждый каталог содержит:
- **README.md** — подробная документация
- **QUICKSTART.md** — шпаргалка для быстрого старта
- **install.sh** — скрипт установки
