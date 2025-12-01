# Syncthing — Быстрый старт

## Установка за 1 минуту

```bash
cd /root/run-in-lxc/syncthing
sudo ./install.sh --gui-password "MyPassword123"
```

Веб-интерфейс: `http://<IP>:8384`

## Сценарии установки

### Личный сервер

```bash
sudo ./install.sh --gui-password "MyPassword"
```

### Слабый ПК / Raspberry Pi

```bash
sudo ./install.sh --low-resources --gui-password "MyPassword"
```

### Корпоративный с SSL

```bash
sudo ./install.sh \
  --gui-password "$(openssl rand -base64 16)" \
  --nginx --ssl \
  --domain sync.company.local \
  --email admin@company.local
```

### Headless (NAS)

```bash
sudo ./install.sh --no-gui --data-dir /mnt/storage/syncthing
```

### Relay-сервер

```bash
sudo ./install.sh --relay
```

## Первые шаги после установки

1. Откройте веб-интерфейс `http://<IP>:8384`
2. Войдите с паролем (пользователь: `admin`)
3. Скопируйте ваш **Device ID** (Действия → Показать ID)
4. На другом устройстве: **Добавить устройство** → вставить ID
5. Создайте папку для синхронизации
6. Поделитесь папкой с добавленным устройством

## Управление

```bash
# Статус
sudo systemctl status syncthing

# Перезапуск
sudo systemctl restart syncthing

# Логи
sudo journalctl -u syncthing -f
```

## Порты (файрвол)

```bash
sudo ufw allow 8384/tcp   # GUI
sudo ufw allow 22000      # Синхронизация
sudo ufw allow 21027/udp  # Обнаружение
```

## Лимиты по ресурсам

| RAM | Устройств | Файлов |
|-----|-----------|--------|
| 256 MB | 3-5 | 10 000 |
| 512 MB | 5-10 | 50 000 |
| 1 GB | 10-20 | 200 000 |
| 2 GB | 20-50 | 500 000 |

## Файлы

| Путь | Описание |
|------|----------|
| `/var/lib/syncthing/config.xml` | Конфигурация |
| `/var/lib/syncthing/credentials/info.txt` | Учётные данные |

## Подробнее

См. [README.md](README.md)

