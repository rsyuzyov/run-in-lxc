# Shinobi CE для LXC контейнеров

Скрипт установки Shinobi CE (Community Edition) — системы видеонаблюдения с открытым исходным кодом.

## О Shinobi

Shinobi — это NVR (Network Video Recorder) с веб-интерфейсом, поддерживающий:
- RTSP, RTMP, MJPEG и другие протоколы камер
- Детекцию движения
- Запись по событиям и расписанию
- GPU ускорение (Intel VAAPI, NVIDIA NVENC)
- REST API
- Множество пользователей и групп

## Требования к ресурсам

| Ресурс | Минимум | Рекомендуется | С GPU |
|--------|---------|---------------|-------|
| CPU | 2 | 4 | 2+ |
| RAM | 4 GB | 8 GB | 8 GB |
| Диск (система) | 20 GB | 40 GB | 40 GB |
| Диск (записи) | 100 GB+ | отдельный storage | отдельный storage |

**Примечание:** Количество CPU зависит от числа камер и качества потока. На 1 камеру 1080p без GPU требуется ~0.5-1 CPU.

## Быстрый старт

```bash
# Минимальная установка (SQLite)
./install.sh

# С встроенным PostgreSQL
./install.sh --with-postgres

# Полная установка с GPU и мониторингом
./install.sh --with-postgres --gpu intel --prometheus \
  --storage-path /mnt/recordings --admin-email admin@example.com
```

## Опции установки

### База данных

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--with-postgres` | Установить встроенный PostgreSQL | SQLite |
| `--db-host HOST` | Хост внешнего PostgreSQL | localhost |
| `--db-port PORT` | Порт PostgreSQL | 5432 |
| `--db-name NAME` | Имя базы данных | shinobi |
| `--db-user USER` | Пользователь БД | shinobi |
| `--db-password PASS` | Пароль БД | генерируется |

### GPU ускорение

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--gpu TYPE` | Тип GPU: `intel`, `nvidia`, `amd` | - |
| `--gpu-device PATH` | Путь к устройству GPU | /dev/dri |

### Хранилище

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--storage-path PATH` | Путь для записей | /var/lib/shinobi/videos |
| `--retention-days N` | Дней хранения записей | 30 |

### Сеть и мониторинг

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--port PORT` | Порт веб-интерфейса | 8080 |
| `--prometheus` | Включить экспорт метрик | - |
| `--prometheus-port PORT` | Порт метрик | 9290 |

### Администратор

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--admin-email EMAIL` | Email супер-админа | admin@shinobi.video |
| `--admin-password PASS` | Пароль супер-админа | генерируется |

### Плагины детекции

| Опция | Описание |
|-------|----------|
| `--plugin-opencv` | Детекция движения через OpenCV (рекомендуется) |
| `--plugin-tensorflow` | Детекция объектов через TensorFlow |
| `--plugin-yolo` | Детекция объектов через YOLO (Darknet) |
| `--plugin-face` | Распознавание лиц (face-recognition) |
| `--plugins-all` | Установить все плагины |

### Прочее

| Опция | Описание |
|-------|----------|
| `--version VERSION` | Версия/ветка Shinobi (по умолчанию: master) |
| `--check` | Только проверить совместимость |
| `--help` | Показать справку |

## Примеры использования

### Минимальная установка

```bash
./install.sh
```

Устанавливает Shinobi с SQLite. Подходит для тестирования или небольших систем (до 4 камер).

### Production с PostgreSQL

```bash
./install.sh --with-postgres \
  --storage-path /mnt/recordings \
  --retention-days 60
```

### С внешним PostgreSQL

```bash
./install.sh \
  --db-host 192.168.1.100 \
  --db-name shinobi \
  --db-user shinobi \
  --db-password SecurePass123
