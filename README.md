<p align="center">
  <img src="app/NaiveVPN/Assets.xcassets/AppIcon.appiconset/icon-1024.png" alt="All-In-One Наивный VPN" width="128" height="128" />
</p>

# All-In-One Наивный VPN

Монорепозиторий с **iOS-клиентом** для NaiveProxy (Packet Tunnel + sing-box `Libbox`) и **скриптом сервера** на Caddy с плагином forwardproxy (naive).

## Состав

| Каталог   | Назначение                                                                          |
| --------- | ----------------------------------------------------------------------------------- |
| `app/`    | iOS-приложение `NaiveVPN`, расширение туннеля, общий код конфигурации               |
| `misc/`   | Дробленный архив `Libbox.xcframework` (восстановление в `app/` — см. ниже)          |
| `server/` | `start_server.sh` — установка и запуск Caddy (naive forward proxy) на Linux-сервере |

## iOS-приложение (`app/`)

1. Получить `Libbox.xcframework` в каталоге `app/` — **либо** собрать из исходников, **либо** восстановить из архива в `misc/` (фреймворк в git не хранится из‑за лимитов GitHub):

Сборка:

```bash
cd app
./Scripts/build_libbox.sh
```

Восстановление из `misc/` (части `Libbox.xcframework.zip.aa`, `.ab`, … склеиваются в один zip, затем распаковка в `app/`):

```bash
# из корня репозитория
cat misc/Libbox.xcframework.zip.* > /tmp/Libbox.xcframework.zip
unzip -o /tmp/Libbox.xcframework.zip -d app
rm /tmp/Libbox.xcframework.zip
```

2. Открыть `NaiveVPN.xcodeproj` в Xcode.

3. При необходимости задать команду подписи и префикс bundle id (`BASE_PACKAGE_IDENTIFIER`).

4. Собрать и запускать на **реальном устройстве** (Packet Tunnel в симуляторе не работает).

Подробности — в [`app/README.md`](app/README.md).

## Сервер (`server/start_server.sh`)

Скрипт рассчитан на **Linux**, запуск **от root** (`sudo`). Он:

- проверяет, что домен указывает на публичный IP машины;
- при первом запуске спрашивает домен, email для Let’s Encrypt, логин и пароль прокси и пишет `/etc/caddy/Caddyfile`;
- скачивает статический `index.html` и бинарник **Caddy с forwardproxy (naive)**;
- выводит share-ссылку и при наличии утилит — QR для импорта в naive-клиент;
- запускает Caddy в foreground (`exec`).

Нужны: `python3`, `tar`, а для скачивания — `curl` или `wget`; для проверки DNS — `dig`, `getent` или `host`.

### Скачать скрипт через `wget` и запустить в `screen`

Подставьте URL **raw**-файла из вашего репозитория (ветка `main` или `master`):

```text
https://raw.githubusercontent.com/OWNER/REPO/BRANCH/server/start_server.sh
```

Пример:

```bash
mkdir -p ~/naive-server && cd ~/naive-server
wget -O start_server.sh "https://raw.githubusercontent.com/OWNER/REPO/main/server/start_server.sh"
chmod +x start_server.sh
```

Сессия `screen`, чтобы процесс остался после выхода из SSH:

```bash
screen -S naive-caddy
sudo ./start_server.sh
```

Выйти из `screen`, оставив Caddy работать: **Ctrl+A**, затем **D**. Вернуться: `screen -r naive-caddy`.

Перед первым запуском настройте **A-запись DNS** домена на IP этого сервера — скрипт это проверит.

### Если репозиторий уже клонирован

```bash
cd /path/to/naive-ios/server
chmod +x start_server.sh
screen -S naive-caddy
sudo ./start_server.sh
```

При повторном запуске, если `/etc/caddy/Caddyfile` уже есть, интерактивные вопросы про домен и учётные данные пропускаются — используется существующая конфигурация.

## Поддержка

Если проект оказался полезен — можно угостить автора кофе на [Buy Me a Coffee](https://buymeacoffee.com/zond80).
