#!/usr/bin/env zsh
set -euo pipefail

# Run from repo root
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[iOS] Fast run (no pub, reuse pods, hot reload ready)"

# Ensure artifacts are present (no-op if already cached)
flutter precache --ios

# Skip pub get when not changing pubspec for faster startup
flutter run --debug --no-pub
