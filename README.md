# run-in-lxc

Этот репозиторий содержит скрипты и инструкции по установке и настройке различного программного обеспечения в LXC контейнерах.

## Структура проекта

Для каждой программы в репозитории выделен отдельный каталог:

### Приложения для установки в LXC

*   **`apache/`** - веб-сервер Apache HTTP Server
*   **`docker/`** - Docker CE с поддержкой зеркал и проверкой совместимости LXC
*   **`nginx/`** - веб-сервер Nginx
*   **`forgejo/`** - легковесный git-сервис (форк Gitea)
*   **`gitlab/`** - GitLab CE (Omnibus) — полноценный DevOps-сервис
*   **`gitlab-runner/`** - агент для выполнения CI/CD задач GitLab
*   **`foreman/`** - управление жизненным циклом хостов
*   **`1c/`** - сервер 1С:Предприятие 8
*   **`postgres/`** - база данных PostgreSQL
*   **`prometheus/`** - система мониторинга и алертинга (Prometheus + Node Exporter + Blackbox Exporter)
*   **`motioneye/`** - веб-система видеонаблюдения MotionEye
*   **`shinobi/`** - система видеонаблюдения Shinobi CE (NVR) с поддержкой GPU
*   **`zoneminder/`** - система видеонаблюдения ZoneMinder (детекция движения, ML)
*   **`syncthing/`** - децентрализованная синхронизация файлов (P2P, без облака)

### Kubernetes (в LXC/VM)

*   **`kubernetes/`** - развёртывание Kubernetes кластеров
    * **`k3s/`** - легковесный Kubernetes от Rancher (рекомендуется для dev/test)
    * **`k0s/`** - Zero Friction Kubernetes от Mirantis (рекомендуется для production)
    * **`common/`** - общие утилиты (подготовка LXC, addons: Helm, MetalLB, Longhorn)

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

### 8. Пример: Установка Docker

```bash
cd run-in-lxc/docker

# Базовая установка
sudo ./install.sh

# С зеркалом Docker Hub (быстрее)
sudo ./install.sh --mirror https://mirror.gcr.io

# С приватным registry без SSL
sudo ./install.sh --insecure-registries registry.local:5000

# Только проверка совместимости LXC
sudo ./install.sh --check
```

Подробнее: [docker/README.md](docker/README.md)

### 9. Пример: Установка Prometheus Stack

```bash
cd run-in-lxc/prometheus

# Базовая установка (Prometheus + Node Exporter + Blackbox Exporter)
sudo ./install.sh

# С Alertmanager и удалённым доступом (для Grafana)
sudo ./install.sh --alertmanager --allow-remote

# Полная установка с мониторингом Proxmox VE
sudo ./install.sh --alertmanager --allow-remote --proxmox \
  --proxmox-host 192.168.1.100:8006 \
  --proxmox-user prometheus@pve \
  --proxmox-token-id monitoring \
  --proxmox-token-secret xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# С мониторингом PostgreSQL
sudo ./install.sh --postgres-exporter \
  --pg-host 192.168.1.50 \
  --pg-user prometheus \
  --pg-password SecurePass123
```

Рекомендуемые ресурсы LXC: 2 CPU, 4 GB RAM, 20 GB диска.

Подробнее: [prometheus/README.md](prometheus/README.md)

### 10. Пример: Установка MotionEye

```bash
cd run-in-lxc/motioneye

# Базовая установка
sudo ./install.sh

# С часовым поясом и NFS-хранилищем
sudo ./install.sh \
  --timezone Europe/Moscow \
  --nfs-mount 192.168.1.100:/recordings

# Веб-интерфейс: http://<IP>:8765
# Логин: admin, пароль: (пустой)
```

Рекомендуемые ресурсы LXC: 2 CPU, 2 GB RAM, 8 GB диска.

Подробнее: [motioneye/README.md](motioneye/README.md)

### 11. Пример: Установка Shinobi CE (видеонаблюдение)

```bash
cd run-in-lxc/shinobi

# Минимальная установка (SQLite)
sudo ./install.sh

# С встроенным PostgreSQL
sudo ./install.sh --with-postgres

# С GPU ускорением (Intel VAAPI) и мониторингом
sudo ./install.sh --with-postgres --gpu intel --prometheus

# Полная production установка
sudo ./install.sh \
  --with-postgres \
  --gpu intel \
  --prometheus \
  --storage-path /mnt/recordings \
  --retention-days 60 \
  --admin-email admin@example.com

# С внешним PostgreSQL
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-name shinobi \
  --db-user shinobi \
  --db-password SecurePass123
```

