# omarchy-backup-hub

Личные плагины, хуки и настройки приложений для Omarchy.

## Установка

```bash
git clone https://github.com/Oxisa/omarchy-backup-hub.git ~/.local/opt/omarchy-backup-hub
~/.local/opt/omarchy-backup-hub/install.sh
```

`install.sh` создаёт симлинки на содержимое `omarchy/plugins/` и `omarchy/hooks/theme-set.d/` в `~/.config/omarchy/`.
Если на месте симлинка уже лежит обычный файл, он сохраняется как `*.pre-hub.bak`. Скрипт можно запускать повторно.

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

Устанавливаются через `omarchy-webapp-install`.

| Название | Адрес |
|---|---|
| YouTube | https://youtube.com |
| YouTube Music | https://music.youtube.com |
| Reddit | https://reddit.com |
| Gmail | https://mail.google.com |
| Google Drive | https://drive.google.com |
| Yandex Диск | https://disk.yandex.ru |
| Яндекс Телемост | https://telemost.yandex.ru |
| Telegram | https://web.telegram.org |
| Zona | https://w1.zona.im |

## Приложения

### Vesktop

- Тему refact0r/system24 под цвета текущей темы Omarchy настраивает хук `omarchy/hooks/theme-set.d/system24`. Он ставится через `install.sh`.
- В `apps/vesktop/vencord-settings.json` лежат включённые плагины Vencord и тема. Переносите только ключи `useQuickCss`, `themeLinks`, `enabledThemes` и `plugins` в `~/.config/vesktop/settings/settings.json`. Целиком файл не заменяйте: в нём хранятся сессии.
