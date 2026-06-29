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
ufw allow 443/tcp
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
8. В файле `synapse-data/homeserver.yaml` добавьте строку `allow_unsafe_locale: true` в блок `database` (на одном уровне с `name: psycopg2`). Измените параметры для безопасности:
```yaml
enable_registration: false
encryption_enabled_by_default_for_room_type: "all"
```
9. Запустите контейнеры:
```bash
docker compose up -d
```

## Управление пользователями

Открытая регистрация отключена. Для создания профиля используйте команду:
```bash
docker exec -it synapse register_new_matrix_user -u "ЛОГИН" -p "ПАРОЛЬ" -c /data/homeserver.yaml
```
Для выдачи прав администратора добавьте флаг `-a --admin`.
