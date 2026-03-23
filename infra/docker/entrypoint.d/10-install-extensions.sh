#!/bin/sh
set -e

EXT_FILE="/home/coder/extensions.txt"

if [ -f "$EXT_FILE" ]; then
  echo "[entrypoint] Installing extensions"
  while IFS= read -r ext; do
    [ -z "$ext" ] && continue
    echo "[entrypoint] → $ext"
    code-server --install-extension "$ext" || true
  done < "$EXT_FILE"
fi

