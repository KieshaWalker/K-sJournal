#!/usr/bin/env bash
# Vercel install step: fetch the Flutter SDK and resolve packages.
set -euo pipefail

FLUTTER_VERSION=3.44.1

if [ ! -d "$HOME/flutter" ]; then
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar xJ -C "$HOME"
fi

# Vercel builds run as root; git refuses the extracted SDK repo otherwise.
git config --global --add safe.directory "$HOME/flutter"

"$HOME/flutter/bin/flutter" pub get
