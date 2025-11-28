# Шпаргалка: Создание LXC контейнеров в Proxmox

## Быстрые команды

### Минимальная установка
```bash
cd /root/run-in-lxc/proxmox
sudo ./create-lxc.sh --name my-container
```

**Что получите:**
- ID: автоматически (следующий свободный)
- 1 CPU ядро
- 2 GB RAM
- 8 GB диск
- DHCP сеть
- Debian 13
- Пароль сгенерирован автоматически

---

## Типовые сценарии

### 1. Контейнер с DHCP (самое простое)
```bash
sudo ./create-lxc.sh --name forgejo --start
```

### 2. Контейнер со статическим IP
```bash
sudo ./create-lxc.sh \
  --name forgejo \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1 \
  --start
```

### 3. Мощный контейнер для БД
```bash
sudo ./create-lxc.sh \
  --name postgres \
  --cores 4 \
  --memory 8192 \
  --disk 50 \
  --ip 192.168.1.101/24 \
  --gateway 192.168.1.1 \
  --start
```

### 4. С SSH ключом (без пароля)
```bash
sudo ./create-lxc.sh \
  --name app \
  --ip 192.168.1.102/24 \
  --gateway 192.168.1.1 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --start
```

### 5. Предварительный просмотр (dry-run)
```bash
sudo ./create-lxc.sh \
  --name test \
  --cores 2 \
  --memory 4096 \
  --dry-run
```

---

## Полный пример для Forgejo

```bash
# Создаем контейнер
sudo ./create-lxc.sh \
  --name forgejo-prod \
  --cores 2 \
  --memory 4096 \
  --disk 20 \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1 \
  --nameserver 8.8.8.8 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --start

# Подключаемся
ssh root@192.168.1.100

# Устанавливаем Forgejo
cd /root
git clone <repo-url> run-in-lxc
cd run-in-lxc/forgejo
./install.sh
```

---

## Управление контейнерами

### Базовые команды
```bash
# Список всех контейнеров
pct list

# Статус контейнера
pct status 100

# Запуск
pct start 100

# Остановка
pct stop 100

# Перезагрузка
pct reboot 100

# Войти в консоль
pct enter 100

# Удалить контейнер
pct destroy 100
```

### Информация о контейнере
```bash
# Конфигурация
pct config 100

# Использование ресурсов
pct status 100 --verbose

# Сетевые интерфейсы
pct exec 100 -- ip addr show
```

### Изменение параметров
```bash
# Изменить память
pct set 100 --memory 4096

# Изменить CPU
pct set 100 --cores 4

# Изменить IP
pct set 100 --net0 name=eth0,bridge=vmbr0,ip=192.168.1.150/24,gw=192.168.1.1

# Добавить диск
pct set 100 --mp0 /mnt/data,mp=/data,size=50G
```

---

## Сеть

### DHCP (автоматически)
```bash
sudo ./create-lxc.sh --name test
# IP получится автоматически
```

### Статический IPv4
```bash
sudo ./create-lxc.sh \
  --name test \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1 \
  --nameserver 8.8.8.8
```

### IPv6
```bash
sudo ./create-lxc.sh \
  --name test \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1 \
  --ipv6 2001:db8::100/64
```

### Узнать IP контейнера
```bash
# Способ 1
pct exec 100 -- ip -4 addr show eth0 | grep inet

# Способ 2
pct config 100 | grep net0
```

---

## Хранилища

### Посмотреть доступные хранилища
```bash
pvesm status
```

### Указать конкретное хранилище
```bash
sudo ./create-lxc.sh \
  --name test \
  --storage local-lvm
```

---

## Шаблоны

### Посмотреть установленные шаблоны
```bash
pveam list local
```

### Посмотреть доступные для загрузки
```bash
pveam available | grep debian
pveam available | grep ubuntu
```

### Загрузить шаблон вручную
```bash
pveam download local debian-13-standard_13.0-1_amd64.tar.zst
```

### Использовать другой шаблон
```bash
sudo ./create-lxc.sh \
  --name test \
  --template ubuntu-24.04-standard
```

---

## Безопасность

### Использование SSH ключей
```bash
# Генерация ключа (если нет)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Создание контейнера с ключом
sudo ./create-lxc.sh \
  --name secure \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --start

# Подключение без пароля
ssh root@<IP>
```

### Смена пароля в контейнере
```bash
pct enter 100
passwd
```

### Непривилегированные контейнеры
```bash
# По умолчанию создаются непривилегированные (безопаснее)
sudo ./create-lxc.sh --name test

# Привилегированный (если нужно)
sudo ./create-lxc.sh --name test --unprivileged 0
```

---

## Резервное копирование

### Создать бэкап
```bash
vzdump 100 --mode snapshot --compress zstd
```

### Восстановить из бэкапа
```bash
pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-*.tar.zst
```

---

## Решение проблем

### Контейнер не создается
```bash
# Проверить логи
journalctl -xe

# Проверить доступное место
pvesm status

# Проверить занятые ID
pct list
qm list
```

### Сеть не работает
```bash
# Войти в контейнер
pct enter 100

# Проверить интерфейсы
ip addr show

# Проверить маршруты
ip route show

# Перезапустить сеть
systemctl restart networking
```

### Шаблон не загружается
```bash
# Обновить список
pveam update

# Проверить доступные
pveam available

# Загрузить вручную
pveam download local debian-13-standard_13.0-1_amd64.tar.zst
```

---

## Полезные комбинации

### Создать и сразу настроить
```bash
# Создать контейнер
sudo ./create-lxc.sh --name app --ip 192.168.1.100/24 --gateway 192.168.1.1 --start

# Обновить систему
pct exec 100 -- bash -c "apt update && apt upgrade -y"

# Установить базовые пакеты
pct exec 100 -- apt install -y curl wget git vim htop
```

### Массовое создание
```bash
# Создать несколько контейнеров
for i in {1..3}; do
  sudo ./create-lxc.sh --name "app-$i" --start
done
```

### Клонирование контейнера
```bash
# Остановить исходный
pct stop 100

# Клонировать
pct clone 100 101 --hostname app-clone

# Запустить оба
pct start 100
pct start 101
```
