# Шпаргалка по установке Forgejo

## Быстрая установка

### Вариант 1: Все автоматически (рекомендуется для начала)
```bash
cd /root/run-in-lxc/forgejo
sudo ./install.sh
```

**Что произойдет:**
- ✅ Установится PostgreSQL локально
- ✅ Создастся база данных `forgejo`
- ✅ Сгенерируется безопасный пароль
- ✅ Установится и запустится Forgejo
- ✅ Все настроится автоматически

**После установки:**
- Откройте браузер: `http://localhost:3000`
- Пароль БД будет показан в выводе скрипта - сохраните его!

---

### Вариант 2: С внешней базой данных

**Подготовка (на сервере PostgreSQL):**
```sql
CREATE USER forgejo WITH PASSWORD 'SecurePass123';
CREATE DATABASE forgejo OWNER forgejo;
GRANT ALL PRIVILEGES ON DATABASE forgejo TO forgejo;
```

**Установка:**
```bash
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-name forgejo \
  --db-user forgejo \
  --db-password SecurePass123
```

---

### Вариант 3: Кастомная настройка

```bash
sudo ./install.sh \
  --version 1.21.5-0 \
  --db-password MyPassword123 \
  --http-port 8080 \
  --ssh-port 2222 \
  --domain git.mycompany.com
```

---

## Управление после установки

### Проверка статуса
```bash
sudo systemctl status forgejo
```

### Перезапуск
```bash
sudo systemctl restart forgejo
```

### Просмотр логов
```bash
sudo journalctl -u forgejo -f
```

### Остановка
```bash
sudo systemctl stop forgejo
```

---

## Важные пути

| Что | Где |
|-----|-----|
| Конфигурация | `/etc/forgejo/app.ini` |
| Данные | `/var/lib/forgejo/` |
| Репозитории | `/var/lib/forgejo/data/gitea-repositories/` |
| Логи | `/var/lib/forgejo/log/` |
| Бинарник | `/usr/local/bin/gitea` |

---

## Первый вход

1. Откройте `http://localhost:3000` (или ваш домен)
2. Создайте учетную запись администратора
3. Настройки БД уже заполнены - просто нажмите "Установить"
4. Готово! Можете создавать репозитории

---

## Обновление версии

```bash
sudo ./install.sh --version 1.22.0-0 [остальные параметры как при установке]
```

Скрипт автоматически:
- Остановит сервис
- Обновит бинарник
- Запустит сервис снова

---

## Решение проблем

### Forgejo не запускается
```bash
# Проверьте логи
sudo journalctl -u forgejo -n 100

# Проверьте конфигурацию
sudo cat /etc/forgejo/app.ini

# Проверьте права
sudo ls -la /var/lib/forgejo
```

### Не подключается к БД
```bash
# Проверьте PostgreSQL
sudo systemctl status postgresql

# Проверьте подключение вручную
psql -h localhost -U forgejo -d forgejo
```

### Забыли пароль БД
```bash
# Посмотрите в конфиге
sudo grep PASSWD /etc/forgejo/app.ini
```

---

## Удаление

```bash
# Остановить и удалить сервис
sudo systemctl stop forgejo
sudo systemctl disable forgejo
sudo rm /etc/systemd/system/forgejo.service

# Удалить данные
sudo rm -rf /var/lib/forgejo
sudo rm -rf /etc/forgejo
sudo rm /usr/local/bin/gitea

# Удалить пользователя
sudo userdel -r forgejo

# Удалить PostgreSQL (если был установлен локально)
sudo apt-get remove --purge postgresql postgresql-contrib
```
