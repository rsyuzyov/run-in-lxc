# Syncthing для LXC

Установка и настройка [Syncthing](https://syncthing.net/) — децентрализованной системы синхронизации файлов в LXC контейнерах.

## Возможности

- ✅ Установка из официального репозитория
- ✅ Автоматическая настройка systemd
- ✅ Поддержка режима минимальных ресурсов
- ✅ Relay-сервер для NAT traversal
- ✅ Discovery-сервер
- ✅ Nginx reverse proxy с SSL
- ✅ Prometheus экспортёр метрик
- ✅ Ограничение скорости синхронизации

## Быстрый старт

```bash
# Базовая установка
sudo ./install.sh

# С паролем на веб-интерфейс (рекомендуется)
sudo ./install.sh --gui-password "MySecurePassword123"

# Для слабых ПК
sudo ./install.sh --low-resources

# Веб-интерфейс: http://<IP>:8384
```

## Опции установки

### Основные

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--user USER` | Пользователь для запуска | `syncthing` |
| `--data-dir PATH` | Директория данных | `/var/lib/syncthing` |
| `--gui-address ADDR` | Адрес веб-интерфейса | `0.0.0.0:8384` |
| `--gui-password PASS` | Пароль для GUI | — |
| `--no-gui` | Headless режим (без GUI) | — |

### Режимы работы

| Опция | Описание |
|-------|----------|
| `--relay` | Relay-сервер (помощь NAT) |
| `--discovery` | Discovery-сервер |

### Интеграции

| Опция | Описание |
|-------|----------|
| `--prometheus` | Prometheus exporter (/metrics) |
| `--nginx` | Nginx reverse proxy |
| `--ssl` | Let's Encrypt SSL |
| `--domain DOMAIN` | Домен для nginx/SSL |
| `--email EMAIL` | Email для Let's Encrypt |

### Оптимизация

| Опция | Описание |
|-------|----------|
| `--low-resources` | Минимальное потребление ресурсов |
| `--max-folder-concurrency N` | Параллельных синхронизаций папок |
| `--max-recv-kbps N` | Лимит скорости приёма (КБ/с) |
| `--max-send-kbps N` | Лимит скорости отправки (КБ/с) |

## Примеры установки

### Личный сервер

```bash
sudo ./install.sh --gui-password "MyPassword"
```

### Корпоративный сервер

```bash
sudo ./install.sh \
  --gui-password "$(openssl rand -base64 16)" \
  --prometheus \
  --nginx --ssl \
  --domain sync.company.local \
  --email admin@company.local
```

### Слабый ПК / Raspberry Pi

```bash
sudo ./install.sh \
  --low-resources \
  --max-folder-concurrency 1 \
  --max-recv-kbps 5000 \
  --max-send-kbps 5000
```

### Headless сервер (NAS)

```bash
sudo ./install.sh \
  --no-gui \
  --data-dir /mnt/storage/syncthing
```

### Relay-сервер

```bash
sudo ./install.sh --relay
```

### Discovery-сервер

```bash
sudo ./install.sh --discovery
```

## Требования к ресурсам

### Минимальные требования

| Ресурс | Минимум | Рекомендуется |
|--------|---------|---------------|
| CPU | 1 ядро | 2 ядра |
| RAM | 256 MB | 512 MB - 1 GB |
| Диск | 8 GB | 20+ GB |

### Рекомендации по конфигурации LXC (Proxmox)

#### Для личного использования (2-5 устройств)

```
cores: 1
memory: 512
swap: 256
rootfs: 8G
```

#### Для среднего использования (5-15 устройств)

```
cores: 2
memory: 1024
swap: 512
rootfs: 20G
```

#### Для корпоративного использования (15-50 устройств)

```
cores: 4
memory: 2048
swap: 1024
rootfs: 50G
```

## Настройки для минимального потребления ресурсов

Если Syncthing работает на слабом ПК (Raspberry Pi, старый ноутбук, маломощный VPS), используйте следующие настройки:

### При установке

```bash
sudo ./install.sh --low-resources --max-recv-kbps 5000 --max-send-kbps 5000
```

### Ручная настройка (через веб-интерфейс)

**Действия → Настройки → Общие:**

| Параметр | Значение для слабых ПК | Описание |
|----------|------------------------|----------|
| Максимум параллельных папок | 1 | Одна папка за раз |
| Использовать лимитированные соединения | ✓ | Меньше потоков |

**Действия → Настройки → Соединения:**

| Параметр | Значение | Описание |
|----------|----------|----------|
| Лимит скорости приёма | 5000 КБ/с | Или меньше |
| Лимит скорости отправки | 5000 КБ/с | Или меньше |
| Включить NAT traversal | ✗ | Экономит CPU |
| Глобальное обнаружение | ✗ | Если не нужно |
| Включить relay | ✗ | Если не нужно |

**Для каждой папки → Расширенные:**

| Параметр | Значение | Описание |
|----------|----------|----------|
| Тип сканирования | Только при изменении | Меньше нагрузки на диск |
| Интервал полного сканирования | 86400 (24ч) | Реже сканирует |
| Порядок загрузки | По алфавиту | Предсказуемая нагрузка |
| Игнорировать права | ✓ | Меньше операций |

### Дополнительные параметры config.xml

Для продвинутых пользователей — редактирование `/var/lib/syncthing/config.xml`:

```xml
<options>
    <!-- Параллельные синхронизации папок (1 = минимум) -->
    <maxFolderConcurrency>1</maxFolderConcurrency>
    
    <!-- Параллельные запросы к устройству (8 = минимум) -->
    <maxConcurrentIncomingRequestKiB>8192</maxConcurrentIncomingRequestKiB>
    
    <!-- Отключить сбор статистики -->
    <urAccepted>-1</urAccepted>
    
    <!-- Реже проверять обновления -->
    <autoUpgradeIntervalH>0</autoUpgradeIntervalH>
    
    <!-- Меньше буфер базы данных -->
    <databaseTuning>small</databaseTuning>
</options>
```

После изменения конфигурации:

```bash
sudo systemctl restart syncthing
```

## Максимальное количество устройств и папок

### Рекомендации по количеству устройств

| RAM | Макс. устройств | Макс. папок | Макс. файлов |
|-----|-----------------|-------------|--------------|
| 256 MB | 3-5 | 5 | 10 000 |
| 512 MB | 5-10 | 10 | 50 000 |
| 1 GB | 10-20 | 20 | 200 000 |
| 2 GB | 20-50 | 50 | 500 000 |
| 4 GB | 50-100 | 100 | 1 000 000 |
| 8 GB+ | 100+ | 200+ | 5 000 000+ |

### Что влияет на производительность

1. **Количество файлов** — больше всего влияет на RAM и CPU
   - Каждый файл занимает ~1 KB в базе данных
   - 1 млн файлов ≈ 1 GB RAM только на метаданные

2. **Количество устройств** — влияет линейно
   - Каждое устройство = отдельное соединение + синхронизация состояния
   - 10 устройств × 100 000 файлов = значительная нагрузка

3. **Размер файлов** — меньше влияет
   - Большие файлы эффективнее (меньше накладных расходов)
   - Много мелких файлов = много операций

4. **Частота изменений** — влияет на CPU и сеть
   - Постоянно меняющиеся файлы создают нагрузку
   - Используйте `.stignore` для исключения временных файлов

### Признаки перегрузки

| Симптом | Причина | Решение |
|---------|---------|---------|
| Высокий CPU (постоянно >80%) | Много файлов или устройств | Уменьшить `maxFolderConcurrency` |
| Высокое потребление RAM | Большая база данных | Добавить RAM или разделить папки |
| Медленная синхронизация | Много мелких файлов | Архивировать или исключить |
| "Syncing" висит | Слишком много изменений | Увеличить интервал сканирования |

### Оптимизация для большого количества файлов

```bash
# .stignore — исключения (создать в корне синхронизируемой папки)
cat > /path/to/folder/.stignore << 'EOF'
// Временные файлы
(?d).DS_Store
(?d)Thumbs.db
(?d)*.tmp
(?d)*.temp
(?d)*~

// Системные
(?d).Trash*
(?d).git
(?d).svn

// Кэши и зависимости
(?d)node_modules
(?d)__pycache__
(?d).cache
(?d)vendor

// Большие файлы (опционально)
// (?d)*.iso
// (?d)*.zip
EOF
```

## Порты и файрвол

| Порт | Протокол | Назначение |
|------|----------|------------|
| 8384 | TCP | Веб-интерфейс и REST API |
| 22000 | TCP | Синхронизация (TCP) |
| 22000 | UDP | Синхронизация (QUIC) |
| 21027 | UDP | Локальное обнаружение |
| 22067 | TCP | Relay-сервер |
| 8443 | TCP | Discovery-сервер |

### Открытие портов (ufw)

```bash
sudo ufw allow 8384/tcp comment "Syncthing GUI"
sudo ufw allow 22000 comment "Syncthing Sync"
sudo ufw allow 21027/udp comment "Syncthing Discovery"
```

### Открытие портов (iptables)

```bash
iptables -A INPUT -p tcp --dport 8384 -j ACCEPT
iptables -A INPUT -p tcp --dport 22000 -j ACCEPT
iptables -A INPUT -p udp --dport 22000 -j ACCEPT
iptables -A INPUT -p udp --dport 21027 -j ACCEPT
```

## Управление

### Сервисы

```bash
# Статус
sudo systemctl status syncthing

# Перезапуск
sudo systemctl restart syncthing

# Логи
sudo journalctl -u syncthing -f

# Логи relay-сервера
sudo journalctl -u syncthing-relay -f
```

### Полезные команды

```bash
# Показать Device ID
syncthing --device-id

# Сгенерировать новый ключ
syncthing generate --config=/var/lib/syncthing

# Проверить конфигурацию
syncthing --config=/var/lib/syncthing serve --no-browser --log-flags=0

# REST API (пример)
curl -H "X-API-Key: YOUR_API_KEY" http://localhost:8384/rest/system/status
```

## Структура файлов

```
/var/lib/syncthing/
├── config.xml          # Конфигурация
├── cert.pem            # Сертификат устройства
├── key.pem             # Приватный ключ
├── index-v0.14.0.db/   # База данных
├── credentials/
│   └── info.txt        # Учётные данные
└── Sync/               # Папка по умолчанию (можно удалить)
```

## Резервное копирование

### Что бэкапить

```bash
# Обязательно (конфигурация и ключи)
/var/lib/syncthing/config.xml
/var/lib/syncthing/cert.pem
/var/lib/syncthing/key.pem

# Опционально (можно пересоздать)
/var/lib/syncthing/index-v0.14.0.db/
```

### Скрипт бэкапа

```bash
#!/bin/bash
BACKUP_DIR="/backup/syncthing/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

systemctl stop syncthing
cp /var/lib/syncthing/{config.xml,cert.pem,key.pem} "$BACKUP_DIR/"
systemctl start syncthing

echo "Backup saved to $BACKUP_DIR"
```

## Миграция на другой сервер

1. Остановите Syncthing на старом сервере
2. Скопируйте `config.xml`, `cert.pem`, `key.pem`
3. Установите Syncthing на новом сервере
4. Замените файлы конфигурации
5. Запустите Syncthing

```bash
# На старом сервере
sudo systemctl stop syncthing
scp /var/lib/syncthing/{config.xml,cert.pem,key.pem} newserver:/tmp/

# На новом сервере
sudo ./install.sh
sudo systemctl stop syncthing
sudo cp /tmp/{config.xml,cert.pem,key.pem} /var/lib/syncthing/
sudo chown syncthing:syncthing /var/lib/syncthing/{config.xml,cert.pem,key.pem}
sudo systemctl start syncthing
```

Device ID сохранится, и другие устройства продолжат синхронизацию.

## Мониторинг (Prometheus)

При установке с `--prometheus` метрики доступны на `http://<IP>:8384/metrics`.

### Grafana Dashboard

Импортируйте dashboard ID: **14536** (Syncthing)

### Основные метрики

| Метрика | Описание |
|---------|----------|
| `syncthing_connections` | Активные соединения |
| `syncthing_folder_state` | Состояние папок |
| `syncthing_folder_files` | Количество файлов |
| `syncthing_folder_bytes` | Размер данных |
| `syncthing_system_mem_alloc` | Использование памяти |

## Безопасность

### Рекомендации

1. **Всегда устанавливайте пароль GUI** — `--gui-password`
2. **Используйте SSL** — `--nginx --ssl`
3. **Ограничьте GUI локальной сетью** — `--gui-address 127.0.0.1:8384`
4. **Отключите глобальное обнаружение** для приватных сетей
5. **Используйте свой relay/discovery** вместо публичных

### Принудительное шифрование

В настройках устройства можно включить "Untrusted" режим — данные хранятся зашифрованными и не расшифровываются на этом узле.

## Troubleshooting

### Syncthing не запускается

```bash
# Проверить логи
sudo journalctl -u syncthing -n 100

# Проверить права
ls -la /var/lib/syncthing/

# Проверить порты
ss -tlnp | grep 8384
```

### Устройства не видят друг друга

1. Проверьте, что Device ID добавлен на обоих устройствах
2. Проверьте открытые порты (22000, 21027)
3. Включите Relay (если за NAT)
4. Проверьте Global Discovery

### Высокое потребление CPU

```bash
# Проверить количество файлов
find /path/to/folder -type f | wc -l

# Увеличить интервал сканирования
# В GUI: Папка → Расширенные → Интервал полного сканирования
```

### Синхронизация зависла

```bash
# Перезапустить сканирование
curl -X POST -H "X-API-Key: KEY" \
  http://localhost:8384/rest/db/scan?folder=FOLDER_ID

# Или через GUI: Папка → Пересканировать
```

## Полезные ссылки

- [Официальная документация](https://docs.syncthing.net/)
- [FAQ](https://docs.syncthing.net/users/faq.html)
- [Форум](https://forum.syncthing.net/)
- [GitHub](https://github.com/syncthing/syncthing)

