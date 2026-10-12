#!/bin/bash
# omasteam installer. Idempotent; the shell plugin runs it at startup.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/omarchy/lib.sh"

templates="$HOME/.config/omarchy/themed"
hooks="$HOME/.config/omarchy/hooks/theme-set.d"
theme_dir="$(omasteam_theme_dir)"

note() { printf 'omasteam: %s\n' "$1"; }
warn() { printf 'omasteam: %s\n' "$1" >&2; }

mkdir -p "$templates" "$hooks" "$OMASTEAM_DATA" "$theme_dir"

install -m 644 "$here/assets/$OMASTEAM_TPL"    "$templates/$OMASTEAM_TPL"
install -m 644 "$here/omarchy/lib.sh"          "$OMASTEAM_DATA/lib.sh"
install -m 755 "$here/omarchy/theme-set-hook"  "$hooks/omasteam"

# The Millennium theme: manifest (MUST be named skin.json - Millennium's
# scanner in scan.cc/theme_cfg.cc only ever looks for that exact filename,
# "theme.json" is invisible to it) + the (static) recolour CSS under the
# three names Millennium's default patch set injects. colors.css comes from
# the hook.
install -m 644 "$here/assets/skin.json" "$theme_dir/skin.json"
rm -f "$theme_dir/theme.json"   # stale filename from an earlier version of this plugin
for f in libraryroot.custom.css friends.custom.css bigpicture.custom.css; do
  install -m 644 "$here/assets/recolor.css" "$theme_dir/$f"
done
[[ -f "$theme_dir/colors.css" ]] || printf ':root{}\n' > "$theme_dir/colors.css"

if ! command -v millennium >/dev/null 2>&1 && [[ ! -e /usr/lib/millennium ]]; then
  note "Millennium not detected — install it first:  yay -S millennium-bin"
fi

# Render colors.css for the current theme + run the hook.
if command -v omarchy >/dev/null 2>&1; then
  omarchy theme refresh >/dev/null 2>&1 || warn "'omarchy theme refresh' failed — run it once yourself"
fi

note "theme installed at: $theme_dir"
note "Next: restart Steam, then Steam ▸ Millennium ▸ Themes ▸ select \"Omarchy\"."
note "After that every 'omarchy theme set' retints Steam live (Millennium hot-reload)."
exit 0
