# MongoDB — Шпаргалка

## Установка

```bash
# Базовая установка (dev)
./install.sh

# С авторизацией (рекомендуется)
./install.sh --auth --admin-password SecurePass123

# Полная установка
./install.sh --auth --admin-password AdminPass123 \
    --db-name myapp --db-user myapp --db-password AppPass123 \
    --allow-remote --prometheus

# Для Replica Set
./install.sh --auth --admin-password AdminPass123 \
    --replica-set rs0 --allow-remote
```

## Управление сервисом

```bash
systemctl status mongod
systemctl restart mongod
systemctl stop mongod
journalctl -u mongod -f
```

## Подключение

```bash
# Без авторизации
mongosh

# С авторизацией (admin)
mongosh -u root -p 'AdminPass' --authenticationDatabase admin

# С авторизацией (пользователь)
mongosh -u myuser -p 'Password' mydb
```

## Частые команды

```javascript
// Список баз
show dbs

// Выбрать базу
use mydb

// Список коллекций
show collections

// Создать коллекцию
db.createCollection("users")

// Вставить документ
db.users.insertOne({ name: "John", age: 30 })

// Найти документы
db.users.find()
db.users.find({ name: "John" })

// Обновить документ
db.users.updateOne({ name: "John" }, { $set: { age: 31 } })

// Удалить документ
db.users.deleteOne({ name: "John" })

// Индексы
db.users.createIndex({ name: 1 })
db.users.getIndexes()

// Статистика
db.stats()
db.users.stats()
```

## Пользователи

```javascript
// Создать пользователя
use admin
db.createUser({
    user: "myuser",
    pwd: "password",
    roles: [{ role: "readWrite", db: "mydb" }]
})

// Список пользователей
db.getUsers()

// Удалить пользователя
db.dropUser("myuser")

// Изменить пароль
db.changeUserPassword("myuser", "newpassword")
```

## Replica Set

```javascript
// Статус
rs.status()

// Конфигурация
rs.conf()

// Добавить узел
rs.add("node2:27017")

// Удалить узел
rs.remove("node2:27017")

// Понизить primary
rs.stepDown()
```

## Бэкап и восстановление

```bash
# Бэкап всех баз
mongodump -u root -p Pass --authenticationDatabase admin -o /backup

# Бэкап одной базы
mongodump -u root -p Pass --authenticationDatabase admin --db mydb -o /backup

# Восстановление
mongorestore -u root -p Pass --authenticationDatabase admin /backup
```

## Строки подключения

```
# Локальное
mongodb://localhost:27017

# С авторизацией
mongodb://user:pass@localhost:27017/mydb

# Replica Set
mongodb://user:pass@node1:27017,node2:27017,node3:27017/mydb?replicaSet=rs0
```

## Пути

| Компонент | Путь |
|-----------|------|
| Данные | `/var/lib/mongodb` |
| Логи | `/var/log/mongodb/mongod.log` |
| Конфиг | `/etc/mongod.conf` |
| Учётные данные | `/root/mongodb-credentials/credentials.txt` |

## Prometheus Exporter

```bash
# Статус
systemctl status mongodb_exporter

# Метрики
curl http://localhost:9216/metrics
```

## Диагностика

```bash
# Проверить порт
ss -tlnp | grep 27017

# Логи
tail -f /var/log/mongodb/mongod.log

# Статус сервера
mongosh --eval "db.serverStatus()"
```

