# MongoDB для LXC контейнеров

Скрипт установки MongoDB Community Edition с поддержкой:
- **Авторизации** — создание администратора и пользователей
- **Replica Set** — подготовка к кластерному режиму
- **MongoDB Exporter** — мониторинг через Prometheus

## Быстрый старт

```bash
# Базовая установка MongoDB 8.0
./install.sh

# С авторизацией (рекомендуется)
./install.sh --auth --admin-password SecureAdminPass123

# Полная установка с базой и мониторингом
./install.sh --auth --admin-password AdminPass123 \
    --db-name myapp --db-user myapp --db-password AppPass123 \
    --allow-remote --prometheus
```

## Варианты установки

### Базовая установка (dev/test)

```bash
./install.sh
```

MongoDB без авторизации, только localhost. Подходит для разработки.

### С авторизацией (рекомендуется)

```bash
./install.sh --auth --admin-password SecureAdminPass123
```

Создаётся администратор `root` с полными правами.

### С базой данных и пользователем

```bash
./install.sh --auth --admin-password AdminPass123 \
    --db-name myapp --db-user myapp --db-password AppPass123
```

Создаёт:
- Администратора `root`
- Базу данных `myapp`
- Пользователя `myapp` с правами на эту базу

### С удалённым доступом

```bash
./install.sh --auth --admin-password AdminPass123 --allow-remote
```

MongoDB слушает на всех интерфейсах (0.0.0.0). Не забудьте настроить firewall!

### Для Replica Set

```bash
./install.sh --auth --admin-password AdminPass123 \
    --replica-set rs0 --allow-remote
```

Подготавливает MongoDB для работы в Replica Set:
- Инициализирует RS с текущим узлом
- Настраивает конфигурацию для репликации

### С мониторингом Prometheus

```bash
./install.sh --auth --admin-password AdminPass123 --prometheus
```

