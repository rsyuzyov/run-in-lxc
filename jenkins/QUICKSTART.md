# Jenkins Quick Start

Шпаргалка по установке и настройке Jenkins в LXC.

## Системные требования

- **CPU**: 4+ ядра
- **RAM**: 4+ GB
- **Диск**: 20+ GB
- **ОС**: Debian 12 / Ubuntu 22.04+

## Установка контроллера

### Минимальная

```bash
sudo ./install.sh
```

### С Nginx и SSL

```bash
sudo ./install.sh \
  --with-nginx \
  --domain jenkins.example.com \
  --letsencrypt \
  --email admin@example.com
```

### С JCasC

```bash
sudo ./install.sh \
  --jcasc \
  --jcasc-file config/jenkins.yaml \
  --plugins config/plugins.txt
```

## Установка агента

### Inbound (JNLP)

```bash
sudo ./install-agent.sh \
  --url https://jenkins.example.com \
  --name agent-01 \
  --secret СЕКРЕТ_ИЗ_JENKINS
```

### SSH агент

```bash
sudo ./install-agent.sh --mode ssh --ssh-key
```

### С Docker

```bash
sudo ./install-agent.sh \
  --url https://jenkins.example.com \
  --name docker-agent \
  --secret СЕКРЕТ \
  --install-docker \
  --labels "docker,linux"
```

## После установки

### Initial Admin Password

```bash
cat /var/lib/jenkins/secrets/initialAdminPassword
```

### Учётные данные

```bash
cat /root/jenkins-credentials/admin.txt
```

## Управление

```bash
# Статус
sudo systemctl status jenkins

# Перезапуск
sudo systemctl restart jenkins

# Логи
sudo journalctl -u jenkins -f
```

## Файлы

| Что | Путь |
|-----|------|
| Home | `/var/lib/jenkins/` |
| Jobs | `/var/lib/jenkins/jobs/` |
| Plugins | `/var/lib/jenkins/plugins/` |
| JCasC | `/var/lib/jenkins/casc_configs/` |
| Logs | `/var/log/jenkins/` |

## Пример Jenkinsfile

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
                sh 'make build'
            }
        }
        
        stage('Test') {
            steps {
                echo 'Testing...'
                sh 'make test'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                echo 'Deploying...'
                sh 'make deploy'
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo 'Success!'
        }
        failure {
            echo 'Failed!'
        }
    }
}
```

## Docker Pipeline

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

## GitLab интеграция

```groovy
pipeline {
    agent any
    triggers {
        gitlab(triggerOnPush: true)
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
            updateGitlabCommitStatus state: 'success'
        }
        failure {
            updateGitlabCommitStatus state: 'failed'
        }
    }
}
```

## Forgejo/Gitea Webhook

URL: `https://jenkins.example.com/gitea-webhook/post`

## Prometheus метрики

```bash
curl http://jenkins:8080/prometheus/
```

## CLI

```bash
# Скачать CLI
wget http://jenkins:8080/jnlpJars/jenkins-cli.jar

# Список jobs
java -jar jenkins-cli.jar -s http://jenkins:8080 -auth admin:TOKEN list-jobs

# Запуск job
java -jar jenkins-cli.jar -s http://jenkins:8080 -auth admin:TOKEN build JOB_NAME
```

## Бэкап

```bash
tar -czf jenkins_backup.tar.gz \
  --exclude='workspace' \
  --exclude='caches' \
  /var/lib/jenkins/
```

## Проблемы

### Нехватка памяти

```bash
# /etc/default/jenkins
JAVA_OPTS="-Xmx4g"
sudo systemctl restart jenkins
```

### Агент не подключается

```bash
# Логи агента
journalctl -u jenkins-agent -f

# Проверка сети
curl -I https://jenkins.example.com
```

## Ссылки

- [Документация](https://www.jenkins.io/doc/)
- [Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Плагины](https://plugins.jenkins.io/)

