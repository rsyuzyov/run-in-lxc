# Docker — Быстрый старт

## Установка за 1 минуту

```bash
cd run-in-lxc/docker
sudo ./install.sh
```

## С зеркалом (быстрее)

```bash
sudo ./install.sh --mirror https://mirror.gcr.io
```

## Проверка

```bash
docker run --rm hello-world
```

## Частые команды

```bash
docker ps                    # список контейнеров
docker images                # список образов
docker run -d nginx          # запуск nginx в фоне
docker stop <id>             # остановка
docker logs <id>             # логи
docker compose up -d         # запуск из docker-compose.yml
```

## Конфигурация

```bash
# Редактирование
sudo nano /etc/docker/daemon.json

# Применение
sudo systemctl restart docker
```

## Проблемы?

```bash
# Проверка совместимости LXC
sudo ./install.sh --check

# Логи Docker
journalctl -u docker -f
```

