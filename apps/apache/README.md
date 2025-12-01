# Apache HTTP Server в LXC контейнере

Скрипты и инструкции для установки [Apache HTTP Server](https://httpd.apache.org/) — надёжного и гибкого веб-сервера — в LXC контейнер.

## Что такое Apache?

Apache HTTP Server — один из самых популярных веб-серверов в мире. Он позволяет:
- Хостить статические и динамические веб-сайты
- Работать как обратный прокси для приложений
- Поддерживать виртуальные хосты для множества доменов
- Интегрироваться с PHP, Python, Perl и другими языками
- Обеспечивать безопасность через SSL/TLS

## Системные требования

### Требования к LXC контейнеру

| Параметр | Минимум | Рекомендуется |
|----------|---------|---------------|
| **ОС** | Debian 11/12, Ubuntu 22.04/24.04 | Debian 12 |
| **RAM** | 512 MB | 1 GB |
| **CPU** | 1 ядро | 2 ядра |
| **Диск** | 5 GB | 10 GB |

### Создание контейнера в Proxmox

```bash
# Из директории proxmox/
sudo ./create-lxc.sh \
  --name apache \
  --memory 1024 \
  --cores 2 \
  --disk 10 \
  --bootstrap
```

## Установка

### Быстрый старт

**Базовая установка Apache:**
```bash
sudo ./install.sh
```

После установки Apache доступен по адресу: `http://<IP-адрес>`

### С виртуальным хостом

```bash
sudo ./install.sh --domain example.com
```

### С SSL (самоподписанный сертификат)

```bash
sudo ./install.sh --domain example.com --ssl
```

### С Let's Encrypt (бесплатный SSL)

```bash
sudo ./install.sh \
  --domain example.com \
  --email admin@example.com \
  --letsencrypt
```

> ⚠️ **Важно**: Для Let's Encrypt домен должен быть доступен из интернета.

### С PHP

**Установка с PHP-FPM:**
```bash
sudo ./install.sh --php
```

**С конкретной версией PHP:**
```bash
sudo ./install.sh --php --php-version 8.3
```

**Полная установка с PHP и SSL:**
```bash
sudo ./install.sh \
  --domain example.com \
  --ssl \
  --php \
  --php-version 8.2
```

### Как обратный прокси

Для проксирования запросов к backend-приложению:

```bash
# Прокси к Node.js приложению
sudo ./install.sh \
  --domain app.example.com \
  --proxy-pass http://localhost:3000 \
  --ssl

# Прокси к Docker контейнеру
sudo ./install.sh \
  --domain api.example.com \
  --proxy-pass http://172.17.0.2:8080 \
  --ssl
```

### С HTTP/2

Для максимальной производительности:

```bash
sudo ./install.sh \
  --domain example.com \
  --ssl \
  --mpm-event \
  --http2
```

> HTTP/2 требует SSL и лучше работает с MPM Event.

### Полная кастомизация

```bash
sudo ./install.sh \
  --domain example.com \
  --email admin@example.com \
  --letsencrypt \
  --php \
  --php-version 8.2 \
  --document-root /var/www/example.com \
  --mpm-event \
  --http2
```

## Параметры установки

| Параметр | Описание | По умолчанию |
|----------|----------|--------------|
| `--domain` | Доменное имя для виртуального хоста | не указан |
| `--email` | Email для Let's Encrypt | не указан |
| `--ssl` | Включить SSL с самоподписанным сертификатом | false |
| `--letsencrypt` | Получить SSL от Let's Encrypt | false |
| `--php` | Установить PHP-FPM | false |
| `--php-version` | Версия PHP | 8.2 |
| `--proxy-pass` | URL для обратного прокси | не указан |
| `--document-root` | Корневая директория сайта | /var/www/html |
| `--mpm-event` | Использовать MPM Event | false |
| `--http2` | Включить HTTP/2 | false |

## После установки

### Проверка статуса

```bash
# Статус Apache
systemctl status apache2

# Проверка конфигурации
apache2ctl configtest

# Версия Apache
apache2 -v
```

### Управление сервисом

```bash
# Перезапуск
systemctl restart apache2

# Перезагрузка конфигурации (без разрыва соединений)
systemctl reload apache2

# Остановка
systemctl stop apache2

# Запуск
systemctl start apache2
```

### Важные пути

| Что | Где |
|-----|-----|
| Основной конфиг | `/etc/apache2/apache2.conf` |
| Доступные сайты | `/etc/apache2/sites-available/` |
| Активные сайты | `/etc/apache2/sites-enabled/` |
| Модули | `/etc/apache2/mods-available/` |
| Логи | `/var/log/apache2/` |
| Document Root | `/var/www/html/` |

## Работа с виртуальными хостами

### Создание нового сайта вручную

```bash
# Создание директории
mkdir -p /var/www/mysite.com
chown -R www-data:www-data /var/www/mysite.com

# Создание конфигурации
cat > /etc/apache2/sites-available/mysite.com.conf << 'EOF'
<VirtualHost *:80>
    ServerName mysite.com
    ServerAlias www.mysite.com
    DocumentRoot /var/www/mysite.com
    
    <Directory /var/www/mysite.com>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog ${APACHE_LOG_DIR}/mysite.com_error.log
    CustomLog ${APACHE_LOG_DIR}/mysite.com_access.log combined
</VirtualHost>
EOF

# Активация сайта
a2ensite mysite.com.conf

# Перезагрузка Apache
systemctl reload apache2
```

### Отключение сайта

```bash
a2dissite mysite.com.conf
systemctl reload apache2
```

## Работа с модулями

### Просмотр модулей

```bash
# Список активных модулей
apache2ctl -M

# Доступные модули
ls /etc/apache2/mods-available/
```

### Включение/отключение модулей

```bash
# Включить модуль
a2enmod rewrite
a2enmod ssl
a2enmod proxy

# Отключить модуль
a2dismod autoindex

# Применить изменения
systemctl restart apache2
```

### Популярные модули

| Модуль | Описание |
|--------|----------|
| `rewrite` | URL-перезапись (mod_rewrite) |
| `ssl` | HTTPS поддержка |
| `proxy` | Обратный прокси |
| `headers` | Управление HTTP-заголовками |
| `expires` | Кэширование на стороне клиента |
| `deflate` | Сжатие gzip |
| `http2` | Поддержка HTTP/2 |

## Настройка SSL

### Самоподписанный сертификат

```bash
# Генерация сертификата
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/apache2/ssl/server.key \
  -out /etc/apache2/ssl/server.crt \
  -subj "/CN=example.com/O=My Company/C=RU"

# Проверка сертификата
openssl x509 -in /etc/apache2/ssl/server.crt -text -noout
```

### Let's Encrypt

```bash
# Установка certbot
apt-get install certbot python3-certbot-apache

# Получение сертификата
certbot --apache -d example.com -d www.example.com

# Проверка автообновления
certbot renew --dry-run

# Просмотр сертификатов
certbot certificates
```

### Обновление сертификатов

Let's Encrypt сертификаты автоматически обновляются через systemd timer:

```bash
# Статус таймера
systemctl status certbot.timer

# Ручное обновление
certbot renew
```

## Интеграция с PHP

### Проверка PHP

```bash
# Версия PHP
php -v

# Проверка PHP-FPM
systemctl status php8.2-fpm

# Тест PHP
echo "<?php phpinfo();" > /var/www/html/info.php
```

### Установка дополнительных расширений

```bash
apt-get install php8.2-imagick php8.2-redis php8.2-memcached
systemctl restart php8.2-fpm
```

### Настройка PHP-FPM

```bash
# Основной конфиг
nano /etc/php/8.2/fpm/php.ini

# Пулы
nano /etc/php/8.2/fpm/pool.d/www.conf

# Применить изменения
systemctl restart php8.2-fpm
```

## Оптимизация производительности

### MPM Event vs Prefork

| MPM | Описание | Когда использовать |
|-----|----------|-------------------|
| **Prefork** | Один процесс на запрос | mod_php, legacy приложения |
| **Event** | Асинхронная обработка | PHP-FPM, прокси, статика |

```bash
# Переключение на MPM Event
a2dismod mpm_prefork
a2enmod mpm_event
systemctl restart apache2
```

### Настройка MPM Event

```bash
cat > /etc/apache2/mods-available/mpm_event.conf << 'EOF'
<IfModule mpm_event_module>
    StartServers             2
    MinSpareThreads         25
    MaxSpareThreads         75
    ThreadLimit             64
    ThreadsPerChild         25
    MaxRequestWorkers      150
    MaxConnectionsPerChild   0
</IfModule>
EOF
```

### Включение сжатия

```bash
cat > /etc/apache2/conf-available/compression.conf << 'EOF'
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css
    AddOutputFilterByType DEFLATE application/javascript application/json
    AddOutputFilterByType DEFLATE image/svg+xml
</IfModule>
EOF

a2enconf compression
systemctl reload apache2
```

### Настройка кэширования

```bash
cat > /etc/apache2/conf-available/caching.conf << 'EOF'
<IfModule mod_expires.c>
    ExpiresActive On
    
    # Изображения - 1 месяц
    ExpiresByType image/jpeg "access plus 1 month"
    ExpiresByType image/png "access plus 1 month"
    ExpiresByType image/gif "access plus 1 month"
    ExpiresByType image/webp "access plus 1 month"
    ExpiresByType image/svg+xml "access plus 1 month"
    
    # CSS и JS - 1 неделя
    ExpiresByType text/css "access plus 1 week"
    ExpiresByType application/javascript "access plus 1 week"
    
    # HTML - 1 час
    ExpiresByType text/html "access plus 1 hour"
</IfModule>
EOF

a2enconf caching
systemctl reload apache2
```

## Безопасность

### Скрытие версии Apache

Скрипт установки автоматически настраивает:

```apache
ServerTokens Prod
ServerSignature Off
```

### Заголовки безопасности

```bash
cat > /etc/apache2/conf-available/security-headers.conf << 'EOF'
<IfModule mod_headers.c>
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
</IfModule>
EOF

a2enconf security-headers
systemctl reload apache2
```

### Ограничение доступа по IP

```apache
<Directory /var/www/admin>
    Require ip 192.168.1.0/24
    Require ip 10.0.0.0/8
</Directory>
```

### Базовая аутентификация

```bash
# Создание файла паролей
htpasswd -c /etc/apache2/.htpasswd admin

# Настройка в .htaccess или VirtualHost
cat >> /var/www/html/protected/.htaccess << 'EOF'
AuthType Basic
AuthName "Restricted Area"
AuthUserFile /etc/apache2/.htpasswd
Require valid-user
EOF
```

## Логирование

### Просмотр логов

```bash
# Логи ошибок
tail -f /var/log/apache2/error.log

# Логи доступа
tail -f /var/log/apache2/access.log

# Логи конкретного сайта
tail -f /var/log/apache2/example.com_error.log
```

### Ротация логов

Логи автоматически ротируются через logrotate:

```bash
cat /etc/logrotate.d/apache2
```

### Кастомный формат логов

```apache
LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %D" combined_timing
CustomLog ${APACHE_LOG_DIR}/access.log combined_timing
```

## Решение проблем

### Apache не запускается

```bash
# Проверка конфигурации
apache2ctl configtest

# Проверка ошибок
journalctl -u apache2 -n 50

# Проверка портов
ss -tlnp | grep :80
ss -tlnp | grep :443
```

### 403 Forbidden

```bash
# Проверка прав
ls -la /var/www/html/

# Исправление прав
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/

# Проверка SELinux (если включён)
getenforce
```

### 500 Internal Server Error

```bash
# Проверка логов
tail -50 /var/log/apache2/error.log

# Проверка .htaccess
apache2ctl configtest
```

### SSL проблемы

```bash
# Проверка сертификата
openssl s_client -connect localhost:443

# Проверка прав на сертификаты
ls -la /etc/apache2/ssl/

# Проверка конфигурации SSL
apache2ctl -t -D DUMP_MODULES | grep ssl
```

### PHP не работает

```bash
# Статус PHP-FPM
systemctl status php8.2-fpm

# Проверка сокета
ls -la /run/php/php8.2-fpm.sock

# Перезапуск PHP-FPM
systemctl restart php8.2-fpm
```

## Мониторинг

### Включение mod_status

```bash
a2enmod status

cat > /etc/apache2/conf-available/server-status.conf << 'EOF'
<Location "/server-status">
    SetHandler server-status
    Require ip 127.0.0.1
    Require ip ::1
</Location>
EOF

a2enconf server-status
systemctl reload apache2

# Просмотр статуса
curl http://localhost/server-status?auto
```

### Включение mod_info

```bash
a2enmod info

cat > /etc/apache2/conf-available/server-info.conf << 'EOF'
<Location "/server-info">
    SetHandler server-info
    Require ip 127.0.0.1
</Location>
EOF

a2enconf server-info
systemctl reload apache2
```

## Удаление

```bash
# Остановка сервиса
systemctl stop apache2

# Удаление пакетов
apt-get remove --purge apache2 apache2-utils

# Удаление данных (ОСТОРОЖНО!)
rm -rf /etc/apache2
rm -rf /var/log/apache2
rm -rf /var/www/html
```

## Поддержка

- [Официальная документация Apache](https://httpd.apache.org/docs/2.4/)
- [Apache Wiki](https://cwiki.apache.org/confluence/display/HTTPD/)
- [DigitalOcean Tutorials](https://www.digitalocean.com/community/tags/apache)
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/)

