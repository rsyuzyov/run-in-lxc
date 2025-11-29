# k0s — Zero Friction Kubernetes

k0s — это сертифицированный CNCF дистрибутив Kubernetes от Mirantis с нулевыми зависимостями. Отличается изолированным control plane и встроенным механизмом автообновления (Autopilot).

## Особенности

- **Единый статический бинарник** ~170MB
- **Zero dependencies** — не требует systemd (может работать под supervisord)
- **Изолированный control plane** — control plane отделён от worker
- **Autopilot** — встроенный механизм автообновления кластера
- **k0sctl** — декларативный инструмент для управления кластером
- **Windows workers** — поддержка Windows узлов
- **Встроенные компоненты:**
  - containerd
  - kube-router (CNI)
  - CoreDNS
  - etcd / SQLite

## Требования

### Минимальные

| Компонент | Требование |
|-----------|------------|
| CPU | 1 ядро |
| RAM | 1 GB (controller), 500 MB (worker) |
| Диск | 10 GB |
| ОС | Linux (x86_64, arm64, armv7) |

### Рекомендуемые (production)

| Компонент | Controller | Worker |
|-----------|------------|--------|
| CPU | 4 ядра | 2+ ядра |
| RAM | 4 GB | 2+ GB |
| Диск | 50+ GB SSD | 20+ GB |

## Установка

### Single-node (development)

```bash
./install.sh --role single
```

Устанавливает k0s с controller и worker на одном узле.

### Controller + Workers (production)

```bash
# На controller node
./install.sh --role controller

# Создать токен для workers
k0s token create --role worker

# На worker nodes
./install.sh --role worker --token <TOKEN>
```

### Controller с workloads

```bash
# Controller, который также запускает поды
./install.sh --role controller+worker
```

### HA кластер (3+ controllers)

```bash
# Первый controller
./install.sh --role controller --with-k0sctl

# Создать токен для дополнительных controllers
k0s token create --role controller

# Дополнительные controllers
./install.sh --role controller --token <TOKEN>

# Workers
./install.sh --role worker --token <WORKER_TOKEN>
```

## Опции установки

### Роли

| Опция | Описание |
|-------|----------|
| `--role single` | Single-node (controller + worker) |
| `--role controller` | Только control plane |
| `--role controller+worker` | Control plane + workloads |
| `--role worker` | Только worker |

### Кластер

| Опция | Описание |
|-------|----------|
| `--token TOKEN` | Токен для подключения |
| `--config PATH` | Путь к k0s.yaml |
| `--no-taints` | Не применять taints (разрешить workloads) |
| `--with-k0sctl` | Установить k0sctl |

## Конфигурация

### Файлы

| Путь | Описание |
|------|----------|
| `/etc/k0s/k0s.yaml` | Конфигурация k0s |
| `/var/lib/k0s/pki/admin.conf` | kubeconfig |
| `/var/lib/k0s/` | Данные k0s |

### Пример k0s.yaml

```yaml
apiVersion: k0s.k0sproject.io/v1beta1
kind: ClusterConfig
metadata:
  name: my-cluster
spec:
  api:
    address: 192.168.1.100
    sans:
      - k8s.example.com
  network:
    provider: kube-router
    podCIDR: 10.244.0.0/16
    serviceCIDR: 10.96.0.0/12
  storage:
    type: etcd
```

### Генерация конфигурации

```bash
# Дефолтная конфигурация
k0s config create > /etc/k0s/k0s.yaml

# Валидация
k0s config validate --config /etc/k0s/k0s.yaml
```

## k0sctl — Управление кластером

k0sctl — декларативный инструмент для развёртывания и управления кластером.

### Установка

```bash
./install.sh --role single --with-k0sctl
```

### Пример k0sctl.yaml

```yaml
apiVersion: k0sctl.k0sproject.io/v1beta1
kind: Cluster
metadata:
  name: my-cluster
spec:
  hosts:
    - role: controller+worker
      ssh:
        address: 192.168.1.100
        user: root
        keyPath: ~/.ssh/id_rsa
    - role: worker
      ssh:
        address: 192.168.1.101
        user: root
        keyPath: ~/.ssh/id_rsa
    - role: worker
      ssh:
        address: 192.168.1.102
        user: root
        keyPath: ~/.ssh/id_rsa
  k0s:
    version: "1.30.0+k0s.0"
```

