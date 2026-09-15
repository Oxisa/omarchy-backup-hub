#!/bin/bash
# Symlinks this repo's content into place on an Omarchy machine.
# Safe to re-run: existing non-symlink files are backed up once as *.pre-hub.bak.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
REPO_DIR="$(pwd)"

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

link_dir_contents "$REPO_DIR/plugins"            "$HOME/.config/omarchy/plugins"
link_dir_contents "$REPO_DIR/hooks/theme-set.d"   "$HOME/.config/omarchy/hooks/theme-set.d"
link_dir_contents "$REPO_DIR/hypr"                "$HOME/.config/hypr"

echo "done."
