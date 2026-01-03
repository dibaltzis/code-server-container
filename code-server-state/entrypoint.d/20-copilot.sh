#!/bin/sh
set -e

COPILOT_MARKER="$HOME/.local/share/code-server/.copilot-installed"

if [ -f "$COPILOT_MARKER" ]; then
  echo "[entrypoint] Copilot already installed, skipping"
  exit 0
fi

echo "[entrypoint] Installing GitHub Copilot for code-server"

# Install curl if somehow missing (paranoid but safe)
command -v curl >/dev/null 2>&1 || {
  echo "[entrypoint] curl missing, skipping Copilot"
  exit 0
}

# Run upstream installer
curl -fsSL https://raw.githubusercontent.com/sunpix/howto-install-copilot-in-code-server/main/install-copilot.sh | bash

# Mark as installed (idempotency)
mkdir -p "$(dirname "$COPILOT_MARKER")"
touch "$COPILOT_MARKER"

echo "[entrypoint] GitHub Copilot installation complete"

