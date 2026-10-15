#!/bin/bash
# Sets up this repo's content on an Omarchy machine:
#   1. installs missing packages the hub relies on
#   2. makes Brave the default browser (web apps follow it, through the tunnel)
#   3. symlinks plugins and theme-set hooks into ~/.config/omarchy, and
#      helper commands into ~/.local/bin
#   4. enables this repo's own shell plugins and adds the hub's Omarchy menu
#      entries (Install → Web App with a route choice)
#   5. removes unwanted default web apps and installs the ones listed below;
#      "direct" ones launch in Chromium, which Happ lets bypass the tunnel
#   6. runs the theme-set hooks once, so they apply without a theme change
# Safe to re-run: existing non-symlink files are backed up once as *.pre-hub.bak,
# installed packages, enabled plugins and installed web apps are left alone.
# Manual steps stay manual (see README): Happ itself and its per-app bypass,
# and Vesktop settings, whose file also holds sessions.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
REPO_DIR="$(pwd)"
APPS_DIR="$HOME/.local/share/applications"
OMARCHY_APPS="/usr/share/omarchy/applications"
MENU_FILE="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
MENU_START="// omarchy-backup-hub-menu-start"
MENU_END="// omarchy-backup-hub-menu-end"

# jq/curl: this script and the hooks; yt-dlp/ffmpeg/wl-clipboard: Omaloader;
# brave-bin/chromium: the tunnel / direct browser split.
PACKAGES=(jq curl yt-dlp ffmpeg wl-clipboard brave-bin chromium)

# Keep in sync with the Web-apps section of README.md.
# Install entries are "Name|URL|route": route "tunnel" opens in the default
# browser (Brave, through the tunnel), "direct" opens in Chromium (bypasses it).
WEBAPPS_REMOVE=(
  "Basecamp" "Discord" "Google Contacts" "Google Maps" "Google Messages"
  "Google Photos" "HEY" "WhatsApp" "Zoom"
)
WEBAPPS_INSTALL=(
  "X|https://x.com|tunnel"
  "YouTube|https://youtube.com|tunnel"
  "YouTube Music|https://music.youtube.com|tunnel"
  "Twitch|https://twitch.tv|tunnel"
  "Reddit|https://reddit.com|tunnel"
  "Telegram|https://web.telegram.org|tunnel"
  "Gmail|https://mail.google.com|tunnel"
  "Google Drive|https://drive.google.com|tunnel"
  "Google Docs|https://docs.google.com|tunnel"
  "Google Translate|https://translate.google.com|tunnel"
  "Claude|https://claude.ai|tunnel"
  "ChatGPT|https://chatgpt.com|tunnel"
  "Gemini|https://gemini.google.com|tunnel"
  "GitHub|https://github.com|tunnel"
  "Figma|https://figma.com|tunnel"
  "Excalidraw|https://excalidraw.com|tunnel"
  "Draw.io|https://app.diagrams.net|tunnel"
  "NanoKVM|https://usbkvm.sipeed.com|tunnel"
  "Яндекс Диск|https://disk.yandex.ru|direct"
  "Яндекс Телемост|https://telemost.yandex.ru|direct"
  "Яндекс Переводчик|https://translate.yandex.ru|direct"
  "Zona|https://w1.zona.im|direct"
)

install_packages() {
  omarchy pkg add "${PACKAGES[@]}"
  command -v happd >/dev/null || command -v /opt/happ/bin/happd >/dev/null \
    || echo "Happ is not installed: get it from https://happ.su (see README)"
}

set_default_browser() {
  if [ "$(omarchy-default-browser)" = "brave" ]; then
    echo "Brave already the default browser"
  else
    omarchy-default-browser brave
  fi
}

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

# Put the hub's menu entries (omarchy/menu/omarchy-menu.jsonc) into the user's
# menu extension file between markers, leaving everything else in it alone.
setup_menu() {
  local block tmp
  block="$MENU_START
$(cat "$REPO_DIR/omarchy/menu/omarchy-menu.jsonc")
$MENU_END"
  mkdir -p "$(dirname "$MENU_FILE")"
  [ -f "$MENU_FILE" ] || printf '{\n}\n' >"$MENU_FILE"
  tmp=$(mktemp)
  if grep -qF "$MENU_START" "$MENU_FILE"; then
    awk -v start="$MENU_START" -v end="$MENU_END" -v block="$block" '
      index($0, start) { print block; skip = 1; next }
      index($0, end)   { skip = 0; next }
      !skip' "$MENU_FILE" >"$tmp"
  else
    # Insert before the closing brace of the top-level object.
    awk -v block="$block" '
      { lines[NR] = $0 }
      END {
        last = NR; while (last > 0 && lines[last] !~ /^[[:space:]]*}[[:space:]]*$/) last--
        for (i = 1; i <= NR; i++) { if (i == last) print block; print lines[i] }
      }' "$MENU_FILE" >"$tmp"
  fi
  if cmp -s "$tmp" "$MENU_FILE"; then
    rm -f "$tmp"; echo "menu entries up to date"
  else
    cat "$tmp" >"$MENU_FILE" && rm -f "$tmp" && echo "updated menu entries in $MENU_FILE"
    omarchy menu refresh >/dev/null 2>&1 || true
  fi
}

# Point a web app's launcher at the given route; idempotent.
route_webapp() {
  local file="$APPS_DIR/$1.desktop" url="$2" route="$3" exec
  [ -f "$file" ] || return 0
  if [ "$route" = "direct" ]; then
    exec="omarchy-launch-webapp-direct \"$url\""
  else
    exec="omarchy-launch-webapp \"$url\""
  fi
  grep -qxF "Exec=$exec" "$file" && return 0
  sed -i "s|^Exec=.*|Exec=$exec|" "$file"
  echo "web app $1 -> $route"
}

setup_webapps() {
  local app name url route rest
  for name in "${WEBAPPS_REMOVE[@]}"; do
    [ -f "$APPS_DIR/$name.desktop" ] || continue
    OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$name" && echo "removed web app $name"
  done
  for app in "${WEBAPPS_INSTALL[@]}"; do
    name="${app%%|*}" rest="${app#*|}"
    url="${rest%%|*}" route="${rest#*|}"
    if [ -f "$APPS_DIR/$name.desktop" ]; then
      echo "web app $name already installed"
    elif [ -f "$OMARCHY_APPS/$name.desktop" ]; then
      # One of Omarchy's own web apps (X, YouTube): reuse its launcher and icon.
      cp "$OMARCHY_APPS/$name.desktop" "$APPS_DIR/" && echo "restored Omarchy web app $name"
    else
      # Empty icon argument: omarchy fetches the site's own icon. If that
      # fails it creates nothing, so fall back to a generic icon.
      { omarchy-webapp-install "$name" "$url" "" \
          || omarchy-webapp-install "$name" "$url" "applications-internet"; } \
        && echo "installed web app $name" || echo "could not install web app $name"
    fi
    route_webapp "$name" "$url" "$route"
  done
  update-desktop-database "$APPS_DIR" &>/dev/null || true
}

install_packages
set_default_browser
link_dir_contents "$REPO_DIR/omarchy/plugins"    "$HOME/.config/omarchy/plugins"
link_dir_contents "$REPO_DIR/omarchy/hooks/theme-set.d" "$HOME/.config/omarchy/hooks/theme-set.d"
link_dir_contents "$REPO_DIR/omarchy/bin"        "$HOME/.local/bin"
enable_plugins
setup_menu
setup_webapps
omarchy-hook theme-set "$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null)"

echo "done."
