# MotionEye — Быстрый старт

## Установка за 1 минуту

```bash
cd /root/run-in-lxc/motioneye
sudo ./install.sh
```

## Веб-интерфейс

```
http://<IP>:8765
Логин: admin
Пароль: (пустой)
```

⚠️ **Сразу установите пароль!**

## Примеры установки

```bash
# Базовая
./install.sh

# С часовым поясом
./install.sh --timezone Europe/Moscow

# С NFS-хранилищем
./install.sh --nfs-mount 192.168.1.100:/recordings

# Кастомный порт
./install.sh --port 8080
```

## Добавление камеры

1. Меню слева → **Add Camera**
2. Тип: **Network Camera**
3. URL:
   ```
   rtsp://user:pass@192.168.1.50:554/stream1
   ```

## Управление

```bash
systemctl status motioneye     # статус
systemctl restart motioneye    # перезапуск
journalctl -u motioneye -f     # логи
```

## USB-камеры в LXC

На хосте Proxmox в `/etc/pve/lxc/<ID>.conf`:

```
lxc.cgroup2.devices.allow: c 81:* rwm
lxc.mount.entry: /dev/video0 dev/video0 none bind,optional,create=file
```

Перезапустить контейнер: `pct restart <ID>`

## NFS-хранилище

```bash
apt install nfs-common
mkdir -p /mnt/recordings
mount -t nfs 192.168.1.100:/recordings /mnt/recordings

# Автомонтирование
echo "192.168.1.100:/recordings /mnt/recordings nfs defaults,_netdev 0 0" >> /etc/fstab
```

## Обновление

```bash
pipx upgrade motioneye
systemctl restart motioneye
```

## Пути

| Что | Где |
|-----|-----|
| Конфиг | `/etc/motioneye/motioneye.conf` |
| Камеры | `/etc/motioneye/camera-*.conf` |
| Логи | `/var/log/motioneye/` |
| Записи | `/var/lib/motioneye/` или NFS |

## Рекомендуемые ресурсы LXC

- **CPU:** 2 vCPU
- **RAM:** 2 GB
- **Диск:** 8 GB (+ хранилище для записей)

