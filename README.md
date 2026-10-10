# omarchy-backup-hub

Личные плагины, хуки и настройки приложений для Omarchy.

## Установка

```bash
git clone https://github.com/Oxisa/omarchy-backup-hub.git ~/.local/opt/omarchy-backup-hub
~/.local/opt/omarchy-backup-hub/install.sh
```

`install.sh` делает следующее:

1. Ставит недостающие пакеты: `jq`, `curl`, `yt-dlp`, `ffmpeg`, `wl-clipboard`, `brave-bin` и `chromium`. Если не установлен Happ, выводит подсказку.
2. Делает Brave браузером по умолчанию, см. [Туннель и браузеры](#туннель-и-браузеры).
3. Создаёт симлинки на содержимое `omarchy/plugins/` и `omarchy/hooks/theme-set.d/` в `~/.config/omarchy/`. Если на месте симлинка уже лежит обычный файл, он сохраняется как `*.pre-hub.bak`.
4. Включает плагины из `omarchy/plugins/`.
5. Удаляет и устанавливает веб-приложения из раздела [Web-apps](#web-apps) и назначает каждому браузер по колонке «Маршрут». Списки продублированы в начале `install.sh`, при изменении правьте оба места.
6. Один раз запускает хуки смены темы, чтобы они применились сразу.

Скрипт можно запускать повторно: уже установленные пакеты, включённые плагины и веб-приложения он пропускает. Вручную остаются Happ и его настройка обхода (см. [Туннель и браузеры](#туннель-и-браузеры)) и настройки Vesktop (см. [Vesktop](#vesktop)).

## Структура

| Путь | Что внутри | Куда ставится |
|---|---|---|
| `omarchy/plugins/` | Плагины omarchy-shell | `~/.config/omarchy/plugins/` |
| `omarchy/hooks/theme-set.d/` | Хуки `omarchy theme set` | `~/.config/omarchy/hooks/theme-set.d/` |
| `apps/<программа>/` | Настройки отдельных программ | вручную, см. ниже |

## Web-apps

### Удалить

Стандартные веб-приложения Omarchy, которые не нужны:

```bash
for app in "Basecamp" "Discord" "Google Contacts" "Google Maps" "Google Messages" \
           "Google Photos" "HEY" "WhatsApp" "Zoom"; do
  omarchy-webapp-remove "$app"
done
```

### Установить

Устанавливаются через `omarchy-webapp-install`. Маршрут «туннель» — открывается в Brave через туннель, «напрямую» — в Chromium мимо туннеля.

| Название | Адрес | Маршрут |
|---|---|---|
| YouTube | https://youtube.com | туннель |
| YouTube Music | https://music.youtube.com | туннель |
| Reddit | https://reddit.com | туннель |
| Gmail | https://mail.google.com | туннель |
| Google Drive | https://drive.google.com | туннель |
| Telegram | https://web.telegram.org | туннель |
| Yandex Диск | https://disk.yandex.ru | напрямую |
| Яндекс Телемост | https://telemost.yandex.ru | напрямую |
| Zona | https://w1.zona.im | напрямую |

## Туннель и браузеры

Туннель работает через [Happ](https://happ.su) в режиме TUN и пропускает через прокси весь трафик системы. Российские сайты через прокси работают плохо или не работают вовсе, поэтому браузеры разделены:

| Браузер | Для чего | Трафик |
|---|---|---|
| Brave | Личный браузер (по умолчанию) и веб-приложения с маршрутом «туннель» | через туннель |
| Chromium | Только веб-приложения с маршрутом «напрямую» | мимо туннеля |

Разделение держится на настройке Happ, её нужно сделать вручную один раз:

1. Установите Happ с [happ.su](https://happ.su): в репозиториях и AUR его нет.
2. В Happ откройте **настройки → TUN → Per-App Proxy**, включите режим обхода и добавьте Chromium (`/usr/lib/chromium/chromium`).

Проверить настройку можно так: в `~/.config/Happ/config.json` среди правил маршрутизации должно быть правило `"outbound": "direct"` с путём к Chromium.

## Приложения

### Obsidian

Хук `omarchy/hooks/theme-set.d/obsidian-minimal` добавляет в тему Minimal (kepano) цветовую схему **Omasidian** в цветах текущей темы Omarchy. Обрабатываются хранилища из `~/.config/obsidian/obsidian.json`, у которых выбрана тема Minimal. Для каждого такого хранилища хук:

- пишет сниппет `.obsidian/snippets/omasidian.css` и обновляет его при каждой смене темы;
- один раз включает этот сниппет в `appearance.json`. Если потом выключить его вручную, хук не включит его обратно;
- добавляет пункт «Omasidian» в списки «Light/Dark mode color scheme» плагина Minimal Theme Settings.

Схема выбирается в настройках плагина Minimal Theme Settings. Пункт появится в списке после перезапуска Obsidian. Обновление плагина убирает пункт из списка до следующей смены темы Omarchy, но уже выбранная схема продолжает работать.

### Vesktop

- Тему refact0r/system24 под цвета текущей темы Omarchy настраивает хук `omarchy/hooks/theme-set.d/system24`. Он ставится через `install.sh`.
- В `apps/vesktop/vencord-settings.json` лежат включённые плагины Vencord и тема. Переносите только ключи `useQuickCss`, `themeLinks`, `enabledThemes` и `plugins` в `~/.config/vesktop/settings/settings.json`. Целиком файл не заменяйте: в нём хранятся сессии.