```

**Подготовка внешнего PostgreSQL:**

```sql
CREATE USER shinobi WITH PASSWORD 'SecurePass123';
CREATE DATABASE shinobi OWNER shinobi;
GRANT ALL PRIVILEGES ON DATABASE shinobi TO shinobi;
```

### С GPU ускорением (Intel)

```bash
./install.sh --with-postgres --gpu intel
```

**Требуется проброс GPU в LXC** (см. раздел GPU).

### Полная установка

```bash
./install.sh \
  --with-postgres \
  --gpu intel \
  --prometheus \
  --storage-path /mnt/recordings \
  --retention-days 90 \
  --admin-email admin@company.com \
  --admin-password MySecurePass123
```

### С плагинами детекции

```bash
# OpenCV для детекции движения (рекомендуется)
./install.sh --with-postgres --plugin-opencv

# TensorFlow для детекции объектов (люди, машины, животные)
./install.sh --with-postgres --gpu intel --plugin-tensorflow

# Все плагины сразу
./install.sh --with-postgres --gpu intel --plugins-all --prometheus
```

## Плагины детекции

Shinobi поддерживает плагины для расширенной аналитики видео.

### Доступные плагины

| Плагин | Описание | Требования |
|--------|----------|------------|
| **OpenCV** | Детекция движения | OpenCV, ~500 MB |
| **TensorFlow** | Детекция объектов (COCO: 80 классов) | Python, TensorFlow, ~2 GB |
| **YOLO** | Детекция объектов (быстрее TensorFlow) | Darknet, ~500 MB |
| **Face** | Распознавание лиц | Python, dlib, ~1 GB, долгая сборка |

### Управление плагинами

```bash
# Статус
systemctl status shinobi-opencv
systemctl status shinobi-tensorflow
systemctl status shinobi-yolo
systemctl status shinobi-face

# Логи
journalctl -u shinobi-opencv -f

# Перезапуск
systemctl restart shinobi-tensorflow
```

### Настройка плагинов

Конфигурация каждого плагина находится в `/opt/shinobi/plugins/<plugin>/conf.json`.

После установки плагина:
1. Откройте монитор камеры в Shinobi
2. Перейдите в настройки детектора (Detector)
3. Выберите "Plugin" в качестве метода детекции
4. Настройте чувствительность и зоны

## Настройка GPU в LXC

### Intel iGPU (VAAPI)

На хосте Proxmox добавьте в `/etc/pve/lxc/<ID>.conf`:

```
lxc.cgroup2.devices.allow: c 226:* rwm
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
```

Проверка в контейнере:

```bash
# Установка инструментов
apt install vainfo

# Проверка VAAPI
vainfo

# Проверка FFmpeg
ffmpeg -hwaccels
```

### NVIDIA GPU

На хосте Proxmox добавьте в `/etc/pve/lxc/<ID>.conf`:

```
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 236:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
```

Требуется установка драйверов NVIDIA на хосте и в контейнере.

Проверка:

```bash
nvidia-smi
ffmpeg -hwaccels
```

## Структура файлов

```
/opt/shinobi/                    # Основная директория Shinobi
├── conf.json                    # Конфигурация
├── super.json                   # Учётные данные супер-админа
├── camera.js                    # Основной процесс
├── cron.js                      # Процесс очистки записей
├── credentials/                 # Сохранённые учётные данные
│   ├── admin.txt
│   └── database.txt
└── prometheus-exporter.js       # Экспортер метрик (если включен)

/var/lib/shinobi/videos/         # Записи (или --storage-path)
```

## Управление сервисами

### Основные команды

```bash
# Статус
systemctl status shinobi
systemctl status shinobi-cron

# Перезапуск
systemctl restart shinobi

# Логи
journalctl -u shinobi -f
journalctl -u shinobi-cron -f

# Остановка
systemctl stop shinobi shinobi-cron
```

### Prometheus экспортер

```bash
systemctl status shinobi-exporter
journalctl -u shinobi-exporter -f
```

## Веб-интерфейс

После установки доступны два интерфейса:

### Супер-админ

- URL: `http://<IP>:8080/super`
- Используется для создания пользователей и групп
- Учётные данные в `/opt/shinobi/credentials/admin.txt`

### Пользовательский интерфейс

- URL: `http://<IP>:8080/`
- Используется для добавления камер и просмотра
- Требуется создать пользователя через супер-админ

