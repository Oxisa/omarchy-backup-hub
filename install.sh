#!/bin/bash
# Sets up this repo's content on an Omarchy machine:
#   1. symlinks plugins and theme-set hooks into ~/.config/omarchy
#   2. enables this repo's own shell plugins
#   3. removes unwanted default web apps and installs the ones listed below
#   4. runs the theme-set hooks once, so they apply without a theme change
# Safe to re-run: existing non-symlink files are backed up once as *.pre-hub.bak,
# enabled plugins and installed web apps are left alone.
# Vesktop settings stay manual (see README): that file also holds sessions.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
REPO_DIR="$(pwd)"
APPS_DIR="$HOME/.local/share/applications"

# Keep in sync with the Web-apps section of README.md.
WEBAPPS_REMOVE=(
  "Basecamp" "Discord" "Google Contacts" "Google Maps" "Google Messages"
  "Google Photos" "HEY" "WhatsApp" "Zoom"
)
WEBAPPS_INSTALL=(
  "YouTube|https://youtube.com"
  "YouTube Music|https://music.youtube.com"
  "Reddit|https://reddit.com"
  "Gmail|https://mail.google.com"
  "Google Drive|https://drive.google.com"
  "Yandex Диск|https://disk.yandex.ru"
  "Яндекс Телемост|https://telemost.yandex.ru"
  "Telegram|https://web.telegram.org"
  "Zona|https://w1.zona.im"
)

link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.pre-hub.bak"
    echo "backed up existing $dst -> $dst.pre-hub.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "linked $dst -> $src"
}

link_dir_contents() {
  local src_dir="$1" dst_dir="$2"
  [ -d "$src_dir" ] || return 0
  find "$src_dir" -mindepth 1 -maxdepth 1 | while read -r entry; do
    link "$entry" "$dst_dir/$(basename "$entry")"
  done
}

enable_plugins() {
  local dir id
  for dir in "$REPO_DIR"/omarchy/plugins/*/; do
    [ -f "$dir/manifest.json" ] || continue
    id=$(jq -r '.id' "$dir/manifest.json")
    if omarchy plugin list --json | jq -e --arg id "$id" 'any(.[]; .id == $id and .enabled)' >/dev/null; then
      echo "plugin $id already enabled"
    else
      omarchy plugin enable "$id" && echo "enabled plugin $id" || echo "could not enable plugin $id"
    fi
  done
}

setup_webapps() {
  local app name url
  for name in "${WEBAPPS_REMOVE[@]}"; do
    [ -f "$APPS_DIR/$name.desktop" ] || continue
    OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$name" && echo "removed web app $name"
  done
  for app in "${WEBAPPS_INSTALL[@]}"; do
    name="${app%%|*}" url="${app#*|}"
    if [ -f "$APPS_DIR/$name.desktop" ]; then
      echo "web app $name already installed"
    else
      # Empty icon argument: omarchy fetches the site's own icon.
      omarchy-webapp-install "$name" "$url" "" && echo "installed web app $name" \
        || echo "could not install web app $name"
    fi
  done
}

link_dir_contents "$REPO_DIR/omarchy/plugins"    "$HOME/.config/omarchy/plugins"
link_dir_contents "$REPO_DIR/omarchy/hooks/theme-set.d" "$HOME/.config/omarchy/hooks/theme-set.d"
enable_plugins
setup_webapps
omarchy-hook theme-set "$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)"

echo "done."
