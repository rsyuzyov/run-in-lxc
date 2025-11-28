# Сервер 1С:Предприятие 8 в LXC контейнере

Скрипты и инструкции для установки сервера 1С:Предприятие 8 в LXC контейнер.

## Системные требования

### Минимальные требования
- **ОС**: Debian 12 (Bookworm) или Ubuntu 22.04/24.04
- **RAM**: 2GB (рекомендуется 4GB+)
- **CPU**: 2 cores (рекомендуется 4+)
- **Диск**: 5GB свободного места (без учёта баз данных)
- **Архитектура**: amd64 (x86_64) или arm64

### Сетевые порты

| Порт | Назначение |
|------|------------|
| 1540 | Агент сервера (ragent) |
| 1541 | Менеджер кластера |
| 1542 | Сервер хранилища конфигураций (CRS) |
| 1545 | Сервер администрирования (RAS) |
| 1560-1591 | Рабочие процессы |

## Источники дистрибутивов

Скрипт поддерживает два способа получения дистрибутивов:

### 1. Скачивание с releases.1c.ru (рекомендуется)

Требуется действующая подписка ИТС. Скрипт автоматически:
- Авторизуется на портале releases.1c.ru
- Скачает необходимые пакеты
- Установит их

```bash
sudo ./install.sh \
  --version 8.3.25.1257 \
  --its-login user@example.com \
  --its-password YourPassword
```

### 2. Локальный каталог с дистрибутивами

Если у вас уже есть скачанные `.deb` пакеты:

```bash
sudo ./install.sh --distrib-dir /path/to/packages
```

**Структура каталога:**
```
/path/to/packages/
├── 1c-enterprise-8.3.25.1257-common_8.3.25-1257_amd64.deb
├── 1c-enterprise-8.3.25.1257-server_8.3.25-1257_amd64.deb
├── 1c-enterprise-8.3.25.1257-crs_8.3.25-1257_amd64.deb     # опционально
└── 1c-enterprise-8.3.25.1257-ws_8.3.25-1257_amd64.deb      # опционально
```

## Установка

### Быстрый старт

**С ИТС:**
```bash
sudo ./install.sh \
  --version 8.3.25.1257 \
  --its-login user@example.com \
  --its-password YourPassword
```

**Из локального каталога:**
```bash
sudo ./install.sh --distrib-dir /opt/distrib/1c
```

### Параметры установки

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--version` | Версия платформы (например: 8.3.25.1257) | — |
| `--its-login` | Логин пользователя ИТС | — |
| `--its-password` | Пароль пользователя ИТС | — |
| `--distrib-dir` | Каталог с .deb пакетами | — |
| `--with-crs` | Установить сервер хранилища конфигураций | нет |
| `--with-ws` | Установить веб-расширения | нет |
| `--cluster-port` | Порт менеджера кластера | 1541 |
| `--ras-port` | Порт сервера администрирования | 1545 |
| `--ragent-port` | Порт агента сервера | 1540 |
| `--no-cluster` | Не создавать кластер автоматически | создаётся |

### Примеры установки

**Полная установка с дополнительными компонентами:**
```bash
sudo ./install.sh \
  --version 8.3.25.1257 \
  --its-login user@example.com \
  --its-password MyPassword \
  --with-crs \
  --with-ws
```

**Установка с нестандартными портами:**
```bash
sudo ./install.sh \
  --distrib-dir /opt/1c-distrib \
  --cluster-port 2541 \
  --ras-port 2545 \
  --ragent-port 2540
```

**Установка без автоматического создания кластера:**
```bash
sudo ./install.sh \
  --distrib-dir /opt/1c-distrib \
  --no-cluster
```

## После установки

### Структура каталогов

| Путь | Назначение |
|------|------------|
| `/opt/1cv8/x86_64/<version>/` | Бинарные файлы платформы |
| `/home/usr1cv8/.1cv8/` | Данные кластера |
| `/var/log/1C/` | Логи |
| `/var/1C/licenses/` | Лицензии |
| `/etc/default/srv1cv8` | Конфигурация сервера |

### Управление сервисами

**Сервер 1С (srv1cv8):**
```bash
sudo systemctl status srv1cv8    # Статус
sudo systemctl restart srv1cv8   # Перезапуск
sudo systemctl stop srv1cv8      # Остановка
sudo journalctl -u srv1cv8 -f    # Логи
```

**Сервер администрирования (RAS):**
```bash
sudo systemctl status ras
sudo systemctl restart ras
```

**Сервер хранилища (CRS):**
```bash
sudo systemctl status crs1cv8
sudo systemctl restart crs1cv8
```

### Утилиты администрирования

Все команды выполняются через `rac` (консоль администрирования):

```bash
# Список кластеров
rac cluster list

# Список информационных баз в кластере
rac infobase summary list --cluster=<CLUSTER_ID>

# Список сеансов
rac session list --cluster=<CLUSTER_ID>

# Завершение сеанса
rac session terminate --cluster=<CLUSTER_ID> --session=<SESSION_ID>

# Блокировка сеансов для базы
rac infobase update --cluster=<CLUSTER_ID> --infobase=<INFOBASE_ID> \
  --sessions-deny=on --denied-message="Техническое обслуживание"
