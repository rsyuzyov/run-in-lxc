# Jenkins в LXC контейнере

Скрипты и инструкции для установки Jenkins CI/CD сервера в LXC контейнер.

## Что такое Jenkins?

Jenkins — это ведущий open-source сервер автоматизации для CI/CD (Continuous Integration / Continuous Delivery). Поддерживает сборку, тестирование и развёртывание программного обеспечения.

### Основные возможности

- **Pipeline as Code** — описание CI/CD процессов в Jenkinsfile
- **Обширная экосистема плагинов** — 1800+ плагинов для интеграций
- **Distributed builds** — распределённые сборки на агентах
- **Configuration as Code (JCasC)** — конфигурация через YAML
- **Blue Ocean** — современный UI для Pipeline

## Системные требования

### Контроллер (сервер)

| Ресурс | Минимум | Рекомендуется |
|--------|---------|---------------|
| CPU | 2 ядра | 4+ ядра |
| RAM | 2 GB | 4+ GB |
| Диск | 10 GB | 20+ GB |
| ОС | Debian 11+ / Ubuntu 20.04+ | Debian 12 / Ubuntu 24.04 |

### Агент

| Ресурс | Минимум | Рекомендуется |
|--------|---------|---------------|
| CPU | 1 ядро | 2+ ядра |
| RAM | 512 MB | 2+ GB |
| Диск | 5 GB | 20+ GB |

## Структура файлов

```
jenkins/
├── install.sh           # Установка контроллера Jenkins
├── install-agent.sh     # Установка агента Jenkins
├── README.md            # Эта документация
├── QUICKSTART.md        # Шпаргалка
└── config/
    ├── jenkins.yaml     # Пример JCasC конфигурации
    └── plugins.txt      # Список рекомендуемых плагинов
```

## Установка контроллера

### Быстрый старт

```bash
cd jenkins
sudo ./install.sh
```

### Параметры установки

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--version` | Версия: lts, weekly, номер | lts |
| `--port` | HTTP порт | 8080 |
| `--admin-password` | Пароль администратора | авто |
| `--java-version` | OpenJDK: 11, 17, 21 | 17 |
| `--with-nginx` | Установить Nginx reverse proxy | нет |
| `--domain` | Доменное имя | нет |
| `--ssl` | Самоподписанный сертификат | нет |
| `--letsencrypt` | Let's Encrypt сертификат | нет |
| `--email` | Email для Let's Encrypt | нет |
| `--plugins` | Файл со списком плагинов | нет |
| `--no-default-plugins` | Не ставить плагины по умолчанию | нет |
| `--prometheus` | Плагин Prometheus metrics | нет |
| `--jcasc` | Включить Configuration as Code | нет |
| `--jcasc-file` | Файл конфигурации JCasC | нет |
| `--check` | Только проверка требований | нет |

### Примеры

#### Базовая установка

```bash
sudo ./install.sh
```

#### С Nginx и самоподписанным SSL

```bash
sudo ./install.sh \
  --with-nginx \
  --domain jenkins.example.com \
  --ssl
```

#### С Let's Encrypt

```bash
sudo ./install.sh \
  --with-nginx \
  --domain jenkins.example.com \
  --letsencrypt \
  --email admin@example.com
```

#### Полная установка с JCasC

```bash
sudo ./install.sh \
  --with-nginx \
  --domain jenkins.example.com \
  --letsencrypt \
  --email admin@example.com \
  --plugins config/plugins.txt \
  --jcasc \
  --jcasc-file config/jenkins.yaml \
  --prometheus
```

#### С конкретной версией

```bash
sudo ./install.sh --version 2.426.3
```

## Установка агента

Jenkins агенты выполняют сборки. Контроллер координирует работу.

### Режимы подключения

| Режим | Описание | Когда использовать |
|-------|----------|-------------------|
| **Inbound (JNLP)** | Агент подключается к контроллеру | Агент за NAT/firewall |
| **SSH** | Контроллер подключается к агенту | Контроллер имеет доступ к агенту |

### Inbound агент

```bash
sudo ./install-agent.sh \
  --url https://jenkins.example.com \
  --name agent-01 \
  --secret xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Где взять секрет:
1. Jenkins → Manage Jenkins → Nodes → New Node
2. Permanent Agent, Launch method: "Launch agent by connecting it to the controller"
3. Сохраните и скопируйте секрет из команды запуска

### SSH агент

