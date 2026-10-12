#!/bin/bash
# Reverses install.sh. Leaves Millennium and Steam alone; just removes the
# generated Omarchy theme + the Omarchy wiring.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/omarchy/lib.sh"

rm -f  "$HOME/.config/omarchy/themed/$OMASTEAM_TPL"
rm -f  "$HOME/.config/omarchy/hooks/theme-set.d/omasteam"
rm -f  "$HOME/.local/state/omarchy/current/theme/$OMASTEAM_RENDERED"
rm -rf "$(omasteam_theme_dir)"
rm -rf "$OMASTEAM_DATA"

command -v omarchy >/dev/null 2>&1 && omarchy theme refresh >/dev/null 2>&1 || true
printf 'omasteam: removed. In Steam ▸ Millennium ▸ Themes pick another theme (or Default).\n'
