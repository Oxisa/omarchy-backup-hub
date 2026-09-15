# omarchy-backup-hub

Личные плагины, theme-set хуки и конфиги для Omarchy. Растёт по мере надобности —
что нужно забэкапить/перенести, добавляется сюда по одному.

## Установка на новой машине

```bash
git clone https://github.com/Oxisa/omarchy-backup-hub.git ~/.local/opt/omarchy-backup-hub
cd ~/.local/opt/omarchy-backup-hub
./install.sh
```

Скрипт симлинкует содержимое `plugins/`, `hooks/theme-set.d/` и `hypr/` в
соответствующие места под `~/.config/`. Существующие обычные файлы (не симлинки)
перед этим сохраняются как `*.pre-hub.bak`. Повторный запуск безопасен.

## Структура

- `plugins/` — omarchy-shell плагины (`~/.config/omarchy/plugins/<name>`)
- `hooks/theme-set.d/` — хуки `omarchy theme set` (`~/.config/omarchy/hooks/theme-set.d/<name>`)
- `hypr/` — файлы Hyprland lua-конфига (`~/.config/hypr/<name>`)
