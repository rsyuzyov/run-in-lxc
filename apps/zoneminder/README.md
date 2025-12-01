# ZoneMinder в LXC контейнере

Автоматизированная установка системы видеонаблюдения ZoneMinder в LXC контейнер.

## Возможности

- **Полнофункциональная система видеонаблюдения**
  - Поддержка IP-камер (RTSP, MJPEG, HTTP)
  - USB-камеры и локальные устройства
  - Детекция движения
  - Запись по событиям и непрерывная запись

- **Гибкая архитектура**
  - Встроенная или внешняя база данных MariaDB
  - SSL с Let's Encrypt или самоподписанным сертификатом
  - Настраиваемое хранилище видео

- **Дополнительные компоненты**
  - **zmeventnotification** — push-уведомления о событиях
  - **ML детекция** — распознавание объектов (люди, машины) на базе YOLO
  - **Prometheus exporter** — метрики для мониторинга

## Системные требования

### Минимальные требования

| Ресурс | Значение |
|--------|----------|
| CPU | 2 ядра |
| RAM | 4 GB |
| Диск | 50 GB |

### Рекомендации по масштабированию

| Камеры (1080p) | CPU | RAM | Примечание |
|----------------|-----|-----|------------|
| 1-4 | 2 | 4 GB | Минимальная конфигурация |
| 5-8 | 4 | 8 GB | Средняя нагрузка |
| 9-16 | 6 | 12 GB | Рекомендуется SSD |
| 16+ | 8+ | 16+ GB | Рассмотрите выделенный сервер |

### Хранилище видео

Расчёт объёма хранилища (примерный):
- 1 камера 1080p @ 15 FPS ≈ 5-10 GB/день (с детекцией движения)
- 1 камера 1080p @ 15 FPS ≈ 20-40 GB/день (непрерывная запись)

### Требования к LXC

- **Privileged контейнер** рекомендуется для работы с устройствами
- Для USB-камер требуется проброс устройств (`/dev/video*`)

## Быстрый старт

### 1. Создание LXC контейнера

```bash
# На хосте Proxmox
cd run-in-lxc/proxmox
sudo ./create-lxc.sh --name zoneminder --memory 4096 --cores 2 --disk 100 --bootstrap
```

### 2. Установка ZoneMinder

```bash
# В контейнере
cd run-in-lxc/zoneminder

# Базовая установка
sudo ./install.sh --domain cameras.example.com

# Или с SSL
sudo ./install.sh --domain cameras.example.com --email admin@example.com --letsencrypt
```

### 3. Открыть веб-интерфейс

```
URL: https://cameras.example.com/zm
Логин: admin
Пароль: admin
```

> ⚠️ **Важно:** Смените пароль после первого входа!

## Параметры установки

### Основные опции

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--domain` | Домен для веб-интерфейса | (обязательно) |
| `--timezone` | Часовой пояс | `Europe/Moscow` |
| `--storage-path` | Путь хранения видео | `/var/cache/zoneminder/events` |
| `--retention-days` | Дни хранения записей | `30` |

### SSL

| Параметр | Описание |
|----------|----------|
| `--ssl` | Включить SSL с самоподписанным сертификатом |
| `--letsencrypt` | Использовать Let's Encrypt |
| `--email` | Email для Let's Encrypt (обязательно с `--letsencrypt`) |

### База данных

По умолчанию устанавливается встроенная MariaDB. Для использования внешней БД:

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--db-host` | Хост БД | `localhost` |
| `--db-port` | Порт БД | `3306` |
| `--db-name` | Имя базы данных | `zm` |
| `--db-user` | Пользователь | `zmuser` |
| `--db-password` | Пароль | (генерируется) |

### Дополнительные компоненты

| Параметр | Описание |
|----------|----------|
| `--with-event-notification` | Установить zmeventnotification (push-уведомления) |
| `--with-ml` | Установить ML детекцию объектов |
| `--prometheus-exporter` | Установить Prometheus exporter |

## Примеры установки

### Базовая установка

```bash
sudo ./install.sh --domain cameras.example.com
```