```

## База данных PostgreSQL

Для работы с базами данных PostgreSQL необходимо установить PostgreSQL для 1С:

```bash
# Из этого репозитория
cd ../postgres
sudo ./install.sh --allow-remote
```

Или используйте существующий сервер PostgreSQL с поддержкой 1С.

**Рекомендуемые настройки PostgreSQL для 1С:**
- `shared_buffers` = 25% от RAM
- `effective_cache_size` = 75% от RAM
- `work_mem` = 256MB
- `maintenance_work_mem` = 1GB
- `max_connections` = 100-500

## Создание информационной базы

### Через конфигуратор (графический интерфейс)

1. Запустите 1C:Enterprise
2. "Добавить" → "Создание новой информационной базы"
3. Выберите "На сервере 1С:Предприятия"
4. Укажите:
   - Кластер серверов: `<IP>:1541`
   - Имя базы данных: `mybase`
   - Тип СУБД: PostgreSQL
   - Сервер БД: `<postgres_host>`
   - Имя БД: `mybase`
   - Пользователь: `postgres` или специальный пользователь
   - Пароль БД

### Через командную строку

```bash
# Создание базы из выгрузки .dt
/opt/1cv8/x86_64/<version>/1cv8 DESIGNER \
  /S <cluster>/<basename> \
  /RestoreIB /path/to/backup.dt

# Создание пустой базы из конфигурации .cf
/opt/1cv8/x86_64/<version>/1cv8 DESIGNER \
  /S <cluster>/<basename> \
  /LoadCfg /path/to/config.cf \
  /UpdateDBCfg
```

## Лицензирование

### Программная лицензия

1. Скопируйте файл лицензии в `/var/1C/licenses/`
2. Установите права: `chown usr1cv8:usr1cv8 /var/1C/licenses/*`
3. Перезапустите сервер: `systemctl restart srv1cv8`

### Аппаратный ключ HASP

1. Установите драйвер HASP:
   ```bash
   apt-get install aksusbd
   systemctl enable aksusbd
   systemctl start aksusbd
   ```
2. Подключите USB-ключ к хосту Proxmox
3. Пробросьте устройство в контейнер (LXC unprivileged может потребовать дополнительную настройку)

## Веб-публикация (--with-ws)

Если установлены веб-расширения, можно публиковать базы через веб-сервер.

### Публикация через Apache

```bash
# Публикация базы
/opt/1cv8/x86_64/<version>/webinst \
  -apache24 \
  -wsdir mybase \
  -dir /var/www/1c/mybase \
  -connstr "Srvr=localhost;Ref=mybase;" \
  -confpath /etc/apache2/1c.conf

# Активация конфигурации
a2enconf 1c
systemctl reload apache2
```

### Публикация через nginx

Требуется модуль FastCGI и настройка upstream.

## Резервное копирование

### Выгрузка базы (dt-файл)

```bash
/opt/1cv8/x86_64/<version>/1cv8 DESIGNER \
  /S localhost/mybase \
  /N admin /P password \
  /DumpIB /backup/mybase_$(date +%Y%m%d).dt
```

### Резервное копирование PostgreSQL

```bash
pg_dump -U postgres -Fc mybase > /backup/mybase_$(date +%Y%m%d).pgdump
```

## Обновление платформы

1. Скачайте новую версию дистрибутивов
2. Остановите сервисы:
   ```bash
   systemctl stop srv1cv8 ras crs1cv8
   ```
3. Установите новые пакеты:
   ```bash
   dpkg -i 1c-enterprise-*.deb
   apt-get install -f -y
   ```
4. Обновите пути в systemd unit-файлах
5. Перезапустите сервисы

## Решение проблем

### Сервер не запускается

```bash
# Проверьте логи
journalctl -u srv1cv8 -n 100

# Проверьте права на каталоги
ls -la /home/usr1cv8/.1cv8/

# Проверьте порты
ss -tlnp | grep -E '154[0-5]'
```

### Не удаётся подключиться к кластеру

```bash
# Проверьте статус сервисов
systemctl status srv1cv8 ras

# Проверьте firewall
iptables -L -n

# Тест подключения
rac cluster list --ras=localhost:1545
```

### Ошибка лицензии

```bash
# Проверьте наличие лицензий
ls -la /var/1C/licenses/

# Проверьте логи
cat /var/log/1C/*/1cv8.log | tail -100
```

### Ошибка подключения к PostgreSQL

```bash
# Проверьте доступность PostgreSQL
psql -h <postgres_host> -U postgres -c "SELECT 1;"

# Проверьте pg_hba.conf
# Должна быть строка: host all all <1c_server_ip>/32 scram-sha-256
```

## Удаление

```bash
# Остановить сервисы
sudo systemctl stop srv1cv8 ras crs1cv8
sudo systemctl disable srv1cv8 ras crs1cv8

# Удалить unit-файлы
sudo rm /etc/systemd/system/srv1cv8.service
sudo rm /etc/systemd/system/ras.service
sudo rm /etc/systemd/system/crs1cv8.service

# Удалить пакеты
sudo dpkg -P $(dpkg -l | grep 1c-enterprise | awk '{print $2}')

# Удалить данные (ВНИМАНИЕ: удаляет все базы!)
sudo rm -rf /home/usr1cv8
sudo rm -rf /opt/1cv8
sudo rm -rf /var/log/1C
sudo rm -rf /var/1C

# Удалить пользователя
sudo userdel -r usr1cv8

# Удалить конфигурацию
sudo rm /etc/default/srv1cv8
sudo rm /etc/profile.d/1c-enterprise.sh
```

## Поддержка

- [Официальная документация 1С](https://its.1c.ru/)
- [1С:ИТС](https://portal.1c.ru/)
- [Форум Infostart](https://infostart.ru/forum/)

