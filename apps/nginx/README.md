# Nginx для LXC контейнеров

Скрипт установки Nginx — высокопроизводительного веб-сервера и обратного прокси.

## Быстрый старт

```bash
# Базовая установка Nginx
./install.sh

# Установка с созданием виртуального хоста
./install.sh --domain example.com
```

## Варианты установки

### Стандартная установка

```bash
./install.sh
```

Устанавливает Nginx из официального репозитория с базовой конфигурацией.

### Установка с виртуальным хостом

```bash
./install.sh --domain example.com
```

Создаёт виртуальный хост с базовой конфигурацией для указанного домена.

### Установка с SSL (Let's Encrypt)

```bash
./install.sh --domain example.com --ssl --email admin@example.com
```

Устанавливает Nginx и настраивает SSL-сертификат через Certbot.

## Опции

| Опция | Описание | По умолчанию |
|-------|----------|--------------|
| `--domain DOMAIN` | Создать виртуальный хост для домена | - |
| `--ssl` | Настроить SSL через Let's Encrypt | - |
| `--email EMAIL` | Email для Let's Encrypt | - |
| `--root PATH` | Корневая директория сайта | `/var/www/<domain>` |
| `--proxy-pass URL` | Настроить как обратный прокси | - |
| `--php` | Установить PHP-FPM и настроить обработку PHP | - |
| `--php-version VERSION` | Версия PHP для установки | 8.2 |
| `--mainline` | Установить mainline версию Nginx | - |

## Примеры использования

### Базовая установка

```bash
./install.sh
```

### Веб-сервер для статического сайта

```bash
./install.sh --domain mysite.com --root /var/www/mysite
```

### Обратный прокси для приложения

```bash
./install.sh --domain api.example.com --proxy-pass http://127.0.0.1:3000
```

### Веб-сервер с PHP

```bash
./install.sh --domain blog.example.com --php
```

### HTTPS-сервер с Let's Encrypt

```bash
./install.sh --domain secure.example.com --ssl --email admin@example.com
```

### Обратный прокси с SSL

```bash
./install.sh \
  --domain app.example.com \
  --proxy-pass http://127.0.0.1:8080 \
  --ssl \
  --email admin@example.com
```

### Mainline версия Nginx

```bash
./install.sh --mainline
```

Mainline версия содержит новейшие функции и исправления.

## Структура файлов

| Компонент | Путь |
|-----------|------|
| Конфигурация | `/etc/nginx/nginx.conf` |
| Виртуальные хосты (доступные) | `/etc/nginx/sites-available/` |
| Виртуальные хосты (включённые) | `/etc/nginx/sites-enabled/` |
| Сниппеты | `/etc/nginx/snippets/` |
| Логи | `/var/log/nginx/` |
| Корень по умолчанию | `/var/www/html/` |

## Управление сервисом

```bash
# Статус
systemctl status nginx

# Перезапуск
systemctl restart nginx

# Перезагрузка конфигурации (без простоя)
systemctl reload nginx

# Остановка
systemctl stop nginx

# Логи
journalctl -u nginx -f

# Логи доступа и ошибок
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

## Проверка конфигурации

Перед применением изменений всегда проверяйте конфигурацию:

```bash
nginx -t
```

При успешной проверке:
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

## Работа с виртуальными хостами

### Создание нового виртуального хоста

```bash
# Создать файл конфигурации
nano /etc/nginx/sites-available/mysite.conf

# Включить сайт
ln -s /etc/nginx/sites-available/mysite.conf /etc/nginx/sites-enabled/

# Проверить и применить
nginx -t && systemctl reload nginx
```

### Отключение виртуального хоста

```bash
# Удалить символическую ссылку
rm /etc/nginx/sites-enabled/mysite.conf

# Применить изменения
systemctl reload nginx
```

## Примеры конфигураций

### Статический сайт

```nginx
server {
    listen 80;
    server_name example.com www.example.com;
    
    root /var/www/example.com;
    index index.html index.htm;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    access_log /var/log/nginx/example.com.access.log;
    error_log /var/log/nginx/example.com.error.log;
}
```

### Обратный прокси

```nginx
server {
    listen 80;
    server_name api.example.com;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### PHP-приложение

```nginx
server {
    listen 80;
    server_name php.example.com;
    
    root /var/www/php.example.com;
    index index.php index.html;
    
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }
    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
```

## Настройка SSL

### Let's Encrypt (Certbot)

```bash
# Установка certbot
apt install certbot python3-certbot-nginx

# Получение сертификата
certbot --nginx -d example.com -d www.example.com

# Автоматическое продление
certbot renew --dry-run
```

### Пример HTTPS-конфигурации

```nginx
server {
    listen 80;
    server_name example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com;
    
    ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    
    root /var/www/example.com;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

## Оптимизация производительности

### Основные настройки (nginx.conf)

```nginx
worker_processes auto;
worker_connections 1024;

# Включить sendfile для статики
sendfile on;
tcp_nopush on;
tcp_nodelay on;

# Сжатие
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

# Кеширование
open_file_cache max=1000 inactive=20s;
open_file_cache_valid 30s;
open_file_cache_min_uses 2;
```

### Кеширование статики

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff2)$ {
    expires 30d;
    add_header Cache-Control "public, no-transform";
}
```

## Безопасность

### Скрытие версии Nginx

```nginx
# В http блоке nginx.conf
server_tokens off;
```

### Заголовки безопасности

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

### Ограничение доступа

```nginx
# По IP
location /admin {
    allow 192.168.1.0/24;
    deny all;
}

# Базовая аутентификация
location /private {
    auth_basic "Restricted Area";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

## Решение проблем

### Nginx не запускается

```bash
# Проверить синтаксис
nginx -t

# Проверить, не занят ли порт 80
ss -tlnp | grep :80

# Проверить логи
journalctl -u nginx -n 50
```

### 502 Bad Gateway

```bash
# Проверить, работает ли бэкенд
curl http://127.0.0.1:3000

# Для PHP — проверить php-fpm
systemctl status php8.2-fpm
```

### 403 Forbidden

```bash
# Проверить права на директорию
ls -la /var/www/mysite/

# Nginx должен иметь доступ на чтение
chown -R www-data:www-data /var/www/mysite/
```

### Сертификат не обновляется

```bash
# Проверить статус certbot
certbot certificates

# Принудительное обновление
certbot renew --force-renewal
```

## Ссылки

- [Документация Nginx](https://nginx.org/ru/docs/)
- [Nginx Admin Guide](https://docs.nginx.com/nginx/admin-guide/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Certbot](https://certbot.eff.org/)

