# K3s — Легковесный Kubernetes

K3s — это сертифицированный CNCF легковесный дистрибутив Kubernetes от Rancher (SUSE). Идеально подходит для edge, IoT, разработки и небольших production окружений.

## Особенности

- **Единый бинарник** ~60MB
- **Минимальные требования:** 512MB RAM, 1 CPU
- **Встроенные компоненты:**
  - containerd (container runtime)
  - Flannel (CNI)
  - CoreDNS
  - Traefik (Ingress)
  - Klipper (LoadBalancer)
  - Local Path Provisioner (Storage)
  - Metrics Server
- **SQLite** для single-node, **etcd** для HA

## Требования

### Минимальные

| Компонент | Требование |
|-----------|------------|
| CPU | 1 ядро |
| RAM | 512 MB (server), 256 MB (agent) |
| Диск | 10 GB |
| ОС | Linux (x86_64, arm64, armv7) |

### Рекомендуемые (production)

| Компонент | Server | Agent |
|-----------|--------|-------|
| CPU | 2+ ядра | 2+ ядра |
| RAM | 4+ GB | 2+ GB |
| Диск | 40+ GB SSD | 20+ GB |

## Установка

### Single-node (development)

```bash
./install.sh --mode single
```

Устанавливает K3s с control plane и worker на одном узле. Все компоненты включены.

### Server + Agents (production)

```bash
# На master node
./install.sh --mode server --cluster-init

# Получить токен
cat /var/lib/rancher/k3s/server/node-token

# На worker nodes
./install.sh --mode agent \
  --server https://<MASTER_IP>:6443 \
  --token <TOKEN>
```

### HA кластер (3+ masters)

```bash
# Первый master
./install.sh --mode server --cluster-init --tls-san k8s.example.com

# Дополнительные masters
./install.sh --mode server \
  --server https://<FIRST_MASTER_IP>:6443 \
  --token <TOKEN>

# Workers
./install.sh --mode agent \
  --server https://k8s.example.com:6443 \
  --token <TOKEN>
```

## Опции установки

### Режимы

| Опция | Описание |
|-------|----------|
| `--mode single` | Single-node (control + worker) |
| `--mode server` | Только control plane |
| `--mode agent` | Только worker |

### Кластер

| Опция | Описание |
|-------|----------|
| `--cluster-init` | Инициализация HA кластера (etcd) |
| `--server URL` | URL master для agent |
| `--token TOKEN` | Токен для подключения |
| `--node-name NAME` | Имя узла |
| `--tls-san NAMES` | Дополнительные SAN для TLS |

### Компоненты

| Опция | Описание |
|-------|----------|
| `--disable-traefik` | Не устанавливать Traefik |
| `--disable-servicelb` | Не устанавливать Klipper LB |
| `--disable-local-storage` | Не устанавливать Local Path |
| `--disable-metrics-server` | Не устанавливать Metrics Server |
| `--flannel-backend TYPE` | Backend: vxlan, host-gw, wireguard-native |

## Конфигурация

### Файлы

| Путь | Описание |
|------|----------|
| `/etc/rancher/k3s/k3s.yaml` | kubeconfig |
| `/var/lib/rancher/k3s/server/node-token` | Токен для agents |
| `/var/lib/rancher/k3s/` | Данные K3s |

### Переменные окружения

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### Конфигурационный файл

Создайте `/etc/rancher/k3s/config.yaml`:

```yaml
write-kubeconfig-mode: "644"
tls-san:
  - "k8s.example.com"
  - "192.168.1.100"
disable:
  - traefik
  - servicelb
flannel-backend: "vxlan"
```

## Управление

### Команды

```bash
# Список узлов
kubectl get nodes

# Все поды
kubectl get pods -A

# Проверка конфигурации
k3s check-config

# Версия
k3s --version
```

### Сервис

```bash
# Статус
systemctl status k3s
# или для agent
systemctl status k3s-agent

# Перезапуск
systemctl restart k3s

# Логи
journalctl -u k3s -f
```

## Helm Controller

K3s включает встроенный Helm Controller. Создайте `HelmChart` ресурс:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: nginx
  namespace: kube-system
spec:
  repo: https://charts.bitnami.com/bitnami
  chart: nginx
  targetNamespace: default
  valuesContent: |-
    replicaCount: 2
```

## Traefik Ingress

K3s включает Traefik 2.x. Пример Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Local Path Provisioner

K3s включает Local Path Provisioner для PersistentVolumes:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 1Gi
```

Данные хранятся в `/var/lib/rancher/k3s/storage/`.

## Сетевые порты

### Server (Master)

| Порт | Протокол | Описание |
|------|----------|----------|
| 6443 | TCP | Kubernetes API |
| 2379-2380 | TCP | etcd (HA) |
| 10250 | TCP | Kubelet metrics |
| 8472 | UDP | Flannel VXLAN |

### Agent (Worker)

| Порт | Протокол | Описание |
|------|----------|----------|
| 10250 | TCP | Kubelet metrics |
| 8472 | UDP | Flannel VXLAN |
| 30000-32767 | TCP/UDP | NodePort Services |

## Обновление

```bash
# Загрузка новой версии
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.30.0+k3s1 sh -

# Проверка
k3s --version
kubectl get nodes
```

## Резервное копирование

### Backup etcd (HA кластер)

```bash
# Создание snapshot
k3s etcd-snapshot save --name backup-$(date +%Y%m%d)

# Список snapshots
k3s etcd-snapshot ls

# Восстановление
k3s server --cluster-reset --cluster-reset-restore-path=/path/to/snapshot
```

### Backup SQLite (single-node)

```bash
# Остановка K3s
systemctl stop k3s

# Копирование данных
cp -r /var/lib/rancher/k3s/server/db /backup/

# Запуск
systemctl start k3s
```

## Удаление

```bash
# Server
/usr/local/bin/k3s-uninstall.sh

# Agent
/usr/local/bin/k3s-agent-uninstall.sh
```

## Устранение неполадок

### K3s не запускается

```bash
# Проверка логов
journalctl -u k3s -n 100

# Проверка конфигурации
k3s check-config
```

### Проблемы с сетью

```bash
# Проверка Flannel
kubectl get pods -n kube-system | grep flannel

# Проверка DNS
kubectl run test --image=busybox --rm -it -- nslookup kubernetes
```

### Проблемы в LXC

Убедитесь, что контейнер подготовлен:
```bash
# На хосте Proxmox
./prepare-lxc.sh --ctid <ID>
```

## Ссылки

- [Документация K3s](https://docs.k3s.io/)
- [GitHub K3s](https://github.com/k3s-io/k3s)
- [Rancher K3s](https://www.rancher.com/products/k3s)

