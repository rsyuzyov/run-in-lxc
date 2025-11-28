# Шпаргалка по установке сервера 1С:Предприятие 8

## Быстрая установка

### Вариант 1: Скачивание с ИТС (рекомендуется)

```bash
cd /root/run-in-lxc/1c
sudo ./install.sh \
  --version 8.3.25.1257 \
  --its-login user@example.com \
  --its-password YourPassword
```

**Что произойдет:**
- ✅ Авторизация на releases.1c.ru
- ✅ Скачивание дистрибутивов
- ✅ Установка сервера 1С
- ✅ Настройка сервисов (srv1cv8, ras)
- ✅ Создание кластера

---

### Вариант 2: Из локального каталога

```bash
sudo ./install.sh --distrib-dir /path/to/1c-packages
```

**Структура каталога:**
```
/path/to/1c-packages/
├── 1c-enterprise*-common*.deb
├── 1c-enterprise*-server*.deb
├── 1c-enterprise*-crs*.deb     # опционально
└── 1c-enterprise*-ws*.deb      # опционально
```

---

### Вариант 3: Полная установка (все компоненты)

```bash
sudo ./install.sh \
  --version 8.3.25.1257 \
  --its-login user@example.com \
  --its-password YourPassword \
  --with-crs \
  --with-ws
```

---

## После установки

### Проверка статуса

```bash
sudo systemctl status srv1cv8
sudo systemctl status ras
```

### Просмотр логов

```bash
sudo journalctl -u srv1cv8 -f
```

### Проверка кластера

```bash
rac cluster list
```

---

## Сетевые порты

| Порт | Сервис |
|------|--------|
| 1540 | Агент сервера |
| 1541 | Менеджер кластера |
| 1545 | Сервер администрирования (RAS) |
| 1542 | Сервер хранилища (CRS) |
| 1560-1591 | Рабочие процессы |

---

## Основные команды

### Управление сервером

```bash
# Статус
sudo systemctl status srv1cv8

# Перезапуск
sudo systemctl restart srv1cv8

# Остановка
sudo systemctl stop srv1cv8

# Логи
sudo journalctl -u srv1cv8 -n 100
```

### Утилиты администрирования (rac)

```bash
# Список кластеров
rac cluster list

# Список баз
rac infobase summary list --cluster=<CLUSTER_ID>

# Список сеансов
rac session list --cluster=<CLUSTER_ID>

# Завершить сеанс
rac session terminate --cluster=<CLUSTER_ID> --session=<SESSION_ID>

# Заблокировать сеансы базы
rac infobase update --cluster=<CLUSTER_ID> --infobase=<INFOBASE_ID> \
  --sessions-deny=on --denied-message="Техобслуживание"
```

---

## Важные пути

| Что | Где |
|-----|-----|
| Платформа | `/opt/1cv8/x86_64/<version>/` |
| Данные кластера | `/home/usr1cv8/.1cv8/` |
| Логи | `/var/log/1C/` |
| Лицензии | `/var/1C/licenses/` |
| Конфигурация | `/etc/default/srv1cv8` |

---

## Подключение базы PostgreSQL

### 1. Установите PostgreSQL для 1С

```bash
cd ../postgres
sudo ./install.sh --allow-remote
```

### 2. Создайте базу данных

```bash
sudo -u postgres psql
CREATE DATABASE mybase;
```

### 3. Подключите базу в 1С

- Кластер: `<server_ip>:1541`
- Тип СУБД: PostgreSQL
- Сервер БД: `localhost` или IP
- База: `mybase`

---

## Типичные проблемы

### Сервер не запускается

```bash
# Проверить логи
journalctl -u srv1cv8 -n 50

# Проверить права
ls -la /home/usr1cv8/.1cv8/
```

### Не видно кластер

```bash
# Проверить RAS
systemctl status ras

# Проверить подключение
rac cluster list --ras=localhost:1545
```

### Ошибка лицензии

```bash
# Проверить файлы лицензий
ls -la /var/1C/licenses/

# Права должны быть у usr1cv8
chown -R usr1cv8:usr1cv8 /var/1C/licenses/
```

---

## Удаление

```bash
# Остановить сервисы
sudo systemctl stop srv1cv8 ras crs1cv8
sudo systemctl disable srv1cv8 ras crs1cv8

# Удалить пакеты
sudo dpkg -P $(dpkg -l | grep 1c-enterprise | awk '{print $2}')

# Удалить данные
sudo rm -rf /home/usr1cv8 /opt/1cv8 /var/log/1C /var/1C

# Удалить пользователя
sudo userdel -r usr1cv8
```

