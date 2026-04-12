<p align="center">
  <img src="app/NaiveVPN/Assets.xcassets/AppIcon.appiconset/icon-1024.png" alt="All-In-One Наивный VPN" width="128" height="128" />  
</p>

# All-In-One Наивный VPN

Монорепозиторий с **iOS-клиентом** для NaiveProxy (Packet Tunnel + sing-box `Libbox`) и **run-and-forget скриптом сервера** на Caddy с плагином forwardproxy (naive).

<p align="center">
  <a href="https://appdb.to/details/8ca8a41db219d2c36acca881628efb1d26e32115">
    <img
      title="Get from appdb"
      src="https://s3cdn.dbservices.to/official_buttons/get_white.png"
      width="100"
    />
  </a>
</p>

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

Сделать его совместимым с iOS билдами

```bash
./app/Scripts/libbox_flatten_framework.sh
```

2. Открыть `NaiveVPN.xcodeproj` в Xcode.

3. Установить параметры цифровой подписи.

4. Собрать и запускать на **реальном устройстве** (Packet Tunnel в симуляторе не работает).


## Сервер (`server/start_server.sh`)

Скрипт рассчитан на **Linux**, запуск **от root** (`sudo`). Он:

- проверяет, что домен указывает на публичный IP машины;
- при первом запуске спрашивает домен, email для Let’s Encrypt, логин и пароль прокси и пишет `/etc/caddy/Caddyfile`;
- скачивает статический `index.html` (спасибо Игорю Сысоеву!) и бинарник **Caddy с forwardproxy (naive)** (той версии, которую я проверил - и она работает);
- выводит share-ссылку и при наличии утилит — QR для импорта в naive-клиент;
- запускает Caddy в foreground (`exec`).

Нужны: `python3`, `tar`, а для скачивания — `curl` или `wget`; для проверки DNS — `dig`, `getent` или `host`.

### Скачать скрипт через `wget` и запустить в `screen`

Прямая ссылка на **raw** (ветка `main`):

```text
https://raw.githubusercontent.com/ZonD80/naivetools/main/server/start_server.sh
```

Пример:

```bash
mkdir -p ~/naive-server && cd ~/naive-server
wget -O start_server.sh "https://raw.githubusercontent.com/ZonD80/naivetools/main/server/start_server.sh"
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
cd naivetools/server
chmod +x start_server.sh
screen -S naive-caddy
sudo ./start_server.sh
```

Каталог `naivetools` — это репозиторий после `git clone https://github.com/ZonD80/naivetools.git`.

При повторном запуске, если `/etc/caddy/Caddyfile` уже есть, интерактивные вопросы про домен и учётные данные пропускаются — используется существующая конфигурация.

## Благодарности

- [NaiveProxy](https://github.com/klzgrad/naiveproxy) — исходная реализация.
- [sing-box](https://github.com/SagerNet/sing-box) — **Libbox** (Packet Tunnel / gomobile-сборка под iOS).
- [forwardproxy](https://github.com/klzgrad/forwardproxy) (naive) — серверная часть.
- [nginx](https://github.com/nginx/nginx) — замечательный веб-сервер и типовая страница по умолчанию; nginx обслуживает порядка 70% сайтов в интернете (по распространённости среди веб-серверов).

**Android:** можно использовать клиент [Exclave](https://github.com/dyhkwong/Exclave) и отдельный релиз **Naive Proxy Plugin** от upstream (см. раздел Download в репозитории Exclave).

## Поддержка

Если проект оказался полезен — можно угостить автора кофе на [Buy Me a Coffee](https://buymeacoffee.com/zond80).
