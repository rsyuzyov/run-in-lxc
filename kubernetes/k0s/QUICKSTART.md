# k0s — Быстрый старт

## Single-node

```bash
./install.sh --role single
```

## Controller без workloads

```bash
./install.sh --role controller
```

## Controller с workloads

```bash
./install.sh --role controller+worker
```

## Multi-node кластер

### Controller node

```bash
./install.sh --role controller

# Токен для workers
k0s token create --role worker
```

### Worker nodes

```bash
./install.sh --role worker \
  --token <JOIN_TOKEN>
```

### Дополнительные controllers (HA)

```bash
# На первом controller
k0s token create --role controller

# На дополнительных
./install.sh --role controller \
  --token <CONTROLLER_TOKEN>
```

## С k0sctl (рекомендуется для multi-node)

```bash
# Установка k0sctl
./install.sh --role single --with-k0sctl

# Создание конфигурации
k0sctl init > k0sctl.yaml
# Отредактировать k0sctl.yaml

# Развёртывание кластера
k0sctl apply -c k0sctl.yaml
```

## Проверка

```bash
k0s status
k0s kubectl get nodes
k0s kubectl get pods -A
```

## Kubeconfig

```bash
# Копирование в стандартное место
cp /var/lib/k0s/pki/admin.conf ~/.kube/config

# Или использовать k0s kubectl
k0s kubectl get nodes
```

## Управление токенами

```bash
# Создать токен для worker
k0s token create --role worker

# Создать токен для controller
k0s token create --role controller

# Список токенов
k0s token list
```

## Логи

```bash
journalctl -u k0s -f
```

## Удаление

```bash
./install.sh --uninstall
# или
k0s stop
k0s reset
```

## Сетевые порты

| Порт | Назначение |
|------|------------|
| 6443 | Kubernetes API |
| 9443 | k0s join API |
| 8132 | Konnectivity |
| 2380 | etcd peers |
| 10250 | Kubelet |
| 179 | kube-router BGP |

