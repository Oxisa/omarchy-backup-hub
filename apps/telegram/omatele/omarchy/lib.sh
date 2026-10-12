#!/bin/bash
# omatele shared helpers. Sourced by install.sh, uninstall.sh and the
# theme-set hook so paths + client discovery have one definition.

OMATELE_DATA="${OMATELE_DATA:-$HOME/.local/share/omatele}"
OMATELE_TPL="omatele.tdesktop-palette.tpl"
OMATELE_RENDERED="omatele.tdesktop-palette"          # rendered into the theme dir
OMATELE_OUT="omarchy.tdesktop-theme"                 # zip for the send-to-chat method
OMATELE_PALETTE_PLAIN="omarchy.tdesktop-palette"     # bare palette (import / fallback)

# Resolve the Omarchy "current theme" directory (4.x uses state; older config).
omatele_theme_dir() {
  if [[ -d $HOME/.local/state/omarchy/current/theme ]]; then
    printf '%s\n' "$HOME/.local/state/omarchy/current/theme"
  elif [[ -d $HOME/.config/omarchy/current/theme ]]; then
    printf '%s\n' "$HOME/.config/omarchy/current/theme"
  else
    return 1
  fi
}

# Telegram Desktop working directory (holds tdata/). Override with
# TELEGRAM_WORKDIR if you launch Telegram with -workdir.
omatele_tg_workdir() {
  local d
  for d in "${TELEGRAM_WORKDIR:-}" \
           "$HOME/.local/share/TelegramDesktop" \
           "$HOME/.local/share/64Gram" \
           "$HOME/.local/share/KotatogramDesktop" \
           "$HOME/.local/share/AyuGram"; do
    [[ -n $d && -d $d/tdata ]] && { printf '%s\n' "$d"; return 0; }
  done
  return 1
}

# The file Telegram's theme editor live-watches. Present only once the user
# has done "Create new theme -> Import existing theme" one time; that is what
# turns every later regen into a live retheme.
omatele_editing_palette() {
  local w
  w=$(omatele_tg_workdir) || return 1
  printf '%s\n' "$w/tdata/editing-theme.tdesktop-palette"
}

omatele_tg_running() {
  pgrep -x -u "$(id -u)" 'Telegram|telegram-deskto|64gram|kotatogram|AyuGram' >/dev/null 2>&1
}
