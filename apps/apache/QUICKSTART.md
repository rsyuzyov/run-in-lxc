# Шпаргалка по установке Apache

## Быстрая установка

### Вариант 1: Базовая установка

```bash
cd /root/run-in-lxc/apache
sudo ./install.sh
```

**Что произойдет:**
- ✅ Установится Apache 2.4
- ✅ Включатся базовые модули (rewrite, headers, expires, deflate)
- ✅ Создастся тестовая страница

**После установки:**
```bash
# Откройте браузер
http://<IP-адрес>
```

---

### Вариант 2: С виртуальным хостом

```bash
sudo ./install.sh --domain example.com
```

---

### Вариант 3: С SSL (самоподписанный)

```bash
sudo ./install.sh --domain example.com --ssl
```

---

### Вариант 4: С Let's Encrypt

```bash
sudo ./install.sh \
  --domain example.com \
  --email admin@example.com \
  --letsencrypt
```

> Домен должен быть доступен из интернета!

---

### Вариант 5: С PHP

```bash
# PHP по умолчанию (8.2)
sudo ./install.sh --php

# Конкретная версия PHP
sudo ./install.sh --php --php-version 8.3
```

---

### Вариант 6: Как обратный прокси

```bash
sudo ./install.sh \
  --domain app.example.com \
  --proxy-pass http://localhost:3000 \
  --ssl
```

---

### Вариант 7: Полная установка с HTTP/2

```bash
sudo ./install.sh \
  --domain example.com \
  --email admin@example.com \
  --letsencrypt \
  --php \
  --mpm-event \
  --http2
```

---

## Управление после установки

### Проверка статуса

```bash
systemctl status apache2
```

### Перезапуск

```bash
systemctl restart apache2
```

### Перезагрузка конфигурации

```bash
systemctl reload apache2
```

### Проверка конфигурации

```bash
apache2ctl configtest
```

---

## Просмотр логов

```bash
# Ошибки
tail -f /var/log/apache2/error.log

# Доступ
tail -f /var/log/apache2/access.log
```

---

## Важные пути

| Что | Где |
|-----|-----|
| Конфигурация | `/etc/apache2/` |
| Сайты | `/etc/apache2/sites-available/` |
| Активные сайты | `/etc/apache2/sites-enabled/` |
| Модули | `/etc/apache2/mods-available/` |
| Логи | `/var/log/apache2/` |
| Document Root | `/var/www/html/` |

---

## Работа с сайтами

### Включить сайт

```bash
a2ensite example.com.conf
systemctl reload apache2
```

### Отключить сайт

```bash
a2dissite example.com.conf
systemctl reload apache2
```

---

## Работа с модулями

### Включить модуль

```bash
a2enmod rewrite
a2enmod ssl
systemctl restart apache2
```

### Отключить модуль

```bash
a2dismod autoindex
systemctl restart apache2
```

### Список активных модулей

```bash
apache2ctl -M
```

---

## SSL / HTTPS

### Самоподписанный сертификат

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/apache2/ssl/server.key \
  -out /etc/apache2/ssl/server.crt \
  -subj "/CN=example.com"
```

### Let's Encrypt вручную

```bash
apt-get install certbot python3-certbot-apache
certbot --apache -d example.com
```

### Обновление сертификата

```bash
certbot renew
```

---

## PHP-FPM

### Статус

```bash
systemctl status php8.2-fpm
```

### Перезапуск

```bash
systemctl restart php8.2-fpm
```

### Тест

```bash
echo "<?php phpinfo();" > /var/www/html/info.php
# Откройте http://<IP>/info.php
# Потом удалите: rm /var/www/html/info.php
```

---

## Решение проблем

### Apache не запускается

```bash
apache2ctl configtest
journalctl -u apache2 -n 50
```

### 403 Forbidden

```bash
chown -R www-data:www-data /var/www/html/
chmod -R 755 /var/www/html/
```

### Проверка портов

```bash
ss -tlnp | grep :80
ss -tlnp | grep :443
```

---

## Полезные команды

```bash
# Версия Apache
apache2 -v

# Полная информация
apache2 -V

# Список виртуальных хостов
apache2ctl -S

# Проверка синтаксиса
apache2ctl configtest
```

---

## Удаление

```bash
systemctl stop apache2
apt-get remove --purge apache2 apache2-utils
rm -rf /etc/apache2 /var/log/apache2
```