### Команды k0sctl

```bash
# Инициализация конфигурации
k0sctl init > k0sctl.yaml

# Развёртывание кластера
k0sctl apply -c k0sctl.yaml

# Получение kubeconfig
k0sctl kubeconfig -c k0sctl.yaml > kubeconfig

# Сброс кластера
k0sctl reset -c k0sctl.yaml
```

## Управление

### Команды k0s

```bash
# Статус
k0s status

# Версия
k0s version

# Список узлов
k0s kubectl get nodes

# Все поды
k0s kubectl get pods -A
```

### Токены

```bash
# Создать токен для worker
k0s token create --role worker

# Создать токен для controller
k0s token create --role controller

# Токен с истечением
k0s token create --role worker --expiry 24h

# Список токенов
k0s token list

# Удалить токен
k0s token invalidate <token-id>
```

### Сервис

```bash
# Статус
systemctl status k0s

# Перезапуск
systemctl restart k0s

# Логи
journalctl -u k0s -f
```

## Autopilot — Автообновление

k0s включает Autopilot для автоматического обновления кластера.

### Пример UpdateConfig

```yaml
apiVersion: autopilot.k0sproject.io/v1beta2
kind: UpdateConfig
metadata:
  name: update-config
spec:
  channel: stable
  updateServer: https://updates.k0sproject.io
  upgradeStrategy:
    type: periodic
    periodic:
      cron: "0 3 * * *"  # 3:00 каждый день
```

### Применение

```bash
kubectl apply -f update-config.yaml
```

## Сетевые порты

### Controller

| Порт | Протокол | Описание |
|------|----------|----------|
| 6443 | TCP | Kubernetes API |
| 9443 | TCP | k0s join API |
| 8132 | TCP | Konnectivity |
| 2380 | TCP | etcd peers |

### Worker

| Порт | Протокол | Описание |
|------|----------|----------|
| 10250 | TCP | Kubelet |
| 179 | TCP | kube-router BGP |
| 4789 | UDP | VXLAN overlay |
| 30000-32767 | TCP/UDP | NodePort Services |

## Резервное копирование

### Backup etcd

```bash
# Создание backup
k0s backup --save-path /backup/

# Восстановление
k0s restore /backup/k0s_backup_xxx.tar.gz
```

### Backup с k0sctl

```bash
k0sctl backup -c k0sctl.yaml
```

## Удаление

```bash
# Через скрипт
./install.sh --uninstall

# Или вручную
k0s stop
k0s reset
rm -rf /var/lib/k0s /etc/k0s
rm /usr/local/bin/k0s
```

## Устранение неполадок

### k0s не запускается

```bash
# Проверка статуса
k0s status

# Логи
journalctl -u k0s -n 100

# Debug режим
k0s controller --debug
```

### Проблемы с сетью

```bash
# Проверка kube-router
k0s kubectl get pods -n kube-system | grep kube-router

# Проверка DNS
k0s kubectl run test --image=busybox --rm -it -- nslookup kubernetes
```

### Проблемы в LXC

Убедитесь, что контейнер подготовлен:
```bash
# На хосте Proxmox
./prepare-lxc.sh --ctid <ID>
```

## Сравнение с K3s

| Параметр | k0s | K3s |
|----------|-----|-----|
| Размер | ~170MB | ~60MB |
| Изоляция CP | Да | Нет |
| Autopilot | Встроен | Внешний |
| Windows | Да | Частично |
| Helm controller | Нет | Встроен |
| Traefik | Нет | Встроен |

## Ссылки

- [Документация k0s](https://docs.k0sproject.io/)
- [GitHub k0s](https://github.com/k0sproject/k0s)
- [GitHub k0sctl](https://github.com/k0sproject/k0sctl)
- [Mirantis](https://www.mirantis.com/software/k0s/)