Устанавливает [MongoDB Exporter](https://github.com/percona/mongodb_exporter) от Percona.

## Опции

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--version VERSION` | Версия MongoDB (7.0, 8.0) | 8.0 |
| `--port PORT` | Порт MongoDB | 27017 |
| `--db-name NAME` | Создать базу данных | - |
| `--db-user USER` | Создать пользователя БД | - |
| `--db-password PASS` | Пароль пользователя | - |
| `--admin-password PASS` | Пароль администратора (root) | - |
| `--auth` | Включить авторизацию | - |
| `--allow-remote` | Разрешить удалённые подключения | - |
| `--replica-set NAME` | Подготовить для Replica Set | - |
| `--prometheus` | Установить MongoDB Exporter | - |
| `--exporter-port PORT` | Порт MongoDB Exporter | 9216 |

## Примеры использования

### Production-сервер с полной настройкой

```bash
./install.sh \
    --auth --admin-password "$(openssl rand -base64 24)" \
    --db-name production \
    --db-user app \
    --db-password "$(openssl rand -base64 24)" \
    --allow-remote \
    --prometheus

# Пароли сохраняются в /root/mongodb-credentials/credentials.txt
```

### MongoDB 7.0 для совместимости

```bash
./install.sh --version 7.0 --auth --admin-password AdminPass123
```

### Replica Set кластер

На первом узле (primary):
```bash
./install.sh --auth --admin-password AdminPass123 \
    --replica-set rs0 --allow-remote
```

На остальных узлах:
```bash
./install.sh --auth --admin-password AdminPass123 \
    --replica-set rs0 --allow-remote
```

Затем на primary добавить узлы:
```bash
mongosh -u root -p AdminPass123 --authenticationDatabase admin --eval "
    rs.add('node2:27017');
    rs.add('node3:27017');
"
```

## Пути установки

| Компонент | Путь |
|-----------|------|
| Данные | `/var/lib/mongodb` |
| Логи | `/var/log/mongodb/mongod.log` |
| Конфигурация | `/etc/mongod.conf` |
| Учётные данные | `/root/mongodb-credentials/credentials.txt` |

## Управление сервисом

```bash
# Статус
systemctl status mongod

# Перезапуск
systemctl restart mongod

# Остановка
systemctl stop mongod

# Логи
journalctl -u mongod -f

# Логи из файла
tail -f /var/log/mongodb/mongod.log
```

## Подключение

### Без авторизации

```bash
mongosh
```

### С авторизацией

```bash
# Администратор
mongosh -u root -p 'YourAdminPassword' --authenticationDatabase admin

# Пользователь базы
mongosh -u myuser -p 'YourPassword' mydb
```

### Строка подключения

```
# Без авторизации
mongodb://localhost:27017

# С авторизацией
mongodb://user:password@localhost:27017/database

# Replica Set
mongodb://user:password@node1:27017,node2:27017,node3:27017/database?replicaSet=rs0
```

## Replica Set

### Проверка статуса

```bash
mongosh -u root -p AdminPass --authenticationDatabase admin --eval "rs.status()"
```

### Добавление узла

```javascript
rs.add("node2:27017")
```

### Удаление узла

```javascript
rs.remove("node2:27017")
```

### Понижение primary

```javascript
rs.stepDown()
```

### Конфигурация RS

```javascript
rs.conf()
```

## Мониторинг (Prometheus)

### MongoDB Exporter

После установки с флагом `--prometheus`:

- Метрики: `http://<IP>:9216/metrics`
- Health check: `http://<IP>:9216/`

### Prometheus конфигурация

```yaml
scrape_configs:
  - job_name: 'mongodb'
    static_configs:
      - targets: ['mongodb-host:9216']
```

### Управление экспортером

```bash
systemctl status mongodb_exporter
systemctl restart mongodb_exporter
journalctl -u mongodb_exporter -f
```

## Безопасность

### Рекомендации

1. **Всегда включайте авторизацию** для production
2. **Используйте сложные пароли** (минимум 16 символов)
3. **Ограничьте bind_ip** если не нужен удалённый доступ
4. **Настройте firewall** для защиты порта 27017
5. **Используйте TLS** для шифрования соединений

### Firewall (ufw)

```bash
# Разрешить только из внутренней сети
ufw allow from 192.168.1.0/24 to any port 27017

# Или конкретный IP
ufw allow from 192.168.1.100 to any port 27017
```

### Firewall (iptables)

```bash
iptables -A INPUT -p tcp -s 192.168.1.0/24 --dport 27017 -j ACCEPT
iptables -A INPUT -p tcp --dport 27017 -j DROP
```

## Резервное копирование

### mongodump

```bash
# Все базы
mongodump -u root -p AdminPass --authenticationDatabase admin --out /backup/$(date +%Y%m%d)

# Конкретная база
mongodump -u root -p AdminPass --authenticationDatabase admin --db mydb --out /backup/mydb
```

### mongorestore

```bash
# Все базы
mongorestore -u root -p AdminPass --authenticationDatabase admin /backup/20231201

# Конкретная база
mongorestore -u root -p AdminPass --authenticationDatabase admin --db mydb /backup/mydb/mydb
```

## Решение проблем

### MongoDB не запускается

```bash
# Проверить логи
journalctl -u mongod -n 100
cat /var/log/mongodb/mongod.log

# Проверить права на директорию данных
ls -la /var/lib/mongodb

# Проверить синтаксис конфига
mongod --config /etc/mongod.conf --validate
```

### Ошибка подключения

```bash
# Проверить, слушает ли MongoDB
ss -tlnp | grep 27017

# Проверить bind_ip в конфиге
grep bindIp /etc/mongod.conf

# Проверить firewall
ufw status
iptables -L -n | grep 27017
```

### Ошибка авторизации

```bash
# Сбросить пароль администратора (требует остановки MongoDB)
systemctl stop mongod

# Запустить без авторизации
mongod --dbpath /var/lib/mongodb --port 27017 --bind_ip 127.0.0.1 &

# Сбросить пароль
mongosh admin --eval "db.changeUserPassword('root', 'NewPassword')"

# Остановить и запустить нормально
pkill mongod
systemctl start mongod
```

### Проблемы с памятью

MongoDB требует достаточно RAM. Рекомендуется минимум 2 GB.

```bash
# Проверить использование памяти
free -h
mongosh --eval "db.serverStatus().mem"
```

### Transparent Huge Pages (THP)

Если в логах предупреждение о THP:

```bash
# Проверить статус THP
cat /sys/kernel/mm/transparent_hugepage/enabled

# Должно быть [never]
# Если нет, перезапустите сервис
systemctl restart disable-thp
```

## Требования

### Минимальные

- CPU: 1 core
- RAM: 1 GB
- Диск: 10 GB

### Рекомендуемые

- CPU: 2+ cores
- RAM: 4+ GB
- Диск: 50+ GB (SSD)

### Поддерживаемые ОС

- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12

## Ссылки

- [MongoDB Documentation](https://docs.mongodb.com/)
- [MongoDB Manual](https://docs.mongodb.com/manual/)
- [MongoDB Exporter](https://github.com/percona/mongodb_exporter)
- [MongoDB University](https://university.mongodb.com/) — бесплатные курсы