### С Let's Encrypt и push-уведомлениями

```bash
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt \
  --with-event-notification
```

### С внешней базой данных

```bash
sudo ./install.sh \
  --domain cameras.example.com \
  --db-host 192.168.1.100 \
  --db-name zm \
  --db-user zmuser \
  --db-password SecurePass123
```

### Полная установка с ML

```bash
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt \
  --timezone Europe/Moscow \
  --storage-path /mnt/storage/zoneminder \
  --retention-days 14 \
  --with-event-notification \
  --with-ml \
  --prometheus-exporter
```

## Добавление камер

### IP-камера (RTSP)

1. Откройте веб-интерфейс ZoneMinder
2. **Console** → **Add**
3. Заполните настройки:

| Вкладка | Параметр | Значение |
|---------|----------|----------|
| General | Name | `Camera-01` |
| General | Source Type | `FFmpeg` |
| General | Function | `Modect` (детекция движения) |
| Source | Source Path | `rtsp://user:pass@192.168.1.100:554/stream1` |
| Source | Method | `TCP` |
| Source | Target colorspace | `32 bit colour` |

### ONVIF камера

Для автоматического обнаружения ONVIF камер:

```bash
# Установка ONVIF probe
apt-get install onvif-util

# Поиск камер в сети
onvif-util 192.168.1.0/24
```

### USB-камера

1. Пробросьте устройство в LXC контейнер (в конфигурации Proxmox):
   ```
   lxc.cgroup2.devices.allow: c 81:* rwm
   lxc.mount.entry: /dev/video0 dev/video0 none bind,optional,create=file
   ```

2. В ZoneMinder:
   - **Source Type:** `Local`
   - **Device Path:** `/dev/video0`

## Настройка детекции движения

### Зоны детекции

1. В настройках монитора откройте вкладку **Zones**
2. Нарисуйте зону детекции
3. Настройте чувствительность:
   - **Min/Max Pixel Threshold** — порог изменения пикселя
   - **Min/Max Alarm Pixels** — минимальное количество изменённых пикселей

### Рекомендуемые настройки

| Параметр | Дневной режим | Ночной режим |
|----------|---------------|--------------|
| Min Pixel Threshold | 25 | 15 |
| Max Pixel Threshold | 255 | 255 |
| Min Alarm Pixels | 30 | 50 |

## ML детекция объектов

При установке с `--with-ml` включается распознавание объектов на базе YOLO.

### Поддерживаемые объекты

- Люди (person)
- Автомобили (car, truck, bus)
- Мотоциклы (motorbike)
- Велосипеды (bicycle)

### Настройка

Конфигурация: `/etc/zm/zmeventnotification.ini`

```ini
[object]
use_object_detection=yes
object_min_confidence=0.5
object_detection_pattern=(person|car|truck)
```

### Производительность

| Режим | Время обработки кадра |
|-------|----------------------|
| CPU (4 ядра) | 2-5 секунд |
| GPU (CUDA) | 0.05-0.1 секунды |

> Для GPU требуется установка NVIDIA CUDA и пересборка OpenCV.

## Prometheus мониторинг

При установке с `--prometheus-exporter` доступны метрики:

### Endpoint

```
http://<IP>:9120/metrics
```

### Доступные метрики

| Метрика | Описание |
|---------|----------|
| `zoneminder_up` | ZoneMinder работает (1/0) |
| `zoneminder_monitors_total` | Общее количество мониторов |
| `zoneminder_monitors_active` | Активные мониторы |
| `zoneminder_events_24h` | События за 24 часа (по монитору) |
| `zoneminder_storage_used_bytes` | Использовано хранилища |
| `zoneminder_monitor_status` | Статус монитора |

### Добавление в Prometheus

```yaml
scrape_configs:
  - job_name: 'zoneminder'
    static_configs:
      - targets: ['192.168.1.50:9120']
```

## Хранение и архивация

### Настройка хранилища

```bash
# Отдельный том для видео
mkdir -p /mnt/video-storage/zoneminder
chown -R www-data:www-data /mnt/video-storage/zoneminder
```

