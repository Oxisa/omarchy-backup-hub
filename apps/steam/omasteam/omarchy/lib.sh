#!/bin/bash
# omasteam shared helpers.

OMASTEAM_DATA="${OMASTEAM_DATA:-$HOME/.local/share/omasteam}"
OMASTEAM_TPL="omasteam-colors.css.tpl"
OMASTEAM_RENDERED="omasteam-colors.css"     # rendered into the Omarchy theme dir
OMASTEAM_THEME_NAME="Omarchy"

omasteam_omarchy_theme_dir() {
  if [[ -d $HOME/.local/state/omarchy/current/theme ]]; then
    printf '%s\n' "$HOME/.local/state/omarchy/current/theme"
  elif [[ -d $HOME/.config/omarchy/current/theme ]]; then
    printf '%s\n' "$HOME/.config/omarchy/current/theme"
  else
    return 1
  fi
}

# Millennium's themes directory. Override with MILLENNIUM_THEMES_DIR.
omasteam_millennium_themes_dir() {
  local d
  for d in "${MILLENNIUM_THEMES_DIR:-}" \
           "$HOME/.local/share/millennium/themes" \
           "$HOME/.millennium/themes" \
           "$HOME/.config/millennium/themes"; do
    [[ -n $d && -d $d ]] && { printf '%s\n' "$d"; return 0; }
  done
  # not created yet -> the canonical Linux path; caller mkdir -p's it
  printf '%s\n' "$HOME/.local/share/millennium/themes"
}

omasteam_theme_dir() {
  printf '%s\n' "$(omasteam_millennium_themes_dir)/$OMASTEAM_THEME_NAME"
}

omasteam_steam_running() {
  pgrep -x -u "$(id -u)" 'steam|steamwebhelper' >/dev/null 2>&1
}