```bash
sudo ./install-agent.sh \
  --mode ssh \
  --ssh-key
```

Затем в Jenkins:
1. Manage Jenkins → Nodes → New Node
2. Launch method: "Launch agents via SSH"
3. Добавьте приватный ключ в Credentials

### Параметры агента

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--url` | URL контроллера | обязателен |
| `--name` | Имя агента | обязателен |
| `--secret` | Секрет агента | обязателен |
| `--workdir` | Рабочая директория | /var/lib/jenkins-agent |
| `--java-version` | OpenJDK: 11, 17, 21 | 17 |
| `--labels` | Метки через запятую | нет |
| `--executors` | Количество executor'ов | 2 |
| `--install-docker` | Установить Docker | нет |
| `--mode` | Режим: inbound, ssh | inbound |

### Агент с Docker

```bash
sudo ./install-agent.sh \
  --url https://jenkins.example.com \
  --name docker-agent \
  --secret xxxxxxxx \
  --install-docker \
  --labels "docker,linux,build"
```

## Плагины по умолчанию

При установке автоматически устанавливаются:

### Основные
- **git** — Git интеграция
- **workflow-aggregator** — Pipeline
- **blueocean** — современный UI

### Docker & Kubernetes
- **docker-workflow** — Docker Pipeline
- **docker-plugin** — Docker интеграция
- **kubernetes** — Kubernetes Cloud

### Git хостинги
- **gitlab-plugin** — GitLab интеграция
- **github** — GitHub интеграция
- **gitea** — Gitea/Forgejo интеграция

### Утилиты
- **credentials** — управление секретами
- **timestamper** — метки времени в логах
- **configuration-as-code** — JCasC

Полный список: `config/plugins.txt`

## Configuration as Code (JCasC)

JCasC позволяет настраивать Jenkins через YAML файлы.

### Включение JCasC

```bash
sudo ./install.sh --jcasc --jcasc-file config/jenkins.yaml
```

### Структура конфигурации

```yaml
jenkins:
  systemMessage: "Welcome to Jenkins!"
  numExecutors: 2
  
  securityRealm:
    local:
      users:
        - id: "admin"
          password: "${JENKINS_ADMIN_PASSWORD}"
          
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            permissions:
              - "Overall/Administer"
            entries:
              - user: "admin"

unclassified:
  location:
    url: "https://jenkins.example.com/"

credentials:
  system:
    domainCredentials:
      - credentials:
          - string:
              id: "api-token"
              secret: "${API_TOKEN}"
```

### Переменные окружения

JCasC поддерживает переменные в формате `${VAR_NAME}`:

```bash
export JENKINS_ADMIN_PASSWORD="SecurePass123"
export API_TOKEN="xxx"
systemctl restart jenkins
```

### Расположение конфигурации

```
/var/lib/jenkins/casc_configs/jenkins.yaml
```

## После установки

### Первоначальная настройка

1. Откройте `http://<IP>:8080` (или ваш домен)
2. Введите Initial Admin Password:
   ```bash
   cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
3. Установите рекомендуемые плагины
4. Создайте пользователя администратора

### Управление сервисом

```bash
# Статус
sudo systemctl status jenkins

# Перезапуск
sudo systemctl restart jenkins

# Логи
sudo journalctl -u jenkins -f

# Остановка
sudo systemctl stop jenkins
```

### Расположение файлов

| Что | Где |
|-----|-----|
| Домашняя директория | `/var/lib/jenkins/` |
| Конфигурация | `/var/lib/jenkins/config.xml` |
| Jobs | `/var/lib/jenkins/jobs/` |
| Плагины | `/var/lib/jenkins/plugins/` |
| Логи | `/var/log/jenkins/` |
| JCasC | `/var/lib/jenkins/casc_configs/` |
| Учётные данные | `/root/jenkins-credentials/` |

## Интеграции

### GitLab

1. Установите плагин `gitlab-plugin`
2. Создайте Access Token в GitLab (Scopes: api)
3. Jenkins → Manage Jenkins → System → GitLab
4. Добавьте Connection с токеном

Pipeline с GitLab:
```groovy
pipeline {
    agent any
    triggers {
        gitlab(triggerOnPush: true, triggerOnMergeRequest: true)
    }
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
    }
    post {
        success {
            updateGitlabCommitStatus name: 'build', state: 'success'
        }
        failure {
            updateGitlabCommitStatus name: 'build', state: 'failed'
        }
    }
}
```

### Forgejo / Gitea

1. Установите плагин `gitea`
2. Создайте Access Token в Forgejo
3. Jenkins → Manage Jenkins → System → Gitea Servers
4. Добавьте сервер

Webhook в Forgejo:
- URL: `https://jenkins.example.com/gitea-webhook/post`
- Events: Push, Pull Request

