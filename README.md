# omarchy-backup-hub

Личные плагины, хуки и настройки приложений для Omarchy.

## Установка

```bash
git clone https://github.com/Oxisa/omarchy-backup-hub.git ~/.local/opt/omarchy-backup-hub
~/.local/opt/omarchy-backup-hub/install.sh
```

`install.sh` делает следующее:

1. Создаёт симлинки на содержимое `omarchy/plugins/` и `omarchy/hooks/theme-set.d/` в `~/.config/omarchy/`. Если на месте симлинка уже лежит обычный файл, он сохраняется как `*.pre-hub.bak`.
2. Включает плагины из `omarchy/plugins/`.
3. Удаляет и устанавливает веб-приложения из раздела [Web-apps](#web-apps). Списки продублированы в начале `install.sh`, при изменении правьте оба места.
4. Один раз запускает хуки смены темы, чтобы они применились сразу.

Скрипт можно запускать повторно: уже включённые плагины и установленные веб-приложения он пропускает. Настройки Vesktop переносятся вручную, см. раздел [Vesktop](#vesktop).

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

### Obsidian

Хук `omarchy/hooks/theme-set.d/obsidian-minimal` добавляет в тему Minimal (kepano) цветовую схему **Omasidian** в цветах текущей темы Omarchy. Обрабатываются хранилища из `~/.config/obsidian/obsidian.json`, у которых выбрана тема Minimal. Для каждого такого хранилища хук:

- пишет сниппет `.obsidian/snippets/omasidian.css` и обновляет его при каждой смене темы;
- один раз включает этот сниппет в `appearance.json`. Если потом выключить его вручную, хук не включит его обратно;
- добавляет пункт «Omasidian» в списки «Light/Dark mode color scheme» плагина Minimal Theme Settings.

Схема выбирается в настройках плагина Minimal Theme Settings. Пункт появится в списке после перезапуска Obsidian. Обновление плагина убирает пункт из списка до следующей смены темы Omarchy, но уже выбранная схема продолжает работать.

### Vesktop

- Тему refact0r/system24 под цвета текущей темы Omarchy настраивает хук `omarchy/hooks/theme-set.d/system24`. Он ставится через `install.sh`.
- В `apps/vesktop/vencord-settings.json` лежат включённые плагины Vencord и тема. Переносите только ключи `useQuickCss`, `themeLinks`, `enabledThemes` и `plugins` в `~/.config/vesktop/settings/settings.json`. Целиком файл не заменяйте: в нём хранятся сессии.
