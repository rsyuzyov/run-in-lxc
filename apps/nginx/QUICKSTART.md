# Nginx — Шпаргалка

## Установка

```bash
# Базовая установка
./install.sh

# С виртуальным хостом
./install.sh --domain example.com

# Обратный прокси
./install.sh --domain api.example.com --proxy-pass http://127.0.0.1:3000

# С SSL
./install.sh --domain example.com --ssl --email admin@example.com

# С PHP
./install.sh --domain example.com --php
```

## Управление сервисом

```bash
systemctl status nginx
systemctl restart nginx
systemctl reload nginx    # Без простоя
systemctl stop nginx
```

## Проверка конфигурации

```bash
nginx -t
```

## Виртуальные хосты

```bash
# Создать конфигурацию
nano /etc/nginx/sites-available/mysite.conf

# Включить сайт
ln -s /etc/nginx/sites-available/mysite.conf /etc/nginx/sites-enabled/

# Отключить сайт
rm /etc/nginx/sites-enabled/mysite.conf

# Применить изменения
nginx -t && systemctl reload nginx
```

## Логи

```bash
# Логи сервиса
journalctl -u nginx -f

# Логи доступа
tail -f /var/log/nginx/access.log

# Логи ошибок
tail -f /var/log/nginx/error.log
```

## Быстрые конфигурации

### Статический сайт

```nginx
server {
    listen 80;
    server_name example.com;
    root /var/www/example.com;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Обратный прокси

```nginx
server {
    listen 80;
    server_name api.example.com;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### PHP-сайт

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
}
```

## SSL / Let's Encrypt

```bash
# Установить certbot
apt install certbot python3-certbot-nginx

# Получить сертификат
certbot --nginx -d example.com

# Проверить автопродление
certbot renew --dry-run
```

## Пути

| Компонент | Путь |
|-----------|------|
| Главный конфиг | `/etc/nginx/nginx.conf` |
| Виртуальные хосты | `/etc/nginx/sites-available/` |
| Включённые сайты | `/etc/nginx/sites-enabled/` |
| Логи | `/var/log/nginx/` |
| Корень по умолчанию | `/var/www/html/` |

## Частые проблемы

```bash
# Порт занят
ss -tlnp | grep :80

# 502 Bad Gateway — проверить бэкенд
curl http://127.0.0.1:3000

# 403 Forbidden — права на файлы
chown -R www-data:www-data /var/www/mysite/
```

