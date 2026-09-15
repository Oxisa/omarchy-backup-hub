# First-pass provisioning prompt

Инструкции для агента (Claude Code), который разворачивает эту репу на свежей
машине с Omarchy. Пункты добавляются по одному, по мере того как накапливаются
требования — этот файл читается и выполняется целиком при первом проходе.

## Веб-приложения

Omarchy по умолчанию ставит набор веб-приложений (сейчас: Basecamp, Discord,
Google Contacts, Google Maps, Google Messages, Google Photos, HEY, WhatsApp,
X, Zoom — `Exec=omarchy-launch-webapp` / `omarchy-webapp-handler-*` в
`/usr/share/omarchy/applications/*.desktop`).

1. Удалить все дефолтные веб-приложения (`omarchy-webapp-remove-all`, при
   необходимости точечно `omarchy-webapp-remove <name>`), **кроме** тех
   веб-приложений, что на момент прохода уже реально установлены/
   персонализированы пользователем (не трогать чужую кастомизацию,
   сделанную до этого шага).
2. Поставить отдельными веб-приложениями (`omarchy-webapp-install <name> <url> <icon>`):
   - YouTube — `https://youtube.com`
   - YouTube Music — `https://music.youtube.com`
   - Reddit — `https://reddit.com`
   - X (Twitter) — `https://x.com`
