#!/bin/bash
# Reverses install.sh. Leaves Telegram itself on whatever theme it is using —
# tearing that out from under a running client would be a surprise, and you
# may want to keep it. Switch back to a stock theme inside Telegram if not.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/omarchy/lib.sh"

rm -f "$HOME/.config/omarchy/themed/$OMATELE_TPL"
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/omatele"
rm -f "$HOME/.local/state/omarchy/current/theme/$OMATELE_RENDERED"
rm -rf "$OMATELE_DATA"

command -v omarchy >/dev/null 2>&1 && omarchy theme refresh >/dev/null 2>&1 || true
printf 'omatele: removed. Telegram keeps its current look until you pick another theme in it.\n'