После установки:
- Супер-админ: `http://<IP>:8080/super`
- Учётные данные: `/opt/shinobi/credentials/admin.txt`

Рекомендуемые ресурсы LXC: 4 CPU, 8 GB RAM, 40 GB диска + отдельное хранилище для записей.

Подробнее: [shinobi/README.md](shinobi/README.md)

### 12. Пример: Установка ZoneMinder

```bash
cd run-in-lxc/zoneminder

# Базовая установка
sudo ./install.sh --domain cameras.example.com

# С Let's Encrypt SSL
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt

# Полная установка с ML детекцией объектов
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt \
  --with-event-notification \
  --with-ml \
  --prometheus-exporter

# С внешней БД
sudo ./install.sh \
  --domain cameras.example.com \
  --db-host 192.168.1.100 \
  --db-name zm \
  --db-user zmuser \
  --db-password SecurePass123
```

После установки:
- Веб-интерфейс: `https://cameras.example.com/zm`
- Логин: `admin`, пароль: `admin`
- Учётные данные: `/root/zoneminder-credentials.txt`

Рекомендуемые ресурсы LXC: 2+ CPU, 4+ GB RAM, 50+ GB диска.

Подробнее: [zoneminder/README.md](zoneminder/README.md)

### 13. Пример: Установка Kubernetes (K3s)

```bash
# 1. На хосте Proxmox: создание LXC с настройками для K8s
cd run-in-lxc/kubernetes/common
sudo ./prepare-lxc.sh --create --name k8s --memory 4096 --cores 2

# 2. В контейнере: установка K3s (single-node)
cd run-in-lxc/kubernetes/k3s
sudo ./install.sh --mode single

# 3. Проверка
kubectl get nodes
kubectl get pods -A

# Multi-node кластер:
# Master
sudo ./install.sh --mode server --cluster-init

# Workers (на других узлах)
sudo ./install.sh --mode agent \
  --server https://<MASTER_IP>:6443 \
  --token <TOKEN>
```

**Альтернатива: k0s** (для production):

```bash
cd run-in-lxc/kubernetes/k0s
sudo ./install.sh --role single
```

**Дополнительные компоненты:**

```bash
cd run-in-lxc/kubernetes/common/addons

# Helm (менеджер пакетов)
./install-helm.sh

# MetalLB (LoadBalancer для bare-metal)
./install-metallb.sh --address-pool 192.168.1.200-192.168.1.220

# Longhorn (распределённое хранилище)
./install-longhorn.sh
```

Рекомендуемые ресурсы: 2+ CPU, 4+ GB RAM, 40+ GB диска.

Подробнее: [kubernetes/README.md](kubernetes/README.md)

### 14. Пример: Установка Syncthing

```bash
cd run-in-lxc/syncthing

# Базовая установка с паролем
sudo ./install.sh --gui-password "MySecurePassword"

# Для слабого ПК (Raspberry Pi и т.п.)
sudo ./install.sh \
  --low-resources \
  --max-recv-kbps 5000 \
  --max-send-kbps 5000 \
  --gui-password "MyPassword"

# Корпоративный сервер с SSL и мониторингом
sudo ./install.sh \
  --gui-password "$(openssl rand -base64 16)" \
  --prometheus \
  --nginx --ssl \
  --domain sync.company.local \
  --email admin@company.local

# Relay-сервер для NAT traversal
sudo ./install.sh --relay
```

После установки:
- Веб-интерфейс: `http://<IP>:8384`
- Учётные данные: `/var/lib/syncthing/credentials/info.txt`

Рекомендуемые ресурсы LXC: 1 CPU, 512 MB RAM (минимум), 8 GB диска.

Подробнее: [syncthing/README.md](syncthing/README.md)

## Документация

Каждый каталог содержит:
- **README.md** - подробная документация
- **QUICKSTART.md** - шпаргалка для быстрого старта
- **install.sh** - скрипт установки (для приложений)
- **config/** - примеры конфигурационных файлов
