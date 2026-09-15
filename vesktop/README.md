# Vesktop

- `hooks/theme-set.d/system24` — свой хук: держит тему refact0r/system24, красит из
  активной темы Omarchy. Ставится автоматически через `install.sh`.
- `vencord-settings.json` — включённые плагины Vencord + `enabledThemes: omarchy-system24.theme.css`.
  Смержить нужные ключи (`useQuickCss`, `themeLinks`, `enabledThemes`, `plugins`) в
  `~/.config/vesktop/settings/settings.json` вручную (там же живут сессии/куки — целиком файл не перезатирать).
- `quickCss.css` → `~/.config/vesktop/settings/quickCss.css`.
