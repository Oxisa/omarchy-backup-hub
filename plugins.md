# Плагины (сторонние, прошли security-аудит)

Ставить через plugin manager по id, все — SAFE:

- radius.spectra — Spectra (аудио-визуализатор)
- equalizer — Equalizer
- io.github.ilyazar.syncthing — Syncthing
- io.github.xshubhamg.omafocus — OmaFocus
- ekollof.omaconnect — Omaconnect (KDE Connect)
- jot — Jot (sticky notes)
- banan.bananet — Bananet (сеть/Tailscale; sudo ограничен жёстким read-only allowlist)
- io.github.joaodrp.green-room — Green Room (камера/микрофон)
- omarchy-display — Display Settings (активная замена дефолтной)
- plugin-manager — Plugin Manager
- io.github.dreed47.print-center — Print Center (единственный pkexec-путь — добавление принтера — санитайзится и экранируется)
- tenzin.live-wallpaper — Live Wallpaper (видео-обои; путь к видео валидируется allowlist'ом путей/расширений и дублируется в bash+QML)
- bibek.lock — Better Lock (активный lock screen; аутентификация полностью через PAM, блокировка на уровне compositor'а — WlSessionLock)

Свои плагины (полный код) — в `plugins/`: `osia.ytgrab`.
