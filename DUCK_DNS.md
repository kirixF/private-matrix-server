# Настройка Duck DNS для Matrix сервера

Duck DNS позволяет получить бесплатный поддомен (например, `yourname.duckdns.org`), который можно использовать для настройки Matrix (Synapse) сервера.

## 1. Регистрация и получение токена
1. Перейдите на сайт [duckdns.org](https://www.duckdns.org/) и авторизуйтесь (например, через GitHub или Google).
2. Создайте новый домен (например, `mymatrix`). Ваш адрес будет `mymatrix.duckdns.org`.
3. Скопируйте ваш **Token** со страницы аккаунта, он понадобится для автоматического обновления IP-адреса.

## 2. Настройка автоматического обновления IP
Даже если у вашего VPS статический IP, настройка скрипта гарантирует актуальность DNS записи.

1. Подключитесь к VPS по SSH.
2. Создайте директорию для скрипта:
   ```bash
   mkdir -p ~/duckdns
   cd ~/duckdns
   ```
3. Создайте скрипт `duck.sh`:
   ```bash
   nano duck.sh
   ```
   Вставьте следующую строку, заменив `YOUR_DOMAIN` на ваш домен (без .duckdns.org) и `YOUR_TOKEN` на ваш токен:
   ```bash
   echo url="https://www.duckdns.org/update?domains=YOUR_DOMAIN&token=YOUR_TOKEN&ip=" | curl -k -o ~/duckdns/duck.log -K -
   ```
4. Сделайте скрипт исполняемым:
   ```bash
   chmod 700 duck.sh
   ```
5. Добавьте задачу в cron для выполнения каждые 5 минут:
   ```bash
   crontab -e
   ```
   Вставьте строку в конец файла:
   ```cron
   */5 * * * * ~/duckdns/duck.sh >/dev/null 2>&1
   ```
6. Запустите скрипт вручную для проверки:
   ```bash
   ./duck.sh
   cat duck.log
   ```
   В ответе должно быть `OK`.

## 3. Настройка Matrix (.env)
Duck DNS предоставляет поддомены первого уровня (`xxx.duckdns.org`). Для стандартной установки Matrix с отдельными веб-клиентом и API, вам понадобится **три** домена в Duck DNS:
1. `mymatrix.duckdns.org` (основной)
2. `matrix-mymatrix.duckdns.org` (API)
3. `element-mymatrix.duckdns.org` (Element Web)

Откройте файл `.env` в директории `private-matrix-server` и укажите их:

```bash
SYNAPSE_SERVER_NAME=mymatrix.duckdns.org
DOMAIN=mymatrix.duckdns.org
MATRIX_SUBDOMAIN=matrix-mymatrix.duckdns.org
ELEMENT_SUBDOMAIN=element-mymatrix.duckdns.org
```

*После этого настройте Nginx и Let's Encrypt (Certbot) аналогично стандартной инструкции из README.md, используя указанные выше Duck DNS домены.*
