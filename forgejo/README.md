# Forgejo в LXC контейнере

Скрипты и инструкции для установки Forgejo - легковесного Git-сервиса (форк Gitea) в LXC контейнер.

## Системные требования

### Минимальные требования
- **ОС**: Debian 12 (Bookworm) или Ubuntu 22.04/24.04
- **RAM**: 1GB (рекомендуется 2GB)
- **CPU**: 2 cores
- **Диск**: 10GB свободного места
- **Архитектура**: amd64 (x86_64) или arm64

### Зависимости
- Git
- PostgreSQL клиент (для подключения к БД)
- systemd

## База данных

Скрипт поддерживает два режима работы с PostgreSQL:

### 1. Автоматическая установка локального PostgreSQL (по умолчанию)

Если параметр `--db-host` **не указан**, скрипт автоматически:
- Установит PostgreSQL на локальную систему
- Создаст базу данных и пользователя
- Сгенерирует безопасный пароль (или использует указанный через `--db-password`)
- Настроит все необходимые права доступа

**Пример:**
```bash
sudo ./install.sh
# или с явным указанием пароля:
sudo ./install.sh --db-password MySecurePassword123
```

### 2. Использование внешнего PostgreSQL

Если параметр `--db-host` **указан**, скрипт будет использовать внешний сервер PostgreSQL.

**Требования:**
- Адрес сервера PostgreSQL
- Имя базы данных (должна быть создана заранее)
- Логин и пароль пользователя БД (с правами на базу)

**Пример:**
```bash
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-name forgejo \
  --db-user forgejo \
  --db-password SecurePass123
```

## Установка

### Быстрый старт

**Автоматическая установка с локальным PostgreSQL:**
```bash
sudo ./install.sh
```

**Установка с внешней базой данных:**
```bash
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-name forgejo \
  --db-user forgejo \
  --db-password your_password
```

### Параметры установки

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--version` | Версия Forgejo для установки | latest (последняя стабильная) |
| `--db-host` | Адрес PostgreSQL сервера (если не указан - устанавливается локальный) | не указан (локальная установка) |
| `--db-port` | Порт PostgreSQL | 5432 |
| `--db-name` | Имя базы данных | forgejo |
| `--db-user` | Пользователь БД | forgejo |
| `--db-password` | Пароль пользователя БД (обязателен для внешней БД) | генерируется автоматически |
| `--http-port` | HTTP порт для Forgejo | 3000 |
| `--ssh-port` | SSH порт для Git | 2222 |
| `--domain` | Доменное имя | localhost |

### Примеры использования

**Установка с внешней БД:**
```bash
sudo ./install.sh \
  --db-host 192.168.1.100 \
  --db-name forgejo_prod \
  --db-user forgejo_user \
  --db-password SecurePass123 \
  --domain git.example.com
```

**Установка конкретной версии:**
```bash
sudo ./install.sh \
  --version 1.21.5-0 \
  --db-host localhost \
  --db-name forgejo \
  --db-user forgejo \
  --db-password your_password
```

## После установки

После успешной установки:

1. Forgejo будет доступен по адресу `http://localhost:3000` (или указанному домену и порту)
2. Сервис управляется через systemd:
   ```bash
   sudo systemctl status forgejo
   sudo systemctl restart forgejo
   sudo systemctl stop forgejo
   ```
3. Логи доступны через journalctl:
   ```bash
   sudo journalctl -u forgejo -f
   ```
4. Конфигурационный файл: `/etc/forgejo/app.ini`
5. Данные хранятся в: `/var/lib/forgejo`

## Первоначальная настройка

При первом входе на веб-интерфейс вам будет предложено:
- Проверить настройки базы данных (уже настроены скриптом)
- Создать учетную запись администратора
- Настроить дополнительные параметры (email, регистрация и т.д.)

## Безопасность

Рекомендации:
- Используйте сильные пароли для БД
- Настройте firewall для ограничения доступа
- Используйте HTTPS в продакшене (настройте reverse proxy)
- Регулярно обновляйте Forgejo

## Обновление

Для обновления Forgejo:
```bash
sudo ./install.sh --version NEW_VERSION [остальные параметры]
```

Скрипт автоматически остановит сервис, обновит бинарник и запустит сервис снова.

## Удаление

```bash
sudo systemctl stop forgejo
sudo systemctl disable forgejo
sudo rm /etc/systemd/system/forgejo.service
sudo rm -rf /var/lib/forgejo
sudo rm -rf /etc/forgejo
sudo userdel -r forgejo
```

## Поддержка

- [Официальная документация Forgejo](https://forgejo.org/docs/)
- [GitHub репозиторий](https://github.com/go-gitea/gitea)
