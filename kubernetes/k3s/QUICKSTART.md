# K3s — Быстрый старт

## Single-node (всё в одном)

```bash
./install.sh --mode single
```

## Без встроенных компонентов

```bash
# Без Traefik (для своего Ingress)
./install.sh --mode single --disable-traefik

# Без ServiceLB (для MetalLB)
./install.sh --mode single --disable-traefik --disable-servicelb
```

## Multi-node кластер

### Master node

```bash
./install.sh --mode server --cluster-init

# Токен для workers
cat /var/lib/rancher/k3s/server/node-token
```

### Worker nodes

```bash
./install.sh --mode agent \
  --server https://<MASTER_IP>:6443 \
  --token <TOKEN>
```

### Дополнительные masters (HA)

```bash
./install.sh --mode server \
  --server https://<FIRST_MASTER_IP>:6443 \
  --token <TOKEN>
```

## Проверка

```bash
kubectl get nodes
kubectl get pods -A
k3s check-config
```

## Kubeconfig

```bash
# Для локального использования
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Для удалённого доступа
scp root@<IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Изменить server: на внешний IP
```

## Логи

```bash
journalctl -u k3s -f
```

## Удаление

```bash
/usr/local/bin/k3s-uninstall.sh
# или для agent
/usr/local/bin/k3s-agent-uninstall.sh
```

## Сетевые порты

| Порт | Назначение |
|------|------------|
| 6443 | Kubernetes API |
| 8472/udp | Flannel VXLAN |
| 10250 | Kubelet |
| 2379-2380 | etcd (HA) |