В `/etc/zm/conf.d/02-paths.conf`:
```
ZM_DIR_EVENTS=/mnt/video-storage/zoneminder
```

### Автоочистка

Cron задача создаётся автоматически: `/etc/cron.daily/zoneminder-cleanup`

Для изменения retention:
```bash
# Редактировать cron
nano /etc/cron.daily/zoneminder-cleanup
```

### Архивация событий

```bash
# Архивация на удалённый сервер
rsync -avz /var/cache/zoneminder/events/ backup-server:/backup/zoneminder/
```

## API

ZoneMinder предоставляет REST API:

### Базовый URL

```
https://cameras.example.com/zm/api/
```

### Примеры запросов

```bash
# Получение списка мониторов
curl -s "https://cameras.example.com/zm/api/monitors.json?token=YOUR_TOKEN"

# Получение событий
curl -s "https://cameras.example.com/zm/api/events.json?token=YOUR_TOKEN"
```

### Генерация токена

1. **Options** → **API** → **Enable API**
2. **Options** → **Users** → выберите пользователя → **Generate Token**

## Управление сервисами

```bash
# Статус ZoneMinder
systemctl status zoneminder
zmpkg.pl status

# Перезапуск
systemctl restart zoneminder

# Логи
journalctl -u zoneminder -f
tail -f /var/log/zm/zm*.log
```

## Устранение неполадок

### ZoneMinder не запускается

```bash
# Проверка логов
journalctl -u zoneminder -n 100

# Проверка БД
mysql -u zmuser -p zm -e "SELECT * FROM Config LIMIT 1;"

# Права на директории
chown -R www-data:www-data /var/cache/zoneminder
```

### Камера не показывает видео

1. Проверьте доступность камеры:
   ```bash
   ffprobe rtsp://user:pass@camera-ip:554/stream1
   ```

2. Проверьте настройки Source Type и Path

3. Проверьте логи:
   ```bash
   tail -f /var/log/zm/zmc_m*.log
   ```

### Высокая нагрузка CPU

- Уменьшите разрешение или FPS камер
- Увеличьте интервал анализа (Analysis FPS)
- Используйте субпотоки камер для анализа

### Ошибки shared memory

```bash
# Увеличение лимитов shared memory
echo "kernel.shmmax = 536870912" >> /etc/sysctl.conf
echo "kernel.shmall = 131072" >> /etc/sysctl.conf
sysctl -p
```

## Интеграция с Home Assistant

### Через компонент ZoneMinder

```yaml
# configuration.yaml
zoneminder:
  - host: cameras.example.com
    path: /zm/
    username: admin
    password: !secret zm_password
    ssl: true
    verify_ssl: true

camera:
  - platform: zoneminder
```

### Через Generic Camera

```yaml
camera:
  - platform: generic
    name: "Camera 1"
    still_image_url: "https://cameras.example.com/zm/cgi-bin/nph-zms?mode=single&monitor=1"
    stream_source: "rtsp://user:pass@camera-ip:554/stream1"
```

## Структура директорий

```
/etc/zm/                          # Конфигурация ZoneMinder
├── zm.conf                       # Основной конфиг
└── conf.d/
    ├── 01-database.conf          # Настройки БД
    └── 02-paths.conf             # Пути

/var/cache/zoneminder/            # Кэш и временные файлы
└── events/                       # Хранилище событий (видео)

/var/log/zm/                      # Логи
├── zmc_m*.log                    # Логи capture
├── zma_m*.log                    # Логи analysis
└── web_php.log                   # Логи веб-интерфейса

/usr/share/zoneminder/            # Файлы приложения
└── www/                          # Веб-интерфейс
```

## Полезные ссылки

- [Официальная документация ZoneMinder](https://zoneminder.readthedocs.io/)
- [Wiki ZoneMinder](https://wiki.zoneminder.com/)
- [GitHub ZoneMinder](https://github.com/ZoneMinder/ZoneMinder)
- [zmeventnotification](https://github.com/ZoneMinder/zmeventnotification)

