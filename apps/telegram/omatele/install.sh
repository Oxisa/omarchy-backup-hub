#!/bin/bash
# omatele installer. Safe to run repeatedly — rewrites only what it owns.
# The shell plugin (Service.qml) runs this at startup so the wiring
# reappears by itself after an `omarchy update` or a fresh checkout.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/omarchy/lib.sh"

templates="$HOME/.config/omarchy/themed"
hooks="$HOME/.config/omarchy/hooks/theme-set.d"

note() { printf 'omatele: %s\n' "$1"; }
warn() { printf 'omatele: %s\n' "$1" >&2; }

mkdir -p "$templates" "$hooks" "$OMATELE_DATA"

install -m 644 "$here/assets/$OMATELE_TPL"      "$templates/$OMATELE_TPL"
install -m 644 "$here/omarchy/lib.sh"           "$OMATELE_DATA/lib.sh"
install -m 755 "$here/omarchy/theme-set-hook"   "$hooks/omatele"

if ! omatele_tg_bin >/dev/null 2>&1; then
  note "no Telegram Desktop client found yet — palette still generated on theme switch"
fi

# Render the palette for the current theme + run the hook now.
if command -v omarchy >/dev/null 2>&1; then
  omarchy theme refresh >/dev/null 2>&1 || warn "'omarchy theme refresh' failed — run it yourself once"
else
  warn "omarchy not on PATH — run 'omarchy theme refresh' once it is"
fi

note "done. Files in $OMATELE_DATA/ : $OMATELE_PALETTE_PLAIN (import this) + $OMATELE_OUT (zip)"
note "One-time in Telegram:  Settings ▸ Chat settings ▸ ⋮ (next to the X) ▸ Create new theme"
note "                       ▸ Import existing theme ▸ pick  $OMATELE_DATA/$OMATELE_PALETTE_PLAIN  ▸ Keep changes"
note "After that every 'omarchy theme set' retints Telegram live (editor open) or on next Telegram start."
exit 0
