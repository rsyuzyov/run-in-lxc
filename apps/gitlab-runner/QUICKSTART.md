# Шпаргалка по установке GitLab Runner

## Быстрая установка

### Вариант 1: Shell executor (простейший)

```bash
cd /root/run-in-lxc/gitlab-runner
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor shell
```

**Что произойдет:**
- ✅ Установится GitLab Runner
- ✅ Зарегистрируется на GitLab сервере
- ✅ Запустится как systemd сервис

---

### Вариант 2: Docker executor

```bash
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor docker \
  --docker-image alpine:latest \
  --install-docker
```

**Что произойдет:**
- ✅ Установится Docker
- ✅ Установится GitLab Runner
- ✅ Каждый job будет в изолированном контейнере

---

### Вариант 3: Docker-in-Docker (для сборки образов)

```bash
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor docker \
  --docker-image docker:latest \
  --docker-privileged \
  --install-docker
```

---

## Где взять токен?

### Instance Runner (для всего GitLab)
```
Admin Area → CI/CD → Runners → "Register an instance runner"
```

### Group Runner (для группы)
```
Группа → Settings → CI/CD → Runners → Expand → Скопировать токен
```

### Project Runner (для проекта)
```
Проект → Settings → CI/CD → Runners → Expand → Скопировать токен
```

---

## Управление после установки

### Проверка статуса

```bash
sudo gitlab-runner status
sudo gitlab-runner list
```

### Проверка связи с GitLab

```bash
sudo gitlab-runner verify
```

### Перезапуск

```bash
sudo systemctl restart gitlab-runner
```

### Просмотр логов

```bash
sudo journalctl -u gitlab-runner -f
```

---

## Важные пути

| Что | Где |
|-----|-----|
| Конфигурация | `/etc/gitlab-runner/config.toml` |
| Домашняя директория | `/home/gitlab-runner/` |
| Кэш (если настроен) | `/cache/` |

---

## Настройка параллельных задач

```bash
sudo nano /etc/gitlab-runner/config.toml
```

```toml
concurrent = 4  # Количество параллельных задач
```

```bash
sudo systemctl restart gitlab-runner
```

---

## Добавление тегов

При установке:
```bash
sudo ./install.sh \
  --url https://gitlab.example.com \
  --token glrt-XXXX \
  --executor docker \
  --tags "docker,linux,build"
```

Использование в `.gitlab-ci.yml`:
```yaml
build:
  tags:
    - docker
    - linux
  script:
    - make build
```

---

## Регистрация дополнительного Runner'а

```bash
sudo gitlab-runner register \
  --url https://gitlab.example.com \
  --token glrt-XXXXXXXXXXXXXXXXXXXX \
  --executor shell \
  --tag-list "deploy,production"
```

---

## Docker в LXC

Для работы Docker в LXC контейнере добавьте в `/etc/pve/lxc/<ID>.conf`:

```conf
features: nesting=1
```

Проверка:
```bash
docker run --rm hello-world
```

---

## Пример .gitlab-ci.yml

```yaml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  tags:
    - docker
  image: node:18
  script:
    - npm install
    - npm run build
  artifacts:
    paths:
      - dist/

test:
  stage: test
  tags:
    - docker
  image: node:18
  script:
    - npm test

deploy:
  stage: deploy
  tags:
    - shell
  script:
    - ./deploy.sh
  only:
    - main
```

---

## Решение проблем

### Runner не появляется в GitLab

```bash
sudo gitlab-runner verify
sudo cat /etc/gitlab-runner/config.toml
```

### Docker permission denied

```bash
sudo usermod -aG docker gitlab-runner
sudo systemctl restart gitlab-runner
```

### Job зависает

```bash
# Проверьте логи
sudo journalctl -u gitlab-runner -n 100

# Debug режим
sudo gitlab-runner --debug run
```

---

## Отмена регистрации

```bash
# Удалить конкретный Runner
sudo gitlab-runner unregister --name "Runner Name"

# Удалить все
sudo gitlab-runner unregister --all-runners
```

---

## Удаление

```bash
# Отмена регистрации
sudo gitlab-runner unregister --all-runners

# Остановка и удаление
sudo systemctl stop gitlab-runner
sudo apt-get remove --purge gitlab-runner
sudo rm -rf /etc/gitlab-runner
```

