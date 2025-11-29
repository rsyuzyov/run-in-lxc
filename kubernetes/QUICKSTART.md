# Kubernetes — Быстрый старт

## Выбор дистрибутива

| Сценарий | Рекомендация |
|----------|--------------|
| Dev/Test, single-node | K3s |
| Production, multi-node | k0s |
| Edge/IoT | K3s |
| Windows workers | k0s |

## Вариант 1: K3s Single-node

```bash
# На хосте Proxmox: создать LXC
cd kubernetes/common
./prepare-lxc.sh --create --name k3s --memory 4096

# В контейнере: установка
cd kubernetes/k3s
./install.sh --mode single

# Проверка
kubectl get nodes
kubectl get pods -A
```

## Вариант 2: k0s Single-node

```bash
# На хосте Proxmox: создать LXC
cd kubernetes/common
./prepare-lxc.sh --create --name k0s --memory 4096

# В контейнере: установка
cd kubernetes/k0s
./install.sh --role single

# Проверка
k0s kubectl get nodes
```

## Multi-node кластер (K3s)

```bash
# Master node
./install.sh --mode server --cluster-init

# Получить токен
TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)

# Worker nodes (на каждом)
./install.sh --mode agent \
  --server https://<MASTER_IP>:6443 \
  --token $TOKEN
```

## Multi-node кластер (k0s)

```bash
# Controller
./install.sh --role controller

# Получить токен
k0s token create --role worker > /tmp/worker-token

# Workers (на каждом)
./install.sh --role worker --token "$(cat /tmp/worker-token)"
```

## Установка Addons

```bash
cd kubernetes/common/addons

# Helm
./install-helm.sh

# MetalLB (LoadBalancer)
./install-metallb.sh --address-pool 192.168.1.200-192.168.1.220

# Longhorn (Storage)
./install-longhorn.sh --replicas 1  # для single-node
```

## Проверка работы

```bash
# Развернуть тестовое приложение
kubectl apply -f kubernetes/examples/nginx-deployment.yaml

# Проверить
kubectl get pods -n demo
kubectl get svc -n demo

# Доступ через NodePort
curl http://<NODE_IP>:30080
```

## Полезные команды

```bash
# K3s
kubectl get nodes
kubectl get pods -A
k3s check-config
journalctl -u k3s -f

# k0s
k0s kubectl get nodes
k0s status
k0s token create --role worker
journalctl -u k0s -f
```

## Удаление

```bash
# K3s
/usr/local/bin/k3s-uninstall.sh

# k0s
./install.sh --uninstall
```

