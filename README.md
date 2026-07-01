# Приватный мессенджер Matrix (Synapse + Element)

Руководство по развертыванию сервера Matrix.

## Требования
* ОС: Ubuntu 22.04 или 24.04.
* Характеристики: от 2 ГБ ОЗУ, от 2 ядер CPU, от 20 ГБ дискового пространства.
* Два домена (например, через DuckDNS) с A-записями, указывающими на IP-адрес сервера.

## Установка

1. Подключитесь к серверу по SSH.
2. Установите необходимые пакеты:
```bash
apt update && apt upgrade -y
apt install -y docker.io docker-compose-v2 ufw certbot
```
3. Настройте фаервол:
```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 4443/tcp
ufw enable
```
4. Получите SSL-сертификаты:
```bash
certbot certonly --standalone -d matrix-ВАШ_ДОМЕН.duckdns.org -d element-ВАШ_ДОМЕН.duckdns.org
```
5. Подготовьте директорию проекта:
```bash
mkdir -p ~/private-matrix-server/synapse-data
cd ~/private-matrix-server
```
6. Скопируйте файлы из этого репозитория (`docker-compose.yml`, `.env.example`, `nginx/templates/matrix.conf.template`) в созданную директорию. Переименуйте `.env.example` в `.env` и укажите в нем свои данные.
7. Сгенерируйте конфигурацию Synapse:
```bash
set -a; source .env; set +a
docker run -it --rm \
    -v $(pwd)/synapse-data:/data \
    -e SYNAPSE_SERVER_NAME=$SYNAPSE_SERVER_NAME \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate
```
8. В файле `synapse-data/homeserver.yaml` внесите следующие изменения:
   * В блок `database` (на одном уровне с `name: psycopg2`) добавьте `allow_unsafe_locale: true` — это необходимо для обхода проверки локали PostgreSQL в Alpine-контейнерах, где по умолчанию используется локаль `C` вместо `C.UTF-8`.
   * Добавьте параметры безопасности и **отключите федерацию**:
```yaml
enable_registration: false
encryption_enabled_by_default_for_room_type: "all"
federation_domain_whitelist: []
```
   * Добавьте ограничения частоты запросов (rate limiting) для защиты от брутфорса:
```yaml
rc_login:
  address:
    per_second: 10
    burst_count: 100
  account:
    per_second: 10
    burst_count: 100
  failed_attempts:
    per_second: 10
    burst_count: 100
```
9. Запустите контейнеры:
```bash
docker compose up -d
```

## Управление пользователями

Открытая регистрация отключена. Для создания нового пользователя используйте скрипт:
```bash
./scripts/add_user.sh ЛОГИН
```
Скрипт запросит пароль интерактивно (без отображения в терминале).

Для создания **администратора** используйте интерактивную команду:
```bash
docker exec -it synapse register_new_matrix_user -c /data/homeserver.yaml -a
```
Команда запросит логин и пароль в интерактивном режиме, что исключает попадание пароля в историю команд.

## Диагностика сервера

Для проверки доступности и корректной работы компонентов выполните на сервере следующие команды.

1. Проверка статуса контейнеров (все должны быть Up):
```bash
docker compose ps
```
2. Проверка открытых портов Nginx (должен слушаться порт 4443):
```bash
docker port nginx
```
3. Локальная проверка ответа от интерфейса Element (ожидается HTTP/2 200):
```bash
curl -s -k -H "Host: element-ВАШ_ДОМЕН.duckdns.org" -I https://localhost:4443 | grep HTTP
```
4. Локальная проверка ответа от сервера Matrix (ожидается JSON со списком поддерживаемых версий протокола):
```bash
curl -s -k -H "Host: matrix-ВАШ_ДОМЕН.duckdns.org" https://localhost:4443/_matrix/client/versions
```
5. Просмотр критических ошибок в логах Nginx за последнюю минуту:
```bash
docker compose logs --since 1m nginx | grep -i "emerg"
```

## Автопродление SSL-сертификатов

Certbot в Ubuntu обычно создаёт systemd-таймер автоматически. Убедитесь, что он активен:
```bash
systemctl list-timers | grep certbot
```
Если таймер отсутствует, добавьте задачу в crontab вручную:
```bash
crontab -e
```
```cron
0 3 * * * certbot renew --quiet && cd ~/private-matrix-server && docker compose exec nginx nginx -s reload
```

## Защита от брутфорса (fail2ban)

Для автоматической блокировки IP-адресов при неудачных попытках входа в Matrix используется `fail2ban`, работающий на хосте и анализирующий логи Nginx.

1. Установите fail2ban:
```bash
apt install -y fail2ban
```
2. Скопируйте конфигурацию из репозитория:
```bash
cp fail2ban/jail.local /etc/fail2ban/jail.local
cp fail2ban/filter.d/matrix-auth.conf /etc/fail2ban/filter.d/
```
3. Перезапустите fail2ban:
```bash
systemctl restart fail2ban
```
4. Проверьте, что jail активен:
```bash
fail2ban-client status matrix-auth
```

*Примечание: логи Nginx пробрасываются на хост через volume `./nginx/logs:/var/log/nginx` в `docker-compose.yml`. После обновления docker-compose необходимо пересоздать контейнер nginx:*
```bash
docker compose up -d nginx
```

## Автоматизация бэкапов

Скрипт `scripts/backup.sh` **требует** наличия `BACKUP_PASSWORD` в `.env` — без него бэкап не будет создан (защита от хранения незашифрованных данных).

Для ежедневного автоматического запуска добавьте задачу в crontab:
```bash
crontab -e
```
```cron
0 3 * * * cd ~/private-matrix-server && ./scripts/backup.sh >> /var/log/matrix-backup.log 2>&1
```
