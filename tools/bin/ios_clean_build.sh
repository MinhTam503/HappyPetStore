#!/usr/bin/env zsh
set -euo pipefail

# Run from repo root
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

echo "[iOS] Full clean build starting (this will be SLOW)..."

# 1) Flutter clean
flutter clean

# 2) Purge Xcode DerivedData (global)
if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
  rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*
fi

# 3) Purge iOS/Pods caches and symlinks
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks ios/Flutter/Flutter.podspec ios/Flutter/Flutter.framework

# 4) Clean CocoaPods cache (optional, can be long)
if command -v pod >/dev/null 2>&1; then
  pod cache clean --all || true
  pushd ios >/dev/null
  pod deintegrate
  pod install --repo-update
  popd >/dev/null
fi

# 5) Pre-cache Flutter iOS artifacts
flutter precache --ios

# 6) Debug build (faster than release for iteration)
flutter build ios --debug

# 7) Optional: install to connected device
flutter install || true

echo "[iOS] Clean build completed."
