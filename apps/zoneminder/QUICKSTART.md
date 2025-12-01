# ZoneMinder — Быстрый старт

## Минимальные требования

- 2 CPU, 4 GB RAM, 50 GB диска
- Debian 13 (Trixie)

## Установка за 5 минут

### 1. Базовая установка

```bash
cd run-in-lxc/zoneminder
sudo ./install.sh --domain cameras.example.com
```

### 2. С SSL (Let's Encrypt)

```bash
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt
```

### 3. Полная установка (с ML детекцией)

```bash
sudo ./install.sh \
  --domain cameras.example.com \
  --email admin@example.com \
  --letsencrypt \
  --with-event-notification \
  --with-ml \
  --prometheus-exporter
```

## Первый вход

```
URL:    https://cameras.example.com/zm
Логин:  admin
Пароль: admin
```

> ⚠️ Смените пароль: Options → Users → admin → Edit

## Добавление IP-камеры (RTSP)

1. **Console** → **Add**
2. Заполните:
   - **Name:** `Camera-01`
   - **Source Type:** `FFmpeg`
   - **Function:** `Modect` (детекция движения)
3. Вкладка **Source**:
   - **Source Path:** `rtsp://user:pass@192.168.1.100:554/stream1`
   - **Method:** `TCP`
4. **Save**

## Основные команды

```bash
# Статус
systemctl status zoneminder
zmpkg.pl status

# Перезапуск
systemctl restart zoneminder

# Логи
journalctl -u zoneminder -f
```

## Опции установки

| Опция | Описание |
|-------|----------|
| `--domain` | Домен (обязательно) |
| `--ssl` | Самоподписанный SSL |
| `--letsencrypt --email` | Let's Encrypt |
| `--db-host --db-password` | Внешняя БД |
| `--with-event-notification` | Push-уведомления |
| `--with-ml` | ML детекция объектов |
| `--prometheus-exporter` | Метрики Prometheus |
| `--timezone` | Часовой пояс |
| `--retention-days` | Дни хранения |

## Файлы

| Путь | Назначение |
|------|------------|
| `/etc/zm/zm.conf` | Конфигурация |
| `/var/cache/zoneminder/events/` | Видео события |
| `/var/log/zm/` | Логи |
| `/root/zoneminder-credentials.txt` | Учётные данные |

## Подробнее

См. [README.md](README.md)

