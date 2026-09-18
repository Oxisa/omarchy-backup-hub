# Windows VM (omarchy-windows-vm)

Windows 11 в Docker-контейнере (`dockurr/windows`, QEMU/KVM), доступ по RDP.
Не путать с загрузочной флешкой (WoeUSB) — это песочница, а не установка на железо.

## Установка / управление

```bash
omarchy-windows-vm install   # спросит RAM/CPU/диск/юзера/пароль/таймзону
omarchy-windows-vm launch    # старт + автоподключение по RDP (/sound /microphone уже включены)
omarchy-windows-vm status
omarchy-windows-vm stop
omarchy-windows-vm remove
```

Прогресс первой установки/загрузки — `http://127.0.0.1:8006` (noVNC).

Данные (диск VM) — `/var/lib/omarchy/windows/mounts/users/<uid>/{storage,shared}`,
персистентны между запусками. Конфиг — `/var/lib/omarchy/windows/docker-compose.yml`
(root:docker, 640; пишется только через сам скрипт — правка руками нужна лишь
для того, чего скрипт не умеет, см. звук ниже).

## Известный false positive: "Failed to start Windows VM"

`launch` ждёт строку "windows started successfully" в логах контейнера **макс. 2
минуты**. Если в этот момент шло скачивание установочного образа Windows с серверов
Microsoft (бывает не только при самой первой установке) — окно не укладывается,
скрипт репортит ошибку, хотя сама VM продолжает подниматься нормально и прогресс
не пропадает. Проверить реальное состояние: `omarchy-windows-vm status` /
`http://127.0.0.1:8006` — если контейнер `running`, ошибка была ложной, просто
подождать.

## Звук

По умолчанию `omarchy-windows-vm install` не включает переменную `AUDIO` — из-за
этого тумблер звука в noVNC (Settings → Advanced) неактивен.

Чинится (нужно после каждого `install`, так как install перезатирает compose):

```bash
pkexec sh -c '
  F=/var/lib/omarchy/windows/docker-compose.yml
  cp -a "$F" "$F.bak.$(date +%s)"
  sed -i "/ARGUMENTS:/a\\      AUDIO: \"Y\"" "$F"
  docker compose -f "$F" config >/dev/null && echo OK
'
pkexec docker compose -f /var/lib/omarchy/windows/docker-compose.yml up -d   # recreate, чтобы env подхватился
```

После этого включить **Audio** в noVNC → Settings → Advanced.

- Звук через **noVNC** — отдельный аудио-поток в браузер (`AUDIO: "Y"`), в
  Windows не выглядит как обычная звуковая карта.
- Звук через **RDP** (то, что запускает `launch`) работает независимо от
  `AUDIO` — в Windows это видно как устройство воспроизведения "Remote Audio",
  не физическая карта. Если через RDP звука всё равно нет — смотреть логи
  контейнера отдельно, это не решается правкой compose.

## Пароль/креды

Хранятся в `~/.config/windows/credentials` (0600) и в самом compose — **не**
коммитить сюда реальные значения, при переустановке ввести новые вручную.
