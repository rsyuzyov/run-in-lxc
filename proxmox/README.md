# Proxmox LXC Management

Скрипты для управления LXC контейнерами в Proxmox VE.

## Системные требования

- Proxmox VE 7.0 или выше
- Доступ к Proxmox API или выполнение на ноде Proxmox
- Права root или sudo

## Скрипты

### create-lxc.sh

Скрипт для автоматического создания LXC контейнеров в Proxmox с гибкой настройкой параметров.

**Возможности:**
- Автоматическое определение свободного ID
- Автоматический выбор хранилища
- Автоматическая загрузка шаблона Debian 13 (если отсутствует)
- Поддержка статического IP и DHCP
- Генерация безопасного пароля root
- Поддержка SSH ключей
- Проверка существования ID и доступности IP
- Режим dry-run для предварительного просмотра

## Использование

### Быстрый старт

**Минимальная команда (только имя):**
```bash
sudo ./create-lxc.sh --name my-container
```

Будет создан контейнер с параметрами по умолчанию:
- ID: автоматически (следующий свободный, начиная с 100)
- CPU: 1 ядро
- RAM: 2 GB
- Диск: 8 GB
- Сеть: DHCP
- Шаблон: Debian 13
- Непривилегированный контейнер с nesting и keyctl

### Примеры

**С статическим IP:**
```bash
sudo ./create-lxc.sh \
  --name forgejo-prod \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1
```

**Полная настройка:**
```bash
sudo ./create-lxc.sh \
  --name forgejo-prod \
  --id 150 \
  --cores 4 \
  --memory 4096 \
  --disk 20 \
  --storage local-lvm \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1 \
  --nameserver 8.8.8.8 \
  --password SecurePass123 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --start
```

**Предварительный просмотр (dry-run):**
```bash
sudo ./create-lxc.sh --name test --dry-run
```

## Параметры

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--name` | Имя контейнера | **обязательный** |
| `--id` | ID контейнера (VMID) | автоматически (следующий свободный ≥100) |
| `--cores` | Количество CPU ядер | 1 |
| `--memory` | Память в MB | 2048 (2GB) |
| `--disk` | Размер диска в GB | 8 |
| `--storage` | Хранилище для диска | автоматически (первое доступное) |
| `--template` | Шаблон контейнера | debian-13-standard |
| `--ip` | IP адрес с маской (например: 192.168.1.100/24) | DHCP |
| `--gateway` | Шлюз по умолчанию | не указан (для DHCP) |
| `--nameserver` | DNS сервер | не указан (для DHCP) |
| `--ipv6` | IPv6 адрес с маской | auto (SLAAC) |
| `--bridge` | Сетевой мост | vmbr0 |
| `--password` | Пароль root | генерируется автоматически |
| `--ssh-key` | Путь к публичному SSH ключу | не указан |
| `--unprivileged` | Создать непривилегированный контейнер | true |
| `--features` | Дополнительные возможности | nesting=1,keyctl=1 |
| `--start` | Запустить контейнер после создания | false |
| `--bootstrap` | Выполнить базовую настройку после создания | false |
| `--gpu TYPE` | Проброс GPU: intel, nvidia, amd | не указан |
| `--dry-run` | Показать команды без выполнения | false |

## GPU Passthrough

Скрипт поддерживает автоматический проброс GPU в контейнер для аппаратного ускорения (транскодирование видео, ML).

### Поддерживаемые GPU

| Тип | Описание | Что добавляется в LXC conf |
|-----|----------|---------------------------|
| `intel` | Intel iGPU (VAAPI) | /dev/dri |
| `nvidia` | NVIDIA GPU | /dev/nvidia*, /dev/dri |
| `amd` | AMD GPU | /dev/dri |

### Примеры

```bash
# Контейнер для видеонаблюдения с Intel GPU
sudo ./create-lxc.sh --name shinobi --cores 4 --memory 8192 --disk 40 \
  --gpu intel --start --bootstrap

# Контейнер для ML с NVIDIA GPU
sudo ./create-lxc.sh --name ml-server --cores 8 --memory 16384 --disk 100 \
  --gpu nvidia --start
```

### Проверка GPU в контейнере

**Intel VAAPI:**
```bash
apt install vainfo
vainfo
# Должен показать доступные профили VA-API
```

**NVIDIA:**
```bash
nvidia-smi
# Должен показать информацию о GPU
```

### Требования для NVIDIA

Перед использованием `--gpu nvidia` убедитесь, что:
1. Драйверы NVIDIA установлены на хосте Proxmox
2. Устройства `/dev/nvidia*` существуют на хосте
3. Версии драйверов в контейнере совпадают с версией на хосте

## После создания

После успешного создания контейнера:

1. Контейнер будет создан с указанными параметрами
2. Учетные данные будут сохранены в файл: `proxmox/credentials/<ID>_<NAME>.txt`
3. Будут выведены данные для подключения:
   ```
   ID: 150
   Имя: forgejo-prod
   IP: 192.168.1.100 (или DHCP)
   Пароль root: [сгенерированный или указанный]
   ```

3. Подключение по SSH:
   ```bash
   ssh root@192.168.1.100
   # или если DHCP:
   pct enter 150
   ```

4. Управление контейнером:
   ```bash
   pct start 150      # запустить
   pct stop 150       # остановить
   pct status 150     # статус
   pct enter 150      # войти в консоль
   pct destroy 150    # удалить
   ```

## Шаблоны

Скрипт автоматически проверяет наличие шаблона Debian 13. Если шаблон отсутствует, он будет автоматически загружен из официального репозитория Proxmox.

Доступные шаблоны можно посмотреть командой:
```bash
pveam available | grep debian
```

## Примеры использования

### Создание контейнера для Forgejo
```bash
sudo ./create-lxc.sh \
  --name forgejo \
  --cores 2 \
  --memory 4096 \
  --disk 20 \
  --ip 192.168.1.100/24 \
  --gateway 192.168.1.1 \
  --ssh-key ~/.ssh/id_rsa.pub \
  --start
```

### Создание нескольких контейнеров
```bash
# Контейнер для БД
sudo ./create-lxc.sh --name postgres --cores 2 --memory 4096 --disk 50

# Контейнер для приложения
sudo ./create-lxc.sh --name app --cores 4 --memory 8192 --disk 30

# Контейнер для мониторинга
sudo ./create-lxc.sh --name monitoring --cores 1 --memory 2048 --disk 10
```

## Устранение проблем

### Контейнер не создается
```bash
# Проверьте доступные хранилища
pvesm status

# Проверьте доступные шаблоны
pveam available

# Проверьте занятые ID
qm list && pct list
```

### Проблемы с сетью
```bash
# Проверьте сетевые мосты
ip link show | grep vmbr

# Проверьте конфигурацию сети в контейнере
pct enter <ID>
ip addr show
```

### Шаблон не загружается
```bash
# Обновите список шаблонов
pveam update

# Загрузите шаблон вручную
pveam download local debian-13-standard_13.0-1_amd64.tar.zst
```

## Безопасность

**Рекомендации:**
- Используйте SSH ключи вместо паролей
- Создавайте непривилегированные контейнеры (по умолчанию)
- Используйте статические IP для продакшн окружений
- Регулярно обновляйте контейнеры
- Настройте firewall на хосте Proxmox

## Дополнительная информация

- [Документация Proxmox LXC](https://pve.proxmox.com/wiki/Linux_Container)
- [Proxmox VE API](https://pve.proxmox.com/wiki/Proxmox_VE_API)
