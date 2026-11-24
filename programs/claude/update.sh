#!/usr/bin/env bash
# Actualiza Claude Code a la última versión (o a la que se pase: ./update.sh 2.1.331)
# bajando su manifiesto de downloads.claude.ai (no pasa por GitHub ni su límite de API).
# Después: home-manager switch --flake ~/.config/home-manager#soka-wsl
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
BASE_URL="https://downloads.claude.ai/claude-code-releases"
VERSION="${1:-$(curl -fsSL "$BASE_URL/latest")}"
curl -fsSL "$BASE_URL/$VERSION/manifest.zst.json" --output manifest.zst.json
echo "Claude Code $VERSION"
