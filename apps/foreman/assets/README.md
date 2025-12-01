# Assets для установки Foreman

Эта папка предназначена для хранения .deb пакетов Puppet, которые могут потребоваться при проблемах со скачиванием из официальных репозиториев.

## Проблема

При установке Foreman скорость скачивания пакетов puppet из apt.puppet.com может падать ниже 1 КБ/с, что приводит к таймаутам и прерыванию установки.

## Решение

Скачайте пакеты вручную и поместите их в эту папку.

### Необходимые пакеты для Debian 12 (Bookworm)

```bash
# puppet-agent (агент Puppet)
wget https://apt.puppet.com/pool/bookworm/puppet8/p/puppet-agent/puppet-agent_8.10.0-1bookworm_amd64.deb

# puppetserver (сервер Puppet)
wget https://apt.puppet.com/pool/bookworm/puppet8/p/puppetserver/puppetserver_8.7.0-1bookworm_all.deb
```

### Альтернативные ссылки

Если прямые ссылки не работают, найдите актуальные версии:
- https://apt.puppet.com/pool/bookworm/puppet8/p/puppet-agent/
- https://apt.puppet.com/pool/bookworm/puppet8/p/puppetserver/

## Использование

После скачивания пакетов запустите установку с флагом `--use-local-assets`:

```bash
sudo ./install.sh --use-local-assets
```

## Структура папки

```
assets/
├── README.md                              # Этот файл
├── puppet-agent_8.10.0-1bookworm_amd64.deb
└── puppetserver_8.7.0-1bookworm_all.deb
```

## Примечания

- Пакеты для amd64 архитектуры
- Версии могут обновляться, проверяйте актуальность на apt.puppet.com
- Файлы .deb добавлены в .gitignore чтобы не раздувать репозиторий