## Добавление камеры

1. Войдите в супер-админ (`/super`)
2. Создайте группу (Account)
3. Войдите как пользователь группы
4. Добавьте камеру:
   - Monitor → Add → Fill details
   - Connection: RTSP URL камеры
   - Input Type: H.264 / H.265
   - Recording: Yes + Record Mode

### Пример RTSP URL

```
# Hikvision
rtsp://admin:password@192.168.1.100:554/Streaming/Channels/101

# Dahua
rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=0

# Generic
rtsp://user:pass@192.168.1.100:554/stream1
```

## Интеграция с Prometheus

При установке с `--prometheus` создаётся экспортер метрик.

### Добавление в Prometheus

Создайте файл `/etc/prometheus/targets/shinobi.yml`:

```yaml
- targets:
    - '192.168.1.50:9290'
  labels:
    job: 'shinobi'
    env: 'production'
```

Или добавьте в `/etc/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'shinobi'
    static_configs:
      - targets: ['192.168.1.50:9290']
```

### Доступные метрики

| Метрика | Описание |
|---------|----------|
| `shinobi_exporter_up` | Экспортер работает |
| `shinobi_memory_usage_bytes` | Использование памяти |
| `shinobi_storage_bytes` | Использование хранилища |
| `shinobi_recordings_total` | Количество записей |

## Резервное копирование

### Что бэкапить

1. **Конфигурация**: `/opt/shinobi/conf.json`, `/opt/shinobi/super.json`
2. **База данных**:
   - SQLite: `/opt/shinobi/shinobi.sqlite`
   - PostgreSQL: `pg_dump shinobi`
3. **Записи**: `/var/lib/shinobi/videos/` (или --storage-path)

### Пример бэкапа

```bash
#!/bin/bash
BACKUP_DIR="/backup/shinobi/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Конфигурация
cp /opt/shinobi/conf.json "$BACKUP_DIR/"
cp /opt/shinobi/super.json "$BACKUP_DIR/"

# SQLite
cp /opt/shinobi/shinobi.sqlite "$BACKUP_DIR/" 2>/dev/null || true

# PostgreSQL
pg_dump -U shinobi shinobi > "$BACKUP_DIR/shinobi.sql" 2>/dev/null || true
```

## Решение проблем

### Shinobi не запускается

```bash
# Проверить логи
journalctl -u shinobi -n 100

# Проверить конфигурацию
cat /opt/shinobi/conf.json | jq .

# Проверить права
ls -la /opt/shinobi/
ls -la /var/lib/shinobi/videos/
```

### Камера не подключается

```bash
# Проверить RTSP вручную
ffprobe rtsp://user:pass@192.168.1.100:554/stream

# Проверить сеть
ping 192.168.1.100
```

### GPU не работает

```bash
# Intel VAAPI
vainfo
ls -la /dev/dri/

# NVIDIA
nvidia-smi
```

### Высокое потребление CPU

1. Включите GPU ускорение
2. Используйте субпоток камеры для превью
3. Уменьшите FPS записи
4. Отключите детекцию движения или используйте GPU

### Заканчивается место

```bash
# Проверить использование
du -sh /var/lib/shinobi/videos/

# Уменьшить retention
# Отредактировать conf.json: "retention": "7d"
systemctl restart shinobi
```

## Обновление Shinobi

```bash
cd /opt/shinobi

# Остановить сервисы
systemctl stop shinobi shinobi-cron

# Обновить
git fetch origin
git pull origin master

# Обновить зависимости
source /opt/nvm/nvm.sh
npm install

# Запустить
systemctl start shinobi shinobi-cron
```

## Полезные ссылки

- [Shinobi Documentation](https://docs.shinobi.video/)
- [Shinobi GitLab](https://gitlab.com/Shinobi-Systems/Shinobi)
- [Shinobi Community](https://hub.shinobi.video/)
- [FFmpeg VAAPI](https://trac.ffmpeg.org/wiki/Hardware/VAAPI)
- [FFmpeg NVENC](https://trac.ffmpeg.org/wiki/HWAccelIntro)