### GitHub

1. Установите плагин `github`
2. Создайте Personal Access Token
3. Jenkins → Manage Jenkins → System → GitHub
4. Добавьте GitHub Server

### Docker

Pipeline с Docker:
```groovy
pipeline {
    agent {
        docker {
            image 'node:20'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'npm install'
                sh 'npm run build'
            }
        }
    }
}
```

### Kubernetes

1. Установите плагин `kubernetes`
2. Jenkins → Manage Jenkins → Clouds → New Cloud → Kubernetes
3. Настройте подключение к кластеру

Pipeline с Kubernetes:
```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3-jdk-17
    command: ['sleep', 'infinity']
'''
        }
    }
    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package'
                }
            }
        }
    }
}
```

## Prometheus метрики

При установке с `--prometheus`:

```bash
sudo ./install.sh --prometheus
```

Метрики доступны по адресу:
```
http://jenkins:8080/prometheus/
```

Пример конфигурации Prometheus:
```yaml
scrape_configs:
  - job_name: 'jenkins'
    metrics_path: '/prometheus/'
    static_configs:
      - targets: ['jenkins:8080']
```

## Резервное копирование

### Что бэкапить

- `/var/lib/jenkins/` — вся конфигурация и jobs
- `/var/lib/jenkins/casc_configs/` — JCasC (если используется)

### Скрипт бэкапа

```bash
#!/bin/bash
BACKUP_DIR="/backup/jenkins"
DATE=$(date +%Y%m%d_%H%M%S)

# Остановка Jenkins (опционально, для консистентности)
# systemctl stop jenkins

# Бэкап
tar -czf "$BACKUP_DIR/jenkins_$DATE.tar.gz" \
  --exclude='/var/lib/jenkins/workspace' \
  --exclude='/var/lib/jenkins/caches' \
  /var/lib/jenkins/

# systemctl start jenkins

# Удаление старых бэкапов (старше 30 дней)
find "$BACKUP_DIR" -name "jenkins_*.tar.gz" -mtime +30 -delete
```

## Обновление

```bash
# Обновление пакета
sudo apt-get update
sudo apt-get install jenkins

# Проверка версии
java -jar /usr/share/java/jenkins.war --version
```

## Безопасность

### Рекомендации

1. **Используйте HTTPS** — `--ssl` или `--letsencrypt`
2. **Настройте авторизацию** — Role-based strategy
3. **Ограничьте executor'ы на контроллере** — установите 0
4. **Используйте агенты** — все сборки на отдельных машинах
5. **Регулярно обновляйте** — Jenkins и плагины
6. **Аудит** — включите логирование

### Настройка CSRF

В `/var/lib/jenkins/jenkins.yaml`:
```yaml
jenkins:
  crumbIssuer:
    standard:
      excludeClientIPFromCrumb: false
```

## Решение проблем

### Jenkins не запускается

```bash
# Проверка логов
sudo journalctl -u jenkins -n 100

# Проверка Java
java -version

# Проверка портов
sudo netstat -tlnp | grep 8080
```

### Нехватка памяти

Увеличьте heap в `/etc/default/jenkins`:
```bash
JAVA_OPTS="-Xmx4g -Xms2g"
```

### Плагины не устанавливаются

```bash
# Проверка сети
curl -I https://updates.jenkins.io

# Ручная установка
wget https://updates.jenkins.io/latest/git.hpi -O /var/lib/jenkins/plugins/git.hpi
chown jenkins:jenkins /var/lib/jenkins/plugins/git.hpi
systemctl restart jenkins
```

### Агент не подключается

```bash
# На агенте: проверка java
java -version

# Проверка сети до контроллера
curl -I https://jenkins.example.com

# Логи агента
journalctl -u jenkins-agent -f
```

## Полезные ссылки

- [Официальная документация](https://www.jenkins.io/doc/)
- [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [JCasC документация](https://www.jenkins.io/projects/jcasc/)
- [Плагины](https://plugins.jenkins.io/)
- [Blue Ocean](https://www.jenkins.io/doc/book/blueocean/)

