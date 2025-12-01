# Shinobi CE — Быстрый старт

## Требования

- LXC контейнер: 4 CPU, 8 GB RAM, 40 GB диск
- Debian 11/12 или Ubuntu 22.04/24.04
- Отдельное хранилище для записей (рекомендуется)

## Установка за 1 минуту

```bash
# Клонировать репозиторий (если ещё не сделано)
git clone <repo-url> run-in-lxc
cd run-in-lxc/shinobi

# Установка
sudo ./install.sh --with-postgres
```

## Варианты установки

```bash
# Минимальная (SQLite, для теста)
sudo ./install.sh

# Production (PostgreSQL)
sudo ./install.sh --with-postgres

# С GPU ускорением Intel
sudo ./install.sh --with-postgres --gpu intel

# С мониторингом Prometheus
sudo ./install.sh --with-postgres --prometheus

# Полная установка
sudo ./install.sh \
  --with-postgres \
  --gpu intel \
  --prometheus \
  --storage-path /mnt/recordings \
  --retention-days 60 \
  --admin-email admin@company.com
```

## После установки

### 1. Открыть супер-админ

```
http://<IP>:8080/super
```

Учётные данные: `/opt/shinobi/credentials/admin.txt`

### 2. Создать пользователя

В супер-админ → Accounts → Add

### 3. Войти как пользователь

```
http://<IP>:8080/
```

### 4. Добавить камеру

Monitor → Add → Заполнить:
- **Name**: Камера 1
- **Full URL Path**: `rtsp://admin:pass@192.168.1.100:554/stream1`
- **Input Type**: H.264
- **Recording**: Yes

## GPU в LXC (Intel)

На хосте Proxmox в `/etc/pve/lxc/<ID>.conf`:

```
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
```

Перезапустить контейнер. Проверить:

```bash
vainfo
```

## Управление

```bash
# Статус
systemctl status shinobi

# Логи
journalctl -u shinobi -f

# Перезапуск
systemctl restart shinobi
```

## Порты

| Порт | Сервис |
|------|--------|
| 8080 | Веб-интерфейс |
| 8082 | Cron сервис |
| 9290 | Prometheus метрики |

## Файлы

| Путь | Описание |
|------|----------|
| `/opt/shinobi/conf.json` | Конфигурация |
| `/opt/shinobi/credentials/` | Учётные данные |
| `/var/lib/shinobi/videos/` | Записи |

## Подробнее

См. [README.md](README.md)

