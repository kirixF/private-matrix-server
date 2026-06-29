# Private Matrix Server (Synapse)

Этот репозиторий содержит всё необходимое для развертывания полностью приватного Matrix-сервера (Synapse) с Element Web и Nginx в качестве реверс-прокси, предназначенного для закрытой группы пользователей (без федерации).

## 1. Подготовка и переменные окружения

Сначала скопируйте файл примера переменных окружения и заполните его:

```bash
cp .env.example .env
nano .env
```

Вам необходимо заполнить следующие переменные:
- `SYNAPSE_SERVER_NAME`: Домен вашего сервера (например, `example.com`).
- `POSTGRES_PASSWORD`: Надежный пароль для базы данных PostgreSQL.
- `REGISTRATION_SHARED_SECRET`: Секретный ключ для регистрации пользователей (создайте с помощью `pwgen -s 64 1` или `openssl rand -hex 32`).
- `DOMAIN`: Ваш основной домен (например, `example.com`).
- `MATRIX_SUBDOMAIN`: Поддомен для API Matrix (например, `matrix.example.com`).
- `ELEMENT_SUBDOMAIN`: Поддомен для веб-клиента Element (например, `element.example.com`).

## 2. Генерация начального конфигурационного файла

Перед первым запуском необходимо сгенерировать `homeserver.yaml`. Выполните следующую команду на сервере:

```bash
# Загрузка .env переменных
set -a; source .env; set +a

docker run -it --rm \
    -v $(pwd)/synapse-data:/data \
    -e SYNAPSE_SERVER_NAME=$SYNAPSE_SERVER_NAME \
    -e SYNAPSE_REPORT_STATS=no \
    matrixdotorg/synapse:latest generate
```

### Настройка приватности и ограничений
После генерации откройте файл `synapse-data/homeserver.yaml` и внесите следующие изменения:

1. **Отключение регистрации**:
   ```yaml
   enable_registration: false
   ```

2. **Отключение федерации** (сервер будет полностью изолирован):
   ```yaml
   federation_domain_whitelist: []
   ```

3. **Лимиты загрузки медиа** (50MB) и URL-превью:
   ```yaml
   max_upload_size: "50M"
   url_preview_enabled: true
   ```
   *(Также может потребоваться раскомментировать `url_preview_ip_range_blacklist` для безопасности)*

4. **Включение E2E шифрования** для новых комнат:
   ```yaml
   encryption_enabled_by_default_for_room_type: "all"
   ```

5. **Настройка базы данных** (вместо sqlite):
   Найдите блок `database` и замените его на PostgreSQL:
   ```yaml
   database:
     name: psycopg2
     args:
       user: synapse
       password: "ВАШ_POSTGRES_PASSWORD_ИЗ_.ENV"
       database: synapse
       host: postgres
       cp_min: 5
       cp_max: 10
   ```

## 3. Первый запуск

После настройки конфигов и получения SSL-сертификатов (Certbot/Let's Encrypt), запустите контейнеры в фоновом режиме:

```bash
docker compose up -d
```

*(Примечание: перед запуском Nginx убедитесь, что сертификаты для `MATRIX_SUBDOMAIN` и `ELEMENT_SUBDOMAIN` сгенерированы. Вы можете временно закомментировать SSL секции в Nginx и запустить certbot через webroot)*

## 4. Проверка работоспособности

Чтобы убедиться, что Synapse работает корректно, выполните запрос:

```bash
curl https://matrix.example.com/_matrix/client/versions
```
Если в ответ приходит JSON со списком поддерживаемых версий, значит сервер успешно запущен.

## 5. Создание администратора и пользователей

Регистрация открыта только из командной строки. Чтобы создать вашего **первого пользователя-администратора**, используйте следующую точную команду:

```bash
docker exec -it synapse register_new_matrix_user -u "your_admin_username" -p "your_secure_password" -c /data/homeserver.yaml -a --admin
```

Для создания **обычных пользователей** вы можете использовать встроенный скрипт:

```bash
bash scripts/add_user.sh "username" "password"
```

## 6. Подключение через Element Web

После развертывания перейдите по адресу вашего Element (например, `https://element.example.com`).
1. Нажмите "Войти" (Sign In).
2. Нажмите "Изменить" (Edit) возле адреса сервера (Homeserver).
3. Введите адрес вашего Matrix API (например, `https://matrix.example.com`).
4. Введите созданные логин и пароль.

## 7. Бэкапы

В репозитории есть скрипт для бэкапа базы данных и медиа-файлов:

```bash
bash scripts/backup.sh
```
Он создаст архив со всем необходимым в папке `./backups/`.
