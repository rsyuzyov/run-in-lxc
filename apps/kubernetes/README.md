# Kubernetes в LXC/VM

Этот раздел содержит скрипты и инструкции для развёртывания Kubernetes кластеров в Proxmox VE.

## Обзор

Полноценный Kubernetes (kubeadm) не работает в стандартных LXC контейнерах из-за ограничений:
- Неполный доступ к cgroups
- Ограниченные capabilities
- Конфликты с AppArmor/seccomp

**Решение:** использовать легковесные дистрибутивы K3s или k0s, которые могут работать в privileged LXC с дополнительными настройками. Для production рекомендуется использовать VM.

## Выбор дистрибутива

### K3s vs k0s — сравнение

| Параметр | K3s | k0s |
|----------|-----|-----|
| **Разработчик** | Rancher (SUSE) | Mirantis |
| **Размер бинарника** | ~60 MB | ~170 MB |
| **RAM (control plane)** | ~512 MB | ~300 MB |
| **База данных** | SQLite / etcd / PostgreSQL | etcd / SQLite |
| **CNI по умолчанию** | Flannel | kube-router |
| **Ingress** | Traefik (встроен) | Нет (ставится отдельно) |
| **Helm controller** | Встроен | Нет |
| **Service LB** | Klipper (встроен) | Нет |
| **Автообновление** | System Upgrade Controller | Autopilot (встроен) |
| **Windows workers** | Экспериментально | Да |
| **Изоляция control plane** | Нет (всё в одном процессе) | Да (отдельный процесс) |

### Когда использовать K3s

✅ **Рекомендуется для:**
- Разработки и тестирования
- Edge/IoT устройств
- Single-node кластеров
- Быстрого старта (всё включено из коробки)
- CI/CD окружений

### Когда использовать k0s

✅ **Рекомендуется для:**
- Production окружений
- Multi-node кластеров с HA
- Сценариев с изолированным control plane
- Автоматизированных обновлений (Autopilot)
- Смешанных кластеров (Linux + Windows workers)

## Структура раздела

```
kubernetes/
├── README.md              # Этот файл
├── QUICKSTART.md          # Быстрый старт
├── k3s/                   # K3s дистрибутив
│   ├── install.sh         # Скрипт установки
│   ├── README.md          # Документация
│   ├── QUICKSTART.md      # Шпаргалка
│   └── config/            # Примеры конфигурации
├── k0s/                   # k0s дистрибутив
│   ├── install.sh         # Скрипт установки
│   ├── README.md          # Документация
│   ├── QUICKSTART.md      # Шпаргалка
│   └── config/            # Примеры конфигурации
├── common/                # Общие утилиты
│   ├── prepare-lxc.sh     # Подготовка LXC для k8s
│   └── addons/            # Дополнительные компоненты
│       ├── install-helm.sh
│       ├── install-metallb.sh
│       └── install-longhorn.sh
└── examples/              # Примеры workloads
    ├── nginx-deployment.yaml
    ├── postgres-statefulset.yaml
    └── ingress-example.yaml
```

## Требования

### Минимальные ресурсы

| Роль | CPU | RAM | Диск |
|------|-----|-----|------|
| Control plane (single) | 2 | 2 GB | 20 GB |
| Control plane (HA) | 2 | 4 GB | 40 GB |
| Worker node | 2 | 2 GB | 20 GB |
| Single-node (control+worker) | 2 | 4 GB | 40 GB |

### Рекомендуемые ресурсы (production)

| Роль | CPU | RAM | Диск |
|------|-----|-----|------|
| Control plane | 4 | 8 GB | 100 GB SSD |
| Worker node | 4+ | 8+ GB | 100+ GB SSD |

## Быстрый старт

### Вариант 1: LXC (dev/test)

```bash
# 1. На хосте Proxmox: подготовка LXC
cd kubernetes/common
./prepare-lxc.sh --create --name k8s-master --memory 4096 --cores 2

# 2. В контейнере: установка K3s
ssh root@<IP>
cd run-in-lxc/kubernetes/k3s
./install.sh --mode single

# 3. Проверка
kubectl get nodes
```

### Вариант 2: VM (production)

```bash
# 1. Создать VM в Proxmox (Ubuntu 22.04/24.04 или Debian 12)
# Минимум: 4 GB RAM, 2 CPU, 40 GB диск

# 2. В VM: установка k0s
cd run-in-lxc/kubernetes/k0s
./install.sh --role single

# 3. Проверка
k0s kubectl get nodes
```

### Multi-node кластер (K3s)

```bash
# Master node
./install.sh --mode server --cluster-init

# Получить токен
cat /var/lib/rancher/k3s/server/node-token

# Worker nodes
./install.sh --mode agent \
  --server https://<MASTER_IP>:6443 \
  --token <TOKEN>
```

### Multi-node кластер (k0s)

```bash
# Controller node
./install.sh --role controller

# Получить токен
k0s token create --role worker

# Worker nodes
./install.sh --role worker \
  --controller https://<CONTROLLER_IP>:6443 \
  --token <TOKEN>
```

## Дополнительные компоненты (Addons)

После установки кластера можно добавить:

```bash
cd kubernetes/common/addons

# Helm — менеджер пакетов
./install-helm.sh

# MetalLB — LoadBalancer для bare-metal
./install-metallb.sh --address-pool 192.168.1.200-192.168.1.220

# Longhorn — распределённое хранилище
./install-longhorn.sh
```

## LXC vs VM — рекомендации

| Сценарий | Рекомендация |
|----------|--------------|
| Разработка/тестирование | LXC (privileged) |
| CI/CD runners | LXC (privileged) |
| Staging | VM |
| Production single-node | VM |
| Production multi-node | VM |
| Edge/IoT | LXC или bare-metal |

### Ограничения LXC

При запуске Kubernetes в LXC контейнерах:

⚠️ **Работает с ограничениями:**
- Flannel, kube-router, Calico (VXLAN mode)
- Большинство workloads

❌ **Не работает или нестабильно:**
- Cilium (требует BPF)
- Calico (BGP mode)
- Некоторые CSI драйверы
- eBPF-based функции

## Сетевые требования

### Порты для control plane

| Порт | Протокол | Назначение |
|------|----------|------------|
| 6443 | TCP | Kubernetes API |
| 2379-2380 | TCP | etcd (HA) |
| 10250 | TCP | Kubelet API |
| 10251 | TCP | kube-scheduler |
| 10252 | TCP | kube-controller-manager |

### Порты для worker nodes

| Порт | Протокол | Назначение |
|------|----------|------------|
| 10250 | TCP | Kubelet API |
| 30000-32767 | TCP/UDP | NodePort Services |

### Порты для overlay сети

| CNI | Порт | Протокол |
|-----|------|----------|
| Flannel VXLAN | 8472 | UDP |
| Calico VXLAN | 4789 | UDP |
| kube-router | 20244 | TCP |

## Документация

- [K3s](k3s/README.md) — подробная документация по K3s
- [k0s](k0s/README.md) — подробная документация по k0s
- [Подготовка LXC](common/README.md) — настройка LXC для Kubernetes
- [Addons](common/addons/README.md) — дополнительные компоненты

## Полезные ссылки

- [K3s Documentation](https://docs.k3s.io/)
- [k0s Documentation](https://docs.k0sproject.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Proxmox VE Wiki](https://pve.proxmox.com/wiki/)

